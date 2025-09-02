class LrvlMembershipExpiration < ApplicationRecord
  self.table_name = "lrvl_membership_expiration"
  belongs_to :user
end
