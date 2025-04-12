class Detention < ApplicationRecord
	# validates :legacy_id, uniqueness: true
	belongs_to :event
	has_many :detainees, class_name: "Member"
	has_and_belongs_to_many :organizations
end
