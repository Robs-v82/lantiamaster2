class DatasetsController < ApplicationController
	
	require 'prawn'
	require 'csv'
	require 'pp'
	require 'net/http'
	require 'net/https'
	require 'uri'
	require 'json'
	require 'nokogiri'
	require 'wicked_pdf'
	require 'open-uri'
	require 'timeout'

	layout false, only: [:year_victims, :state_victims, :county_victims, :county_victims_map]
	after_action :remove_load_message, only: [:load, :terrorist_panel]

	before_action :authenticate_panel_access, only: [:members_search, :members_query, :members_outcome]
	before_action :authenticate_terrorist_access, only: [:terrorist_search, :terrorist_panel, :state_members, :clear_members, :clear_state_members]

	def show
	end
	
	def create_fake_identity
    @member = Member.find(params[:member_id])
    @fake_identity = @member.fake_identities.build(
      firstname: params[:firstname],
      lastname1: params[:lastname1],
      lastname2: params[:lastname2]
    )

    if @fake_identity.save
      redirect_back fallback_location: root_path, notice: "Identidad falsa agregada"
    else
      redirect_back fallback_location: root_path, alert: "Error al guardar identidad"
    end
  end


	# Clasificación personalizada de roles
	def clasificar_rol(member)
	  role_name = member.role&.name.to_s.strip
	  involved = member.involved

	  miembros = [
	    "Operador", "Jefe regional u operador", "Extorsionador-narcomenudista", "Jefe de sicarios", "Sicario",
	    "Jefe de plaza", "Jefe de célula", "Extorsionador", "Secuestrador", "Traficante o distribuidor",
	    "Narcomenudista", "Jefe operativo", "Jefe regional","Sin definir"
	  ]

	  licitos = ["Abogado", "Músico", "Servicios lícitos", "Periodista", "Dirigente sindical", "Artista"]

	  autoridades = ["Gobernador", "Alcalde", "Regidor", "Delegado estatal", "Coordinador estatal", "Secretario de Seguridad", "Policía", "Militar"]

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

	def terrorist_search
	  hits = Hit.all
	  members = Member.joins(:hits).where(hits: { id: hits.pluck(:id) }).distinct
	  @hits = hits
	  @members = members

	  # Tabla por usuario
	  por_usuario_raw = Hash.new { |h, k| h[k] = { hits: 0, miembros: Set.new } }
	  hits.includes(:user, :members).each do |hit|
	    key = hit.user&.id || :undefined
	    por_usuario_raw[key][:hits] += 1
	    hit.members.each { |m| por_usuario_raw[key][:miembros] << m.id }
	  end
	  @por_usuario = por_usuario_raw.sort_by { |_, data| -data[:miembros].size }.to_h

	  # Tabla por tipo de exposición
	  exposicion_raw = { true => [], false => [], nil => [] }
	  members.each do |m|
	    exposicion_raw[m.involved] << m
	  end
	  @por_exposicion = exposicion_raw

	  # Agrupar según clasificación personalizada
	  rol_raw = Hash.new { |h, k| h[k] = [] }
	  members.each do |m|
	    categoria = clasificar_rol(m)
	    rol_raw[categoria] << m
	  end
	  @por_rol = rol_raw.sort_by { |_, v| -v.size }.to_h

	  # Tabla por organización
	  @por_organizacion = members.group_by(&:organization).sort_by { |_, v| -v.size }.to_h

	  # Agregar desagregación de roles por los dos usuarios con más miembros
	  top_two_users = @por_usuario.keys.first(2).reject { |id| id == :undefined }
	  user_members_map = {}
	  top_two_users.each do |user_id|
	    user_members_map[user_id] = Member.joins(:hits).where(hits: { user_id: user_id }).distinct
	  end

	  @por_rol_con_users = @por_rol.transform_values do |miembros|
	    counts = top_two_users.map do |user_id|
	      (miembros & user_members_map[user_id]).count
	    end
	    { miembros: miembros.count, por_usuario: counts }
	  end
	  @top_two_users = top_two_users
	end


	def state_members
	  @all_roles = ["Gobernador","Líder","Operador","Autoridad cooptada","Familiar","Socio","Alcalde","Delegado estatal","Secretario de Seguridad","Autoridad expuesta","Servicios lícitos","Periodista","Abogado","Coordinador estatal","Regidor","Policía","Militar","Dirigente sindical"]

	  state = State.find_by(code: params[:code])
	  hits = Hit.joins(town: { county: :state }).where(states: { id: state.id })
	  members = Member.joins(:hits).where(hits: { id: hits.pluck(:id) }).distinct

	  @state = state
	  @hits = hits
	  @members = members
	  @rackets = @state.rackets.distinct.order(:name)
	  @link_types = ["Hermano","Esposo","Padre","Hijo","Abuelo","Nieto","Tio","Sobrino","Cuñado","Primo","Compadre","Padrino", "Ahijado", "Enlace", "Abogado", "Defendido", "Jefe", "Colaborador","Compañero", "Allegado"]

	  # Tabla por usuario
	  por_usuario_raw = Hash.new { |h, k| h[k] = { hits: 0, miembros: Set.new } }
	  hits.includes(:user, :members).each do |hit|
	    key = hit.user&.id || :undefined
	    por_usuario_raw[key][:hits] += 1
	    hit.members.each { |m| por_usuario_raw[key][:miembros] << m.id }
	  end
	  @por_usuario = por_usuario_raw.sort_by { |_, data| -data[:miembros].size }.to_h

	  # Tabla por tipo de exposición
	  exposicion_raw = { true => [], false => [], nil => [] }
	  members.each do |m|
	    exposicion_raw[m.involved] << m
	  end
	  @por_exposicion = exposicion_raw

	  # Agrupar según clasificación personalizada
	  rol_raw = Hash.new { |h, k| h[k] = [] }
	  members.each do |m|
	    categoria = clasificar_rol(m)
	    rol_raw[categoria] << m
	  end
	  @por_rol = rol_raw.sort_by { |_, v| -v.size }.to_h

	  @por_organizacion = members.group_by(&:organization).sort_by { |_, v| -v.size }.to_h
	  # Tabla por organización: incluir todas las organizaciones del estado, incluso si no tienen miembros
	  # organizaciones_del_estado = Organization.joins(:states).where(states: { id: state.id }).distinct

	  # @por_organizacion = organizaciones_del_estado.map do |org|
	  #   miembros = members.select { |m| m.organization_id == org.id }
	  #   [org, miembros]
	  # end.to_h.sort_by { |_, miembros| -miembros.size }.to_h
	end

	def add_member_link
	  member_a = Member.find_by(id: params[:source_member_id])
	  member_b = Member.find_by(id: params[:target_member_id])
	  role_a = params[:link_type].to_s.strip
	  state_code = params[:state_code]

	  if member_a.nil? || member_b.nil?
	    flash[:error] = "No se encontró uno de los miembros"
	    return redirect_to controller: :datasets, action: :state_members, code: state_code
	  end

	  if member_a.id == member_b.id
	    flash[:error] = "No puedes crear un vínculo con el mismo miembro"
	    return redirect_to controller: :datasets, action: :state_members, code: state_code
	  end

	  role_b = reciprocal_link_type(role_a)

	  # Diccionario para traducir roles al femenino
	  feminine_role_map = {
		  "Padre" => "Madre",
		  "Hijo" => "Hija",
		  "Abuelo" => "Abuela",
		  "Nieto" => "Nieta",
		  "Tio" => "Tia",
		  "Sobrino" => "Sobrina",
		  "Padrino" => "Madrina",
		  "Ahijado" => "Ahijada",
		  "Abogado" => "Abogada",
		  "Defendido" => "Defendida",
		  "Jefe" => "Jefa",
		  "Colaborador" => "Colaboradora",
		  "Hermano" => "Hermana",
		  "Compañero" => "Compañera",
		  "Amigo" => "Amiga",
		  "Primo" => "Prima",
		  "Conyuge" => "Conyuge",
		  "Pareja" => "Pareja",
		  "Esposo" => "Esposa",
		  "Socio" => "Socia",
		  "Allegado" => "Allegada",
		  "Compadre" => "Comadre",
		  "Cuñado" => "Cuñada"
	  }

	  # Asignar versión femenina si corresponde, o dejar el rol original
	  role_a_gender = member_a.gender == "FEMENINO" ? (feminine_role_map[role_a] || role_a) : role_a
	  role_b_gender = member_b.gender == "FEMENINO" ? (feminine_role_map[role_b] || role_b) : role_b

	  existe = MemberRelationship.exists?(
	    member_a_id: member_a.id, member_b_id: member_b.id, role_a: role_a, role_b: role_b
	  ) || MemberRelationship.exists?(
	    member_a_id: member_b.id, member_b_id: member_a.id, role_a: role_b, role_b: role_a
	  )

	  unless existe
	    MemberRelationship.create!(
	      member_a: member_a,
	      member_b: member_b,
	      role_a: role_a,
	      role_b: role_b,
	      role_a_gender: role_a_gender,
	      role_b_gender: role_b_gender
	    )
	  end

	  flash[:notice] = "Vínculo creado exitosamente"
	  redirect_to controller: :datasets, action: :state_members, code: state_code
	end

	def update_name
	  member = Member.find(params[:id])
	  nombre = member.firstname.strip
	  nuevo_genero = params[:member][:gender]&.strip&.capitalize

	  if member.update(params.require(:member).permit(:firstname, :lastname1, :lastname2, :role_id, :gender))
	    
	    # Ruta al archivo CSV

			if Rails.env.production?
			  # gender_file = Rails.root.join("..", "shared", "names_by_gender.csv").expand_path
			  gender_file = "/var/www/lantiamaster/shared/names_by_gender.csv"
			else
			  gender_file = Rails.root.join("scripts", "names_by_gender.csv")
			end

			unless File.exist?(gender_file)
			  raise "No se encontró el archivo de géneros en #{gender_file}"
			end

	    table = CSV.read(gender_file, headers: true)

	    # Buscar si el nombre ya está
	    row = table.find { |r| r['firstname'].to_s.strip.casecmp(nombre).zero? }

	    if row.nil?
	      # Agregar nuevo nombre
	      table << [nombre, nuevo_genero]
	    elsif row['genero_estimado'].strip.downcase == "desconocido"
	      row['genero_estimado'] = nuevo_genero
	    end

	    # Guardar archivo actualizado
	    CSV.open(gender_file, 'w') do |csv|
	      csv << ["firstname", "genero_estimado"]
	      table.each { |row| csv << row }
	    end

	    redirect_to controller: :datasets, action: :state_members, code: params[:state_code]
	  else
	    flash[:error] = "No se pudo actualizar el miembro"
	    redirect_to controller: :datasets, action: :state_members, code: params[:state_code]
	  end
	end

	def download_state_rackets
	  state = State.find_by(code: params[:code])
	  rackets = state.rackets.distinct.order(:name)

	  csv_data = CSV.generate(headers: true) do |csv|
	    csv << ["NOMBRE", "ESTATUS"]
	    rackets.each do |r|
	      csv << [r.name, r.active == false ? "Inactiva" : "Activa"]
	    end
	  end

	  # send_data csv_data.encode('UTF-8'), filename: "rackets_estado_#{state.code}.csv"
	end

	def members_query
	  query_params = members_query_params

	  input_firstname = I18n.transliterate(query_params[:firstname].to_s.strip.downcase)
	  input_lastname1 = I18n.transliterate(query_params[:lastname1].to_s.strip.downcase)
	  input_lastname2 = I18n.transliterate(query_params[:lastname2].to_s.strip.downcase)

	  def match?(input, candidate)
	    return false if candidate.blank?
	    return true if input.blank?
	    input.include?(candidate) || candidate.include?(input)
	  end

	  potential_matches = Member.includes(:fake_identities, :hits).distinct.select do |member|
	    next false if member.hits.blank?
	    # Omitir members sin al menos un nombre válido
	    next false if member.firstname.blank? && member.lastname1.blank? && member.lastname2.blank? &&
	                   member.fake_identities.none? { |fi| fi.firstname.present? || fi.lastname1.present? || fi.lastname2.present? }

	    real_match =
	      match?(input_firstname, I18n.transliterate(member.firstname.to_s.downcase)) &&
	      match?(input_lastname1, I18n.transliterate(member.lastname1.to_s.downcase)) &&
	      match?(input_lastname2, I18n.transliterate(member.lastname2.to_s.downcase))

	    fake_match = member.fake_identities.any? do |fi|
	      # Saltar identidades totalmente vacías
	      next false if fi.firstname.blank? && fi.lastname1.blank? && fi.lastname2.blank?

	      match?(input_firstname, I18n.transliterate(fi.firstname.to_s.downcase)) &&
	      match?(input_lastname1, I18n.transliterate(fi.lastname1.to_s.downcase)) &&
	      match?(input_lastname2, I18n.transliterate(fi.lastname2.to_s.downcase))
	    end

	    real_match || fake_match
	  end

	  user = User.find_by(id: session[:user_id])

	  new_query = Query.new(
	    firstname: query_params[:firstname],
	    lastname1: query_params[:lastname1],
	    lastname2: query_params[:lastname2],
	    homo_score: query_params[:homo_score],
	    outcome: potential_matches.map(&:id),
	    search: Member.joins(:hits).distinct.count,
	    user: user,
	    member: user&.member,
	    organization: user&.member&.organization
	  )

	  new_query.save

	  redirect_to '/datasets/members_outcome'
	end

	def redirect_to_outcome
	  session[:query_id] = params[:id]
	  redirect_to datasets_members_outcome_path
	end

	def members_outcome
		@all_officers = ["Gobernador","Alcalde","Secretario de Seguridad","Delegado estatal", "Coordinador estatal", "Regidor"]
		@federal_officers = ["Delegado estatal", "Coordinador estatal"]
		@state_officers = ["Gobernador", "Secretario de Seguridad"]
		@other_organizations = ["Servicios lícitos", "Dirigente sindical", "Músico"]
		@myQuery = if session[:query_id]
			Query.find_by(id: session[:query_id])
		else
			User.find(session[:user_id]).queries.last
		end
		@user = User.find(session[:user_id])
		@keyMembers = Member.where(id: @myQuery.outcome)
		@keyRolegroups = []
		@keyMembers.each {|member|
			memberGroup = clasificar_rol(member)
			@keyRolegroups.push(memberGroup)
		}
		session.delete(:query_id) # ← limpia después de usar
	end

