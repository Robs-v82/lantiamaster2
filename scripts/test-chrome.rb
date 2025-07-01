require 'selenium-webdriver'
require 'webdrivers'  # asegura que tenga el chromedriver correcto
Webdrivers::Chromedriver.required_version = '114.0.5735.90'

options = Selenium::WebDriver::Chrome::Options.new
# Quita este comentario si quieres que corra sin abrir ventana:
# options.add_argument('--headless')

driver = Selenium::WebDriver.for :chrome, options: options
driver.navigate.to "https://www.google.com"
puts "Título de la página: #{driver.title}"
driver.quit
