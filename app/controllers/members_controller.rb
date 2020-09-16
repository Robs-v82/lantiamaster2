class MembersController < ApplicationController
	
	def detentions

		myFile = detention_params[:file]
		table = CSV.parse(File.read(myFile))

		table.each{|x|
			x = x.collect{ |e| e ? e.strip : e}
			unless Organization.where(:name=>x[0]).empty?
				limit = x.length-1
				targetOrganization = Organization.where(:name=>x[0]).last
				unless x[10].nil? && x[13].nil?
					if targetOrganization.members.where(:firstname=>x[10],:lastname1=>x[11],:lastname2=>x[12]).empty?
						myAlias = nil
						unless x[13].nil?
							myAlias = x[13].split(";")
						end
						Member.create(:organization_id=>targetOrganization.id,:firstname=>x[10],:lastname1=>x[11],:lastname2=>x[12], :alias=>myAlias)
						targetMember = Member.last
					else
						targetMember = targetOrganization.members.where(:firstname=>x[10],:lastname1=>x[11],:lastname2=>x[12]).last
					end
				end
			end	
		}

		session[:filename] = detention_params[:file].original_filename
		session[:load_success] = true

		redirect_to "/datasets/load"	

	end

	private

	def detention_params
		params.require(:query).permit(:file)
	end

end
