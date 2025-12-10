# scripts/fixLeadership.rb
require "csv"

class FixLeadership
  # Nombre por defecto del CSV. Puedes cambiarlo o usar la variable de entorno:
  # FIX_LEADERSHIP_CSV="otro_nombre.csv" load "scripts/fixLeadership.rb"
  CSV_BASENAME = ENV["FIX_LEADERSHIP_CSV"] || "TEAM Líderes criminales JAVL (01122025) - Revisado.csv"

  # Mapeo de valores de New.role → nombre de Role
  # nil significa "no cambiar" (caso Líder criminal).
  ROLE_MAPPING = {
    "Líder criminal"     => nil,              # No se cambia
    "Operador"           => "Operador",
    "Subjefe criminal"   => "Jefe operativo",
    "Jefe de plaza"      => "Jefe de plaza"
  }.freeze

  def self.run
    new.run
  end

  def run
    path = File.join(__dir__, CSV_BASENAME)

    unless File.exist?(path)
      puts "[ERROR] No se encontró el archivo CSV en: #{path}"
      puts "Puedes especificar un archivo distinto con FIX_LEADERSHIP_CSV=\"archivo.csv\""
      return
    end

    puts "== Iniciando FixLeadership =="
    puts "Usando CSV: #{path}"
    processed = 0

    CSV.foreach(path, headers: true, encoding: "bom|utf-8") do |row|
      processed += 1
      begin
        process_row(row)
      rescue => e
        puts "[ERROR] Fila #{processed}: #{e.class} - #{e.message}"
        puts e.backtrace.first(3).join("\n")
      end
    end

    puts "== Terminado FixLeadership. Filas procesadas: #{processed} =="
  end

  private

  # --- Procesamiento de cada fila ---

  def process_row(row)
    member = find_member(row)

    unless member
      puts "[OMITIDO] No se encontró Member para la fila: #{summary(row)}"
      return
    end

    ActiveRecord::Base.transaction do
      update_role(member, row)
      update_organization(member, row)

      if delete_flag?(row)
        merge_and_delete(member, row)
      else
        if member.changed?
          member.save!
          puts "[OK] Actualizado Member #{member.id} (#{member.fullname})"
        else
          puts "[OK] Sin cambios para Member #{member.id} (#{member.fullname})"
        end
      end
    end
  end

  # Intenta localizar el Member usando diversas posibles columnas de ID
  def find_member(row)
    id_str = (
      row["id"] ||
      row["member_id"] ||
      row["Member.id"] ||
      row["memberId"]
    ).to_s.strip

    return nil if id_str.empty?

    Member.find_by(id: id_str)
  end

  # --- 1) Cambio de rol con base en New.role ---

  def update_role(member, row)
    new_role_key = (
      row["New.role"] ||
      row["new.role"] ||
      row["new_role"]
    ).to_s.strip

    return if new_role_key.empty?

    mapped_name = ROLE_MAPPING[new_role_key]

    # Caso A: "Líder criminal" → no cambiar
    return if mapped_name.nil?

    role = Role.find_by(name: mapped_name)
    unless role
      puts "[AVISO] No existe Role con name='#{mapped_name}'. No se cambió el rol de Member #{member.id}."
      return
    end

    if member.role_id != role.id
      old_name = member.role&.name || "(sin rol)"
      member.role = role
      puts "  - Rol: #{old_name} → #{role.name} (Member #{member.id})"
    end
  end

  # --- 2) Cambio de organización con base en new.Organization.name ---

  def update_organization(member, row)
    org_name = (
      row["new.Organization.name"] ||
      row["New.Organization.name"] ||
      row["Organization.name"]
    ).to_s.strip

    return if org_name.empty?

    org = Organization.find_by(name: org_name)
    unless org
      puts "[AVISO] No existe Organization con name='#{org_name}'. No se cambió la organización de Member #{member.id}."
      return
    end

    if member.organization_id != org.id
      old_name = member.organization&.name || "(sin organización)"
      member.organization = org
      puts "  - Organización: #{old_name} → #{org.name} (Member #{member.id})"
    end
  end

  # --- 3) Lógica de eliminación / fusión ---

  def delete_flag?(row)
    val = (row["Eliminar"] || row["eliminar"] || row["delete"]).to_s.strip
    val.to_i == 1
  end

  def merge_and_delete(source_member, row)
    target_id_str = (
      row["Fusionar"] ||
      row["fusionar"] ||
      row["Merge.into"]
    ).to_s.strip

    if target_id_str.empty?
      raise "Columna Fusionar vacía para Member #{source_member.id} marcado con Eliminar=1"
    end

    target = Member.find_by(id: target_id_str)
    raise "No se encontró Member destino con id=#{target_id_str} para fusión de Member #{source_member.id}" unless target

    if target.id == source_member.id
      raise "Member destino igual al origen (#{source_member.id}) para fusión"
    end

    # 3A) Asociar todos los hits al Member destino
    move_hits(source_member, target)

    # 3A) Reasignar relaciones al Member destino
    move_relationships(source_member, target)

    # 3B) Eliminar el Member fuente
    source_id = source_member.id
    source_member.destroy!
    puts "[OK] Member #{source_id} fusionado en #{target.id} y eliminado"
  end

  # --- Helpers de fusión ---

  def move_hits(source_member, target)
    source_hits = source_member.hits.to_a
    return if source_hits.empty?

    hits_to_add = source_hits.reject { |h| target.hits.exists?(h.id) }
    hits_to_add.each { |h| target.hits << h }

    puts "  - Movidos #{hits_to_add.size} hits de #{source_member.id} → #{target.id}"
  end

  def move_relationships(source_member, target)
    rels = MemberRelationship.where("member_a_id = :id OR member_b_id = :id", id: source_member.id)

    moved   = 0
    removed = 0

    rels.find_each do |rel|
      if rel.member_a_id == source_member.id
        rel.member_a_id = target.id
      else
        rel.member_b_id = target.id
      end

      # Si la relación queda autorreferenciada (A==B), la eliminamos
      if rel.member_a_id == rel.member_b_id
        rel.destroy!
        removed += 1
        next
      end

      begin
        rel.save!
        moved += 1
      rescue ActiveRecord::RecordNotUnique
        # Si hay índice único que impide duplicados, borramos la duplicada
        rel.destroy
        removed += 1
      end
    end

    puts "  - Reasignadas #{moved} relaciones a #{target.id}, eliminadas #{removed} relaciones duplicadas/autorreferenciadas"
  end

  # --- Utilidades de logging ---

  def summary(row)
    id = row["id"] || row["member_id"] || row["Member.id"] || row["memberId"]
    name = row["fullname"] || row["Nombre"] || row["name"]
    "id=#{id}, nombre=#{name}"
  end
end

FixLeadership.run