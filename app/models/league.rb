class League < ApplicationRecord
	has_many :organizations, foreign_key: "mainleague_id"
end
