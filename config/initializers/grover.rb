Grover.configure do |config|
  config.options = {
    executable_path: '/usr/bin/chromium-browser', # Asegúrate que este sea el path correcto
    args: ['--no-sandbox']
  }
end