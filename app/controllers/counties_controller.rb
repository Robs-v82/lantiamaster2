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
		bigCounties = helpers.bigCounties
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
        }
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
