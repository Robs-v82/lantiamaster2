class Source < ApplicationRecord
  belongs_to :member, optional: true
  has_and_belongs_to_many :events
end
