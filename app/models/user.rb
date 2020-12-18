class User < ApplicationRecord
	VALID_PASSWORD_REGEX = /\A
	  (?=.{7,})          # Must contain 7 or more characters
	  (?=.*\d)           # Must contain a digit
	  (?=.*[a-z])        # Must contain a lower case character
	  (?=.*[A-Z])        # Must contain an upper case character
	/x
	VALID_EMAIL_REGEX = /\A([\w+\-]\.?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i
	has_secure_password
	has_secure_password :recovery_password, validations: false

	# validates :mail, :firstname, :lastname1, :lastname2, presence: true 
	validates :mail, format:  {with: VALID_EMAIL_REGEX }
	validates :mail, uniqueness:  {case_sensitive: false }
	# belongs_to :organization, optional: true
	# belongs_to :role, optional: true
	belongs_to :member, optional: true
	has_many :keys
end