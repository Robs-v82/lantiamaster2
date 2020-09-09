class Member < ApplicationRecord
	belongs_to :organization, optional: true
	belongs_to :role, optional: true
	has_many :accounts
	has_many :sources
	has_one :user
	serialize :alias, Array

	has_one_attached :avatar
end