def members_outcome_pdf
  @myQuery = Query.find_by(id: params[:id]) || User.find(session[:user_id]).queries.last
  @user = User.find(session[:user_id])
  @keyMembers = Member.where(id: @myQuery.outcome)

  pdf = Prawn::Document.new(page_size: 'A4', margin: 40)
  pdf.font_families.update("Poppins" => {
    normal: Rails.root.join("app/assets/fonts/Poppins-Regular.ttf"),
    bold:   Rails.root.join("app/assets/fonts/Poppins-Bold.ttf")
  })
  pdf.font "Poppins"

  pdf.text "RESULTADO DE CONSULTA", size: 16, style: :bold, align: :center, color: "33333C"
  pdf.move_down 20

  clave = "#{@user.member.firstname.first}#{@user.member.lastname1.first}-#{@user.member.organization_id}-#{@myQuery.id}"

  homonimo_label = case @myQuery.homo_score.to_f
    when 0...2 then "Baja"
    when 2...5 then "Media"
    when 5..10 then "Alta"
    else "Muy alta"
  end

  estimacion = case @myQuery.homo_score.to_f
    when 0...2 then "sólo 1"
    when 2...3 then "más de 2"
    when 3...4 then "más de 3"
    when 4...5 then "más de 4"
    when 5...6 then "más de 5"
    when 6...7 then "más de 6"
    when 7...8 then "más de 7"
    when 8...9 then "más de 8"
    when 9...10 then "más de 9"
    when 10...20 then "más de 10"
    when 20...30 then "más de 20"
    when 30...40 then "más de 30"
    when 40...50 then "más de 40"
    when 50...60 then "más de 50"
    when 60...70 then "más de 60"
    when 70...80 then "más de 70"
    when 80...90 then "más de 80"
    when 90...100 then "más de 90"
    when 100...200 then "más de 100"
    when 200...500 then "más de 200"
    when 500...1000 then "más de 500"
    else "más de 1000"
  end

  pdf.text "Parámetros de consulta", size: 12, style: :bold, color: "EF4E50"
  pdf.move_down 8

  resumen_data = [
    ["ID", clave],
    ["Fecha y hora", @myQuery.created_at.in_time_zone("Mexico City").strftime("%d/%m/%Y %H:%M")],
    ["Nombre(s)", @myQuery.firstname],
    ["Apellido paterno", @myQuery.lastname1],
    ["Apellido materno", @myQuery.lastname2],
    ["Registros analizados", @myQuery.search.to_s],
    ["Probabilidad de homónimos", homonimo_label],
    ["", "Se estima que hay #{estimacion} mexicano(s) adulto(s) con el nombre y apellidos consultados o alguna de sus variantes."]
  ]

  pdf.bounding_box([0, pdf.cursor], width: 325) do
    pdf.table(resumen_data, cell_style: { size: 10, padding: [4, 8, 4, 8] }) do
      row(0..-1).columns(0).font_style = :bold
      row(6).columns(1).text_color = "EF4E50"
    end
  end

  pdf.move_down 20

  if @keyMembers.any?
    pdf.text "Resultados", size: 12, style: :bold, color: "EF4E50"
    pdf.move_down 10

    @keyMembers.first(3).each_with_index do |member, index|
      pdf.text "#{%w[Primer Segundo Tercer][index]} registro", style: :bold, size: 11
      pdf.move_down 6

      cartel_designado = nil
      cartel_fuente = nil
      cartel_fuente_tipo = nil

      if member.organization&.designation
        cartel_designado = member.organization
      elsif member.organization&.parent&.designation
        cartel_designado = member.organization.parent
        cartel_fuente = cartel_designado.name
        cartel_fuente_tipo = "subordinada a"
      elsif member.organization&.allies.present?
        aliadas_designadas = Organization.where(id: member.organization.allies).select(&:designation)
        if aliadas_designadas.any?
          cartel_designado = aliadas_designadas.first
          cartel_fuente = cartel_designado.name
          cartel_fuente_tipo = "aliada a"
        end
      end

      data = [
        ["Nombre(s)", member.firstname],
        ["Apellido paterno", member.lastname1],
        ["Apellido materno", member.lastname2],
      ]
      data << ["Alias", member.alias.join(", ")] if member.alias.present?
      data << ["Organización", member.organization&.name || "Sin definir"]

      if cartel_designado.present?
        mensaje = if cartel_fuente.nil?
          "Cártel designado como terrorista\n#{cartel_designado.designation_date.strftime('%d/%m/%Y')}"
        else
          "Organización #{cartel_fuente_tipo} #{cartel_fuente}\nCártel designado como terrorista\n#{cartel_designado.designation_date.strftime('%d/%m/%Y')}"
        end
        data << ["Designación del Departamento de Estado", mensaje]
      else
        data << ["Designación del Departamento de Estado", "Organización sin vínculos de alianza o subordinación a cárteles designados como terroristas."]
      end

      data << ["Rol o vínculo con la organización", member.role&.name || "Sin definir"]

      pdf.table(data, cell_style: { size: 10, padding: [4, 6, 4, 6] }, column_widths: [180, 320]) do
        row(0..-1).columns(0).font_style = :bold
      end

      pdf.move_down 6
      pdf.text "Actividad reportada:", style: :bold, size: 10
      member.hits.order(date: :desc).each do |hit|
        lugar = "#{hit.date.strftime('%d/%m/%y')} – "
        lugar += "#{hit.town.county.name}, " unless hit.town.county.name == "Sin definir"
        lugar += hit.town.county.state.shortname
        pdf.text "• #{lugar}", size: 9
      end
      pdf.move_down 18
    end
  else
    pdf.text "No se identificaron registros de personas señaladas o personas expuestas que coincidan con los parámetros de consulta.", size: 10
  end

  send_data pdf.render, filename: "#{clave}.pdf", type: "application/pdf", disposition: "attachment"
