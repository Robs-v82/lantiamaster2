class CountiesController < ApplicationController

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
        bigCounties.all.each{|place|
            # comparisonHash = {:name=>place.shortname}
            # comparisonHash[:score] = ircoOutput(myQuarter, place)[:score]
            # comparisonValues[place[:code]] = comparisonHash
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
            # comparisonArr = []
            # place.comparison.each{|key|
            #     comparisonArr.push(comparisonValues[State.find(key).code])
            # }
            # placeHash[:comparison] = comparisonArr
            # placeHash[:max] = comparisonArr.max_by{|k| k[:score] }[:score]
            placeHash[:femaleViolence] = female_victims(myQuarter, place)
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
    end

  	def ircoOutput(quarter, county)
  		localVictims = county.victims
  		total_victims = helpers.get_quarter_victims(quarter, localVictims)
 		victims_index = total_victims/county.population.to_f*100000
		victims_index = Math.log(victims_index+1,100).round(2)
		if victims_index > 1
			victims_index =  1
		end

  		score = ((victims_index*10)).round(2)
  		ircoHash = {
  			:victims=>total_victims,
  			:score=>score*10
  		}
  		return ircoHash
  	end

    def female_victims(quarter, place)
        localVictims = place.victims
        quarterVictims = quarter.victims
        femaleQuarterVictims = localVictims.merge(quarterVictims).where(:gender=>"FEMENINO").length
        previousYear = []
        [3,2,1].each{|x|
            t = (quarter.first_day - (x*90).days).strftime('%m-%Y')
            Quarter.all.each{|q|
                if (q.first_day.strftime('%m-%Y')) == t
                   previousYear.push(q)
                end
            } 
        }
        femaleYearVictims = femaleQuarterVictims
        previousYear.each{|q|
            quarterVictims = q.victims
            thisQuarteFemaleVictims = localVictims.merge(quarterVictims).where(:gender=>"FEMENINO").length
            femaleYearVictims += thisQuarteFemaleVictims
        }
        femaleViolence = false
        print femaleQuarterVictims 
        if (femaleQuarterVictims/place.population.to_f)*100000 > 1
            femaleViolence = true 
        elsif (femaleYearVictims/place.population.to_f)*100000 > 4
            femaleViolence = true                     
        end
        return femaleViolence
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

	private

	def getCounties_params
    params.require(:query).permit(:state_id)
  	end

    def load_irco_params
        params.require(:query).permit(:year, :quarter)
        
    end
end
