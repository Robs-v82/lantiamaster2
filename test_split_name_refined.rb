require_relative 'config/environment'

def normalize(str)
  I18n.transliterate(str.to_s.downcase.strip)
end

# VERSIÓN REFINADA - Mejorar post-procesamiento
def split_name_refined(name)
  clean = name.gsub(/\s+/, " ").strip

  if clean.include?(",")
    last, first = clean.split(",", 2)
    last_normalized = normalize(last)
    first_normalized = normalize(first)

    last_tokens = last_normalized.split
    prepositions = ["de", "del", "da", "la", "el"]

    # PARTE 1: LÓGICA ORIGINAL
    grouped_last = []
    i = 0
    while i < last_tokens.length
      current = last_tokens[i]

      if prepositions.include?(current) && i + 1 < last_tokens.length
        grouped_last << "#{current} #{last_tokens[i + 1]}"
        i += 2
      else
        grouped_last << current
        i += 1
      end
    end

    # PARTE 2: POST-PROCESAMIENTO MEJORADO
    # Si tenemos 3+ grupos, aplicar lógica más sofisticada:
    # - Si grupo[i] contiene preposición Y grupo[i+1] es palabra sola,
    #   combinar grupo[i] + grupo[i+1]
    
    if grouped_last.length >= 3
      new_grouped = []
      i = 0
      
      while i < grouped_last.length
        current_group = grouped_last[i]
        
        # Si hay siguiente grupo y el actual tiene preposición
        # y el siguiente NO tiene preposición, combínalos
        if i + 1 < grouped_last.length &&
           prepositions.any? { |p| current_group.include?(" #{p} ") || current_group.start_with?(p) } &&
           !prepositions.any? { |p| grouped_last[i + 1].include?(" #{p} ") || grouped_last[i + 1].start_with?(p) }
          
          # El siguiente es palabra sola, combínalo
          new_grouped << "#{current_group} #{grouped_last[i + 1]}"
          i += 2
        else
          new_grouped << current_group
          i += 1
        end
      end
      
      grouped_last = new_grouped
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
puts "PRUEBA REFINADA - POST-PROCESAMIENTO MEJORADO"
puts "=" * 100

fails = 0

test_cases.each_with_index do |test, idx|
  result = split_name_refined(test[:name])
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
