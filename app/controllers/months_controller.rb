class MonthsController < ApplicationController

	def reports
		@months = []
		all_months = Month.all.order(:first_day => :desc)
		all_months.each{|month|
			if month.violence_report.attached?
				@months.push(month)
			end
		}
	end

	def load_violence_report
		myName = load_violence_report_params[:year]+"_"+load_violence_report_params[:month]
		myMonth = Month.where(:name=>myName).last		
		myMonth.violence_report.purge
		myMonth.violence_report.attach(load_violence_report_params[:report])	
		if myMonth.violence_report.attached?
			session[:filename] = load_violence_report_params[:report].original_filename
			session[:load_success] = true
			print "*******ATTACHEMENT WORKED: "
			print "TRUE"
		end
		redirect_to "/datasets/load"
	end

	def load_social_report
		myName = load_social_report_params[:year]+"_"+load_social_report_params[:month]
		myMonth = Month.where(:name=>myName).last		
		myMonth.social_report.purge
		myMonth.social_report.attach(load_social_report_params[:report])	
		if myMonth.social_report.attached?
			session[:filename] = load_social_report_params[:report].original_filename
			session[:load_success] = true
			print "*******ATTACHEMENT WORKED: "
			print "TRUE"
		end
		redirect_to "/datasets/load"
	end

	def load_forecast_report
		myName = load_forecast_report_params[:year]+"_"+load_forecast_report_params[:month]
		myMonth = Month.where(:name=>myName).last		
		myMonth.forecast_report.purge
		myMonth.forecast_report.attach(load_forecast_report_params[:report])	
		if myMonth.forecast_report.attached?
			session[:filename] = load_forecast_report_params[:report].original_filename
			session[:load_success] = true
			print "*******ATTACHEMENT WORKED: "
			print "TRUE"
		end
		redirect_to "/datasets/load"
	end

	def load_crime_victim_report
		myName = load_crime_victim_report_params[:year]+"_"+load_crime_victim_report_params[:month]
		myMonth = Month.where(:name=>myName).last		
		myMonth.crime_victim_report.purge
		myMonth.crime_victim_report.attach(load_crime_victim_report_params[:report])	
		if myMonth.crime_victim_report.attached?
			session[:filename] = load_crime_victim_report_params[:report].original_filename
			session[:load_success] = true
			print "*******ATTACHEMENT WORKED: "
			print "TRUE"
		end
		redirect_to "/datasets/load"	
	end

	def header_selector
		@months = []
		all_months = Month.all.order(:first_day => :desc)
		all_months.each{|month|
			if month.violence_report.attached?
				@months.push(month)
			end
		}
		myMonth = @months[params[:month].to_i]
		myMonth = I18n.l(myMonth.first_day, format: '%B de %Y')
		render json: {month: myMonth}
	end

	private

	def load_violence_report_params
		params.require(:query).permit(:report,:year,:month)
	end

	def load_social_report_params
		params.require(:query).permit(:report,:year,:month)
	end

	def load_forecast_report_params
		params.require(:query).permit(:report,:year,:month)
	end

	def load_crime_victim_report_params
		params.require(:query).permit(:report,:year,:month)
	end
end
