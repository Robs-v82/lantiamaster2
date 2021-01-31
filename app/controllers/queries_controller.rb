class QueriesController < ApplicationController
	
	after_action :remove_email_message, only: [:files]

	def mapOff
		session[:map] = false
		print "**********MAP: "
		print session[:map]
	end

	def mapOn
		session[:map] = true
		print "**********MAP: "
		print session[:map]
	end

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
		@cartels = Sector.where(:scian2=>"98").last.organizations.uniq
		@cartels = @cartels.sort_by{|c| c.name}
		@fileArr = [
			{:route=>"mails", :caption=>"Usuarios",:data=>@towns,:pdf=>false,:csv=>true,:excel=>false},
			{:route=>"towns", :caption=>"Colonias/Localidades",:data=>@towns,:pdf=>false,:csv=>true,:excel=>false},
			{:route=>"counties",:caption=>"Municipios",:data=>@counties,:pdf=>false,:csv=>true,:excel=>true},
			# {:route=>"cities",:caption=>"Zonas metropolitanas",:data=>@cities,:pdf=>true,:csv=>true,:excel=>true},
			{:route=>"papers",:caption=>"Medios",:data=>@papers,:pdf=>false,:csv=>true,:excel=>false},
			{:route=>"cartels",:caption=>"Organizaciones criminales",:data=>@cartels,:pdf=>false,:csv=>true,:excel=>false}
		]
	end

	def send_query_file
		recipient = User.find(session[:user_id])
		current_date = Date.today.strftime
		current_query_count = recipient.query_counter
		current_query_count +=1
		recipient.update(:query_counter=>current_query_count)
		current_query_string = recipient.id.to_s+"-"+current_query_count.to_s
		header = helpers.header_and_cells[:header]
 		cells = helpers.header_and_cells[:cells]
		
		myParams = session[:params]
		myHash = helpers.define_query(myParams)
		@myQuery = myHash[:myQuery]
		@type_of_query = myHash[:type_of_query]

		content = helpers.cell_content(@type_of_query, cells, @myQuery)
		file_name = "consulta-"+current_date+"-"+current_query_string+"."+params[:extension]
		print "********** "
		print file_name
		print " **********"
		file_root = Rails.root.join("private",file_name)
		QueryMailer.query_email(recipient, header, content, file_root, file_name).deliver_now
		session[:email_success] = true
		redirect_to "/send_query"
	end

	def send_file
		recipient = User.find(session[:user_id])
		current_date = Date.today.strftime
		if params[:catalogue] == "mails"
		 	records = User.all
		 	file_name = "usuarios("+current_date+")."+params[:extension]
		 	caption = "usuarios"			
		 elsif params[:catalogue] == "towns"
		 	records = Town.all.order(:full_code)
		 	file_name = "localidades("+current_date+")."+params[:extension]
		 	caption = "localidades"
		 elsif params[:catalogue] == "counties"
		 	records = County.all
		 	file_name = "municipios("+current_date+")."+params[:extension]
		 	caption = "municipios"
		 elsif params[:catalogue] == "cities"
		 	records = City.all
		 	file_name = "zonas_metropolitanas("+current_date+")."+params[:extension]
		 	caption = "zonas metropolitanas"
		 elsif params[:catalogue] == "papers"
		 	records = Division.where(:scian3=>510).last.organizations
		 	file_name = "medios("+current_date+")."+params[:extension]
		 	caption = "medios"
		 elsif params[:catalogue] == "cartels"
		 	records = Sector.where(:scian2=>"98").last.organizations.uniq
		 	records = records.sort_by{|c| c.name}
		 	file_name = "org-criminales("+current_date+")."+params[:extension]
		 	caption = "organizaciones criminales"
		end 
		file_root = Rails.root.join("private",file_name)
		myLength = helpers.root_path[:myLength]
		QueryMailer.file_email(recipient, file_root, file_name, records, myLength, caption).deliver_now
		session[:email_success] = true
		redirect_to "/queries/files"
	end

	def test_xlsx

		require 'axlsx'

		p = Axlsx::Package.new
		wb = p.workbook

		wb.add_worksheet(name: 'Basic Worksheet') do |sheet|
		  sheet.add_row ['First', 'Second', 'Third']
		  sheet.add_row [1, 2, 3]
		end

		p.serialize 'basic_example.xlsx'
		print "****"*100
		# @records = County.all
		# @records = Division.where(:scian3=>510).last.organizations
		# current_date = Date.today.strftime
		# file_name = "municipios("+current_date+").xlsx"

		# xlsx = render_to_string formats: [:xlsx], handlers: [:axlsx], template: ["queries/test_xlsx.xlsx"]
		# self.instance_variable_set(:@_lookup_context, nil)
		# attachment = Base64.encode64(xlsx)
		# export = {mime_type: Mime[:xlsx], content: xlsx, encoding: 'base64'}

		respond_to do |format|
			# format.xlsx {response.headers['Content-Disposition'] = "attachment; filename='#{file_name}'"}			
			format.xlsx { render xlsx: p, mime_type: Mime[:xlsx] }
			# format.xlsx { render xlsx: "queries/test_xlsx.xlsx.axlsx", mime_type: Mime[:xlsx], :filename => "'#{file_name}'"}
			# format.html { render :files }
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

	def pageback
		session[:indexPage] -= 1
		if params[:index] == "irco"
			redirect_to '/counties/irco'
		end
	end

	def pageforward
		session[:indexPage] += 1
		if params[:index] == "irco"
			redirect_to '/counties/irco'
		end
	end

	private

	def get_months_params

		params.require(:query).permit(:year)

	end

end