end

	def members_search
		@names_data = Name.all.pluck(:word, :freq).map { |word, freq| [word.capitalize, freq] }.to_h
		@user = User.find_by(id: session[:user_id])
		@queries_info = consultas_mensuales(@user)
		@suscription = set_suscription(@user)
		@queries_por_dia = @user.queries
			.where(created_at: Time.current.beginning_of_month..Time.current.end_of_month)
			.group_by { |q| q.created_at.to_date }
	end

def terrorist_panel	
  if session[:load_success]
    @load_success = true
  end

  if session[:filename]
    @filename = session[:filename]
  end

  if session[:message]
    @mesagge = session[:message]
  end

  @forms = [
    { caption: "Notas/links", myAction: "/datasets/upload_hits", timeSearch: nil, myObject: "file", loaded: nil, fileWindow: true },
    { caption: "Personas", myAction: "/datasets/upload_members", timeSearch: nil, myObject: "file", loaded: nil, fileWindow: true }
  ]
end

def upload_members
	myFile = load_members_params[:file]

	# 🔍 Roles que queremos conservar
	roles_permitidos = [
	  "Líder",
	  "Operador",
	  "Autoridad cooptada",
	  "Socio",
	  "Familiar",
	  "Autoridad expuesta",
	  "Regidor",
	  "Policía",
	  "Militar",
	  "Abogado",
	  "Periodista",
	  "Servicios lícitos"
	]

	# 🗂️ Contenedores por categoría
	repetidos = []
	validos = []
	invalidos = []
	correcciones_nombres = 0

	reemplazos_roles = {
		"Líder criminal" => "Líder",
		"Familiar de un criminal" => "Familiar",
		"Miembro de un grupo criminal" => "Operador",
		"Autoridad coludida" => "Autoridad cooptada",
		"Socio de un grupo criminal" => "Socio"
	}

	# 🔎 Función auxiliar refinada para encontrar la organización
	def find_organization_by_name_or_alias(name)
	  return nil if name.blank?
	  normalized = name.to_s.strip.downcase

	  # 1️⃣ Buscar coincidencia exacta por nombre
	  exact_match = Organization.find_by("LOWER(name) = ?", normalized)
	  return exact_match if exact_match

	  # 2️⃣ Buscar coincidencia exacta por acrónimo
	  acronym_match = Organization.find_by("LOWER(acronym) = ?", normalized)
	  return acronym_match if acronym_match

	  # 3️⃣ Buscar coincidencia exacta por alias
	  alias_match = Organization.where.not(alias: nil).find do |org|
	    Array(org.alias).map { |a| a.downcase.strip }.include?(normalized)
	  end
	  return alias_match if alias_match

	  # 4️⃣ Coincidencia parcial si no se encontró por exactitud (último recurso)
	  partial_match = Organization.find do |org|
	    org.name.to_s.downcase.include?(normalized) ||
	    org.acronym.to_s.downcase.include?(normalized) ||
	    Array(org.alias).any? { |a| a.downcase.strip.include?(normalized) }
	  end
	  return partial_match
	end


	def corregir_nombres(fn, ln1, ln2)
		if fn.to_s.strip.split.size == 1 && ln1.to_s.strip.split.size == 1 && ln2.to_s.strip.split.size == 2
			nuevo_fn = "#{fn.strip} #{ln1.strip}"
			nuevo_ln1, nuevo_ln2 = ln2.strip.split
			return [nuevo_fn, nuevo_ln1, nuevo_ln2]
		end
		[fn, ln1, ln2] # si no aplica la heurística, devolver tal cual
	end

	CSV.foreach(myFile, headers: true, encoding: "bom|utf-8") do |row|
		role = row["role"]&.strip
		role = reemplazos_roles[role] || role

		next unless roles_permitidos.include?(role)
		original_fn  = row["firstname"]&.strip
		original_ln1 = row["lastname1"]&.strip
		original_ln2 = row["lastname2"]&.strip
		firstname, lastname1, lastname2 = corregir_nombres(original_fn, original_ln1, original_ln2)
		org_name   = row["organization"]&.strip
		legacy_id = row["legacy_id"]&.strip

		if [firstname, lastname1, lastname2] != [original_fn, original_ln1, original_ln2]
				correcciones_nombres += 1
		end

		# Extraer los alias
		alias_string = row["alias"]&.strip
		alias_array = alias_string.present? ? alias_string.split(";").map(&:strip).uniq : []

		datos_completos = firstname.present? && lastname1.present? && lastname2.present?

		unless datos_completos
			invalidos << row.to_h
			next
		end

		myOrganization = find_organization_by_name_or_alias(org_name)
			unless myOrganization.present?
			invalidos << row.to_h
			next
		end

		myOrganization = find_organization_by_name_or_alias(org_name)

		# Buscar posibles miembros con nombre similar o idéntico (sin importar la organización)
		miembros_potenciales = Member.where(
		  firstname: firstname,
		  lastname1: lastname1,
		  lastname2: lastname2
		)

		# Buscar match exacto
		match = miembros_potenciales.find do |m|
		  m.firstname == firstname && m.lastname1 == lastname1 && m.lastname2 == lastname2
		end

		# Si no hay match exacto, buscar similar sólo en miembros con nombres completos
		match ||= Member.where.not(firstname: [nil, ''], lastname1: [nil, ''], lastname2: [nil, '']).find do |m|
		  members_similar?(m, OpenStruct.new(firstname: firstname, lastname1: lastname1, lastname2: lastname2))
		end

		if match
		  repetidos << row.to_h

		  # Asignar rol si no tiene
			case role
			when "Líder", "Operador", "Socio"
			  rol = Role.find_or_create_by!(name: role)
			  match.update(role: rol, involved: true)

			when "Autoridad cooptada"
				match.update(involved: true)
				match.update(criminal_link: myOrganization) if myOrganization.present?

			when "Autoridad expuesta", "Regidor"
			  if match.role_id.nil?
			    rol = Role.find_or_create_by!(name: role)
			    match.update(role: rol)
			  end
		    if match.involved.nil?
		    	match.update(:involved=>false)
		    end
			  match.update(criminal_link: myOrganization) if myOrganization.present?

			else
			  # No se actualiza rol ni involved
			end

		  # Asociar hit si aplica
		  legacy_id_valida = Hit.exists?(legacy_id: legacy_id)
		  if legacy_id_valida
		    myHit = Hit.find_by(legacy_id: legacy_id) 
		    match.hits << myHit unless match.hits.exists?(myHit.id)
		  end

		  # Asignar alias si hay nuevos
		  if alias_array.any?
		    match.alias ||= []
		    nuevos_alias = alias_array - match.alias
		    if nuevos_alias.any?
		      match.alias += nuevos_alias
		      match.save!
		    end
		  end

		  # 🆕 Si se marca como detenido
		  if row["detention"].to_s.strip == "1" && myHit.present?
		    match.hits << myHit unless match.hits.exists?(myHit.id)

		    hit_date = myHit.date
		    town_id = myHit.town_id
		    detention = Detention.find_by(legacy_id: myHit.legacy_id)

		    if detention.nil?
		      new_event = Event.create!(event_date: hit_date, town_id: town_id)
		      detention = Detention.create!(event: new_event, legacy_id: myHit.legacy_id)
		    end

		    if match.detention.nil? || match.detention.event.event_date < hit_date
		      match.update!(detention: detention)
		    end
		  end

		  next
		end

		# Verificar si los datos básicos son válidos
		organizacion_valida = myOrganization.present?
		legacy_id_valida = Hit.exists?(legacy_id: legacy_id)
		if legacy_id_valida
			myHit = Hit.find_by(legacy_id: legacy_id) 
		end
		if datos_completos && organizacion_valida && legacy_id_valida
			validos << row.to_h
			rol = Role.find_or_create_by!(name: role)
			valor_involved = ["Líder", "Operador", "Autoridad cooptada", "Socio"].include?(role)
			
		# Ruta del archivo de géneros
		if Rails.env.production?
		  # gender_file = Rails.root.join("..", "shared", "names_by_gender.csv").expand_path
		  gender_file = "/var/www/lantiamaster/shared/names_by_gender.csv"
		else
		  gender_file = Rails.root.join("scripts", "names_by_gender.csv")
		end

		unless File.exist?(gender_file)
		  raise "No se encontró el archivo de géneros en #{gender_file}"
		end

		gender_data = CSV.read(gender_file, headers: true)

		# Buscar el género estimado
		gender_row = gender_data.find { |row| row["firstname"].to_s.strip.downcase == firstname.strip.downcase }

		# Estimar género
		estimated_gender = gender_row&.[]("genero_estimado")
		assignable_gender = case estimated_gender&.downcase
		                    when "masculino"
		                      "MASCULINO"
		                    when "femenino"
		                      "FEMENINO"
		                    else
		                      nil
		                    end

		# Crear el nuevo miembro con género estimado (si existe)
		myMember = Member.create!(
		  firstname: firstname,
		  lastname1: lastname1,
		  lastname2: lastname2,
		  organization: myOrganization, 
		  alias: alias_array,
		  role: rol,
		  involved: valor_involved,
		  gender: assignable_gender
		)

		# Agregar el nombre al archivo si no existía
		if gender_row.nil?
		  CSV.open(gender_file, "a+") do |csv|
		    csv << [firstname, "Desconocido"]
		  end
		end

		    myMember.hits << myHit

			if row["detention"].to_s.strip == "1" && myHit.present?
				hit_date = myHit.date
				town_id = myHit.town_id
				detention = Detention.find_by(legacy_id: myHit.legacy_id)
				if detention.nil?
					new_event = Event.create!(event_date: hit_date, town_id: town_id)
					detention = Detention.create!(event: new_event, legacy_id: myHit.legacy_id)
				end
				myMember.update!(detention: detention)
			end
		else
			invalidos << row.to_h
		end
	end

	session[:filename] = load_members_params[:file].original_filename
	session[:load_success] = true
	session[:message] = "🔁 Repetidos: #{repetidos.count}"+"\n"+
		"✅ Válidos:   #{validos.count}"+"\n"+
		"⚠️ Inválidos: #{invalidos.count}" + "\n" +
		"✏️ Nombres corregidos: #{correcciones_nombres}"


	csv_string = CSV.generate(headers: true) do |csv|
	  csv << ["legacy_id", "firstname", "lastname1", "lastname2", "alias", "role", "organization", "detention"]
	  invalidos.each do |row|
	    csv << [
	      row["legacy_id"],
	      row["firstname"],
	      row["lastname1"],
	      row["lastname2"],
	      row["alias"],
	      row["role"],
	      row["organization"],
	      row["detention"]
	    ]
	  end
	end

	# Guardar CSV en archivo temporal
	filename = "invalid_members_#{Time.now.to_i}.csv"
	filepath = Rails.root.join("tmp", filename)
	File.write(filepath, csv_string)

	# Guardar el nombre en sesión para usarlo en la vista
	session[:invalid_members_csv] = filename

	# Obtener miembros con al menos un hit
	targetMembers = Member.joins(:hits).distinct

	# Evaluar media_score de cada miembro
	puts "⏳ Evaluando media_score..."
	targetMembers.find_each do |member|
	  hits = member.hits
	  media_score_value = hits.size >= 2 && hits.any? { |h| h.national }
	  member.update_column(:media_score, media_score_value)
	end
	Member.joins(:role).where(roles: { name: ["Alcalde","Regidor","Policía","Militar"] }, involved: false).update_all(media_score: true)
	puts "✅ media_score actualizado para miembros clave."

	redirect_to '/datasets/terrorist_panel'
