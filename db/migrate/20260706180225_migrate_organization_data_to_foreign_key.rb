class MigrateOrganizationDataToForeignKey < ActiveRecord::Migration[6.0]
  def up
    DetentionCapture.find_each do |capture|
      # Prioridad: grupo_afiliado si existe, sino organizacion
      org_name = (capture.grupo_afiliado.presence || capture.organizacion.presence)

      if org_name.present?
        # SOLO buscar - sin crear
        org = Organization.where("name ILIKE ?", org_name.strip).first

        if org
          capture.update_column(:organization_id, org.id)
        else
          # Log para revisar qué no se encontró
          Rails.logger.warn("[Migration] Organization NOT FOUND: '#{org_name}' en DetentionCapture #{capture.id}")
        end
      end
    end
  end

  def down
    DetentionCapture.update_all(organization_id: nil)
  end
end
