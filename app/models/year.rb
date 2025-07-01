class Year < ApplicationRecord
	has_many :quarters
	has_many :months, :through => :quarters
	has_many :events, :through => :quarters
	has_many :sources, :through => :events 
	has_many :killings, :through => :events 
	has_many :detentions, :through => :events 
	has_many :victims, :through => :killings
	has_many :detainees, :through => :detentions
	has_many :months, :through => :quarters
	has_many :leads, :through => :events
	has_many :cookies
	has_many :titles, dependent: :destroy
end
