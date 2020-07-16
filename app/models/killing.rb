class Killing < ApplicationRecord
  belongs_to :event
  has_many :victims
end
