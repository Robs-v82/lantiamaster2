class MemberRelationship < ApplicationRecord
  belongs_to :member_a, class_name: 'Member'
  belongs_to :member_b, class_name: 'Member'

  validates :role_a, :role_b, presence: true
  validate :members_must_be_different

  def members_must_be_different
    errors.add(:member_b, "debe ser diferente a member_a") if member_a_id == member_b_id
  end
end

