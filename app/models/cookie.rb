class Cookie < ApplicationRecord
	serialize :data, Array
	belongs_to :quarter, optional: true
	belongs_to :year, optional: true
end