end

	def download_invalid_members
		filename = params[:filename]
		filepath = Rails.root.join("tmp", filename)

		if File.exist?(filepath)
			send_file filepath, filename: filename, type: "text/csv"
		else
			redirect_to '/datasets/terrorist_panel', alert: "El archivo ya no está disponible."
		end
	end

	def load
		@quarters = Quarter.all.sort
		@months = Month.all.sort
		ensuLoaded = []
		violenceReportLoaded = []
		socialReportLoaded = []
		forecastReportLoaded = []
		crimeVictimReportLoaded = []
		briefingLoaded = []
		@quarters.each{|quarter|
			if quarter.ensu.attached?
				ensuLoaded.push(quarter.name)
			end
		}
		@months.each{|month|
			if month.violence_report.attached?
				violenceReportLoaded.push(month.name)
			end
			if month.social_report.attached?
				socialReportLoaded.push(month.name)
			end
			if month.forecast_report.attached?
				forecastReportLoaded.push(month.name)
			end
			if month.crime_victim_report.attached?
				crimeVictimReportLoaded.push(month.name)
			end
		}
		myFiles = Dir['public/briefings/*'].sort { |a, b| a.downcase <=> b.downcase }
    	myFiles.each{|file|
    		# myHash = {}
    		# myHash[:path] = file[7..-1]
    		# myHash[:number] = file[34..36]
    		myString = file[34..36]
    		# myMonth = Month.where(:name=>myString).last
    		# myHash[:month] = I18n.l(myMonth.first_day, format: '%B de %Y')
    		briefingLoaded.push(myString)
    	}
    	briefingLoaded = briefingLoaded[-31..-1]


		@cartels = helpers.get_cartels
		if session[:load_success]
			@load_success = true
		end
		if session[:filename]
			@filename = session[:filename]
		end
		if session[:bad_briefing]
			@bad_briefing = true
		end
		@myYears = (2010..2030)
		@forms = [
			{caption:"Víctimas", myAction:"/victims/load_victims", timeSearch: "shared/monthsearch", myObject:"file", loaded: nil, fileWindow: true},
			{caption:"ICon", myAction:"/states/load_icon", timeSearch: "shared/quartersearch", myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Perfil OC", myAction:"/organizations/load_organizations", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Referencias-Incidentes OC", myAction:"/organizations/load_organization_events", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Presencia estatal-municipal OC", myAction:"/organizations/load_organization_territory", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Detenciones", myAction:"/members/detentions", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"ENSU BP1_1", myAction:"/datasets/load_ensu", timeSearch:"shared/quartersearch", myObject:"ensu", loaded:ensuLoaded, fileWindow: true},
			{caption:"Reporte de Violencia del Crimen Organizado", myAction:"/months/load_violence_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:violenceReportLoaded, fileWindow: true},
			{caption:"Reporte de Riesgo Social", myAction:"/months/load_social_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:socialReportLoaded, fileWindow: true},
			{caption:"Prospectiva", myAction:"/months/load_forecast_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:forecastReportLoaded, fileWindow: true},
			{caption:"Briefing semanal", myAction:"/datasets/load_briefing", timeSearch: nil, myObject:"report", loaded:briefingLoaded, fileWindow: true},
			{caption:"Cifras delictivas mensuales", myAction:"/months/load_crime_victim_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:crimeVictimReportLoaded, fileWindow: true},
			{caption:"Crear irco estatal", myAction:"/states/load_irco", timeSearch:"shared/quartersearch", myObject: nil, loaded:nil},
			{caption:"Crear datos para irco estatal", myAction:"/states/stateIndexHash", timeSearch:"shared/quartersearch", myObject: nil, loaded:nil},
			{caption:"Crear irco municipal", myAction:"/counties/load_irco", timeSearch:"shared/quartersearch", myObject: nil, loaded:nil},
			{caption:"Cambiar nombre a organización", myAction:"/organizations/new_name", timeSearch:"shared/cartelsearch", myObject: "name", loaded:nil}
		]
	end

	def api_control
		@forms = [
		]		
	end

	def load_ensu

		myName = load_ensu_params[:year]+"_"+load_ensu_params[:quarter]
		myQuarter = Quarter.where(:name=>myName).last		
		myQuarter.ensu.purge
		myQuarter.ensu.attach(load_ensu_params[:ensu])

		if myQuarter.ensu.attached?
			session[:filename] = load_ensu_params[:ensu].original_filename
			session[:load_success] = true
		end


		# CHECK CSV FILE STRUCTURE
		myFile = myQuarter.ensu.download
		myFile = myFile.force_encoding("UTF-8")
		rawData = myFile

		ensuArr = []
		rawData.each_line{|l| line = l.split(","); ensuArr.push(line)}
		ensuArr.each{|x|x.each{|y|y.strip!}}


		l = ensuArr.length-1

		State.all.each{|state|
			stateArr = []
			statePopulation = 0
			feel_safe = 0
			state.ensu_cities.each{|city|
				(0..l).each{|x|
					if ensuArr[x][0]
						if ensuArr[x][0] == city and ensuArr[x][1] !=""
							cityArr = []
							statePopulation += ensuArr[x][1].delete(' ').to_i
							cityArr.push(ensuArr[x][0],ensuArr[x][1].delete(' ').to_i,ensuArr[x+1][4].to_f)
							stateArr.push(cityArr)
						end
					end
				}
			}
			stateArr.each{|y|
				myShare = ((y[1].to_f/statePopulation.to_f))
				myPoints = myShare*y[2]
				feel_safe += myPoints
			}
		}
		redirect_to "/datasets/load"
	end

	def load_briefing
		myFile = load_briefing_params[:report]
		regex = /^Briefing_Semanal_\d{3}_Lantia_Intelligence_\d{8}_.pdf$/
		if !!(myFile.original_filename =~ regex)
			dir = Rails.root.join('public','briefings')
			File.open(dir.join(myFile.original_filename), 'wb') do |file|
  				file.write(myFile.read)
			end
			session[:load_success] = true
			session[:filename] = myFile.original_filename
		else
			session[:bad_briefing] = true
		end
		redirect_to "/datasets/load"	
	end

	def basic
		@forms = [
			{caption:"countyScript", myAction:"/datasets/load_counties", myObject:"csv"},
			{caption:"killingScript", myAction:"/datasets/load_killings", myObject:"csv"}
		]
	end 	

	def victims_query
		helpers.clear_session
		session[:checkedYearsArr] = []
		years = helpers.get_regular_years
		years.each {|year|
			session[:checkedYearsArr].push(year.id)
		}
		session[:checkedStatesArr] = []
		states = State.all.sort
		stateArr = []
		states.each{|state|
			session[:checkedStatesArr].push(state.id)	
			stateArr.push(state.id)
		}
		session[:checkedCitiesArr] = []
		cities = City.all.sort_by {|city| city.name}
		citiesArr = []
		cities.each{|city|
			session[:checkedCitiesArr].push(city.id)	
			citiesArr.push(city.id)
		}
		genderOptions = ["Masculino","Femenino","No identificado"]
		session[:checkedGenderOptions] = genderOptions
		countiesArr = []
		session[:victim_freq_params] = ["annual","stateWise","noGenderSplit", years, stateArr, citiesArr, genderOptions, countiesArr]
		redirect_to "/datasets/victims"
		session[:checkedCounties] = "states"
	end

	def post_victim_query
		if victim_freq_params[:freq_timeframe]
			session[:victim_freq_params][0] = victim_freq_params[:freq_timeframe]
		end
		if victim_freq_params[:freq_placeframe]
			session[:victim_freq_params][1] = victim_freq_params[:freq_placeframe]
		end
		if victim_freq_params[:freq_genderframe]
			session[:victim_freq_params][2] = victim_freq_params[:freq_genderframe]
		end
		if victim_freq_params[:freq_years]
			session[:checkedYearsArr] = victim_freq_params[:freq_years].map(&:to_i)
			myArr = []
			victim_freq_params[:freq_years].each{|id|
				myArr.push(Year.find(id))
			}
			session[:victim_freq_params][3] = myArr
		end
		if victim_freq_params[:freq_states]
			session[:checkedStatesArr] = victim_freq_params[:freq_states].map(&:to_i) 
			# myArr = []
			# victim_freq_params[:freq_states].each{|id|
			# 	myArr.push(id)
			# }
			session[:victim_freq_params][4] = session[:checkedStatesArr]
		end
		if victim_freq_params[:freq_gender_options]
			session[:checkedGenderOptions] = victim_freq_params[:freq_gender_options]
			session[:victim_freq_params][6] = session[:checkedGenderOptions]
		end
		if victim_freq_params[:freq_counties]
			myArr = victim_freq_params[:freq_counties].map(&:to_i)
			Cookie.create(:data=>myArr)
			session[:checkedCounties] = Cookie.last.id
		else
			session[:checkedCounties] = "states"
		end
		session[:checkedCitiesArr] = victim_freq_params[:freq_cities]
		session[:checkedCitiesArr] = session[:checkedCitiesArr].map(&:to_i)
		session[:victim_freq_params][5] = session[:checkedCitiesArr]
		redirect_to "/datasets/victims"
	end

	def victims
		@key = Rails.application.credentials.google_maps_api_key
		@my_freq_table = victim_freq_table(session[:victim_freq_params][0],session[:victim_freq_params][1],session[:victim_freq_params][2],session[:victim_freq_params][3],session[:victim_freq_params][4],session[:victim_freq_params][5],session[:victim_freq_params][6],session[:checkedCounties])
		@timeFrames = [
  			{caption:"Anual", box_id:"annual_query_box", name:"annual"},
			{caption:"Trimestral", box_id:"quarterly_query_box", name:"quarterly"},
			{caption:"Mensual", box_id:"monthly_query_box", name:"monthly"},
  		]
  		@placeFrames = [
  			{caption:"Nacional", box_id:"nation_query_box", name:"nationWise"},
  			{caption:"Estado", box_id:"state_query_box", name:"stateWise"},
			{caption:"Z Metropolitana", box_id:"city_query_box", name:"cityWise"},
			{caption:"Municipio", box_id:"county_query_box", name:"countyWise"},
  		]
  		@genderFrames = [
  			{caption:"No desagregar", box_id:"no_gender_split_query_box", name:"noGenderSplit"},
			{caption:"Desagregar", box_id:"gender_split_query_box", name:"genderSplit"},
  		]

  		if session[:victim_freq_params][0] == "annual"
  			@timeFrames[0][:checked] = true
  			@annual = true
  		elsif session[:victim_freq_params][0] == "quarterly"
  			@timeFrames[1][:checked] = true
  			@quarterly = true
  		elsif session[:victim_freq_params][0] == "monthly"
  			@timeFrames[2][:checked] = true
  		end

  		if session[:victim_freq_params][1] == "nationWise"
  			@nationWise = true
  			@placeFrames[0][:checked] = true
  		elsif session[:victim_freq_params][1] == "stateWise"
  			@stateWise = true
  			@placeFrames[1][:checked] = true
  		elsif session[:victim_freq_params][1] == "cityWise"
  			@cityWise = true
  			@placeFrames[2][:checked] = true
  		elsif session[:victim_freq_params][1] == "countyWise"
  			@countyWise = true
  			@placeFrames[3][:checked] = true
  		end

  		if session[:victim_freq_params][2] == "noGenderSplit"
  			@genderFrames[0][:checked] = true
  		elsif session[:victim_freq_params][2] == "genderSplit"
  			@genderFrames[1][:checked] = true
  		end
  		
  		@sortCounter = 0
  		@sortType = "victims"
  		@years = helpers.get_regular_years
  		@checkedYears = session[:checkedYearsArr]
  		@states = State.all.sort
  		@cities = City.all.sort_by {|city| city.name}
  		@genderOptions = [
  			{"caption"=>"Masculino","value"=>"Masculino"},
  			{"caption"=>"Femenino","value"=>"Femenino"},
  			{"caption"=>"No identificado","value"=>"No identificado"},
  		]
  		@checkedStates = session[:checkedStatesArr]
  		@checkedCities = session[:checkedCitiesArr]
  		@checkedGenderOptions = session[:checkedGenderOptions]
  		if @checkedStates.length == 1
  			targetState = State.find(@checkedStates[0])
  			@counties = targetState.counties.sort_by {|county| county.full_code}
  		else
  			@counties = []
  		end
  		unless session[:checkedCounties] == "states"
  			@checkedCounties = Cookie.find(session[:checkedCounties]).data
  		else
  			@checkedCounties = []
  		end
  		@county_toast_message = 'Seleccione estado y municipios en "Filtros"'
  		unless session[:victim_freq_params][1] == "nationWise"
			if @genderFrames[0][:checked]
				@maps = true
			elsif @checkedGenderOptions.length == 1
				@maps = true
			end
		end
	end

	def load_victim_freq_table
		years = Year.all
		tablesArr = [
			{:scope=>"stateWise", :regions=>State.all, :periods=>helpers.get_specific_years(years, "victims"), :category=>"state_annual_noGenderSplit_victims"},
			{:scope=>"countyWise", :regions=>County.all, :periods=>helpers.get_specific_years(years, "victims"), :category=>"county_annual_noGenderSplit_victims"}
		] 
		
		tablesArr.each{|x|
			myArr = []
			totalHash = {}
			totalFreq = []
			(1..x[:periods].length).each {
				totalFreq.push(0)
			}

			x[:regions].each{|place|
				unless place.victims.empty?
					placeHash = {}
					placeHash[:name] = place.name
					if x[:scope] == "countyWise"
						placeHash[:parent_name] = place.state.shortname
					end
					freq = []
					counter = 0
					place_total = 0
					localVictims = place.victims
					x[:periods].each {|timeUnit|
						number_of_victims = localVictims.merge(timeUnit.victims).length
						freq.push(number_of_victims)
						totalFreq[counter] += number_of_victims
						counter += 1
						place_total += number_of_victims
					}
					placeHash[:freq] = freq
					placeHash[:place_total] = place_total
					myArr.push(placeHash)
				end
			}
			totalHash[:freq] = totalFreq
			total_total = 0
			totalFreq.each{|q|
				total_total += q
			}
			totalHash[:total_total] = total_total
			myArr.push(totalHash)
			Cookie.create(:data=>myArr, :category=>x[:category])
		}

		
		redirect_to '/datasets/load'
	end

	def victim_freq_table(period, scope, gender, years, states, cities, genderOptions, counties)
		myTable = []
		headerHash = {}
		totalHash = {}
		totalHash[:name] = "Total"
		
		myStates = []
		states.each {|x|
			myState = State.find(x)
			myStates.push(myState)
		}

		myCities = []
		cities.each {|x|
			myCity = City.find(x)
			myCities.push(myCity)
		}

		if	scope == "nationWise"
			myScope = nil
		elsif scope == "stateWise"
			headerHash[:scope] = "ESTADO" 
			myScope = myStates
		elsif scope == "cityWise"
			headerHash[:scope] = "Z METRO"
			myScope = myCities
		elsif scope == "countyWise"
			headerHash[:pre_scope] = "ESTADO"
			totalHash[:county_placer] = "--"
			headerHash[:scope] = "MUNICIPIO"
			myScope = []
			if counties == "states"
				myStates.each{|state|
					myScope.push(state.counties)
				}
			else
				myCounties = []
				myKeys = Cookie.find(counties).data
				myKeys.each {|x|
					myCounty = County.find(x)
					myCounties.push(myCounty)
				}
				myScope = myCounties
			end		
			myScope = myScope.flatten
			myScope = myScope.sort_by {|county| county.full_code}
			pp myScope
		end

		if period == "annual"
			myPeriod = helpers.get_specific_years(years, "victims")
		elsif period == "quarterly"
			myPeriod = helpers.get_specific_quarters(years, "victims")
		elsif period == "monthly"
			myPeriod = helpers.get_specific_months(years, "victims")
		end

		totalFreq = []
		(1..myPeriod.length).each {
			totalFreq.push(0)
		}

		headerHash[:period] = myPeriod

		if myScope == nil
			if gender == "noGenderSplit"
				myTable.push(headerHash)
				placeHash = {}
				placeHash[:name] = "Nacional"
				freq = []
				counter = 0
				place_total = 0
				myPeriod.each {|timeUnit|
					number_of_victims = timeUnit.victims.length
					freq.push(number_of_victims)
					totalFreq[counter] += number_of_victims
					counter += 1
					place_total += number_of_victims
				}
				placeHash[:freq] = freq
				placeHash[:place_total] = place_total
				myTable.push(placeHash)
			else
				headerHash[:gender] = "GÉNERO"
				totalHash[:gender_placer] = "--"
				myTable.push(headerHash)
				genderOptions.each{|gender|
					placeHash = {}
					placeHash[:name] = "Nacional"
					placeHash[:gender] = gender
					freq = []
					counter = 0
					place_total = 0
					myPeriod.each {|timeUnit|
						number_of_victims = timeUnit.victims.where(:gender=>gender).length
						freq.push(number_of_victims)
						totalFreq[counter] += number_of_victims
						counter += 1
						place_total += number_of_victims
					}
					placeHash[:freq] = freq
					placeHash[:place_total] = place_total 
					myTable.push(placeHash)
				}	
			end
		else
			if gender == "noGenderSplit"
				myTable.push(headerHash)
				myScope.each {|place|
					localVictims = place.victims
						placeHash = {}
						placeHash[:name] = place.name
						if scope == "countyWise"
							placeHash[:parent_name] = place.state.shortname
							placeHash[:full_code] = place.full_code
						end
						freq = []
						counter = 0
						place_total = 0
						
						myPeriod.each {|timeUnit|
							number_of_victims = localVictims.merge(timeUnit.victims).length
							freq.push(number_of_victims)
							totalFreq[counter] += number_of_victims
							counter += 1
							place_total += number_of_victims
						}
					placeHash[:freq] = freq
					placeHash[:place_total] = place_total
					myTable.push(placeHash)
				}
			else
				headerHash[:gender] = "GÉNERO"
				totalHash[:gender_placer] = "--"
				myTable.push(headerHash)
				myScope.each {|place|
					genderOptions.each{|gender|
						placeHash = {}
						placeHash[:name] = place.name
						if scope == "countyWise"
							placeHash[:parent_name] = place.state.shortname
							placeHash[:full_code] = place.full_code
						end
						placeHash[:gender] = gender
						freq = []
						counter = 0
						place_total = 0
						localVictims = place.victims
						myPeriod.each {|timeUnit|
							number_of_victims = timeUnit.victims.where(:gender=>gender).merge(localVictims).length
							freq.push(number_of_victims)
							totalFreq[counter] += number_of_victims
							counter += 1
							place_total += number_of_victims
						}
						placeHash[:freq] = freq
						placeHash[:place_total] = place_total 
						myTable.push(placeHash)
					}
				}
			end
		end
		totalHash[:freq] = totalFreq
		total_total = 0
		totalFreq.each{|q|
			total_total += q
		}
		totalHash[:total_total] = total_total
		myTable.push(totalHash)
		return myTable
	end

	# def sort
	# 	if params[:type] == "victims"
	# 		redirect_to "/datasets/victims"
	# 	end
	# end

    def loadApi
        myHash = {}
        stateArr = []
        State.all.each{|state|
        	stateHash = {}
        	stateHash[:code] = state.code
        	stateHash[:name] = state.name
        	stateHash[:shortname] = state.shortname
        	stateHash[:population] = state.population
        	countyArr = []
        	state.counties.each{|county|
        		countyHash = {}
        		countyHash[:code] = county.full_code
        		countyHash[:name] = county.name
        		countyHash[:shortname] = county.shortname
        		countyHash[:population] = county.population
        		countyArr.push(countyHash)
        	}
        	stateHash[:conties] = countyArr
        	stateArr.push(stateHash)
        }
        stateArr = stateArr.sort_by{|state| state[:code]}
        myHash[:states_and_counties] = stateArr
 
        # LAST UPDATE
        lastKilling = Killing.all.sort_by{|k| k.event.event_date}.last
        thisMonth = Event.find(lastKilling.event_id).month
        lastDay = Event.find(lastKilling.event_id).event_date

        myHash[:lastUpdate] = Date.civil(lastDay.year, lastDay.month, -1)

        # TOTAL VICTIMS PER YEAR (WITH ESTIMATE FOR CURRENT YEAR)
        myYears = helpers.get_regular_years
        # CHANGE THIS IN JANUARY!!!
        # thisYear = Year.where(:name=>Time.now.year.to_s).last
        thisYear = Year.where(:name=>"2024").last
        victimYearsArr = []
        myYears.each{|year|
            yearHash = {}
            yearHash[:year] = year.name.to_i
            genderHash = {}
            if year != thisYear
                yearHash[:victims] = year.victims.length
                genderHash[:maleVictims] = year.victims.where(:gender=>"Masculino").length
                genderHash[:femaleVictims] = year.victims.where(:gender=>"Femenino").length
                genderHash[:undefined] = year.victims.where(:gender=>"").length
                yearHash[:estimate] = false
            else
                n = helpers.get_specific_months([thisYear], "victims").length
                unless n == 0
                    yearHash[:victims] = year.victims.length*(12/n.to_f)
                    print "OOoo"*100
                    print yearHash[:victims]
                    yearHash[:victims] = yearHash[:victims].round(0)
                    if n == 12
                        yearHash[:estimate] = false        
                    else
                        yearHash[:estimate] = true
                    end
                end
            end
            yearHash[:victimsGender] = genderHash
            victimYearsArr.push(yearHash)
        }
        myHash[:years] = victimYearsArr

        # MONTHLY VICITMS FOR 5 MOST VIOLENT STATE (PREVIOUS 12 MONTHS) 
        topStatesArr = []
        State.all.each{|state|
            stateHash = {}
            stateHash[:code] = state.code
            stateHash[:name] = state.name
            stateHash[:shortname] = state.shortname
            r = 11..0
            stateHash[:totalVictims] = 0
            stateHash[:months] = []
            localVictims = state.victims
            (r.first).downto(r.last).each {|x|
                monthHash = {}
                monthHash[:month] = (thisMonth.first_day - (x*28).days).strftime('%m-%Y')
                monthHash[:victims] = Month.where(:name=>(thisMonth.first_day - (x*28).days).strftime('%Y_%m')).last.victims.merge(localVictims).length
                stateHash[:totalVictims] += monthHash[:victims]
                stateHash[:months].push(monthHash)
            }
            topStatesArr.push(stateHash)
        }
        topStatesArr = topStatesArr.sort_by{|state| -state[:totalVictims]}
        myHash[:topStates] = topStatesArr[0..3]

        topCountiesArr = []
        allCountiesArr = []
        County.all.each{|county|
            unless county.name == "Sin definir"
            	unless county.victims == 0
		            countyHash = {}
		            countyHash[:code] = county.full_code
		            countyHash[:name] = county.name
		            countyHash[:shortname] = county.shortname
		            r = 11..0
		            countyHash[:totalVictims] = 0
		            countyHash[:months] = []
		            localVictims = county.victims
		            (r.first).downto(r.last).each {|x|
		                monthHash = {}
		                monthHash[:month] = (thisMonth.first_day - (x*28).days).strftime('%m-%Y')
		                monthHash[:victims] = Month.where(:name=>(thisMonth.first_day - (x*28).days).strftime('%Y_%m')).last.victims.merge(localVictims).length
		                countyHash[:totalVictims] += monthHash[:victims]
		                countyHash[:months].push(monthHash)
		            }
		            topCountiesArr.push(countyHash)
		            if county.population
			            if county.population > 200000
			            	positiveCountyHash = {}
			            	positiveCountyHash[:code] = county.full_code
			            	positiveCountyHash[:name] = county.name
			            	positiveCountyHash[:shortname] = county.shortname
			            	positiveCountyHash[:latitude] = county.towns.where(:code=>"0000").last.latitude
			            	positiveCountyHash[:longitude] = county.towns.where(:code=>"0000").last.longitude
				        	if countyHash[:totalVictims] > 240
				        		positiveCountyHash[:victimLevel] = "21 en adelante"
				        	elsif countyHash[:totalVictims] > 120
				        		positiveCountyHash[:victimLevel] = "11 a 20"
				        	elsif countyHash[:totalVictims] > 12
				        		positiveCountyHash[:victimLevel] = "1 a 10"
				        	else
				        		positiveCountyHash[:victimLevel] = "menos de 1"	
				        	end
				        	allCountiesArr.push(positiveCountyHash)
			        	end
			        end
		        end
	        end
        }

        topCountiesArr = topCountiesArr.sort_by{|county| -county[:totalVictims]}
        myHash[:countyVictimsMap] = allCountiesArr.sort_by{|county| county[:full_code]}
        myHash[:topCounties] = topCountiesArr[0..3]
        Cookie.create(:data=>[myHash], :category=>"api")
        redirect_to "/datasets/api_control"
    end

    def load_featured_state
    	myState = State.where(:name=>"Guerrero").last
    	levels = helpers.ircoLevels
    	myHash = {}
    	irco = Cookie.where(:category=>"irco").last.data
    	myHash[:quarter] = irco[0][:evolution_score].last[:string] 
    	myHash[:state] = {:code=>myState.code, :name=>myState.name, :shortname=>myState.shortname}
    	irco.each{|x|
    		if x[:state].id == myState.id
    			myHash[:irco] = {:score=>x[:irco][:score]}
    			myHash[:irco][:level] = x[:level]
    			myHash[:irco][:trend] = x[:trend]
    			myHash[:irco][:rank] = x[:rank].to_i
    			myHash[:irco][:n] = 32
    		end
    	}
    	myHash[:irco][:score] =  myHash[:irco][:score]*10
        myHash[:irco][:score] = myHash[:irco][:score].round()
    	myRackets = {}
    	cartel_id = League.where(:name=>"Cártel").last.id
    	mafia_id = League.where(:name=>"Mafia").last.id
    	band_id = League.where(:name=>"Banda").last.id
    	myRackets[:n] = myState.rackets.uniq.length
    	myRackets[:cartels] = myState.rackets.where(:mainleague=>cartel_id).uniq.pluck(:name).sort
    	myRackets[:mafias] = myState.rackets.where(:mainleague=>mafia_id).uniq.pluck(:name).sort
    	myRackets[:bands] = myState.rackets.where(:mainleague=>band_id).uniq.pluck(:name).sort
    	myHash[:rackets] = myRackets
    

    	Cookie.create(:data=>[myHash], :category=>"featured_state_api")
    	redirect_to "/featured_state_api"
    end

    def load_featured_county
    	myCounty = County.where(:full_code=>"09015").last
    	levels = helpers.ircoLevels
    	myHash = {}
    	irco = Cookie.where(:category=>"irco_counties").last.data
    	myHash[:quarter] = irco[0][:evolution_score].last[:string]
    	myHash[:county] = {:code=>myCounty.full_code, :name=>myCounty.name, :shortname=>myCounty.shortname}
    	irco.each{|x|
    		if x[:county].id == myCounty.id
    			myHash[:irco] = {:score=>x[:irco][:score]}
    			myHash[:irco][:level] = x[:level]
    			myHash[:irco][:trend] = x[:trend]
    			myHash[:irco][:rank] = x[:rank].to_i
    			myHash[:irco][:n] = helpers.bigCounties.length
    		end
    	}
    	myHash[:irco][:score] =  myHash[:irco][:score]*10
        myHash[:irco][:score] = myHash[:irco][:score].round()
    	myRackets = {}
    	cartel_id = League.where(:name=>"Cártel").last.id
    	mafia_id = League.where(:name=>"Mafia").last.id
    	band_id = League.where(:name=>"Banda").last.id
    	myRackets[:n] = myCounty.rackets.uniq.length
    	myRackets[:cartels] = myCounty.rackets.where(:mainleague=>cartel_id).uniq.pluck(:name).sort
    	myRackets[:mafias] = myCounty.rackets.where(:mainleague=>mafia_id).uniq.pluck(:name).sort
    	myRackets[:bands] = myCounty.rackets.where(:mainleague=>band_id).uniq.pluck(:name).sort
    	myHash[:rackets] = myRackets
    

    	Cookie.create(:data=>[myHash], :category=>"featured_county_api")
    	redirect_to "/featured_county_api"
    end

    def states_and_counties_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:data=>myData[:states_and_counties]}
        render json: myHash 
    end

    def year_victims_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:lastUpdate=>myData[:lastUpdate], :data=>myData[:years]}
        render json: myHash 
    end

    def year_victims
        previousYears = [
        	{:year=>"2007",:victims=>2826},
        	{:year=>"2008",:victims=>6837},
        	{:year=>"2009",:victims=>9614},
        	{:year=>"2010",:victims=>15266},
        	{:year=>"2011",:victims=>15768},
        	{:year=>"2012",:victims=>13675},
        	{:year=>"2013",:victims=>11269},
        	{:year=>"2014",:victims=>8004},
        	{:year=>"2015",:victims=>8122},
        	{:year=>"2016",:victims=>12224},
        	{:year=>"2017",:victims=>18946}
        ]
        victimYearsArr = Cookie.where(:category=>"api").last.data[0][:years]
        @yearData = previousYears.append(*victimYearsArr)
        @yearData[0][:change] = "--"
        (1..@yearData.length-1).each{|x|
        	change = @yearData[x][:victims]/@yearData[x-1][:victims].to_f
        	@yearData[x][:change] = ((change - 1)*100).round(1)
        }
    end

    def state_victims_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:lastUpdate=>myData[:lastUpdate], :data=>myData[:topStates]}
        render json: myHash 
    end

    def state_victims
    	colorAxis = ["#2f8f8f", "#ef974e", "#3ebf3e", "#757575"]
    	@placeData = Cookie.where(:category=>"api").last.data[0][:topStates]
    	(0..3).each{|x|
    		@placeData[x][:color] = colorAxis[x]
    	}
    end

    def county_victims_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:lastUpdate=>myData[:lastUpdate], :data=>myData[:topCounties]}
        render json: myHash 
    end

    def county_victims
    	colorAxis = ["#2f8f8f", "#ef974e", "#3ebf3e", "#757575"]
    	@placeData = Cookie.where(:category=>"api").last.data[0][:topCounties]
    	(0..3).each{|x|
    		@placeData[x][:color] = colorAxis[x]
    	}
    end

    def county_victims_map_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:lastUpdate=>myData[:lastUpdate], :data=>myData[:countyVictimsMap]}
        render json: myHash 
    end

    def county_victims_map
    	@mapData = Cookie.where(:category=>"api").last.data[0][:countyVictimsMap]
    end

    def featured_state_api
        myData = Cookie.where(:category=>"featured_state_api").last.data[0]
        myHash = {:data=>myData}
    	render json: myHash
    end

    def featured_county_api
        myData = Cookie.where(:category=>"featured_county_api").last.data[0]
        myHash = {:data=>myData}
    	render json: myHash
    end

    def downloads
    	@v_months = Month.joins(:violence_report_attachment).sort { |a, b| b <=> a }
    	@s_months = Month.joins(:social_report_attachment).sort { |a, b| b <=> a }
    	@f_months = Month.joins(:forecast_report_attachment).sort { |a, b| b <=> a }
    	myFiles = Dir['public/briefings/*'].sort { |a, b| b.downcase <=> a.downcase }
    	@briefings = []
    	myFiles.each{|file|
    		myHash = {}
    		myHash[:path] = file[7..-1]
    		myHash[:number] = file[34..36]
    		myString = file[62..65]+"_"+file[60..61]
    		myMonth = Month.where(:name=>myString).last
    		myHash[:month] = I18n.l(myMonth.first_day, format: '%B de %Y')
    		@briefings.push(myHash)
    	}
    end

	def upload_hits
		loaded = 0
		skipped = 0
		errors = []
		user_agent = "WickedPdf/1.0 (Lantia Intelligence)"
		myFile = load_hit_params[:file]
		CSV.foreach(myFile, headers: true, encoding: "bom|utf-8") do |row|
			legacy_id = row["legacy_id"]&.strip
			date      = Date.parse(row["fecha"]) rescue nil
			state_name = row["estado"]&.strip
			municipality_name = row["municipio o localidad"]&.strip
			clave = row["clave INEGI"]&.strip
			clave = clave.rjust(5, "0") if clave.present? # Normaliza clave a 6 dígitos
			title = row["título"]&.strip
			report = row["reporte"]&.strip
			link = row["link"]&.strip

	    # Validación: legacy_id único
	    if Hit.exists?(legacy_id: legacy_id)
			skipped += 1
			next
	    end

	    # Validación: fecha válida
	    if date.nil?
			errors << { legacy_id: legacy_id, error: "Fecha inválida" }
			next
	    end

	    # Validación: determinar el town por clave INEGI o nombre del estado
	    town = nil

	    if clave.present?
	    	clave = clave + "0000"
	    	unless Town.find_by(full_code: clave).nil?
	    		town = Town.find_by(full_code: clave).id
	    	end
	    end

	    if town.nil? && state_name.present?
			state = State.find_by(name: state_name)
			clave = state.code + "0000000"
			town = Town.find_by(full_code: clave).id
	    end

	    if town.nil?
			errors << { legacy_id: legacy_id, error: "No se encontró municipio ni estado" }
			next
	    end

	    # Validación: link único o reporte presente
	    link_valido = link.present? && !Hit.exists?(link: link)
	    tiene_reporte = report.present?

	    unless link_valido || tiene_reporte
			errors << { legacy_id: legacy_id, error: "Sin link válido ni reporte" }
			next
	    end

	    # Crear el hit
	    Hit.create!(
			legacy_id: legacy_id,
			date: date,
			title: title,
			link: link,
			report: report,
			town_id: town,
			user_id: session[:user_id]
	    )
	    loaded += 1

	    begin
		    targetHit = Hit.last
		    next unless targetHit.link.present? && targetHit.link.start_with?('http')
		    puts "🌀 Generando PDF para: #{targetHit.link}"
	    	timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
	    	image_url = "https://dashboard.lantiaintelligence.com/assets/Lantia_LogoPositivo.png"

		    html_header = <<~HTML
		      <div style='font-size: 14px; font-family: sans-serif; border-bottom: 1px solid #ccc; padding-bottom: 10px; margin-bottom: 20px;'>
		        <img src='#{image_url}' style='width: 160px; display: block; margin-bottom: 10px;' alt='Lantia Logo'>
		        <div style="font-size: 14px;">
		          Fuente:<span style="font-weight: 800;"> #{targetHit.link}</span><br>
		          Capturado:<span style="font-weight: 800;"> #{timestamp}</span><br>
		          User-Agent:<span style="font-weight: 800;"> #{user_agent}</span><br>
		          Organización:<span style="font-weight: 800;"> Estrategias, Decisiones y Mejores Prácticas</span>
		        </div>
		      </div>
		    HTML

		    Timeout.timeout(45) do
		      html_body = URI.open(targetHit.link, "User-Agent" => user_agent).read

		      pdf = WickedPdf.new.pdf_from_string(
		        html_header + html_body,
		        encoding: 'UTF-8',
		        margin: { top: 20, bottom: 10 },
		        disable_javascript: true,
		        javascript_delay: 3000,
		        print_media_type: true,
		        zoom: 1.25,
		        dpi: 150,
		        viewport_size: '1280x1024'
		      )

		      io = StringIO.new(pdf)
		      targetHit.pdf.attach(io: io, filename: "targetHit_#{targetHit.id}.pdf", content_type: 'application/pdf')
		      puts "✅ PDF adjuntado a Hit ##{targetHit.id}"
		    end

		  rescue => e
		    puts "⚠️ Error en Hit ##{targetHit.id}: #{e.message}"
		    targetHit.update(protected_link: true)
		  end

		rescue => e
			errors << { legacy_id: legacy_id, error: e.message }
			next
		end

		puts "✅ Hits cargados: #{loaded}"
		puts "⚠️ Hits omitidos (legacy_id duplicado): #{skipped}"
		puts "❌ Errores:"
		errors.each { |e| puts e.inspect }
	  	session[:filename] = load_hit_params[:file].original_filename
		session[:load_success] = true
		session[:message] = "✅ Hits cargados: #{loaded} \n ⚠️ Hits omitidos (legacy_id duplicado): #{skipped}"
		
		nationalMedia = [
		  "infobae.com",
		  "jornada.com.mx",
		  "oem.com.mx",
		  "lasillarota.com",
		  "milenio.com",
		  "proceso.com.mx",
		  "excelsior.com.mx",
		  "elfinanciero.com.mx",
		  "eluniversal.com.mx",
		  "eleconomista.com.mx",
		  "sinembargo.mx",
		  "aristeguinoticias.com",
		  "reforma.com",
		  "univision.com",
		  "latinus.us"
		]

		puts "⏳ Actualizando nacionalidad de hits..."
		Hit.where(:national=>nil).each do |hit|
		  domain = hit.link.to_s.match(/https?:\/\/(?:www\.)?([^\/]+)/).to_a[1]
		  is_national = nationalMedia.include?(domain)
		  hit.update_column(:national, is_national)
		end
		puts "✅ Hits actualizados."

		redirect_to '/datasets/terrorist_panel'
	end

	def search
		@cartels = Sector.where(:scian2=>98).last.organizations.uniq
	end

	def web_scrape

		def build_duckduckgo_url(query, offset)
			base_url = 'https://html.duckduckgo.com/html/'
			"#{base_url}?q=#{URI.encode_www_form_component(query)}&s=#{offset}"
		end

		def fetch_html_with_scrapingbee(url)
			api_key = '7F4T3OWDZ2MS5CJN7RF6K7E9XVTBR0RFXXZYQD9U5C2G430S09JTMLUCKTQRUQRG3B292VW5RC6O6FUK' 
			uri = URI('https://app.scrapingbee.com/api/v1/')
			params = {
			api_key: api_key,
			url: url,
			render_js: false,
			block_resources: true
			}
			uri.query = URI.encode_www_form(params)

			res = Net::HTTP.get_response(uri)

			html = res.body
			html.force_encoding('UTF-8')
			html.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
		end

		def extract_links_from_duckduckgo(html)
			doc = Nokogiri::HTML(html)
			links = []

			doc.css('a.result__a').each do |a|
				href = a['href']
				# if href.include?('milenio.com')
				links << href
			end

			links.uniq
		end

		year = scraping_params[:year]
		if year == "2025"
			months = %w[enero febrero marzo abril]
		else
			months = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre]
		end
		cartel = scraping_params[:cartel]
		state = scraping_params[:state]
		if scraping_params[:domain]
			myDomain = scraping_params[:domain]
		else
			puts "XXxx"*1000 +"Domain empty"
		end
		pages_per_month = 1
		all_links = []
		Dir.mkdir('htmls') unless Dir.exist?('htmls')

		months.each do |month|
			puts "\n📅 Procesando: #{month.capitalize} #{year}"

			pages_per_month.times do |i|
				offset = i * 30
				query = "#{cartel} #{month} #{year} #{state}"
				if myDomain
					query = query + " site: #{myDomain}"
				end
				url = build_duckduckgo_url(query, offset)

				puts "🔎 Página #{i + 1} — Offset #{offset}"
				html = fetch_html_with_scrapingbee(url)

				# Guardar HTML por si querés inspeccionar
				File.write("htmls/duck_cjng_#{month}_#{year}_p#{i + 1}.html", html)

				links = extract_links_from_duckduckgo(html)
				puts "   ↳ Se encontraron #{links.size} enlaces"
				all_links.concat(links)

				sleep(2)
			end
		end

		filename = "tmp/scraped_links_#{SecureRandom.hex(10)}.json"
		File.write(filename, all_links.uniq.to_json)
		session[:scraped_links_file] = filename
		redirect_to '/datasets/terrorist_panel'
	end

	def download_scraped_links
		if session[:scraped_links_file] && File.exist?(session[:scraped_links_file])
			links = JSON.parse(File.read(session[:scraped_links_file])) rescue []

			csv_data = CSV.generate do |csv|
				csv << ['Enlace']
				links.each { |link| csv << [link] }
			end
				send_data csv_data, filename: "enlaces_scrapeados_#{Time.zone.now.to_date}.csv", type: 'text/csv'
			else
				redirect_to '/datasets/terrorist_panel'
			end
	end

