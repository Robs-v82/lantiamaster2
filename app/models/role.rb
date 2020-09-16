class Role < ApplicationRecord
	validates :name, uniqueness:  {case_sensitive: false }
	has_many :members
end
