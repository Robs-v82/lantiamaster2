class Account < ApplicationRecord
	has_many :posts
	validates :code, uniqueness: true
	validates :name, uniqueness: true
end
