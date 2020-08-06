class Member < ApplicationRecord
	belongs_to :organization, optional: true
	belongs_to :role, optional: true
	has_many :accounts
	has_many :sources
	has_one :user

	has_one_attached :avatar
end
