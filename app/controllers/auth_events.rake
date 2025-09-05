namespace :audit do
  desc "Exporta eventos de autenticación últimos N días (default 30) a stdout CSV"
  task :export, [:days] => :environment do |_, args|
    days = (args[:days] || 30).to_i
    require "csv"
    from = days.days.ago
    events = AuthEvent.where("created_at >= ?", from).order(:created_at)
    CSV($stdout) do |csv|
      csv << %w[id created_at user_id event_type ip user_agent metadata]
      events.find_each do |e|
        csv << [e.id, e.created_at.iso8601, e.user_id, e.event_type, e.ip, e.user_agent, e.metadata]
      end
    end
  end
end
