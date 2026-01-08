module MembersOutcomeUtils
  extend self

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

  # - appt_span_label(start_date, end_date)
  def appt_span_label(s, e)
    return "Sin fechas" if s.blank? && e.blank?
    return s.strftime("%d/%m/%Y") if s.present? && e.blank?
    return e.strftime("%d/%m/%Y") if e.present? && s.blank?
    "#{s.strftime("%d/%m/%Y")} a #{e.strftime("%d/%m/%Y")}"
  end

end