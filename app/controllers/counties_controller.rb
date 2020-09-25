class CountiesController < ApplicationController

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

	def ispyv
		@key = Rails.application.credentials.google_maps_api_key
		myQuarter = Quarter.where(:name=>"2019_Q4").last
		@current_quarter_strings = helpers.quarter_strings(myQuarter)
		bigCounties = County.where("population > ?",100000)
		
		@tableHeader
		@tableHeader = ["MUNICIPIO", "PUNTAJE", "TENDENCIA"]

		ispyvTable = []
		bigCounties.each{|county|
			countyHash = {}
			countyHash[:county] = county
			countyHash[:score] = this_quarter_ispyv(myQuarter, county)
			ispyvTable.push(countyHash)
		}
		@sortedTable = ispyvTable.sort_by{|row| -row[:score]}
	end

  	def this_quarter_ispyv(quarter, county)
  		localVictims = county.victims

  		total_victims = get_quarter_victims(quarter, localVictims)
 		victims_index = total_victims/county.population.to_f*100000
		victims_index = Math.log(victims_index+1,100).round(2)

  		ispyv_score = ((victims_index*4).round(2))
  		return ispyv_score
  	end

  	def get_quarter_victims(quarter, localVictims)
  		periodVictims = quarter.victims
  		number_of_victims = localVictims.merge(periodVictims).length 
  		return number_of_victims
  	end

	private

	def getCounties_params
    params.require(:query).permit(:state_id)
  	end

end
