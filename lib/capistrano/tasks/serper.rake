namespace :serper do
  desc "Guardar SERPER_API_KEY en el servidor. Uso: cap production serper:set KEY=tu_key"
  task :set do
    key = ENV.fetch("KEY") { abort "Uso: cap production serper:set KEY=tu_api_key" }
    on roles(:app) do
      path = "#{shared_path}/config/serper_api_key"
      execute "echo #{key.shellescape} > #{path}"
      execute "chmod 600 #{path}"
      info "SERPER_API_KEY guardada en #{path}"
    end
  end
end
