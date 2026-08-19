class BulkQueryRun < ApplicationRecord
  belongs_to :user
  has_many :queries, dependent: :destroy

  validates :user_id, presence: true
end
