class StatesController < ApplicationController
    before_action :set_state, only: [:show, :edit, :update, :destroy]
    require 'pp'

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
        CSV.foreach(myFile, :headers => true) do |row|
          row[:score] = row[myQuarter.name]
          row[:name] = State.where(:code=>row["code"]).last.name
          components = [
            "cs",
            "gob",
            "vd",
            "vis"
          ]
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
        unless Role.where(:name=>"Gobernador").empty?
           governorKey = Role.where(:name=>"Gobernador").last.id 
        end
        myName = load_irco_params[:year]+"_"+load_irco_params[:quarter]
        myQuarter = Quarter.where(:name=>myName).last
        back_one_quarter = helpers.back_one_q(myQuarter)
        back_one_year = helpers.back_one_y(myQuarter)
        @states = State.all.sort_by{|state| state.name }
        @levels = helpers.ircoLevels
        ircoTable = []
        @states.each{|state|
            stateHash = {}
            stateHash[:state] = state
            stateHash[:irco] = ircoOutput(myQuarter, state)

            stateHash[:back_one_quarter_irco]  = ircoOutput(back_one_quarter, state) 
            stateHash[:back_one_year_irco]  = ircoOutput(back_one_year, state)
            stateHash[:trend] = helpers.quarter_score_trend(stateHash[:irco][:score], stateHash[:back_one_quarter_irco][:score], stateHash[:back_one_year_irco][:score]) 
            
            @levels.each {|level|
                if stateHash[:irco][:score] < level[:score]
                    stateHash[:level] = level[:name]
                    stateHash[:color] = level[:color]
                    stateHash[:hex] = level[:hex]
                end
            }

            stateHash[:q1_victims_change] = helpers.variable_change_and_icon(stateHash[:irco][:victims],stateHash[:back_one_quarter_irco][:victims])
            stateHash[:y1_victims_change] = helpers.variable_change_and_icon(stateHash[:irco][:victims],stateHash[:back_one_year_irco][:victims])

            stateHash[:q1_feel_safe_change] = helpers.variable_change_and_icon(stateHash[:irco][:feel_safe],stateHash[:back_one_quarter_irco][:feel_safe])
            stateHash[:y1_feel_safe_change] = helpers.variable_change_and_icon(stateHash[:irco][:feel_safe],stateHash[:back_one_year_irco][:feel_safe])

            stateHash[:q1_stolen_cars_change] = helpers.variable_change_and_icon(stateHash[:irco][:stolen_cars],stateHash[:back_one_quarter_irco][:stolen_cars])
            stateHash[:y1_stolen_cars_change] = helpers.variable_change_and_icon(stateHash[:irco][:stolen_cars],stateHash[:back_one_year_irco][:stolen_cars])
            
            if governorKey
                stateHash[:governor] = state.organizations.where(:league=>"CONAGO").last.members.where(:role_id=>governorKey).last
            end

            stateHash[:evolution_score] = []
            [7,6,5,4,3,2,1,0].each{|x|
                t = (myQuarter.first_day - (x*90).days).strftime('%m-%Y')
                Quarter.all.each{|q|
                    periodHash = {}
                    if (q.first_day.strftime('%m-%Y')) == t
                        periodString = helpers.quarter_strings(q)
                        periodString = periodString[:quarterShort]+"/"+q.name[0..3]
                        periodHash[:string] = periodString
                        q_score = ircoOutput(q, state)[:score]
                        periodHash[:score] = q_score
                        stateHash[:evolution_score].push(periodHash)
                    end
                } 
            }

            stateHash[:comparisonArr] = []
            state.comparison.each{|c|
                comparisonHash = {}
                comparisonHash[:state] = State.find(c)
                comparisonHash[:score] = ircoOutput(myQuarter, comparisonHash[:state])[:score]
                stateHash[:comparisonArr].push(comparisonHash)
            }

            ircoTable.push(stateHash)
        }
        @sortedTable = ircoTable.sort_by{|row| -row[:irco][:score]}
        rankCount = 0
        @sortedTable.each{|x|
            rankCount += 1
            x[:rank] = rankCount
        }
        Cookie.create(:data=>@sortedTable, :quarter_id=>myQuarter.id, :category=>"irco")
        redirect_to "/datasets/load"
    end

    def irco
        @irco = true
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
            :acronym=>"IRCO",
            :name=>"Índice de Riesgo por Crimen Organizado",
            :placeFrame=>"Estatal",
        }
    end

    def icon
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
            :placeFrame=>"Estatal"
        }
    end

    def ircoOutput(quarter, state)
        localVictims = state.victims
        total_victims = helpers.get_quarter_victims(quarter, localVictims)
        victims_index = total_victims/state.population.to_f*100000
        victims_index = Math.log(victims_index+1,100).round(2)
        if victims_index > 1
            victims_index =  1
        end

        current_feel_safe = feel_safe(quarter, state)
        feel_safe_index = 1-(current_feel_safe.to_f/100)

        stolen_cars = car_theft(quarter,state)
        car_theft_index = stolen_cars/state.population.to_f*100000
        car_theft_index = Math.log(car_theft_index+1,200).round(2)
        if car_theft_index > 1
            car_theft_index = 1
        end

        score = ((victims_index*4)+(feel_safe_index*3)+(car_theft_index*3)).round(2)
        ircoHash = {
            :victims=>total_victims,
            :feel_safe=>current_feel_safe,
            :stolen_cars=>stolen_cars,
            :score=>score
        }
        return ircoHash
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
end
