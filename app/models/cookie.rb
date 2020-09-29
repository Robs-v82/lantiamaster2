class Cookie < ApplicationRecord
	serialize :data, Array
	belongs_to :quarter, optional: true
end
