class County < ApplicationRecord
	belongs_to :state
	belongs_to :city, optional: true
	has_many :towns
	has_many :organizations
	has_many :events, :through => :towns
	has_many :killings, :through => :events
	has_many :victims, :through => :killings
	has_many :sources, :through => :events
end


 