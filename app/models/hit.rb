class Hit < ApplicationRecord
  belongs_to :town
  has_and_belongs_to_many :members
  validates :link, uniqueness: true, allow_nil: true
  validates :legacy_id, uniqueness: true
  has_one_attached :pdf
end
