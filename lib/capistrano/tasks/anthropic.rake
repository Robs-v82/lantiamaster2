namespace :anthropic do
  desc "Guardar ANTHROPIC_API_KEY en el servidor. Uso: cap production anthropic:set KEY=tu_key"
  task :set do
    key = ENV.fetch("KEY") { abort "Uso: cap production anthropic:set KEY=tu_api_key" }
    on roles(:app) do
      path = "#{shared_path}/config/anthropic_api_key"
      execute "echo #{key.shellescape} > #{path}"
      execute "chmod 600 #{path}"
      info "ANTHROPIC_API_KEY guardada en #{path}"
    end
  end
end
