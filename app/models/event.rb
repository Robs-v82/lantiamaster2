class Event < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :town, optional: true
  has_and_belongs_to_many :sources
  has_one :killing
  has_many :victims, :through => :killings
  accepts_nested_attributes_for :killing
end