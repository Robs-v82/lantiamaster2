class FakeIdentity < ApplicationRecord
  belongs_to :member
  validates :firstname, :lastname1, :lastname2, presence: true

  def fullname
    [firstname, lastname1, lastname2].compact.join(" ").strip
  end
  
end
