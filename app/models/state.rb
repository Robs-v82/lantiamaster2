class State < ApplicationRecord
	belongs_to :capital, class_name: "County", optional: true
	has_many :counties
	has_many :organizations, :through => :counties
	has_many :towns, :through => :counties
	has_many :events, :through => :towns
	has_many :rackets, :through => :towns
	has_many :killings, :through => :events
	has_many :detentions, :through => :events
	has_many :victims, :through => :killings
	has_many :detainees, :through => :detentions
	has_many :sources, :through => :events

	serialize :ensu_cities, Array
	serialize :comparison, Array
end