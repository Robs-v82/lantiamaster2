require_relative 'config/environment'

def normalize(str)
  I18n.transliterate(str.to_s.downcase.strip)
end

# VERSIÓN V3 - Estrategia basada en PATRONES
def split_name_v3(name)
  clean = name.gsub(/\s+/, " ").strip

  if clean.include?(",")
    last, first = clean.split(",", 2)
    last_normalized = normalize(last)
    first_normalized = normalize(first)

    last_tokens = last_normalized.split
    prepositions = ["de", "del", "da", "la", "el"]

    # NUEVA ESTRATEGIA: Identificar patrones de preposiciones
    # Patrones conocidos:
    # - "preposicion palabra": agrupa ambas
    # - "preposicion preposicion palabra": agrupa las tres
    # - "palabra preposicion palabra": agrupa los últimos dos si hay más tokens
    
    grouped_last = []
    i = 0
    
    while i < last_tokens.length
      current = last_tokens[i]
      
      if prepositions.include?(current)
        # Es una preposición. Agrúpala inteligentemente.
        group = current
        i += 1
        
        # PATRÓN: preposición + palabras hasta encontrar un "límite"
        # Límite = cuando tenemos suficientes palabras para formar 2 apellidos
        word_count_in_group = 0
        
        while i < last_tokens.length
          next_token = last_tokens[i]
          
          if prepositions.include?(next_token)
            # Otra preposición - agrégala también
            group += " #{next_token}"
            i += 1
          else
            # Palabra normal
            group += " #{next_token}"
            word_count_in_group += 1
            i += 1
            
            # CRITERIO: si ya tenemos 2 palabras reales en el grupo, y hay más tokens,
            # detente (asume que es el final de este apellido)
            if word_count_in_group >= 2 && i < last_tokens.length && 
               !prepositions.include?(last_tokens[i])
              break
            end
          end
        end
        
        grouped_last << group
      else
        # Palabra sin preposición anterior
        grouped_last << current
        i += 1
      end
    end

    first_tokens = first_normalized.split

    {
      firstname: first_tokens.join(" "),
      lastname1: grouped_last[0],
      lastname2: grouped_last[1]
    }
  else
    tokens = normalize(clean).split
    {
      firstname: tokens[0],
      lastname1: tokens[1],
      lastname2: tokens[2]
    }
  end
end

# TEST CASES
test_cases = [
  {
    name: "LELO DE LARREA VENTIMILLA, Horacio Edmundo",
    expected: { firstname: "horacio edmundo", lastname1: "lelo de larrea", lastname2: "ventimilla" },
    description: "Múltiples apellidos con preposición en el primero"
  },
  {
    name: "GARCIA Lopez, Juan",
    expected: { firstname: "juan", lastname1: "garcia", lastname2: "lopez" },
    description: "Dos apellidos simples"
  },
  {
    name: "DE ANDA LEDEZMA, Miguel Angel",
    expected: { firstname: "miguel angel", lastname1: "de anda", lastname2: "ledezma" },
    description: "Preposición en primer apellido"
  },
  {
    name: "MARTINEZ DE LA CRUZ, Carlos",
    expected: { firstname: "carlos", lastname1: "martinez", lastname2: "de la cruz" },
    description: "Preposición en segundo apellido"
  },
  {
    name: "DE ANDA, Miguel",
    expected: { firstname: "miguel", lastname1: "de anda", lastname2: nil },
    description: "Un solo apellido con preposición"
  },
  {
    name: "FERNANDEZ DE LUNA GARCIA, Jesus",
    expected: { firstname: "jesus", lastname1: "fernandez de luna", lastname2: "garcia" },
    description: "Tres componentes, preposición en el medio"
  },
  {
    name: "DE LA CRUZ DE ANDA, Rosa",
    expected: { firstname: "rosa", lastname1: "de la cruz", lastname2: "de anda" },
    description: "Múltiples preposiciones en diferentes partes"
  },
  {
    name: "DEL ROSARIO GARCIA, Maria",
    expected: { firstname: "maria", lastname1: "del rosario", lastname2: "garcia" },
    description: "Preposición DEL (contracción)"
  },
  {
    name: "LA CRUZ MARTINEZ, Pedro",
    expected: { firstname: "pedro", lastname1: "la cruz", lastname2: "martinez" },
    description: "Artículo LA en primer apellido"
  },
  {
    name: "DA SILVA SANTOS, Joao",
    expected: { firstname: "joao", lastname1: "da silva", lastname2: "santos" },
    description: "Preposición DA (portugués)"
  },
]

puts "=" * 100
puts "PRUEBA V3 - ESTRATEGIA DE PATRONES MEJORADA"
puts "=" * 100

fails = 0

test_cases.each_with_index do |test, idx|
  result = split_name_v3(test[:name])
  match = result == test[:expected]
  
  status = match ? "✓" : "✗"
  puts "#{status} [#{idx+1}] #{test[:description]}"
  
  unless match
    puts "  Input:    #{test[:name].inspect}"
    puts "  Expected: #{test[:expected].inspect}"
    puts "  Got:      #{result.inspect}"
    fails += 1
  end
end

puts "\n" + "=" * 100
puts "Total: #{test_cases.length - fails}/#{test_cases.length} casos correctos"
puts "=" * 100
