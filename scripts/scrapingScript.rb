require 'net/http'
require 'net/https'

# Classic (GET )
def send_request
    uri = URI('https://app.scrapingbee.com/api/v1/?api_key=7F4T3OWDZ2MS5CJN7RF6K7E9XVTBR0RFXXZYQD9U5C2G430S09JTMLUCKTQRUQRG3B292VW5RC6O6FUK&url=https://www.elfinanciero.com.mx/nacional/2025/03/31')
    # Create client
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    # Create Request
    req =  Net::HTTP::Get.new(uri)

    # Fetch Request
    res = http.request(req)
    puts "Response HTTP Status Code: #{ res.code }".force_encoding("UTF-8")
    puts "Response HTTP Response Body: #{ res.body }".force_encoding("UTF-8")
rescue StandardError => e
    puts "HTTP Request failed (#{ e.message })"
end

send_request()