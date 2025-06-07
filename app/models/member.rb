class Member < ApplicationRecord
	belongs_to :organization, optional: true
	belongs_to :criminal_link, class_name: 'Organization', optional: true
	belongs_to :role, optional: true
	belongs_to :detention, optional: true
	has_many :accounts
	has_many :sources
	has_many :queries
	has_one :user
	serialize :alias, Array
	has_one_attached :avatar
	has_and_belongs_to_many :hits
	has_many :relationships_as_a, class_name: 'MemberRelationship', foreign_key: :member_a_id, dependent: :destroy
	has_many :related_as_a, through: :relationships_as_a, source: :member_b

	has_many :relationships_as_b, class_name: 'MemberRelationship', foreign_key: :member_b_id, dependent: :destroy
	has_many :related_as_b, through: :relationships_as_b, source: :member_a

	def all_relationships
	MemberRelationship.where("member_a_id = ? OR member_b_id = ?", id, id)
	end

	def relationships_with_roles
	all_relationships.map do |rel|
	  if rel.member_a_id == id
	    { other: rel.member_b, my_role: rel.role_a, their_role: rel.role_b }
	  else
	    { other: rel.member_a, my_role: rel.role_b, their_role: rel.role_a }
	  end
	end
	end
end
