class QueryMailer < ApplicationMailer
	# default from: "roberto.valladarespiedras@gmail.com"
	default from: "plataforma@lantiaintelligence.com"

	def greeting
		current_time = Time.now.to_i
		midnight = Time.now.beginning_of_day.to_i
		noon = Time.now.middle_of_day.to_i
		five_pm = Time.now.change(:hour => 17 ).to_i
		eight_pm = Time.now.change(:hour => 20 ).to_i
		if midnight.upto(noon).include?(current_time)
			@greeting = "Buenos días,"
		elsif noon.upto(eight_pm).include?(current_time)
			@greeting = "Buenas tardes,"
		elsif eight_pm.upto(midnight + 1.day).include?(current_time)
			@greeting = "Buenas noches,"
		end	
	end

	def query_email(user, header, records, fileroot, myFile)
		@greeting = greeting
		@number_of_records = records.length
		# myUpdate = records.order("updated_at").last.updated_at
		# @last_update = I18n.l(myUpdate, :format=> "%d de %B de %Y")
		mySubject = "Consulta Lantia Intelligence"

		# CREATE FILE ACCORDDING TO FILE EXTENSION AND CATALOGUE
		if myFile.include? ("csv")
			headers = header
			CSV.open(fileroot, 'w:UTF-8', write_headers: true, headers: headers) do |writer|
				records.each do |record|
					writer << record
				end
			end
		end		
		attachments[myFile] = File.read(fileroot)
		@user = user
		mail(to: @user.mail, subject: mySubject)	
	end

	def freq_email(user, fileroot, filename, records, myLength, caption, timeFrame, placeFrame, extension)
		@greeting = greeting
		@caption = caption
		@timeFrame = timeFrame
		@number_of_records = records.length
		myFile = fileroot
		mySubject = "Tabulado Lantia Intelligence: "+caption
		if extension == 'xlsx'
			filename += 'xls'
		else
			filename += extension	
		end
		@extension = extension.upcase
		CSV.open(myFile, 'w') do |writer|
			writer.to_io.write "\uFEFF"
			row = []
			if 	records[0][:pre_scope]
				row.push(records[0][:pre_scope])
			end
			row.push(records[0][:scope])
			[:organization, :role, :gender].each{|header|
				if 	records[0][header]
					row.push(records[0][header])
				end
			}
			records[0][:period].each{|period|
				if timeFrame == "annual"
					row.push(period.name)
				elsif timeFrame == "quarterly"
					row.push("T"+period.name[-1]+"/"+I18n.l(period.first_day, format: '%Y'))
				else
					row.push(I18n.l(period.first_day, format: '%b/%Y'))
				end
			}
			unless records[-1][:freq].length == 1
				row.push("TOTAL")
			end
			writer << row
			records[1..-2].each do |record|
				unless placeFrame == "stateWise" && record[:name] == "Nacional" || placeFrame == "cityWise" && record[:name] == "Nacional" || record[:full_code] == "00000"
					row = []
					[:parent_name, :name, :organization, :role, :gender].each do |cell|
						if record[cell]
							row.push(record[cell])
						end
					end
					record[:freq].each do |figure|
						row.push(figure)
					end
					unless records[-1][:freq].length == 1
						row.push(record[:place_total])
					end
					writer << row
				end
			end
			unless records.length < 4
				row = []
				[:name, :county_placer, :organization_placer, :role_placer, :gender_placer].each do |cell|
					if records[-1][cell]
						row.push(records[-1][cell])
					end
				end
				records[-1][:freq].each do |figure|
					row.push(figure)
				end
				unless records[-1][:freq].length == 1
					row.push(records[-1][:total_total])
				end
				writer << row
			end		
		end
		if extension == "xlsx"
			CSV.open(myFile, 'w', col_sep: "\t") do |writer|
				writer.to_io.write "\uFEFF"
				row = []
				if 	records[0][:pre_scope]
					row.push(records[0][:pre_scope])
				end
				row.push(records[0][:pre_scope])
				[:organization, :role, :gender].each{|header|
					if 	records[0][header]
						row.push(records[0][header])
					end
				}
				records[0][:period].each{|period|
					if timeFrame == "annual"
						row.push(period.name)
					elsif timeFrame == "quarterly"
						row.push("T"+period.name[-1]+"/"+I18n.l(period.first_day, format: '%Y'))
					else
						row.push(I18n.l(period.first_day, format: '%b/%Y'))
					end
				}
				unless records[-1][:freq].length == 1
					row.push("TOTAL")
				end
				writer << row
				records[1..-2].each do |record|
					unless placeFrame == "stateWise" && record[:name] == "Nacional" || placeFrame == "cityWise" && record[:name] == "Nacional" || record[:full_code] == "00000"
						row = []
						[:parent_name, :name, :organization, :role, :gender].each do |cell|
							if record[cell]
								row.push(record[cell])
							end
						end
						record[:freq].each do |figure|
							row.push(figure)
						end
						unless records[-1][:freq].length == 1
							row.push(record[:place_total])
						end
						writer << row
					end
				end
				unless records.length < 5
					row = []
					[:name, :county_placer, :organization_placer, :role_placer, :gender_placer].each do |cell|
						if records[-1][cell]
							row.push(records[-1][cell])
						end
					end
					records[-1][:freq].each do |figure|
						row.push(figure)
					end
					unless records[-1][:freq].length == 1
						row.push(records[-1][:total_total])
					end
					writer << row
				end		
			end
		end

		attachments[filename] = File.read(myFile)
		@user = user
		mail(to: @user.mail, subject: mySubject)
	end

	def file_email(user, fileroot, filename, records, myLength, caption)
		
		@greeting = greeting
		@caption = caption
		@number_of_records = records.length
		if records.kind_of?(Array)
			updatedRecords = records.sort_by {|record| record.updated_at}
			myUpdate = updatedRecords.last.updated_at
			records = records.sort_by {|record| record.id}
		else
			myUpdate = records.order("updated_at").last.updated_at
		end
		@last_update = I18n.l(myUpdate, :format=> "%d de %B de %Y")

		myFile = fileroot
		mySubject = "Catálogo Lantia Intelligence: "+caption
		
		# CREATE FILE ACCORDDING TO FILE EXTENSION AND CATALOGUE
		# CSV
		if filename.include? ("csv")
			if caption == "usuarios"
				headers = %w{firstname lastname1 mail membership_type}
				CSV.open(myFile, 'w:UTF-8', write_headers: true, headers: headers) do |writer|
					records.each do |record|
						writer << [record.member.firstname, record.member.lastname1, record.mail, record.membership_type]
					end
				end
			end

			if caption == "localidades"
				headers = %w{id county.full_code name full_code zip_code urban settlement_type}
				CSV.open(myFile, 'w:UTF-8', write_headers: true, headers: headers) do |writer|
					records.each do |record|
						writer << [record.id, record.county.full_code, record.name, record.full_code, record.zip_code, record.urban, record.settlement_type]
					end
				end
			end
			if caption == "municipios"
				headers = %w{id state.name state.code name full_code}
				CSV.open(myFile, 'w:UTF-8', write_headers: true, headers: headers) do |writer|
					records.each do |record|
						# if record.city
						# 	writer << [record.id, record.state.name, record.state.code, record.name, record.full_code, record.city.code, record.city.name]
						# else
							writer << [record.id, record.state.name, record.state.code, record.name, record.full_code,]
						# end
					end
				end
			end
			if caption == "ciudades"
				headers = %w{id name code}
				CSV.open(myFile, 'w:UTF-8', write_headers: true, headers: headers) do |writer|
					records.each do |record|
						writer << [record.id, record.name, record.code]
					end
				end
			end
			if caption == "medios"
				headers = %w{id state.id state.name name domain active_links active_since}
				CSV.open(myFile, 'w:UTF-8', write_headers: true, headers: headers) do |writer|
					records.each do |record|
						writer << [record.id, record.county.state.id, record.county.state.name, record.name, record.domain, record.active_links, record.active_since]
					end
				end
			end
			if caption == "organizaciones criminales"
				headers = %w{nombre siglas tipo subtipo pertenencia}
				CSV.open(myFile, 'w:UTF-8', write_headers: true, headers: headers) do |writer|
					records.each do |record|
						unless record.parent.nil?
							myOrigin = record.parent.name
						else
							myOrigin = nil
						end
						writer << [record.name, record.acronym, record.league, record.subleague, myOrigin]
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
			xlsx = render_to_string formats: [:xlsx], handlers: [:axlsx], template: ["queries/test_xlsx.xlsx.axlsx"]
			self.instance_variable_set(:@_lookup_context, nil)
			# attachment = Base64.encode64(xlsx)
			attachments[this_file] = {mime_type: Mime[:xlsx], content: xlsx, encoding: 'base64'}
		end		
	end
end
