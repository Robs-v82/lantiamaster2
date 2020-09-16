class Detention < ApplicationRecord
	belongs_to :event
	has_many :detainees, class_name: "Member"
	has_and_belongs_to_many :organizations
end
