class DuplicationLog < ApplicationRecord
  belongs_to :source_record, class_name: 'DetentionCapture', foreign_key: 'source_record_id', optional: true
  belongs_to :duplicate_record, class_name: 'DetentionCapture', foreign_key: 'duplicate_record_id'

  enum action: { marked_as_duplicate: 'marked', unmarked_as_duplicate: 'unmarked', merged: 'merged' }
  enum reason: {
    same_fullcode: 'same_fullcode',
    same_name_date: 'same_name_date',
    manual_review: 'manual_review',
    recapture: 'recapture',
    multi_source: 'multi_source',
    manual_correction: 'manual_correction'
  }

  validates :duplicate_record_id, :action, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_reason, ->(reason) { where(reason: reason) }
end
