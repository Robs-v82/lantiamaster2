class Organization < ApplicationRecord
  validates :name, uniqueness:  {case_sensitive: false }
  has_and_belongs_to_many :divisions
  has_many :members
  belongs_to :county, optional: true

  has_one_attached :avatar
end
