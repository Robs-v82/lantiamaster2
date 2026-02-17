# app/services/reclassify_member_criminal_role.rb
class ReclassifyMemberCriminalRole
  Result = Struct.new(:ok?, :changed?, :error, keyword_init: true)

  EXPECTED_TRUE = [
    "Militar", "Coordinador estatal", "Abogado", "Extorsionador", "Manager",
    "Jefe operativo", "Sicario", "Jefe de plaza", "Sin definir", "Regidor",
    "Socio", "Policía", "Operador", "Jefe de célula", "Líder",
    "Traficante o distribuidor", "Delegado estatal", "Artista", "Gobernador",
    "Autoridad cooptada", "Jefe de sicarios", "Dirigente sindical", "Alcalde",
    "Músico", "Narcomenudista", "Secretario de Seguridad", "Jefe regional"
  ].freeze

  MAP_TRUE = {
    "Líder" => ["Líder"],
    "Miembro" => ["Extorsionador", "Jefe operativo", "Sicario", "Jefe de plaza", "Operador",
                 "Jefe de célula", "Traficante o distribuidor", "Narcomenudista",
                 "Jefe de sicarios", "Jefe regional"],
    "Socio" => ["Abogado", "Manager", "Socio", "Artista", "Dirigente sindical", "Músico"],
    "Autoridad vinculada" => ["Militar", "Coordinador estatal", "Alcalde", "Regidor", "Policía",
                              "Delegado estatal", "Gobernador", "Autoridad cooptada",
                              "Secretario de Seguridad"],
    nil => ["Sin definir"]
  }.freeze

  EXPECTED_FALSE = [
    "Regidor", "Policía", "Delegado estatal", "Autoridad expuesta", "Artista",
    "Gobernador", "Alcalde", "Secretario de Seguridad", "Coordinador estatal",
    "Servicios lícitos", "Abogado", "Manager", "Dirigente sindical", "Músico",
    "Familiar", "Sin definir"
  ].freeze

  MAP_FALSE = {
    "Autoridad expuesta" => ["Regidor", "Policía", "Delegado estatal", "Autoridad expuesta",
                             "Gobernador", "Alcalde", "Secretario de Seguridad", "Coordinador estatal"],
    "Servicios lícitos" => ["Servicios lícitos", "Abogado", "Manager", "Dirigente sindical", "Músico", "Artista"],
    "Familiar/allegado" => ["Familiar"],
    nil => ["Sin definir"]
  }.freeze

  LOOKUP_TRUE  = MAP_TRUE.flat_map { |k, arr| arr.map { |rn| [rn, k] } }.to_h.freeze
  LOOKUP_FALSE = MAP_FALSE.flat_map { |k, arr| arr.map { |rn| [rn, k] } }.to_h.freeze

  def self.call(member:)
    new(member).call
  end

  def initialize(member)
    @member = member
  end

  def call
    role_name = @member.role&.name
    return Result.new(ok?: false, changed?: false, error: "Member sin rol") if role_name.nil?

    involved = !!@member.involved

    if involved
      return Result.new(ok?: false, changed?: false, error: "Rol fuera de expected (involved=true): #{role_name}") unless EXPECTED_TRUE.include?(role_name)
      new_value = LOOKUP_TRUE[role_name]
    else
      return Result.new(ok?: false, changed?: false, error: "Rol fuera de expected (involved=false): #{role_name}") unless EXPECTED_FALSE.include?(role_name)
      new_value = LOOKUP_FALSE[role_name]
    end

    if @member.criminal_role == new_value
      return Result.new(ok?: true, changed?: false, error: nil)
    end

    # Igual que tu script: update directo
    @member.update_columns(criminal_role: new_value, updated_at: Time.current)
    Result.new(ok?: true, changed?: true, error: nil)
  rescue => e
    Result.new(ok?: false, changed?: false, error: e.message)
  end
end