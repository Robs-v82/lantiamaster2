class CountiesController < ApplicationController

	def getCounties
	    targetState = getCounties_params[:state_id].to_i
	    targetCounties = State.find(targetState).counties
	    render json: {counties: targetCounties}		
	end

	private

	def getCounties_params
    params.require(:query).permit(:state_id)
  	end

end
