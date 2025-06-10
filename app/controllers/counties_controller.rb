class CountiesController < ApplicationController

  before_action :require_premium, only: [:irco]
	before_action :require_irco_access, only: [:irco]
  require 'csv'

	def getCounties
	    targetState = getCounties_params[:state_id].to_i
	   	targetCounties = State.find(targetState).counties
	   	undefinedCounty = targetCounties.where(:name=>"Sin definir").last
	   	targetCounties = targetCounties.where.not(:name=>"Sin definir")
	   	targetCounties = targetCounties.sort_by{|county|county.name}
	    targetCounties << undefinedCounty
	    render json: {counties: targetCounties}		
	end


	def getCheckboxCounties
		targetState = params[:id]
	   	targetCounties = State.find(targetState).counties.reject { |county| county.victims.length < 5 }
	   	targetCounties = targetCounties.sort_by{|county|county.name}
	    print "******"*1000
	    print targetCounties
	    render json: {counties: targetCounties}
	end

	def low_risk
		session[:indexPage] = nil
		unless session[:descendingIndex]
			session[:descendingIndex] = true
		end
		if session[:indexCounty]
			session[:indexCounty] = nil
		end
		session[:destinations] = nil
		redirect_to '/counties/irco'
	end

	def high_risk
		session[:indexPage] = nil
		if session[:destinations]
			session[:destinations] = nil
		elsif session[:indexCounty]
			session[:indexCounty] = nil
		end
		session[:descendingIndex] = nil
		redirect_to '/counties/irco'
	end

	def destinations
		session[:indexPage] = nil
		session[:destinations] = true
		if session[:descendingIndex]
			session[:descendingIndex] = nil
		elsif session[:indexCounty]
			session[:indexCounty] = nil
		end
		redirect_to '/counties/irco'
	end

	def set_index_county
		if session[:descendingIndex]
			session[:descendingIndex] = nil
		elsif session[:destinations]
			session[:destinations] = nil
		end
		session[:indexCounty] = params[:id].to_i
		redirect_to '/counties/irco'
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
            "victims"
        ]
        comparisonValues = {}
        bigCounties = helpers.bigCounties
        bigCounties.each{|place|
            comparisonHash = {:name=>place.shortname}
            comparisonHash[:score] = ircoOutput(myQuarter, place)[:score]
            comparisonValues[place.full_code] = comparisonHash
        }
        bigCounties.each{|place|
            placeHash = {}
            placeHash["code"] = place.full_code
            inputs = ircoOutput(myQuarter, place)
            inputs_back_one_quarter = ircoOutput(back_one_quarter, place)
            inputs_back_one_year = ircoOutput(back_one_year, place)
            placeHash[:score] = inputs[:score]
            placeHash[:name] = place.shortname
            placeHash[:state] = place.state.shortname
            helpers.indexLevels.each{|level|
              if placeHash[:score].to_f >= level[:floor] && placeHash[:score].to_f < level[:ceiling] 
                  placeHash[:color] = level[:hex]
                  placeHash["nivel"] = level[:name]
              end
            }
            placeHash["tendencia"] = helpers.quarter_score_trend(placeHash[:score], inputs_back_one_quarter[:score], inputs_back_one_year[:score])
            @evolutionArr.each{|q|
                placeHash[q.name] = ircoOutput(q, place)[:score]
            }
            comparisonArr = []
            place.comparison.each{|key|
                comparisonArr.push(comparisonValues[County.find(key).full_code])
            }
            placeHash[:comparison] = comparisonArr
            placeHash[:max] = comparisonArr.max_by{|k| k[:score] }[:score]
           placeHash[:warnings] = []
           if inputs[:general_victims] > 0.5
                placeHash[:warnings].push("Violencia generalizada")
            end
            if inputs[:female_victims] == 1
               placeHash[:warnings].push("Agresiones a mujeres") 
            end
            if inputs[:commercial_killings] == 1
                placeHash[:warnings].push("Agresiones a comercios")
            end
            if inputs[:police_victims] == 1
                placeHash[:warnings].push("Agresiones a autoridades")
            end
            if inputs[:passenger_killings] == 1
                placeHash[:warnings].push("Agresiones en el transporte de pasajeros")
            end
            ircoTable.push(placeHash)
        }
        sortedTable = ircoTable.sort_by{|row| -row[:score]}
        rankCount = 0
        sortedTable.each{|x|
            rankCount += 1
            x["rank"] = rankCount
        }
        Cookie.create(:data=>sortedTable, :quarter_id=>myQuarter.id, :category=>"irco_counties")
        redirect_to "/counties/irco"
    end

    def irco
        @irco = true
        @indexName = "IRCO"
        @countyWise = true
        @myModel = County
        myQuarter = Cookie.where(:category=>"irco_counties").last.quarter
        @myQuarter = myQuarter
        @current_quarter_strings = helpers.quarter_strings(myQuarter)
        back_one_quarter = helpers.back_one_q(myQuarter) 
        @back_one_q_strings = helpers.quarter_strings(back_one_quarter)
        back_one_year = helpers.back_one_y(myQuarter)
        @back_one_y_strings = helpers.quarter_strings(back_one_year)
        @levels = helpers.indexLevels
        @tableHeader = ["MUNICIPIO", "POSICIÓN", "PUNTAJE", "TENDENCIA"]
        @icon_table = Cookie.where(:category=>"irco_counties").last.data
        @icon_table = @icon_table.sort_by{|state| state["rank"].to_i }

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

        ]
        @indexStringHash = {
            :acronym=>"IRCO",
            :name=>"Índice de Riesgo por Crimen Organizado",
            :placeFrame=>"Estatal",
            :placeNoun=>"municipio",
            :noun=>"riesgo"
        }
        @critical_table = []
        @icon_table.map{|row|
        	if row["nivel"] == "Crítico"
        		@critical_table.push(row)
        	end
        }
        @criticalScreens = [
            {:style=>"hide-on-med-and-down", :width=>"l6", :scopes=>[0..@critical_table.length/2,@critical_table.length/2+1..@critical_table.length]},
            {:style=>"hide-on-large-only", :width=>"s12", :scopes=>[0..@critical_table.length]}
        ]

        @destination_table = []
        @icon_table.map{|row|
        	if County.where(:full_code=>row["code"]).last.destination == true
        		@destination_table.push(row)
        	end
        }
        @destinationScreens = [
            {:style=>"hide-on-med-and-down", :width=>"l6", :scopes=>[0..@destination_table.length/2,@destination_table.length/2+1..@destination_table.length]},
            {:style=>"hide-on-large-only", :width=>"s12", :scopes=>[0..@destination_table.length]}
        ]
        @warningStrings = [
            "Violencia generalizada",
            "Agresiones a mujeres",
            "Agresiones a comercios",
            "Agresiones a autoridades",
            "Conflicto criminal inminente (IRCO estatal)",
            "Agresiones en el transporte de pasajeros (IRCO municipal)"
        ]
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

      passenger_killings = helpers.passenger_killings(quarter, place)
      passenger_index = 0
      if passenger_killings
        passenger_index += 1
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
          :passenger_killings=>passenger_index,
          :commercial_killings=>commercial_index,
      }
      placeScore = (placeHash[:general_victims]*40)+(placeHash[:female_victims]*10)+(placeHash[:police_victims]*20)+(placeHash[:commercial_killings]*20)+(placeHash[:passenger_killings]*10)
      placeHash[:score] = placeScore.round(1)
      return placeHash
      
    end

	def car_theft(quarter, county)
  		myYear = quarter.year.name
  		car_count = 0
  		file_name = 'public/carTheft/'+county.full_code+'.csv'
  		keyArr = [
  			{:key=>"1", :numbers=>[9,10,11]},
  			{:key=>"2", :numbers=>[12,13,14]},
  			{:key=>"3", :numbers=>[15,16,17]},
  			{:key=>"4", :numbers=>[18,19,20]}
  		]
  		keyArr.each{|k|
  			if k[:key] == quarter.name[6]
  				CSV.foreach(file_name) do |row|
  					if row[0] == myYear
  						k[:numbers].each{|n|
  							car_count += row[n].to_i
  						}
  					end
  				end
  			end
  		}
  		return car_count
  	end

	def autocomplete
	    myCounties = helpers.bigCounties
	    matches = []
	    nameMatches = myCounties.select{|county| helpers.bob_decode(county.name).downcase.include? helpers.bob_decode(params[:myString]).downcase}
	    matches.append(*nameMatches)
	    stateMatches = myCounties.select{|county| helpers.bob_decode(county.state.name).downcase.include? helpers.bob_decode(params[:myString]).downcase}
	    matches.append(*stateMatches)
	    acronymMatches = myCounties.select{|county| helpers.bob_decode(county.state.shortname).downcase.include? helpers.bob_decode(params[:myString]).downcase}
	    matches.append(*acronymMatches)
	    shortnameMatches = myCounties.select{|county| helpers.bob_decode(county.shortname).downcase.include? helpers.bob_decode(params[:myString]).downcase}
	    matches.append(*shortnameMatches)
	    matches.uniq!
	 	if params[:myString] == 'Xp987jy' || params[:myString].length < 3
	 		matchTable = nil
	 	elsif matches.empty?
	 		matchTable = ["none"]
	 	elsif matches.length >= 1 && matches.length <= 10
		    matches = matches.pluck(:full_code)
		    icon_table = Cookie.where(:category=>"irco_counties").last.data
		    matchTable = []
	        icon_table.map{|row|
	        	if matches.include? row["code"]
	        		matchTable.push(row)
	        	end
	        }
	    end
	    render json: matchTable
	end

    def testmap
        @stateCode = 16  
    end

    def send_file
        recipient = User.find(session[:user_id])
        current_date = Date.today.strftime
        downloadCounter = recipient.downloads
        downloadCounter += 1
        recipient.update(:downloads=>downloadCounter)
        myCookie = Cookie.where(:category=>"irco_counties").last
        # myCookie = Cookie.joins(:quarter).where(category: "irco_counties", quarters: { name: "2024_Q4" }).last
        q = Quarter.find(myCookie[:quarter_id]).name
        file_name = "IRCO_Municipal_"+q+"_.csv"
        @icon_table = myCookie.data
        @icon_table = @icon_table.sort_by{|county| county["rank"].to_i }
        def send_irco_file        
            CSV.generate do |writer|
                writer.to_io.write "\uFEFF"
                header = ['MUNICIPIO','POSICIÓN','PUNTAJE','NIVEL','TENDENCIA',"Violencia generalizada","Agresiones a mujeres","Agresiones a comercios","Agresiones a autoridades","Agresiones en el transporte de pasajeros"]
                writer << header
                @icon_table.each do |county|
                    row = []
                    row.push(county[:name])
                    row.push(county["rank"])
                    row.push(county[:score])
                    row.push(county["nivel"])
                    row.push(county["tendencia"])
                     header[5..-1].each do |warning|
                        if county[:warnings].include? warning
                            row.push(1)
                        else
                            row.push(0)
                        end
                     end
                    writer << row
                end
            end
        end
            
        myFile = send_irco_file
        respond_to do |format|
            format.html
            format.csv { send_data myFile, filename: file_name}
        end        
    end

	private

	def getCounties_params
    params.require(:query).permit(:state_id)
  	end

    def load_irco_params
        params.require(:query).permit(:year, :quarter)
        
    end
end
