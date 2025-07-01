class Title < ApplicationRecord
  belongs_to :member
  belongs_to :organization
  belongs_to :year

  validates :legacy_id, format: { with: /\A\d+\z/, message: "solo puede contener números" }
end
