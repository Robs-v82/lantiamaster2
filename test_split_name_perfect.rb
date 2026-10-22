require_relative 'config/environment'

def normalize(str)
  I18n.transliterate(str.to_s.downcase.strip)
end

# VERSIÓN PERFECTA - Agrupar múltiples preposiciones + palabra siguiente
def split_name_perfect(name)
  clean = name.gsub(/\s+/, " ").strip

  if clean.include?(",")
    last, first = clean.split(",", 2)
    last_normalized = normalize(last)
    first_normalized = normalize(first)

    last_tokens = last_normalized.split
    prepositions = ["de", "del", "da", "la", "el"]

    # PARTE 1: AGRUPAMIENTO MEJORADO
    # Cuando encuentres una preposición, agrupa:
    # - todas las preposiciones consecutivas, LUEGO
    # - la siguiente palabra
    grouped_last = []
    i = 0
    while i < last_tokens.length
      current = last_tokens[i]

      if prepositions.include?(current)
        # Es preposición: agrupa todas las preposiciones seguidas + siguiente palabra
        group = current
        i += 1
        
        # Continúa con preposiciones/artículos
        while i < last_tokens.length && prepositions.include?(last_tokens[i])
          group += " #{last_tokens[i]}"
          i += 1
        end
        
        # Ahora agrupa la palabra que sigue (si existe)
        if i < last_tokens.length
          group += " #{last_tokens[i]}"
          i += 1
        end
        
        grouped_last << group
      else
        grouped_last << current
        i += 1
      end
    end

    # PARTE 2: POST-PROCESAMIENTO BIDIRECCIONAL (igual que antes)
    if grouped_last.length >= 3
      new_grouped = []
      i = 0
      
      while i < grouped_last.length
        current_group = grouped_last[i]
        has_prep_current = prepositions.any? { |p| current_group.include?(" #{p} ") || current_group.start_with?(p) }
        
        if i + 1 < grouped_last.length
          next_group = grouped_last[i + 1]
          has_prep_next = prepositions.any? { |p| next_group.include?(" #{p} ") || next_group.start_with?(p) }
          
          if has_prep_current && !has_prep_next
            new_grouped << "#{current_group} #{next_group}"
            i += 2
          elsif !has_prep_current && has_prep_next
            new_grouped << "#{current_group} #{next_group}"
            i += 2
          else
            new_grouped << current_group
            i += 1
          end
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
puts "VERSIÓN FINAL PERFECTA - 10/10 CASOS"
puts "=" * 100

fails = 0

test_cases.each_with_index do |test, idx|
  result = split_name_perfect(test[:name])
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
