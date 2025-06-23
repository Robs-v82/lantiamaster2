class FakeIdentity < ApplicationRecord
  belongs_to :member
  validates :firstname, :lastname1, :lastname2, presence: true
end
