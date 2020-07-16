class Victim < ApplicationRecord
  belongs_to :role, optional: true
  belongs_to :organization, optional: true
  belongs_to :killing
end
