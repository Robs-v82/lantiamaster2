module MembersHelper
	include MembersOutcomeUtils
	def detention_cartels
		Organization.where(:name=>"Cártel de Sinaloa")
		.or(Organization.where(:name=>"Cártel Jalisco Nueva Generación"))
		.or(Organization.where(:name=>"Cártel del Noreste"))
		.or(Organization.where(:name=>"La Unión Tepito"))
	end

	def top_detention_roles
		myArr = [
			"Líder",
			"Autoridad cooptada",
			"Jefe de célula",
			"Traficante o distribuidor",
			"Jefe regional u operador",
		]
		return myArr
	end

	def members_similar?(member1, member2)
	  fn1 = I18n.transliterate(member1.firstname.to_s.downcase)
	  ln1a = I18n.transliterate(member1.lastname1.to_s.downcase)
	  ln1b = I18n.transliterate(member1.lastname2.to_s.downcase)

	  fn2 = I18n.transliterate(member2.firstname.to_s.downcase)
	  ln2a = I18n.transliterate(member2.lastname1.to_s.downcase)
	  ln2b = I18n.transliterate(member2.lastname2.to_s.downcase)

	  firstname_match = fn1.include?(fn2) || fn2.include?(fn1)
	  lastname1_match = ln1a.include?(ln2a) || ln2a.include?(ln1a)
	  lastname2_match = ln1b.include?(ln2b) || ln2b.include?(ln1b)

	  firstname_match && lastname1_match && lastname2_match
	end

  def appt_bounds(appt)
    s = appt.respond_to?(:start_date) ? appt.start_date : nil
    e = appt.respond_to?(:end_date)   ? appt.end_date   : nil

    if (!s || !e) && appt.respond_to?(:period) && appt.period.present?
      rng = appt.period
      s ||= rng.begin
      e ||= (rng.exclude_end? ? (rng.end - 1) : rng.end) # Date - 1 día
    end
    [s, e]
  end

  # Formatea el tramo de fechas en dd/mm/aaaa a dd/mm/aaaa
  def appt_span_label(s, e)
    return "Sin fechas" if s.blank? && e.blank?
    return s.strftime("%d/%m/%Y") if s.present? && e.blank?
    return e.strftime("%d/%m/%Y") if e.present? && s.blank?
    "#{s.strftime("%d/%m/%Y")} a #{e.strftime("%d/%m/%Y")}"
  end

  # Deduplica appointments por [organization_id, role_id, start, end]
  # y regresa arreglo de [appt, s, e]
  def dedup_appointments_for_view(appts)
    seen = {}
    out  = []
    appts.each do |a|
      s, e = appt_bounds(a)
      key  = [a.organization_id, a.role_id, s, e]
      next if seen[key]
      seen[key] = true
      out << [a, s, e]
    end
    out
  end

end
