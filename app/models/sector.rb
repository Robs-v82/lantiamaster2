class Sector < ApplicationRecord
	has_many :divisions
	has_many :organizations, through: :divisions
end
