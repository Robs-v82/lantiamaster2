class City < ApplicationRecord
	# validates :code, uniqueness: true
	has_many :counties
	has_many :towns, :through => :counties
	has_many :events, :through => :towns
	has_many :killings, :through => :events
	has_many :victims, :through => :killings
	has_many :sources, :through => :events
	belongs_to :core_county, class_name: "County", optional: true

	def self.to_csv
		attributes = %w{id name code}
		CSV.generate(headers: true) do |csv|
			csv << attributes

			all.each do |city|
				csv << city.attributes.values_at(*attributes)	
			end
			
		end
	end

end
