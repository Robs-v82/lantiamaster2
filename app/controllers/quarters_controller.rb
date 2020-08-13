class QuartersController < ApplicationController
  	
  	require "pp"
  	
  	def ispyv

	  	# DEFINE HEADER AND QUARTER
	  	@myQuarter = Quarter.where(:name=>"2019_Q4").last
	  	@current_quarter_strings = quarter_strings(@myQuarter)

	  	key_one_q = @myQuarter.id-1
	  	back_one_q = Quarter.find(key_one_q)
	  	key_one_y = @myQuarter.id-4
	  	back_one_y = Quarter.find(key_one_y) 

	  	@back_one_q_strings = quarter_strings(back_one_q)
	  	@back_one_y_strings = quarter_strings(back_one_y)


	  	# BUILD TABLE
	  	@states = State.all.sort
	  	@ispyvTable = []
	  	@states.each {|state|
	  		stateHash = {}
	  		stateHash[:name] = state.name
	  		stateHash[:population] = state.population
			
			stateHash[:current_feel_safe] = feel_safe(@myQuarter, state)
			stateHash[:back_one_q_feel_safe] = feel_safe(back_one_q, state)
			stateHash[:back_one_y_feel_safe] = feel_safe(back_one_y, state)
			
			stateHash[:current_car_theft] = car_theft(@myQuarter, state)
			stateHash[:back_one_q_car_theft] = car_theft(back_one_q, state)
			stateHash[:back_one_y_car_theft] = car_theft(back_one_y, state)

			stateHash[:current_number_of_victims] = get_quarter_victims(@myQuarter, state)
			stateHash[:back_one_q_number_of_victims] = get_quarter_victims(back_one_q, state)
			stateHash[:back_one_y_number_of_victims] = get_quarter_victims(back_one_y, state)

			# CURRENT ISPYV SCORE
			current_stolen_cars = car_theft(@myQuarter, state)
			car_theft_index = current_stolen_cars/state.population.to_f*100000
			car_theft_index = Math.log(car_theft_index+1,200).round(2)

			total_victims = get_quarter_victims(@myQuarter, state)
			victims_index = total_victims/state.population.to_f*100000
			victims_index = Math.log(victims_index+1,100).round(2)
			current_victims = total_victims
			
			feel_safe_index = 1-(stateHash[:current_feel_safe].to_f/100)
			feel_safe_pop = 1-(stateHash[:current_feel_safe].to_f/100)
			current_feel_safe_float = feel_safe_pop
			current_feel_safe_index = (feel_safe_pop*100).round()

			ispyv_score = ((victims_index*4)+(car_theft_index*3)+(feel_safe_index*3)).round(2)

			evolution_score = []
			[7,6,5,4,3,2,1,0].each{|x|
				id = @myQuarter.id
				this_quarter = Quarter.find(id-x)
				periodString = quarter_strings(this_quarter)
				periodString = periodString[:quarterShort]+"/"+this_quarter.name[0..3]
				this_quarter_score = this_quarter_ispyv(this_quarter, state)
				periodArr = [periodString,this_quarter_score]
				evolution_score.push(periodArr)
			}

			# ONE Q ISPYV SCORE
			q1_stolen_cars = car_theft(back_one_q, state)
			car_theft_index = q1_stolen_cars/state.population.to_f*100000
			car_theft_index = Math.log(car_theft_index+1,200).round(2)
			q1_stolen_cars_change = (((current_stolen_cars - q1_stolen_cars)/q1_stolen_cars.to_f)*100).round(1)
			if q1_stolen_cars_change < 0
				q1_stolen_cars_icon = "arrow_downward"
				q1_stolen_cars_color = "light-green"
			elsif q1_stolen_cars_change == 0
				q1_stolen_cars_icon = "drag_handle"
				q1_stolen_cars_color = "grey"
			else
				q1_stolen_cars_icon = "arrow_upward"
				q1_stolen_cars_color = "red"	
			end

			total_victims = get_quarter_victims(back_one_q, state)
			victims_index = total_victims/state.population.to_f*100000
			victims_index = Math.log(victims_index+1,100).round(2)
			q1_victims_change = ((current_victims - total_victims)/total_victims.to_f).round(1)
			if q1_victims_change < 0
				q1_victims_change_icon = "arrow_downward"
				q1_victims_change_color = "light-green"
			elsif q1_victims_change == 0
				q1_victims_change_icon = "drag_handle"
				q1_victims_change_color = "grey"
			else
				q1_victims_change_icon = "arrow_upward"
				q1_victims_change_color = "red"	
			end

			feel_safe_index = 1-(stateHash[:back_one_q_feel_safe].to_f/100)
			feel_safe_pop = 1-(stateHash[:back_one_q_feel_safe].to_f/100)
			feel_safe_change_q1 = ((current_feel_safe_float - feel_safe_pop)*100).round(1)
			back_one_q_ispyv_score = ((victims_index*4)+(car_theft_index*3)+(feel_safe_index*3)).round(2)
			
			if feel_safe_change_q1 < 0
				feel_safe_change_q1_icon = "arrow_downward"
				feel_safe_change_q1_color = "light-green"
			elsif feel_safe_change_q1 == 0
				feel_safe_change_q1_icon = "drag_handle"
				feel_safe_change_q1_color = "grey"
			else
				feel_safe_change_q1_icon = "arrow_upward"
				feel_safe_change_q1_color = "red"				
			end

			# ONE Y ISPYV SCORE
			y1_stolen_cars = car_theft(back_one_y, state)
			car_theft_index = y1_stolen_cars/state.population.to_f*100000
			car_theft_index = Math.log(car_theft_index+1,200).round(2)
			y1_stolen_cars_change = (((current_stolen_cars - y1_stolen_cars)/y1_stolen_cars.to_f)*100).round(1)

			if y1_stolen_cars_change < 0
				y1_stolen_cars_icon = "arrow_downward"
				y1_stolen_cars_color = "light-green"
			elsif y1_stolen_cars_change == 0
				y1_stolen_cars_icon = "drag_handle"
				y1_stolen_cars_color = "grey"
			else
				y1_stolen_cars_icon = "arrow_upward"
				y1_stolen_cars_color = "red"	
			end

			total_victims = get_quarter_victims(back_one_y, state)
			victims_index = total_victims/state.population.to_f*100000
			victims_index = Math.log(victims_index+1,100).round(2)
			y1_victims_change = ((current_victims - total_victims)/total_victims.to_f).round(1)
			if y1_victims_change < 0
				y1_victims_change_icon = "arrow_downward"
				y1_victims_change_color = "light-green"
			elsif y1_victims_change == 0
				y1_victims_change_icon = "drag_handle"
				y1_victims_change_color = "grey"
			else
				y1_victims_change_icon = "arrow_upward"
				y1_victims_change_color = "red"	
			end

			feel_safe_index = 1-(stateHash[:back_one_y_feel_safe].to_f/100)
			feel_safe_pop = 1-(stateHash[:back_one_y_feel_safe].to_f/100)
			feel_safe_change_y1 = ((current_feel_safe_float - feel_safe_pop)*100 ).round(1)
			back_one_y_ispyv_score = ((victims_index*4)+(car_theft_index*3)+(feel_safe_index*3)).round(2)
			if feel_safe_change_y1 < 0
				feel_safe_change_y1_icon = "arrow_downward"
				feel_safe_change_y1_color = "light-green"
			elsif feel_safe_change_y1 == 0
				feel_safe_change_y1_icon = "drag_handle"
				feel_safe_change_y1_color = "grey"
			else
				feel_safe_change_y1_icon = "arrow_upward"
				feel_safe_change_y1_color = "red"				
			end

			change = (ispyv_score - back_one_q_ispyv_score) + (ispyv_score - back_one_y_ispyv_score)

			if ispyv_score < 4
				level = "Moderado"
				color = "light-green"
			elsif ispyv_score < 5
				level = "Medio"
				color = "yellow"
			elsif ispyv_score < 6.5
				level = "Alto"
				color = "orange"	
			else
				level = "Crítico"
				color = "red"			
			end

			if change  < -0.5
				trend_icon = "expand_more"
				trend = "Mejora"
			elsif change < 0.5
				trend_icon = "drag_handle"
				trend = "Estable"
			else
				trend_icon = "expand_less"
				trend = "Deterioro"
			end	

			governorKey = Role.where(:name=>"Gobernador").last.id
			governor = state.organizations.where(:league=>"CONAGO").last.members.where(:role_id=>governorKey).last

			

			state.comparison.each{}
			
			finalHash = {:object=>state,
				:name=> state.name,
				:population=> state.population,
				:shortname => state.shortname,
				:governor => governor,
				:car_theft => car_theft_index,
				:current_stolen_cars => current_stolen_cars,
				:q1_stolen_cars_change => q1_stolen_cars_change.abs,
				:q1_stolen_cars_icon => q1_stolen_cars_icon,
				:q1_stolen_cars_color => q1_stolen_cars_color,
				:y1_stolen_cars_change => y1_stolen_cars_change.abs,
				:y1_stolen_cars_icon => y1_stolen_cars_icon,
				:y1_stolen_cars_color => y1_stolen_cars_color,				
				:victims => victims_index,
				:current_victims => current_victims,
				:q1_victims_change => q1_victims_change.abs,
				:q1_victims_change_icon => q1_victims_change_icon,
				:q1_victims_change_color => q1_victims_change_color,				
				:y1_victims_change => y1_victims_change.abs,
				:y1_victims_change_icon => y1_victims_change_icon,
				:y1_victims_change_color => y1_victims_change_color,
				:feel_safe => current_feel_safe_index,
				:feel_safe_change_q1=> feel_safe_change_q1.abs,
				:feel_safe_change_y1=>feel_safe_change_y1.abs,
				:ispyv_score => ispyv_score,
				:level=> level,
				:color => color,
				:change => change,
				:trend => trend,
				:trend_icon => trend_icon,
				:feel_safe_change_q1_icon => feel_safe_change_q1_icon,
				:feel_safe_change_q1_color => feel_safe_change_q1_color,
				:feel_safe_change_y1_icon => feel_safe_change_y1_icon,
				:feel_safe_change_y1_color => feel_safe_change_y1_color,
				:evolution_score => evolution_score
			}
			print "******GOBERNADOR: "
			print finalHash[:governor].firstname
			@ispyvTable.push(finalHash)
		}
		rankArr = @ispyvTable.sort_by {|hz| -hz[:ispyv_score]}
		rankCount = 0
		rankArr.each{|x|
			rankCount += 1
			@ispyvTable.each{|z|
				if z[:name] == x[:name]
					z[:rank] = rankCount
				end 
			}
		} 
		@tableHeader = ["ENTIDAD FEDERATIVA", "PUNTAJE", "NIVEL", "TENDENCIA"]

		@comparisonTable = []
		State.all.sort.each{|state|
			generalArr = []
			stateArr = []
			state_short = state.shortname.upcase
			stateArr.push(state_short)
			state_score = @ispyvTable[state.id-1][:ispyv_score]			
			stateArr.push(state_score)
			generalArr.push(stateArr)
			state.comparison.each{|x|
				stateArr = []
				state_short = State.find(x).shortname.upcase
				stateArr.push(state_short)
				state_score = @ispyvTable[x-1][:ispyv_score]
				stateArr.push(state_score)
				generalArr.push(stateArr)
			}
			@comparisonTable.push(generalArr)
		}
  	end

  	def this_quarter_ispyv(quarter, state)
  		
  		current_stolen_cars = car_theft(quarter, state)
 		car_theft_index = current_stolen_cars/state.population.to_f*100000
		car_theft_index = Math.log(car_theft_index+1,200).round(2)

  		total_victims = get_quarter_victims(quarter, state)
 		victims_index = total_victims/state.population.to_f*100000
		victims_index = Math.log(victims_index+1,100).round(2)

  		current_feel_safe = feel_safe(quarter, state)
  		feel_safe_index = 1-(current_feel_safe.to_f/100)

  		ispyv_score = ((victims_index*4)+(car_theft_index*3)+(feel_safe_index*3)).round(2)
  		return ispyv_score

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

  	def quarter_strings(quarter)
	  	quarterString = quarter.name[5..6]
	  	if quarterString == "Q1"
	  		quarterText = "Primer trimestre"
	  		quarterShort = "T1"
	  	elsif quarterString == "Q2"
	  		quarterText = "Segundo trimestre"
	  		quarterShort = "T2"
	  	elsif quarterString == "Q3"
	  		quarterText = "Tercer trimestre"
	  		quarterShort = "T3"
	  	elsif quarterString == "Q4"
	  		quarterText = "Cuarto trimestre"
	  		quarterShort = "T4"
	  	end
	  	myDate = quarter.first_day
	  	myHash = {:quarterText=>quarterText, :quarterShort=>quarterShort, :quarterDate=>myDate}
	  	return myHash
  	end

  	def get_quarter_victims(quarter, state)
  		number_of_victims = quarter.victims.merge(state.victims).length 
  		return number_of_victims
  	end

end
