class Town < ApplicationRecord
  belongs_to :county
  has_many :events
  has_and_belongs_to_many :rackets, class_name: "Organization"
end
