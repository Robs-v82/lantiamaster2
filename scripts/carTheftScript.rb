require 'csv'

national_file_name = "public/carTheft/national.csv"

CSV.open(national_file_name, 'w', write_headers: false) do |writer|
	CSV.foreach('public/municipal_delitos.csv') do |row|
		if row[7] == "Robo de vehículo automotor"
			writer << row
		end
	end
end

bigCounties = County.where("population > ?",50000)

bigCounties.each{|county|
	county_file_name = "public/carTheft/"+county.full_code+".csv"
	CSV.open(county_file_name, 'w', write_headers: false) do |writer|
		CSV.foreach('public/carTheft/national.csv') do |row|
			if row[3] == county.full_code.to_i.to_s
				writer << row
			end
		end
	end
}