def clear_members
  if session[:clear_state]
  	session.delete(:clear_state)
  end
  @key_members = Member.joins(:hits).distinct.includes(:role, :organization)
  @key_members = @key_members.sort_by { |m| m.role&.name == "Autoridad" ? 0 : 1 }

  session[:ignored_conflicts] ||= []

  @similar_pairs_count = 0
  evaluated_pairs = Set.new

  @key_members.each_with_index do |member1, idx1|
    @key_members.each_with_index do |member2, idx2|
      next if idx2 <= idx1

      pair_key = member1.id < member2.id ? [member1.id, member2.id] : [member2.id, member1.id]
      next if evaluated_pairs.include?(pair_key)

      evaluated_pairs << pair_key

      if members_similar?(member1, member2)
        @similar_pairs_count += 1

        unless session[:ignored_conflicts].include?(pair_key)
          @member1 = member1
          @member2 = member2
          return
        end
      end
    end
  end

  session.delete(:ignored_conflicts)
  flash[:notice] = "No hay más miembros en conflicto."
  redirect_to datasets_terrorist_panel_path
end


def clear_state_members
	session[:clear_state] = params[:code]
  state = State.where(:code=>params[:code]).last
  @key_members = Member.joins(:hits => { town: { county: :state } }).where(states: { code: params[:code] }).distinct
  @key_members = @key_members.sort_by { |m| m.role&.name == "Autoridad" ? 0 : 1 }
  @key_members.each{|m|
  }

  session[:ignored_conflicts] ||= []

  @similar_pairs_count = 0
  evaluated_pairs = Set.new

  @key_members.each_with_index do |member1, idx1|
    @key_members.each_with_index do |member2, idx2|
      next if idx2 <= idx1

      pair_key = member1.id < member2.id ? [member1.id, member2.id] : [member2.id, member1.id]
      next if evaluated_pairs.include?(pair_key)

      evaluated_pairs << pair_key

      if members_similar?(member1, member2)
        @similar_pairs_count += 1

        unless session[:ignored_conflicts].include?(pair_key)
          @member1 = member1
          @member2 = member2
          return
        end
      end
    end
  end

  session.delete(:ignored_conflicts)
  flash[:notice] = "No hay más miembros en conflicto."
