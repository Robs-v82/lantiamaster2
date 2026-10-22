require_relative 'config/environment'

def normalize(str)
  I18n.transliterate(str.to_s.downcase.strip)
end

# VERSIÓN FINAL - Estrategia basada en DISTRIBUCIÓN DE TOKENS
def split_name_final(name)
  clean = name.gsub(/\s+/, " ").strip

  if clean.include?(",")
    last, first = clean.split(",", 2)
    last_normalized = normalize(last)
    first_normalized = normalize(first)

    last_tokens = last_normalized.split
    prepositions = ["de", "del", "da", "la", "el"]

    # ESTRATEGIA FINAL:
    # 1. Si hay 2 tokens: son lastname1 y lastname2
    # 2. Si hay 3 tokens:
    #    - Si el 2do es preposición: agrupar 1er + 2do, 3er es lastname2
    #    - Si no: 1er es lastname1, agrupar 2do + 3er como lastname2
    # 3. Si hay 4+ tokens:
    #    - Si el 2do es preposición: 1er+2do+3er como lastname1, 4to como lastname2
    #    - Si no: 1er+2do como lastname1, 3er+resto como lastname2

    if last_tokens.length <= 1
      {
        firstname: first_normalized.split.join(" "),
        lastname1: last_tokens[0],
        lastname2: nil
      }
    elsif last_tokens.length == 2
      # Caso simple: 2 tokens = lastname1 y lastname2
      {
        firstname: first_normalized.split.join(" "),
        lastname1: last_tokens[0],
        lastname2: last_tokens[1]
      }
    elsif last_tokens.length == 3
      # Caso: 3 tokens
      if prepositions.include?(last_tokens[1])
        # El 2do es preposición: agrupar 1er + 2do, dejar 3er
        {
          firstname: first_normalized.split.join(" "),
          lastname1: "#{last_tokens[0]} #{last_tokens[1]} #{last_tokens[2]}",
          lastname2: nil
        }
      else
        # El 2do no es preposición: 1er es lastname1, agrupar 2do + 3er
        {
          firstname: first_normalized.split.join(" "),
          lastname1: last_tokens[0],
          lastname2: "#{last_tokens[1]} #{last_tokens[2]}"
        }
      end
    else
      # Caso: 4+ tokens
      if prepositions.include?(last_tokens[1])
        # El 2do es preposición
        if prepositions.include?(last_tokens[3]) && last_tokens.length >= 5
          # Hay otra preposición en posición 4: patrón "palabra preposición palabra preposición palabra..."
          # Agrupa: 1er+2do+3er como lastname1, 4to+5to+resto como lastname2
          lastname2 = last_tokens[3..-1].join(" ")
          {
            firstname: first_normalized.split.join(" "),
            lastname1: "#{last_tokens[0]} #{last_tokens[1]} #{last_tokens[2]}",
            lastname2: lastname2
          }
        else
          # El 4to NO es preposición: es un apellido separado
          {
            firstname: first_normalized.split.join(" "),
            lastname1: "#{last_tokens[0]} #{last_tokens[1]} #{last_tokens[2]}",
            lastname2: last_tokens[3..-1].join(" ")
          }
        end
      else
        # El 2do NO es preposición
        # Agrupar 1er+2do como lastname1, resto como lastname2
        {
          firstname: first_normalized.split.join(" "),
          lastname1: "#{last_tokens[0]} #{last_tokens[1]}",
          lastname2: last_tokens[2..-1].join(" ")
        }
      end
    end
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
puts "PRUEBA FINAL - DISTRIBUCIÓN DE TOKENS"
puts "=" * 100

fails = 0

test_cases.each_with_index do |test, idx|
  result = split_name_final(test[:name])
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
