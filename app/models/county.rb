class County < ApplicationRecord
	belongs_to :state
	belongs_to :city, optional: true
	has_many :towns
	has_many :organizations
	has_many :rackets, :through => :towns
	has_many :events, :through => :towns
	has_many :killings, :through => :events
	has_many :leads, :through => :events
	has_many :detentions, :through => :events
	has_many :victims, :through => :killings
	has_many :detainees, :through => :detentions
	has_many :sources, :through => :events
	serialize :comparison, Array
end


 