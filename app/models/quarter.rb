class Quarter < ApplicationRecord
	belongs_to :year
	has_many :months
	has_many :events, :through => :months
	has_many :sources, :through => :events 
	has_many :killings, :through => :events 
	has_many :detentions, :through => :events 
	has_many :victims, :through => :killings
	has_many :detainees, :through => :detentions
	has_many :cookies

	has_many :leads, :through => :events

	has_one_attached :survey
	has_one_attached :ensu
	has_one_attached :icon
end