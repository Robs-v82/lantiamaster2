class AuthEvent < ApplicationRecord
  belongs_to :user, optional: true
end