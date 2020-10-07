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
	   	targetCounties = State.find(targetState).counties
	   	undefinedCounty = targetCounties.where(:name=>"Sin definir").last
	   	targetCounties = targetCounties.where.not(:name=>"Sin definir")
	   	targetCounties = targetCounties.sort_by{|county|county.name}
	    targetCounties << undefinedCounty
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
		bigCounties = County.where("population > ?",100000)
		@levels = helpers.ircoLevels
		ircoTable = []
		bigCounties.each{|county|
			countyHash = {}
			countyHash[:county] = county
			countyHash[:irco] = ircoOutput(myQuarter, county)

			countyHash[:back_one_quarter_irco]  = ircoOutput(back_one_quarter, county) 
			countyHash[:back_one_year_irco]  = ircoOutput(back_one_year, county)
			countyHash[:trend] = helpers.quarter_score_trend(countyHash[:irco][:score], countyHash[:back_one_quarter_irco][:score], countyHash[:back_one_year_irco][:score]) 
			
			@levels.each {|level|
				if countyHash[:irco][:score] < level[:score]
					countyHash[:level] = level[:name]
					countyHash[:color] = level[:color]
					countyHash[:hex] =level[:hex]
				end
			}

			countyHash[:q1_victims_change] = helpers.variable_change_and_icon(countyHash[:irco][:victims],countyHash[:back_one_quarter_irco][:victims])
			countyHash[:y1_victims_change] = helpers.variable_change_and_icon(countyHash[:irco][:victims],countyHash[:back_one_year_irco][:victims])

			countyHash[:q1_stolen_cars_change] = helpers.variable_change_and_icon(countyHash[:irco][:stolen_cars],countyHash[:back_one_quarter_irco][:stolen_cars])
			countyHash[:y1_stolen_cars_change] = helpers.variable_change_and_icon(countyHash[:irco][:stolen_cars],countyHash[:back_one_year_irco][:stolen_cars])

            countyHash[:evolution_score] = []
            [7,6,5,4,3,2,1,0].each{|x|
                t = (myQuarter.first_day - (x*90).days).strftime('%m-%Y')
                Quarter.all.each{|q|
                    periodHash = {}
                    if (q.first_day.strftime('%m-%Y')) == t
                        periodString = helpers.quarter_strings(q)
                        periodString = periodString[:quarterShort]+"/"+q.name[0..3]
                        periodHash[:string] = periodString
                        q_score = ircoOutput(q, county)[:score]
                        periodHash[:score] = q_score
                        countyHash[:evolution_score].push(periodHash)
                    end
                } 
            }

			ircoTable.push(countyHash)
		}
		@sortedTable = ircoTable.sort_by{|row| -row[:irco][:score]}
		rankCount = 0
		@sortedTable.each{|x|
			rankCount += 1
			x[:rank] = rankCount
		}
        Cookie.create(:data=>@sortedTable, :quarter_id=>myQuarter.id, :category=>"irco_counties")
        redirect_to "/datasets/load"
	end

	def irco
		@key = Rails.application.credentials.google_maps_api_key
		@countyWise = true
        myCookie = Cookie.where(:category=>"irco_counties").last
        myQuarter = myCookie.quarter		
        @current_quarter_strings = helpers.quarter_strings(myQuarter)
		back_one_quarter = helpers.back_one_q(myQuarter) 
		@back_one_q_strings = helpers.quarter_strings(back_one_quarter)
		back_one_year = helpers.back_one_y(myQuarter)
		@back_one_y_strings = helpers.quarter_strings(back_one_year)

		@selectionFrames = [
  			{caption: "Mayor riesgo", box_id: "high_risk_query_box", name: "high_risk"},
			{caption: "Menor riesgo", box_id: "low_risk_query_box", name: "low_risk"},
			{caption: "Destinos turísticos", box_id: "destinations_query_box", name: "destinations"},
  		]

  		@states = State.all.sort_by{|state| state.name }
  		if session[:destinations]
  			@selectionFrames[2][:checked] = true
  		elsif session[:descendingIndex]
  			@selectionFrames[1][:checked] = true
  		elsif session[:indexCounty] == nil
  			@selectionFrames[0][:checked] = true
  		end
		@levels = helpers.ircoLevels
		bigCounties = County.where("population > ?",100000)
		@tableHeader = ["MUNICIPIO", "POSICIÓN", "PUNTAJE", "TENDENCIA"]

		@sortedTable = myCookie.data

		if session[:descendingIndex]
			@sortedTable = @sortedTable.sort_by{|row| -row[:rank]}
		end

		@sortedTable.each{|x|
			if session[:destinations]
				unless x[:county].destination
					@sortedTable = @sortedTable -[x]
				end
			elsif session[:indexCounty]
				unless x[:county].state.id == session[:indexCounty]
					@sortedTable = @sortedTable -[x]
				end
			end
		}

		@page_scope = 20
		unless session[:indexPage]
			session[:indexPage] = 1
		end
		@data_length = @sortedTable.length
	 	if session[:indexPage] >= (@data_length/@page_scope.to_f).ceil
	 		@finalPage = true
	 	end
	 	if session[:indexPage] > @data_length/@page_scope
	 		@end = @data_length
	 	else
	 		@end = @page_scope * session[:indexPage]
	 	end
	 	@beginning = 1+((session[:indexPage]-1)*@page_scope)
 		@pageQuery = @sortedTable[@beginning - 1, @page_scope]
	end

  	def ircoOutput(quarter, county)
  	
  		localVictims = county.victims
  		total_victims = helpers.get_quarter_victims(quarter, localVictims)
 		victims_index = total_victims/county.population.to_f*100000
		victims_index = Math.log(victims_index+1,100).round(2)
		if victims_index > 1
			victims_index =  1
		end

		stolen_cars = car_theft(quarter,county)
 		car_theft_index = stolen_cars/county.population.to_f*100000
		car_theft_index = Math.log(car_theft_index+1,200).round(2)
		if car_theft_index > 1
			car_theft_index = 1
		end

  		score = ((victims_index*6)+(car_theft_index*4)).round(2)
  		ircoHash = {
  			:victims=>total_victims,
  			:stolen_cars=>stolen_cars,
  			:score=>score
  		}
  		return ircoHash
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

	private

	def getCounties_params
    params.require(:query).permit(:state_id)
  	end

    def load_irco_params
        params.require(:query).permit(:year, :quarter)
        
    end
end
