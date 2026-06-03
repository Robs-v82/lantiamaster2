class CountyAlias < ApplicationRecord
  belongs_to :county

  validates :alias_name, presence: true, uniqueness: { scope: :county_id }
  validates :alias_type, presence: true

  # Tipos de alias
  TYPES = {
    common_name: 'Nombre común (ej: Cancún para Benito Juárez)',
    alternative: 'Nombre alternativo',
    historical: 'Nombre histórico'
  }.freeze
end