end


def ignore_conflict
  member1_id = params[:member1_id].to_i
  member2_id = params[:member2_id].to_i

  session[:ignored_conflicts] ||= []
  session[:ignored_conflicts] << [member1_id, member2_id].sort

  redirect_to datasets_clear_members_path
end

def merge_members
  keep = Member.find(params[:keep_id])
  remove = Member.find(params[:remove_id])

  # Transferir hits
  remove.hits.each do |hit|
    keep.hits << hit unless keep.hits.include?(hit)
  end

  # Solo aplicar si el que se conserva tiene rol "Alcalde"
  if keep.role&.name == "Alcalde" && remove.involved == true
    # nueva_role_id = Role.where(name: "Autoridad cooptada").last&.id
    keep.update(
      involved: true,
      role_id: nueva_role_id,
      criminal_link_id: remove.organization_id,
      media_score: remove.media_score,
    ) if nueva_role_id
  end

  remove.destroy

  # Redirigir al siguiente conflicto recalculado
	if session[:clear_state]
	  redirect_to "/datasets/clear_state_members/#{session[:clear_state]}" and return
	end	
	redirect_to datasets_clear_members_path
end

private

def reciprocal_link_type(type)
  map = {
    "Padre" => "Hijo","Hijo" => "Padre",
    "Abuelo" => "Nieto","Nieto" => "Abuelo",
    "Tio" => "Sobrino","Sobrino" => "Tio",
    "Padrino" => "Ahijado","Ahijado" => "Padrino",
    "Abogado" => "Defendido","Defendido" => "Abogado",
    "Jefe" => "Colaborador","Colaborador" => "Jefe"
  }
  map[type] || type # Si es recíproco como "Hermano" o "Compañero", se repite igual
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


	def members_query_params
 		params.require(:query).permit(:firstname, :lastname1, :lastname2, :homo_score)
	end

	def load_ensu_params
		params.require(:query).permit(:ensu,:year,:quarter)
	end

	def load_briefing_params
		params.require(:query).permit(:report)
	end

	def basic_county_params
		params.require(:file).permit(:csv)
	end

	def victim_freq_params
		params[:query][:freq_years] ||= []
		params.require(:query).permit(:freq_timeframe, :freq_placeframe, :freq_genderframe, freq_years: [], freq_states: [], freq_cities: [], freq_counties: [], freq_gender_options: [])
	end

	def load_hit_params
		params.require(:query).permit(:file)
	end

	def load_members_params
		params.require(:query).permit(:file)
	end

	def scraping_params
		params.require(:query).permit(:year, :cartel, :state, :domain)
	end

	def authenticate_panel_access
		user = User.find_by(id: session[:user_id])
		org = user&.member&.organization

		unless org&.search_panel && org.search_level.to_i > 0
			redirect_to root_path, alert: "Acceso no autorizado."
		end
	end

	def consultas_mensuales(user)
		return { usuario: 0, organizacion: 0, total: 0 } unless user&.member&.organization

			inicio_de_mes = Time.current.beginning_of_month
			fin_de_mes = Time.current.end_of_month
			org = user.member.organization

			queries_usuario = user.queries.where(created_at: inicio_de_mes..fin_de_mes).count

			queries_organizacion = Query.where(user_id: org.users.where.not(id: user.id).pluck(:id))
			.where(created_at: inicio_de_mes..fin_de_mes)
			.count

			{
			usuario: queries_usuario,
			organizacion: queries_organizacion,
			total: queries_usuario + queries_organizacion
		}
	end


	def set_suscription(user)
		org_level = user&.member&.organization&.search_level.to_i

		@suscription = case org_level
		when 1
		{ level: "básica", points: 200 }
			when 2
		{ level: "avanzada", points: 500 }
			when 3
		{ level: "premium", points: 1000 }
		else
			{ level: "sin suscripción", points: 0 }
		end
	end

end
