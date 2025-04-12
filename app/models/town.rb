class Town < ApplicationRecord
	belongs_to :county
	has_many :events
	has_many :killings, :through => :events
	has_many :detentions, :through => :events
	has_many :victims, :through => :killings
	has_many :detainees, :through => :detentions
	has_and_belongs_to_many :rackets, class_name: "Organization"
	has_many :hits
end
