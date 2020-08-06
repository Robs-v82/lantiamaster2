class QueriesController < ApplicationController
	
	after_action :remove_email_message, only: [:files]

	def get_months
	    targetYear = get_months_params[:year]
	    targetMonths = helpers.get_months(targetYear)
	    render json: {months: targetMonths}
		
	end

	def get_regular_months
	    targetMonths = %w{01 02 03 04 05 06 07 08 09 10 11 12}
	    render json: {months: targetMonths}			
	end

	def get_quarters
	    targetQuarters = ["Q1","Q2","Q3","Q4"]
	    render json: {quarters: targetQuarters}	
	end

	def files
		if session[:email_success]
			@email_success = true
		end
		@user = User.find(session[:user_id])
		@counties = County.all
		@papers = Division.where(:scian3=>510).last.organizations
		@fileArr = [
			{:route=>"towns",:caption=>"Colonias/Localidades",:data=>@towns,:pdf=>false,:csv=>true,:excel=>false},
			{:route=>"counties",:caption=>"Municipios",:data=>@counties,:pdf=>false,:csv=>true,:excel=>false},
			# {:route=>"cities",:caption=>"Zonas metropolitanas",:data=>@cities,:pdf=>true,:csv=>true,:excel=>true},
			{:route=>"papers",:caption=>"Medios",:data=>@papers,:pdf=>true,:csv=>true,:excel=>true}
		]
	end

	def send_query_file
		recipient = User.find(session[:user_id])
		current_date = Date.today.strftime
		header = helpers.header_and_cells[:header]
 		cells = helpers.header_and_cells[:cells]
 		myLength = helpers.root_path[:myLength]
		
		myParams = session[:params]
		myHash = helpers.define_query(myParams)
		@myQuery = myHash[:myQuery]
		@type_of_query = myHash[:type_of_query]

		content = helpers.cell_content(@type_of_query, cells, @myQuery)
		file_name = helpers.root_path[:myPath]+"private/consulta_("+current_date+")."+params[:extension]
		QueryMailer.query_email(recipient, header, content, file_name, myLength).deliver_now
		session[:email_success] = true
		redirect_to "/send_query"
	end

	def send_file
		recipient = User.find(session[:user_id])
		current_date = Date.today.strftime
		if params[:catalogue] == "towns"
		 	records = Town.all.order(:full_code)
		 	file_name = helpers.root_path[:myPath]+"private/localidades("+current_date+")."+params[:extension]
		 	caption = "localidades"
		 elsif params[:catalogue] == "counties"
		 	records = County.all
		 	file_name = helpers.root_path[:myPath]+"private/municipios("+current_date+")."+params[:extension]
		 	caption = "municipios"
		 elsif params[:catalogue] == "cities"
		 	records = City.all
		 	file_name = helpers.root_path[:myPath]+"private/zonas_metropolitanas("+current_date+")."+params[:extension]
		 	caption = "zonas metropolitanas"
		 elsif params[:catalogue] == "papers"
		 	records = Division.where(:scian3=>510).last.organizations
		 	file_name = helpers.root_path[:myPath]+"private/medios("+current_date+")."+params[:extension]
		 	caption = "medios"
		end 
		myLength = helpers.root_path[:myLength]
		QueryMailer.file_email(recipient, file_name, records, myLength, caption).deliver_now
		session[:email_success] = true
		redirect_to "/queries/files"
	end

	def test_xlsx
		@records = Division.where(:scian3=>510).last.organizations
		current_date = Date.today.strftime
		file_name = "medios("+current_date+").xlsx"
		respond_to do |format|
			format.xlsx {
				response.headers['Content-Disposition'] = "attachment; filename='#{file_name}'"
			}
			format.html { render :files }
		end
		
		# recipient = User.find(session[:user_id])
		# current_date = Date.today.strftime
		# file_name = "medios("+current_date+").xlsx"
		# @records = Division.where(:scian3=>510).last.organizations
		# myLength = helpers.root_path[:myLength]
		# caption = "medios"
		# QueryMailer.file_email(recipient, file_name, @records, myLength, caption).deliver_now
		# session[:email_success] = true
		# redirect_to "/queries/files"
	end

	private

	def get_months_params

		params.require(:query).permit(:year)

	end

end
