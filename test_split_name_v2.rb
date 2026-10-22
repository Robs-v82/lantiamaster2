require_relative 'config/environment'

def normalize(str)
  I18n.transliterate(str.to_s.downcase.strip)
end

# VERSIÓN V2 MEJORADA - Estrategia más robusta
def split_name_v2(name)
  clean = name.gsub(/\s+/, " ").strip

  if clean.include?(",")
    last, first = clean.split(",", 2)
    last_normalized = normalize(last)
    first_normalized = normalize(first)

    last_tokens = last_normalized.split
    prepositions = ["de", "del", "da", "la", "el"]

    # Nueva estrategia:
    # 1. Separar los tokens en "bloques" donde cada bloque es:
    #    - UNA palabra no-preposición, O
    #    - UNA preposición + siguiente(s) palabra(s)
    # 2. Distribuir los bloques entre lastname1 y lastname2
    
    blocks = []
    i = 0
    
    while i < last_tokens.length
      current = last_tokens[i]
      
      if prepositions.include?(current)
        # Este es una preposición, agrupala con lo que sigue
        block = current
        i += 1
        
        # Agrega palabras después de la preposición hasta:
        # - Encontrar otra preposición, O
        # - Llegar al final
        while i < last_tokens.length && !prepositions.include?(last_tokens[i])
          block += " #{last_tokens[i]}"
          i += 1
        end
        
        blocks << block
      else
        # Palabra normal, sin preposición
        blocks << current
        i += 1
      end
    end

    # Ahora distribuye los bloques:
    # Si hay 2 bloques: firstname, lastname1
    # Si hay 3 bloques: firstname, lastname1, lastname2
    # Si hay 4 o más: agrupar últimos 2 bloques del lastname part
    
    first_tokens = first_normalized.split
    
    if blocks.length <= 1
      # Caso raro: solo 1 bloque de apellidos (ej: "De", "Garcia")
      {
        firstname: first_tokens.join(" "),
        lastname1: blocks[0],
        lastname2: nil
      }
    elsif blocks.length == 2
      # Caso simple: 2 bloques = lastname1 y lastname2
      {
        firstname: first_tokens.join(" "),
        lastname1: blocks[0],
        lastname2: blocks[1]
      }
    else
      # Caso complejo: 3+ bloques
      # Estrategia: tomar el primer bloque como lastname1,
      # y si hay preposición en el segundo bloque, combinarlos
      
      lastname1 = blocks[0]
      remaining_blocks = blocks[1..-1]
      
      # Si el segundo bloque es una preposición (o comienza con preposición),
      # combínalo con el primero
      if remaining_blocks[0] && prepositions.include?(remaining_blocks[0].split.first)
        lastname1 += " #{remaining_blocks[0]}"
        remaining_blocks = remaining_blocks[1..-1]
      end
      
      # El resto son apellidos adicionales, pero solo tomamos el último como lastname2
      lastname2 = remaining_blocks.join(" ") if remaining_blocks.any?
      
      {
        firstname: first_tokens.join(" "),
        lastname1: lastname1,
        lastname2: lastname2
      }
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
puts "PRUEBA V2 - VERSIÓN MEJORADA"
puts "=" * 100

fails = 0

test_cases.each_with_index do |test, idx|
  result = split_name_v2(test[:name])
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
