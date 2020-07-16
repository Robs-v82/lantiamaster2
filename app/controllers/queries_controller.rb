class QueriesController < ApplicationController
	
	def get_months
	    targetYear = get_months_params[:year]
	    targetMonths = helpers.get_months(targetYear)
	    render json: {months: targetMonths}
		
	end

	private

	def get_months_params

		params.require(:query).permit(:year)

	end

end
