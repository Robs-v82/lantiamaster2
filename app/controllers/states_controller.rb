class StatesController < ApplicationController
    before_action :set_state, only: [:show, :edit, :update, :destroy]
    after_action :stop_index_help, only: [:irco, :icon]
    before_action :require_basic, only: [:icon]
    before_action :require_icon_access, only: [:icon]


    require 'pp'

    def stop_index_help
        User.find(session[:user_id]).update(:index_help=>false)
    end

    def getStates
        states = State.all
        render json: {states: states}
    end

    def getCities
        cities = City.all.sort_by{|city|city.name}
        render json: {cities: cities}
    end

    def index
        @states = State.all
    end

    def load_icon
        myFile = load_icon_params[:file]
        myName = load_icon_params[:year]+"_"+load_icon_params[:quarter]
        myQuarter = Quarter.where(:name=>myName).last
        iconTable = []
        components = [
            "cs",
            "gob",
            "vd",
            "vis"
        ]
        CSV.foreach(myFile, :headers => true) do |row|
          row[:score] = row[myQuarter.name]
          row[:name] = State.where(:code=>row["code"]).last.name
          components.each{|component|
            row[component+"-1"] =  row[component].to_f - row[component+"-1"].to_f 
            row[component+"-4"] =  row[component].to_f - row[component+"-4"].to_f
          }
          helpers.indexLevels.each{|level|
              if row[:score].to_f > level[:floor] && row[:score].to_f < level[:ceiling] 
                  row[:color] = level[:hex]
              end
          }
          iconTable.push(row)
        end
        iconTable.each{|row|
            comparisonArr = []
            State.where(:code=>row["code"]).last.comparison.each{|key|
                comparisonHash = {:name=> State.find(key).shortname}
                myState = iconTable.select{|state| state["code"] == State.find(key).code}.last
                comparisonHash[:score] = myState[:score]
                comparisonArr.push(comparisonHash)
            }
            row[:comparison] = comparisonArr 
            row[:max] = comparisonArr.max_by{|k| k[:score] }[:score]
        }
        @states = State.all.sort_by{|state| state.name}
        Cookie.create(:data=>iconTable, :quarter_id=>myQuarter.id, :category=>"icon")    
        redirect_to "/datasets/load"
    end

    def load_irco
        myName = load_irco_params[:year]+"_"+load_irco_params[:quarter]
        myQuarter = Quarter.where(:name=>myName).last
        back_one_quarter = helpers.back_one_q(myQuarter)
        back_one_year = helpers.back_one_y(myQuarter)
        @evolutionArr = []
        [7,6,5,4,3,2,1,0].each{|x|
            t = (myQuarter.first_day - (x*90).days).strftime('%m-%Y')
            Quarter.all.each{|q|
                if (q.first_day.strftime('%m-%Y')) == t
                    @evolutionArr.push(q)
                end
            } 
        }
        ircoTable = []
        components = [
            "victims",
            "feel_safe"
        ]
        comparisonValues = {}
        State.all.each{|state|
            comparisonHash = {:name=>state.shortname}
            comparisonHash[:score] = ircoOutput(myQuarter, state)[:score]
            comparisonValues[state[:code]] = comparisonHash
        }
        State.all.each{|state|
            placeHash = {}
            placeHash["code"] = state.code
            inputs = ircoOutput(myQuarter, state)
            inputs_back_one_quarter = ircoOutput(back_one_quarter, state)
            inputs_back_one_year = ircoOutput(back_one_year, state)
            placeHash[:score] = inputs[:score]
            placeHash[:name] = state.name
            helpers.indexLevels.each{|level|
              if placeHash[:score].to_f >= level[:floor] && placeHash[:score].to_f < level[:ceiling] 
                  placeHash[:color] = level[:hex]
                  placeHash["nivel"] = level[:name]
              end
            }
            placeHash["tendencia"] = helpers.quarter_score_trend(placeHash[:score], inputs_back_one_quarter[:score], inputs_back_one_year[:score])
            @evolutionArr.each{|q|
                placeHash[q.name] = ircoOutput(q, state)[:score]
            }
            comparisonArr = []
            state.comparison.each{|key|
                comparisonArr.push(comparisonValues[State.find(key).code])
            }
            placeHash[:comparison] = comparisonArr
            placeHash[:max] = comparisonArr.max_by{|k| k[:score] }[:score]
            placeHash[:warnings] = []
            if inputs[:general_victims] > 0.5
                placeHash[:warnings].push("Violencia generalizada")
            end
            # if inputs[:conflict] > inputs[:general_victims]
            #     placeHash[:warnings].push("Conflicto criminal inminente")
            # end
            if inputs[:female_victims] == 1
               placeHash[:warnings].push("Agresiones a mujeres") 
            end
            if inputs[:commercial_killings] == 1
                placeHash[:warnings].push("Agresiones a comercios")
            end
            if inputs[:police_victims] == 1
                placeHash[:warnings].push("Agresiones a autoridades")
            end
            # if inputs[:feel_safe] > 0.5
            #     placeHash[:warnings].push("Percepción de inseguridad")
            # end
            ircoTable.push(placeHash)
        }
        sortedTable = ircoTable.sort_by{|row| -row[:score]}
        rankCount = 0
        sortedTable.each{|x|
            rankCount += 1
            x["rank"] = rankCount
        }
        Cookie.create(:data=>sortedTable, :quarter_id=>myQuarter.id, :category=>"irco")
        redirect_to "/states/irco"
    end

    def irco
        @irco = true
        @indexName = "IRCO"
        @myModel = State
        myCookie = Cookie.where(:category=>"irco").last
        myQuarter = myCookie.quarter
        @current_quarter_strings = helpers.quarter_strings(myQuarter)
        back_one_quarter = helpers.back_one_q(myQuarter) 
        @back_one_q_strings = helpers.quarter_strings(back_one_quarter)
        back_one_year = helpers.back_one_y(myQuarter)
        @back_one_y_strings = helpers.quarter_strings(back_one_year)
        @levels = helpers.indexLevels
        @tableHeader = ["ESTADO", "POSICIÓN", "PUNTAJE", "TENDENCIA"]
        @icon_table = myCookie.data
        @icon_table = @icon_table.sort_by{|state| state["rank"].to_i }
        @screens = [
            {:style=>"hide-on-med-and-down", :width=>"l6", :scopes=>[0..15,16..31]},
            {:style=>"hide-on-large-only", :width=>"s12", :scopes=>[0..31]}
        ]
        @evolutionArr = []
        [7,6,5,4,3,2,1,0].each{|x|
            t = (myQuarter.first_day - (x*90).days).strftime('%m-%Y')
            Quarter.all.each{|q|
                if (q.first_day.strftime('%m-%Y')) == t
                    @evolutionArr.push(q)
                end
            } 
        }
        @indexStringHash = {
            :acronym=>"IRCO",
            :name=>"Índice de Riesgo por Crimen Organizado",
            :placeFrame=>"Estatal",
            :placeNoun=>"estado",
            :noun=>"riesgo"
        }
        @warningStrings = [
            "Violencia generalizada",
            "Agresiones a mujeres",
            "Agresiones a comercios",
            "Agresiones a autoridades",
            # "Conflicto criminal inminente (IRCO estatal)",
            "Agresiones en el transporte de pasajeros (IRCO municipal)"
        ]
        print "****"*100
        print @evolutionArr
    end

    def icon
        @icon = true
        @indexName = "ICon"
        @myModel = State
        myCookie = Cookie.where(:category=>"icon").last
        myQuarter = myCookie.quarter
        @current_quarter_strings = helpers.quarter_strings(myQuarter)
        back_one_quarter = helpers.back_one_q(myQuarter) 
        @back_one_q_strings = helpers.quarter_strings(back_one_quarter)
        back_one_year = helpers.back_one_y(myQuarter)
        @back_one_y_strings = helpers.quarter_strings(back_one_year)
        @levels = helpers.indexLevels
        @tableHeader = ["ESTADO", "POSICIÓN", "PUNTAJE", "TENDENCIA"]
        @icon_table = myCookie.data
        @icon_table = @icon_table.sort_by{|state| state["rank"].to_i }
        @screens = [
            {:style=>"hide-on-med-and-down", :width=>"l6", :scopes=>[0..15,16..31]},
            {:style=>"hide-on-large-only", :width=>"s12", :scopes=>[0..31]}
        ]
        @evolutionArr = []
        [7,6,5,4,3,2,1,0].each{|x|
            t = (myQuarter.first_day - (x*90).days).strftime('%m-%Y')
            Quarter.all.each{|q|
                if (q.first_day.strftime('%m-%Y')) == t
                    @evolutionArr.push(q)
                end
            } 
        }
        @components = [
            {:key=>"cs", :name=>"Conflictividad social", :share=>0.14},
            {:key=>"gob", :name=>"Ingobernabilidad", :share=>0.22},
            {:key=>"vd", :name=>"Violencia con daños colaterales", :share=>0.4},
            {:key=>"vis", :name=>"Violencia con impacto social", :share=>0.24}
        ]
        @indexStringHash = {
            :acronym=>"ICon",
            :name=>"Índice de Conflictividad",
            :placeFrame=>"Estatal",
            :placeNoun=>"estado",
            :noun=>"conflictividad"
        }
        @defStrings = [
            {:name=>"Conflictividad social", :definition=>"Incluye movilizaciones sociales, marchas o manifestaciones, el surgimiento de grupos armados, y huelgas con impacto mediático"},
            {:name=>"Ingobernabilidad", :definition=>"Incluye linchamientos, fugas o motines en centros de readaptación social, bloqueos en vías de comunicación, retenes en carreteras o toma de instalaciones"},
            {:name=>"Violencia con daños colaterales", :definition=>"Incluye rafagueos, balaceras, incendios provocados y robo en carreteras"},
            {:name=>"Violencia con impacto social", :definition=>"Incluye atentados, agresiones o secuestros de figuras públicas, así como casos de trata de personas"}
        ]
        print "****"*100
        print @evolutionArr
    end

    def ircoOutput(quarter, place)
        localVictims = place.victims

        # VICTIMS
        total_victims = helpers.get_quarter_victims(quarter, localVictims)
        victims_index = total_victims/place.population.to_f*100000
        victims_index = Math.log(victims_index+1,100).round(2)
        if victims_index > 1
            victims_index =  1
        end

        # FEMALE
        female_victims = helpers.female_victims(quarter, place, localVictims)
        female_index = 0
        if female_victims
            female_index += 1
        end

        #COMMERCIAL
        commercial_killings = helpers.commercial_killings(quarter, place)
        commercial_index = 0
        if commercial_killings
            commercial_index += 1
        end

        # POLICE
        police_victims = helpers.police_victims(quarter, place, localVictims)
        police_index = 0
        if police_victims
           police_index += 1 
        end

        placeHash = {
            :state=>place.name,
            :general_victims=>victims_index.round(2),
            :female_victims=>female_index.round, 
            :police_victims=>police_index,
            :commercial_killings=>commercial_index,
            # :conflict=>Cookie.where(:category=>"conflict_analysis").last.data[0][place.code].round(2),
            :feel_safe=>(1-(feel_safe(quarter, place)/100)).round(2)
        }
        stateScore = (placeHash[:general_victims]*40)+(placeHash[:female_victims]*10)+(placeHash[:police_victims]*20)+(placeHash[:commercial_killings]*20)+(placeHash[:feel_safe]*10)
        placeHash[:score] = stateScore.round(1)
        return placeHash
    end

    def stateIndexHash
        myName = stateIndexHash_params[:year]+"_"+stateIndexHash_params[:quarter]
        myQuarter = Quarter.where(:name=>myName).last
        indexHash = {}
        State.all.each{|place|
            localVictims = place.victims

            # VICTIMS
            total_victims = helpers.get_quarter_victims(myQuarter, localVictims)
            victims_index = total_victims/place.population.to_f*100000
            victims_index = Math.log(victims_index+1,100).round(2)
            if victims_index > 1
                victims_index =  1
            end

            # FEMALE
            female_victims = helpers.female_victims(myQuarter, place, localVictims)
            female_index = 0
            if female_victims
                female_index += 1
            end

            #COMMERCIAL
            commercial_killings = helpers.commercial_killings(myQuarter, place)
            commercial_index = 0
            if commercial_killings
                commercial_index += 1
            end

            # POLICE
            police_victims = helpers.police_victims(myQuarter, place, localVictims)
            police_index = 0
            if police_victims
               police_index += 1 
            end

            placeHash = {
                :state=>place.name,
                :general_victims=>victims_index.round(2),
                :female_victims=>female_index.round, 
                :police_victims=>police_index,
                :commercial_killings=>commercial_index,
                # :conflict=>Cookie.where(:category=>"conflict_analysis").last.data[0][place.code].round(2),
                :feel_safe=>(1-(feel_safe(myQuarter, place)/100)).round(2)
            }
            # stateScore = (placeHash[:general_victims]*30)+(placeHash[:female_victims]*10)+(placeHash[:police_victims]*10)+(placeHash[:commercial_killings]*10)+(placeHash[:conflict]*20)+(placeHash[:feel_safe]*20)
            stateScore = (placeHash[:general_victims]*40)+(placeHash[:female_victims]*10)+(placeHash[:police_victims]*20)+(placeHash[:commercial_killings]*20)+(placeHash[:feel_safe]*10)
            placeHash[:score] = stateScore.round(1)
            indexHash[place.code] = placeHash
        }
        Cookie.create(:category=>"stateIRCOIndex", :data=>[indexHash], :quarter=>params[:quarter])
        return Cookie.last.data[0]
    end

    def feel_safe(quarter, state)
        ensu = quarter.ensu.download
        ensu = ensu.force_encoding("UTF-8")
        ensuArr = []
        ensu.each_line{|l| line = l.split(","); ensuArr.push(line)}
        ensuArr.each{|x|x.each{|y|y.strip!}}
        l = ensuArr.length-1
        stateEnsuArr = []
        ensuPopulation = 0
        feel_safe = 0
        state.ensu_cities.each{|city|
            (0..l).each{|x|
                if ensuArr[x][0]
                    if ensuArr[x][0] == city and ensuArr[x][1] !=""
                        cityArr = []
                        ensuPopulation += ensuArr[x][1].delete(' ').to_i
                        cityArr.push(ensuArr[x][0],ensuArr[x][1].delete(' ').to_i,ensuArr[x+1][4].to_f)
                        stateEnsuArr.push(cityArr)
                    end
                end
            }
        }
        stateEnsuArr.each{|y|
            myShare = ((y[1].to_f/ensuPopulation.to_f))
            myPoints = myShare*y[2]
            feel_safe += myPoints
        }
        return feel_safe
    end

    def car_theft(quarter, state)
        car_count = 0
        floor = (state.code.to_i*98)-98
        quarter.months.each{|month|
            crime_victim_arr = []
            crime_victim_report = month.crime_victim_report.download
            crime_victim_report = crime_victim_report.force_encoding("UTF-8")
            crime_victim_report.each_line{|l| line = l.split(","); crime_victim_arr.push(line)}
            crime_victim_arr.each{|x|x.each{|y|y.strip!}}
            (41..45).each{|x|
                car_count += crime_victim_arr[floor+x][7].to_i
            }
        }
        return car_count
    end

    def conflict_analysis
        stateHash = {}
        State.all.each{|state|
            myFloat = 0.0
            state.counties.where.not(:name=>"Sin definir").each{|county|
                unless county.population.nil?
                    conflictScore = 0.0
                    county.rackets.each{|racket|
                        racket.rivals.each{|x|
                            rival = Organization.find(x)
                            if county.rackets.include? rival
                                conflictScore += 0.25
                            end
                        }
                    }
                    if conflictScore > 1.0
                        conflictScore = 1.0
                    end
                    countyPop = county.population
                    statePop = state.population
                    share = countyPop/statePop.to_f
                    addition = share*conflictScore
                    myFloat += addition
                end
            }
            stateHash[state.code]= myFloat
        }
        Cookie.create(:data=>[stateHash], :category=>"conflict_analysis")
        redirect_to '/datasets/load'        
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_state
        @state = State.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def state_params
        params.require(:state).permit(:name, :shortname, :code, :population)
    end

    def load_icon_params
        params.require(:query).permit(:year, :quarter, :file)
    end

    def load_irco_params
        params.require(:query).permit(:year, :quarter)
    end

    def stateIndexHash_params
        params.require(:query).permit(:year, :quarter)
    end
end
