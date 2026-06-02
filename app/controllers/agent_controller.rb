class AgentController < ApplicationController
  before_action :authenticate_terrorist_access

  SERPER_QUERIES = [
    "detienen líder cártel México",
    "capturan integrantes CJNG México operativo",
    "cae líder criminal célula México",
    "detenido integrante cártel Sinaloa",
    "caen integrantes crimen organizado México",
    "operativo detienen célula criminal México"
  ].freeze

  def detentions
  end

  def search
    key_file = Rails.root.join("..", "..", "shared", "config", "serper_api_key").expand_path
    api_key  = ENV["SERPER_API_KEY"].presence ||
               Rails.application.credentials.dig(:serper, :api_key) ||
               (File.read(key_file).strip if File.exist?(key_file))

    if api_key.blank?
      return render json: { error: "SERPER_API_KEY no configurada." }, status: :service_unavailable
    end

    results = []
    mutex   = Mutex.new

    threads = SERPER_QUERIES.map do |query|
      Thread.new do
        begin
          uri  = URI("https://google.serper.dev/news")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl     = true
          http.read_timeout = 10
          http.open_timeout = 5

          req = Net::HTTP::Post.new(uri)
          req["X-API-KEY"]    = api_key
          req["Content-Type"] = "application/json"
          req.body = { q: query, tbs: "qdr:d", gl: "mx", hl: "es", num: 10 }.to_json

          res  = http.request(req)
          data = JSON.parse(res.body)

          if data["news"].is_a?(Array)
            mutex.synchronize { results.concat(data["news"]) }
          end
        rescue => e
          Rails.logger.error("[Agent#search] query=#{query.inspect} #{e.class}: #{e.message}")
        end
      end
    end

    threads.each(&:join)

    seen   = {}
    unique = results.select { |a| a["link"] && seen[a["link"]] ? false : (seen[a["link"]] = true) }

    render json: { articles: unique }
  end
end
