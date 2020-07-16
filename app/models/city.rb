class City < ApplicationRecord
	# validates :code, uniqueness: true
	has_many :counties
	has_many :towns, :through => :counties
	has_many :events, :through => :towns
	has_many :killings, :through => :events
	has_many :victims, :through => :killings
	has_many :sources, :through => :events
end
