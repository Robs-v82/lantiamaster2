class Organization < ApplicationRecord
	validates :name, uniqueness:  {case_sensitive: false }
	has_and_belongs_to_many :divisions
	has_and_belongs_to_many :towns
	has_many :members
	has_many :events
	has_many :leads, :through => :events
	has_many :sources, :through => :events
	belongs_to :county, optional: true
	belongs_to :thissubleague, class_name: "League", optional: true, foreign_key: "subleague_id"
	belongs_to :mainleague, class_name: "League", optional: true, foreign_key: "mainleague_id"

	belongs_to :member, optional: true

	has_many :subordinates, class_name: "Organization", foreign_key: "parent_id"
	belongs_to :parent, class_name: "Organization", optional: true
	has_one_attached :avatar

	serialize :origin, Array
	serialize :allies, Array
	serialize :rivals, Array
	serialize :alias, Array

	def self.search(term)
	  where("name LIKE ?", "%#{term}%")
	end


end
