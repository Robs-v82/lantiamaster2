source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.7.1'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0.3'
# Use Puma as the app server
gem 'puma', '~> 4.1'
# Use SCSS for stylesheets
gem 'sass-rails', '>= 6'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem 'webpacker', '3.3.1'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
# gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
gem 'bcrypt', '~> 3.1.13'

# Use Active Storage variant
gem 'image_processing', '~> 1.2'
gem "aws-sdk-s3", require: false
gem "active_storage_validations"

# Reduces boot times through caching; required in config/boot.rb
# gem 'bootsnap', '>= 1.4.2', require: false
gem 'bootsnap', '~> 1.18', '>= 1.18.3', require: false

# Materialize CSS
gem 'materialize-sass', '~> 1.0.0'

gem 'execjs'

# gem 'mini_racer'

# for Excel downloads
gem 'rubyzip', '>= 1.2.1'
# gem 'caxlsx', '~> 3.0'

# gem 'poppler'
gem 'mini_magick'

gem 'wicked_pdf'
gem 'wkhtmltopdf-binary'

gem "chartkick"

# gem 'daru-view', git: 'https://github.com/SciRuby/daru-view'

gem 'capistrano', '~> 3.11'
gem 'capistrano-rails', '~> 1.4'
gem 'capistrano-passenger', '~> 0.2.0'
gem 'capistrano-rbenv', '~> 2.1', '>= 2.1.4'

gem 'capistrano3-puma'

gem 'listen', '~> 3.2' 
gem 'database_cleaner'

gem 'jquery-rails'
# gem 'jquery-ui-rails'
# gem 'sqlite3', '~> 1.4.1'
gem 'pg'

gem 'csv-xlsx-converter'
gem 'prawn'
gem 'prawn-table'

gem 'wicked_pdf'
gem 'wkhtmltopdf-binary', platforms: [:mri, :mingw, :x64_mingw]

gem 'selenium-webdriver'
gem 'ferrum'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  # Use sqlite3 as the database for Active Record
end

group :development do
  gem 'capistrano-db-tasks', require: false
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  # gem 'capybara', '>= 2.15'
  gem 'sqlite3'
end

group :production do 
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem "httparty", "~> 0.23.1"
