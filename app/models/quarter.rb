class Quarter < ApplicationRecord
	belongs_to :year
	has_many :months
	has_many :events, :through => :months
	has_many :sources, :through => :events 
	has_many :killings, :through => :events 
	has_many :victims, :through => :killings

	has_one_attached :survey
	has_one_attached :ensu
end