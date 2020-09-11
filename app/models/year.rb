class Year < ApplicationRecord
	has_many :quarters
	has_many :months, :through => :quarters
	has_many :events, :through => :months
	has_many :sources, :through => :events 
	has_many :killings, :through => :events 
	has_many :victims, :through => :killings
	has_many :months, :through => :quarters
	has_many :leads, :through => :events
end
