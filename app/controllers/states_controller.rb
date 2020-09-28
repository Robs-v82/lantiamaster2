class StatesController < ApplicationController
    before_action :set_state, only: [:show, :edit, :update, :destroy]
  
    def api
        myHash = {}

        myYear = Year.where(:name=>"2020")
        myPeriod = helpers.get_specific_months(myYear, "victims").last
        myHash[:update] = myPeriod.first_day

        topKillings = myPeriod.killings
        topKillings = topKillings.sort_by{|k| -k.killed_count}
        myHash[:killings] = topKillings[0,5]



        stateArr = []
        State.all.each{|state|
            stateHash = {}
            stateHash[:code] = state.code
            stateHash[:name] = state.name
            stateHash[:shortname] = state.shortname
            stateHash[:victims] = myPeriod.victims.merge(state.victims).length 
            stateArr.push(stateHash)
        }
        myHash[:states] = stateArr
        render json: myHash
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

    def irco
        @key = Rails.application.credentials.google_maps_api_key
        myQuarter = Quarter.where(:name=>"2019_Q4").last
        @current_quarter_strings = helpers.quarter_strings(myQuarter)
        back_one_quarter = helpers.back_one_q(myQuarter) 
        @back_one_q_strings = helpers.quarter_strings(back_one_quarter)
        back_one_year = helpers.back_one_y(myQuarter)
        @back_one_y_strings = helpers.quarter_strings(back_one_year)

        @states = State.all.sort_by{|state| state.name }

        @levels = helpers.ircoLevels
        @tableHeader = ["ESTADO", "POSICIÓN", "PUNTAJE", "TENDENCIA"]

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
                end
            }

            stateHash[:q1_victims_change] = helpers.variable_change_and_icon(stateHash[:irco][:victims],stateHash[:back_one_quarter_irco][:victims])
            stateHash[:y1_victims_change] = helpers.variable_change_and_icon(stateHash[:irco][:victims],stateHash[:back_one_year_irco][:victims])

            stateHash[:q1_stolen_cars_change] = helpers.variable_change_and_icon(stateHash[:irco][:stolen_cars],stateHash[:back_one_quarter_irco][:stolen_cars])
            stateHash[:y1_stolen_cars_change] = helpers.variable_change_and_icon(stateHash[:irco][:stolen_cars],stateHash[:back_one_year_irco][:stolen_cars])
            
            ircoTable.push(stateHash)
        }
        @sortedTable = ircoTable.sort_by{|row| -row[:irco][:score]}
        rankCount = 0
        @sortedTable.each{|x|
            rankCount += 1
            x[:rank] = rankCount
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

        stolen_cars = car_theft(quarter,state)
        car_theft_index = stolen_cars/state.population.to_f*100000
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
end
