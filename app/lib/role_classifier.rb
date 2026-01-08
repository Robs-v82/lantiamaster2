module RoleClassifier
  def clasificar_rol(member)
    role_name = member.role&.name.to_s.strip
    involved = member.involved

    miembros = [
      "Operador", "Jefe regional u operador", "Extorsionador-narcomenudista", "Jefe de sicarios", "Sicario",
      "Jefe de plaza", "Jefe de célula", "Extorsionador", "Secuestrador", "Traficante o distribuidor",
      "Narcomenudista", "Jefe operativo", "Jefe regional","Sin definir"
    ]

    licitos = ["Abogado", "Músico", "Manager", "Servicios lícitos", "Periodista", "Dirigente sindical", "Artista"]

    autoridades = ["Autoridad cooptada", "Autoridad expuesta", "Gobernador", "Alcalde", "Regidor", "Delegado estatal", "Coordinador estatal", "Secretario de Seguridad", "Policía", "Militar"]

    return "Líder" if role_name == "Líder"
    return "Socio" if role_name == "Socio"
    return "Familiar/allegado" if role_name == "Familiar"
    return "Autoridad cooptada" if role_name == "Autoridad vinculada"
    return "Autoridad expuesta" if role_name == "Autoridad expuesta"

    if autoridades.include?(role_name)
      return involved ? "Autoridad vinculada" : "Autoridad expuesta"
    end

    return "Servicios lícitos" if licitos.include?(role_name)

    return "Miembro" if miembros.include?(role_name)

    "Sin clasificar"
  end
end