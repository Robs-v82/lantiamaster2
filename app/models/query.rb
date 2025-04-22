class Query < ApplicationRecord
  belongs_to :user
  belongs_to :member, optional: true
  belongs_to :organization, optional: true

  serialize :outcome, Array
end
