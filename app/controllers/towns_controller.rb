class TownsController < ApplicationController

	def getTowns
	    targetCounty = getTowns_params[:county_id].to_i
	    targetTowns = County.find(targetCounty).towns.order(:name)
	    render json: {towns: targetTowns}		
	end

	private

	def getTowns_params
    params.require(:query).permit(:county_id)
  	end

end
