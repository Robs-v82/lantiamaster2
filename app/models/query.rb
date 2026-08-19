class Query < ApplicationRecord
  belongs_to :user
  belongs_to :member, optional: true
  belongs_to :organization, optional: true
  belongs_to :bulk_query_run, optional: true
  serialize :outcome, Array
  scope :successful, -> { where(success: true) }
end
