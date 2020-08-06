class State < ApplicationRecord
	has_many :counties
	has_many :organizations, :through => :counties
	has_many :towns, :through => :counties
	has_many :events, :through => :towns
	has_many :killings, :through => :events
	has_many :victims, :through => :killings
	has_many :sources, :through => :events

	serialize :ensu_cities, Array
	serialize :comparison, Array
end