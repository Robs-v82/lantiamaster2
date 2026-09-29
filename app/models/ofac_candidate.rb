class OfacCandidate < ApplicationRecord
  belongs_to :organization, optional: true

  enum status: { pending: 0, found_with_org: 1, found_no_org: 2, not_found: 3 }

  validates :ofac_name, presence: true, uniqueness: true
end
