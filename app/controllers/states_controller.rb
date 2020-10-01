class StatesController < ApplicationController
    before_action :set_state, only: [:show, :edit, :update, :destroy]
    require 'pp'

    def loadApi
        myHash = {}

        # LAST UPDATE
        validKillings = []
        Killing.all.each {|k|
            if k.event.event_date
                validKillings.push(k)
            end
        }
        lastKilling = validKillings.all.sort_by{|k| k.event.event_date}.last
        thisMonth = Event.find(lastKilling.event_id).month
        lastDay = Event.find(lastKilling.event_id).event_date

        myHash[:lastUpdate] = Date.civil(lastDay.year, lastDay.month, -1)

        # TOTAL VICTIMS PER YEAR (WITH ESTIMATE FOR CURRENT YEAR)
        myYears = helpers.get_regular_years
        thisYear = Year.where(:name=>Time.now.year.to_s).last
        victimYearsArr = []
        myYears.each{|year|
            yearHash = {}
            yearHash[:year] = year.name.to_i
            if year != thisYear
                yearHash[:victims] = year.victims.length
                yearHash[:estimate] = false
            else
                n = helpers.get_specific_months([thisYear], "victims").length
                unless n == 0
                    yearHash[:victims] = year.victims.length*(12/n)
                    if n == 12
                        yearHash[:estimate] = false        
                    else
                        yearHash[:estimate] = true
                    end
                end
            end
            victimYearsArr.push(yearHash)
        }
        myHash[:years] = victimYearsArr

        # MONTHLY VICITMS FOR 5 MOST VIOLENT STATE (PREVIOUS 12 MONTHS) 
        topStatesArr = []
        State.all.each{|state|
            stateHash = {}
            stateHash[:code] = state.code
            stateHash[:name] = state.name
            stateHash[:shortname] = state.shortname
            r = 11..0
            stateHash[:totalVictims] = 0
            stateHash[:months] = []
            localVictims = state.victims
            (r.first).downto(r.last).each {|x|
                monthHash = {}
                monthHash[:month] = (thisMonth.first_day - (x*28).days).strftime('%m-%Y')
                monthHash[:victims] = Month.where(:name=>(thisMonth.first_day - (x*28).days).strftime('%Y_%m')).last.victims.merge(localVictims).length
                stateHash[:totalVictims] += monthHash[:victims]
                stateHash[:months].push(monthHash)
            }
            topStatesArr.push(stateHash)
        }
        topStatesArr = topStatesArr.sort_by{|state| -state[:totalVictims]}
        myHash[:topStates] = topStatesArr[0..4]

        topCountiesArr = []
        bigCounties = County.where("population > ?",50000)
        bigCounties.each{|county|
            countyHash = {}
            countyHash[:code] = county.full_code
            countyHash[:name] = county.shortname
            r = 11..0
            countyHash[:totalVictims] = 0
            countyHash[:months] = []
            localVictims = county.victims
            (r.first).downto(r.last).each {|x|
                monthHash = {}
                monthHash[:month] = (thisMonth.first_day - (x*28).days).strftime('%m-%Y')
                monthHash[:victims] = Month.where(:name=>(thisMonth.first_day - (x*28).days).strftime('%Y_%m')).last.victims.merge(localVictims).length
                countyHash[:totalVictims] += monthHash[:victims]
                countyHash[:months].push(monthHash)
            }
            topCountiesArr.push(countyHash)
        }
        topCountiesArr = topCountiesArr.sort_by{|county| -county[:totalVictims]}
        myHash[:topCounties] = topCountiesArr[0..4]

        Cookie.create(:data=>[myHash], :category=>"api")
        redirect_to "/datasets/load"
    end

    def api
        myHash = Cookie.where(:category=>"api").last.data[0]
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
        @key = Rails.application.credentials.google_maps_api_key
        myCookie = Cookie.where(:category=>"irco").last
        myQuarter = myCookie.quarter
        @current_quarter_strings = helpers.quarter_strings(myQuarter)
        back_one_quarter = helpers.back_one_q(myQuarter) 
        @back_one_q_strings = helpers.quarter_strings(back_one_quarter)
        back_one_year = helpers.back_one_y(myQuarter)
        @back_one_y_strings = helpers.quarter_strings(back_one_year)

        @levels = helpers.ircoLevels
        @tableHeader = ["ESTADO", "POSICIÓN", "PUNTAJE", "TENDENCIA"]

        @sortedTable = myCookie.data
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

    def load_irco_params
        params.require(:query).permit(:year, :quarter)
        
    end
end
