#!/usr/bin/env rails runner

require 'net/http'
require 'json'
require 'base64'

puts "\n=== DIAGNÓSTICO DE API CLAUDE ===="
puts "Fecha/Hora: #{Time.now}"
puts "Ambiente: #{Rails.env}"

# 1. Verificar clave API
puts "\n--- Verificación de Clave API ---"

key_file = Rails.root.join("..", "..", "shared", "config", "anthropic_api_key").expand_path
api_key_env = ENV["ANTHROPIC_API_KEY"].presence
api_key_creds = Rails.application.credentials.dig(:anthropic, :api_key)
api_key_file = (File.read(key_file).strip if File.exist?(key_file))

puts "ENV[ANTHROPIC_API_KEY]: #{api_key_env.present? ? "✓ Presente" : "✗ No encontrada"}"
puts "credentials[:anthropic][:api_key]: #{api_key_creds.present? ? "✓ Presente" : "✗ No encontrada"}"
puts "Archivo (#{key_file}): #{api_key_file.present? ? "✓ Presente" : "✗ No encontrado"}"

api_key = api_key_env || api_key_creds || api_key_file

if api_key.blank?
  puts "\n❌ ERROR: No se encontró ANTHROPIC_API_KEY en ninguna ubicación"
  exit 1
end

puts "\n✓ API Key encontrada (primeros 10 caracteres): #{api_key[0..9]}..."

# 2. Probar conexión a API con un prompt simple
puts "\n--- Prueba de Conexión a API ---"

uri = URI("https://api.anthropic.com/v1/messages")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
http.read_timeout = 30
http.open_timeout = 10

req = Net::HTTP::Post.new(uri)
req["x-api-key"] = api_key
req["anthropic-version"] = "2023-06-01"
req["content-type"] = "application/json"

# Crear un payload simple (sin PDF) para prueba rápida
req.body = {
  model: "claude-opus-4-5",
  max_tokens: 100,
  system: "Eres un asistente.",
  messages: [
    {
      role: "user",
      content: "¿Cuál es el capital de Francia?"
    }
  ]
}.to_json

puts "Enviando solicitud a Claude API (claude-opus-4-5)..."
puts "Body: #{req.body[0..200]}..."

begin
  res = http.request(req)

  puts "\nRespuesta HTTP:"
  puts "  Status: #{res.code}"
  puts "  Headers: #{res.to_hash.slice('content-type', 'x-request-id').inspect}"

  body = JSON.parse(res.body)

  if res.code == "200"
    puts "\n✓ Conexión exitosa a Claude API"
    puts "\nContenido de respuesta:"
    puts "  #{body.inspect[0..500]}..."

    if body["content"] && body["content"][0] && body["content"][0]["text"]
      puts "\n✓ Estructura de respuesta es correcta"
      puts "  Respuesta: #{body["content"][0]["text"]}"
    else
      puts "\n⚠ Estructura de respuesta no es la esperada"
      puts "  Content: #{body["content"].inspect}"
    end
  else
    puts "\n❌ Error HTTP #{res.code}"
    puts "Respuesta completa:"
    puts JSON.pretty_generate(body)

    if body["error"]
      puts "\nDetalles del error:"
      puts "  Type: #{body["error"]["type"]}"
      puts "  Message: #{body["error"]["message"]}"
    end
  end

rescue => e
  puts "\n❌ Error al hacer la solicitud: #{e.class} - #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n=== FIN DEL DIAGNÓSTICO ==="
