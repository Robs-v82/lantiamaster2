class Member < ApplicationRecord
	belongs_to :organization, optional: true
	belongs_to :role, optional: true
	belongs_to :detention, optional: true
	has_many :accounts
	has_many :sources
	has_many :queries
	has_one :user
	serialize :alias, Array
	has_one_attached :avatar
	has_and_belongs_to_many :hits
end
