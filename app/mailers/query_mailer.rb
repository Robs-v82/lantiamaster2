class QueryMailer < ApplicationMailer
	default from: "roberto.valladarespiedras@gmail.com"

	def greeting
		current_time = Time.now.to_i
		midnight = Time.now.beginning_of_day.to_i
		noon = Time.now.middle_of_day.to_i
		five_pm = Time.now.change(:hour => 17 ).to_i
		eight_pm = Time.now.change(:hour => 20 ).to_i
		if midnight.upto(noon).include?(current_time)
			@greeting = "Buenos días"
		elsif noon.upto(eight_pm).include?(current_time)
			@greeting = "Buenas tardes"
		elsif eight_pm.upto(midnight + 1.day).include?(current_time)
			@greeting = "Buenas noches"
		end	
	end

	def query_email(user, header, records, fileroot, myFile, myLength)
		@greeting = greeting
		@number_of_records = records.length
		# myUpdate = records.order("updated_at").last.updated_at
		# @last_update = I18n.l(myUpdate, :format=> "%d de %B de %Y")
		mySubject = "Consulta Lantia Intelligence"

		# CREATE FILE ACCORDDING TO FILE EXTENSION AND CATALOGUE
		if myFile.include? ("csv")
			headers = header
			CSV.open(myFile, 'w', write_headers: true, headers: headers) do |writer|
				records.each do |record|
					writer << record
				end
			end
		end		
		attachments[myFile] = File.read(fileroot)
		@user = user
		mail(to: @user.mail, subject: mySubject)	
	end

	def file_email(user, fileroot, filename, records, myLength, caption)
		
		@greeting = greeting
		@caption = caption
		@number_of_records = records.length
		myUpdate = records.order("updated_at").last.updated_at
		@last_update = I18n.l(myUpdate, :format=> "%d de %B de %Y")

		myFile = fileroot
		mySubject = "Catálogo Lantia Intelligence: "+caption
		
		# CREATE FILE ACCORDDING TO FILE EXTENSION AND CATALOGUE
		# CSV
		if filename.include? ("csv")
			if caption == "localidades"
				headers = %w{id county.full_code name full_code zip_code urban settlement_type}
				CSV.open(myFile, 'w', write_headers: true, headers: headers) do |writer|
					records.each do |record|
						writer << [record.id, record.county.full_code, record.name, record.full_code, record.zip_code, record.urban, record.settlement_type]
					end
				end
			end
			if caption == "municipios"
				headers = %w{id state.code name full_code city.code city.name}
				CSV.open(myFile, 'w', write_headers: true, headers: headers) do |writer|
					records.each do |record|
						if record.city
							writer << [record.id, record.state.code, record.name, record.full_code, record.city.code, record.city.name]
						else
							writer << [record.id, record.state.code, record.name, record.full_code,]
						end
					end
				end
			end
			if caption == "ciudades"
				headers = %w{id name code}
				CSV.open(myFile, 'w', write_headers: true, headers: headers) do |writer|
					records.each do |record|
						writer << [record.id, record.name, record.code]
					end
				end
			end
			if caption == "medios"
				headers = %w{id state.id state.name name domain active_links active_since}
				CSV.open(myFile, 'w', write_headers: true, headers: headers) do |writer|
					records.each do |record|
						writer << [record.id, record.county.state.id, record.county.state.name, record.name, record.domain, record.active_links, record.active_since]
					end
				end
			end
			attachments[filename] = File.read(myFile)
			@user = user
			mail(to: @user.mail, subject: mySubject)	
		end
		
		# XLSX
		if filename.include? ("xlsx")
			print "******"
			print "XLSX"
			@records = records
			xlsx = render_to_string formats: [:xlsx], handlers: [:axlsx], template: ["queries/test_xlsx.xlsx.axlsx"]
			self.instance_variable_set(:@_lookup_context, nil)
			# attachment = Base64.encode64(xlsx)
			attachments[this_file] = {mime_type: Mime[:xlsx], content: xlsx, encoding: 'base64'}
		end		
	end
end
