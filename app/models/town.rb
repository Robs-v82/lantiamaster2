class Town < ApplicationRecord
  belongs_to :county
  has_many :events
end
