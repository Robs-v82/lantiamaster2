class Query < ApplicationRecord
  belongs_to :user
  belongs_to :member, optional: true
  belongs_to :organization, optional: true

  has_encrypted :firstname
  has_encrypted :lastname1
  has_encrypted :lastname2
  has_encrypted :query_label
  has_encrypted :outcome

  blind_index :query_label, key: Rails.application.credentials.dig(:blind_index, :master_key)

  serialize :outcome, Array
  scope :successful, -> { where(success: true) }
end
