require 'ferrum'

puts "🚀 Lanzando navegador..."
browser = Ferrum::Browser.new(
  headless: true,
  browser_path: "/usr/bin/chromium-browser"
)
browser.goto("https://example.com")
puts "✅ Página cargada: #{browser.title}"
browser.screenshot(path: "example_screenshot.png")
puts "🖼️ Captura guardada como example_screenshot.png"
browser.quit

