class Role < ApplicationRecord
	validates :name, uniqueness:  {case_sensitive: false }
	has_many :members
	has_many :appointments, dependent: :restrict_with_error
end
