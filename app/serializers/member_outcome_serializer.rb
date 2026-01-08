class MemberOutcomeSerializer
  def initialize(member, rolegroup:)
    @m = member
    @rolegroup = rolegroup
  end

  def as_json(*)
    {
      id: @m.id,
      media_score: @m.media_score,
      firstname: @m.firstname,
      lastname1: @m.lastname1,
      lastname2: @m.lastname2,
      alias: (@m.alias || []),
      birthday: birthday_payload,
      fake_identities: @m.fake_identities.map { |fi| { firstname: fi.firstname, lastname1: fi.lastname1, lastname2: fi.lastname2 } },
      titles: titles_payload,
      classification: { involved: @m.involved },
      rolegroup: @rolegroup,
      cartel: cartel_payload,
      cartel_designation: cartel_designation_payload,
      notes: @m.notes.map(&:story),
      appointments: appointments_payload,
      hits: hits_payload
    }
  end

  private

  def birthday_payload
    return nil unless @m.birthday?
    if @m.birthday_aprox?
      { approx: true, year: @m.birthday.strftime("%Y") }
    else
      { approx: false, date: @m.birthday.strftime("%Y-%m-%d") }
    end
  end

  def titles_payload
    @m.titles.map do |t|
      {
        legacy_id: t.legacy_id,
        type: t.type,
        profesion: t.profesion,
        institution: t.organization&.name,
        year: t.year&.name
      }
    end
  end

  def cartel
    @m.criminal_link.presence || @m.organization
  end

  def cartel_payload
    c = cartel
    { id: c&.id, name: c&.name }
  end

  def cartel_designation_payload
    c = cartel
    return { status: "no_cartel" } unless c

    if c.designation
      { status: "designated", source: "self", name: c.name, date: c.designation_date }
    elsif c.parent&.designation
      { status: "designated", source: "parent", name: c.parent.name, date: c.parent.designation_date, relation: "subordinada a" }
    elsif c.allies.present?
      ally = Organization.where(id: c.allies).select(&:designation).first
      if ally
        { status: "designated", source: "ally", name: ally.name, date: ally.designation_date, relation: "aliada a" }
      else
        { status: "not_designated" }
      end
    else
      { status: "not_designated" }
    end
  end

  def appointments_payload
    appts = @m.appointments.to_a
    dedup = MembersOutcomeUtils.dedup_appointments_for_view(appts)

    dedup.sort_by { |(_a, s, e)| [s || Date.new(1,1,1), e || Date.new(9999,12,31)] }.map do |appt, s, e|
      {
        id: appt.id,
        role: appt.role&.name,
        organization: appt.organization&.name,
        span_label: (s.present? || e.present?) ? MembersOutcomeUtils.appt_span_label(s, e) : nil
      }
    end
  end

  def hits_payload
    @m.hits.sort_by { |h| h.date || Date.new(1,1,1) }.reverse.map do |hit|
      {
        date: hit.date&.strftime("%Y-%m-%d"),
        link: hit.link,
        county: hit.town&.county&.name,
        state_shortname: hit.town&.county&.state&.shortname
      }
    end
  end
end