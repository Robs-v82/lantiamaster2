class Event < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :town, optional: true
  belongs_to :month, optional: true
  has_and_belongs_to_many :sources
  has_one :killing
  has_many :detentions
  has_many :victims, :through => :killings
  has_many :detainees, :through => :detentions
  has_many :leads
  accepts_nested_attributes_for :killing
end