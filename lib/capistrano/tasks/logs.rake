namespace :logs do
  desc "Tail production log (últimas 100 líneas)"
  task :tail do
    on roles(:app) do
      execute "tail -100 #{shared_path}/log/production.log"
    end
  end
end
