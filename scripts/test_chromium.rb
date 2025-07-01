require 'selenium-webdriver'

chrome_bin_path = '/Applications/Chromium.app/Contents/MacOS/Chromium'
chromedriver_path = File.expand_path('scripts/chrome-bin/chromedriver')

# 👉 Aquí se especifica el path al chromedriver explícitamente
service = Selenium::WebDriver::Service.chrome(path: chromedriver_path)

options = Selenium::WebDriver::Chrome::Options.new
options.binary = chrome_bin_path
options.add_argument('--headless')
options.add_argument('--disable-gpu')

# 👉 Se pasa el service directamente
driver = Selenium::WebDriver.for :chrome, options: options, service: service

driver.navigate.to "https://www.google.com"
puts "Título de la página: #{driver.title}"

driver.quit


