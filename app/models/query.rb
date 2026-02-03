require "lockbox"
require "blind_index"

class Query < ApplicationRecord
  belongs_to :user
  belongs_to :member, optional: true
  belongs_to :organization, optional: true
  serialize :outcome, Array
  scope :successful, -> { where(success: true) } 

  self.ignored_columns += %w[firstname lastname1 lastname2 query_label outcome]
  has_encrypted :firstname, :lastname1, :lastname2, :query_label, :outcome

  blind_index :query_label do |value|
    I18n.transliterate(value.to_s.strip.downcase).gsub(/\s+/, " ")
  end
end
