require_relative 'config/environment'

def normalize(str)
  I18n.transliterate(str.to_s.downcase.strip)
end

# VERSIÓN ACTUAL (DEFECTUOSA)
def split_name_old(name)
  clean = name.gsub(/\s+/, " ").strip

  if clean.include?(",")
    last, first = clean.split(",", 2)
    last_normalized = normalize(last)
    first_normalized = normalize(first)

    last_tokens = last_normalized.split
    prepositions = ["de", "del", "da", "la", "el"]

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

# VERSIÓN PROPUESTA (MEJORADA)
def split_name_new(name)
  clean = name.gsub(/\s+/, " ").strip

  if clean.include?(",")
    last, first = clean.split(",", 2)
    last_normalized = normalize(last)
    first_normalized = normalize(first)

    last_tokens = last_normalized.split
    prepositions = ["de", "del", "da", "la", "el"]

    # Estrategia mejorada: Detectar patrones de preposiciones
    # y agruparlas inteligentemente sin asumir que la preposición siempre 
    # es solo para el siguiente token
    
    grouped_last = []
    i = 0
    
    while i < last_tokens.length
      current = last_tokens[i]
      
      # Si es preposición y hay siguiente token
      if prepositions.include?(current) && i + 1 < last_tokens.length
        # Agrupa la preposición con el siguiente token
        grouped_item = "#{current} #{last_tokens[i + 1]}"
        i += 2
        
        # NUEVA LÓGICA: Si hay más tokens después de la preposición+palabra
        # y el siguiente NO es una preposición, agrega esos tokens también
        # al grupo actual (podría ser "de la cruz garcía" que es un apellido)
        while i < last_tokens.length && !prepositions.include?(last_tokens[i])
          # Pero detente si parece que es un nuevo apellido (palabra larga/diferentes)
          # Para mantener consistencia: máximo agregamos 1 palabra más a la preposición
          break if i > last_tokens.length - 2 && last_tokens[i].length > 4
          grouped_item += " #{last_tokens[i]}"
          i += 1
          break # Solo agregamos UNA palabra más máximo
        end
        
        grouped_last << grouped_item
      else
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

# TEST CASES - Casos de validación exhaustiva
test_cases = [
  # Caso 1: Problema ACTUAL - Horacio Edmundo Lelo De Larrea Ventimilla
  {
    name: "LELO DE LARREA VENTIMILLA, Horacio Edmundo",
    expected: { firstname: "horacio edmundo", lastname1: "lelo de larrea", lastname2: "ventimilla" },
    description: "Múltiples apellidos con preposición en el primero"
  },
  
  # Caso 2: Simple - dos apellidos, sin preposición
  {
    name: "GARCIA Lopez, Juan",
    expected: { firstname: "juan", lastname1: "garcia", lastname2: "lopez" },
    description: "Dos apellidos simples"
  },
  
  # Caso 3: Con preposición en primer apellido
  {
    name: "DE ANDA LEDEZMA, Miguel Angel",
    expected: { firstname: "miguel angel", lastname1: "de anda", lastname2: "ledezma" },
    description: "Preposición en primer apellido"
  },
  
  # Caso 4: Con preposición en segundo apellido
  {
    name: "MARTINEZ DE LA CRUZ, Carlos",
    expected: { firstname: "carlos", lastname1: "martinez", lastname2: "de la cruz" },
    description: "Preposición en segundo apellido"
  },
  
  # Caso 5: Un solo apellido con preposición
  {
    name: "DE ANDA, Miguel",
    expected: { firstname: "miguel", lastname1: "de anda", lastname2: nil },
    description: "Un solo apellido con preposición"
  },
  
  # Caso 6: Tres apellidos con una preposición
  {
    name: "FERNANDEZ DE LUNA GARCIA, Jesus",
    expected: { firstname: "jesus", lastname1: "fernandez de luna", lastname2: "garcia" },
    description: "Tres componentes, preposición en el medio"
  },
  
  # Caso 7: Múltiples preposiciones
  {
    name: "DE LA CRUZ DE ANDA, Rosa",
    expected: { firstname: "rosa", lastname1: "de la cruz", lastname2: "de anda" },
    description: "Múltiples preposiciones en diferentes partes"
  },
  
  # Caso 8: Apellido con "Del"
  {
    name: "DEL ROSARIO GARCIA, Maria",
    expected: { firstname: "maria", lastname1: "del rosario", lastname2: "garcia" },
    description: "Preposición DEL (contracción)"
  },
  
  # Caso 9: Apellido con "La"
  {
    name: "LA CRUZ MARTINEZ, Pedro",
    expected: { firstname: "pedro", lastname1: "la cruz", lastname2: "martinez" },
    description: "Artículo LA en primer apellido"
  },
  
  # Caso 10: Casos portugueses/brasileños
  {
    name: "DA SILVA SANTOS, Joao",
    expected: { firstname: "joao", lastname1: "da silva", lastname2: "santos" },
    description: "Preposición DA (portugués)"
  },
]

puts "=" * 100
puts "PRUEBA EXHAUSTIVA DE split_name()"
puts "=" * 100

old_fails = 0
new_fails = 0

test_cases.each_with_index do |test, idx|
  puts "\n[CASO #{idx + 1}] #{test[:description]}"
  puts "Input: #{test[:name].inspect}"
  puts "Expected: #{test[:expected].inspect}"
  puts
  
  old_result = split_name_old(test[:name])
  new_result = split_name_new(test[:name])
  
  old_match = old_result == test[:expected]
  new_match = new_result == test[:expected]
  
  puts "Versión ACTUAL:   #{old_result.inspect}"
  puts "  ✓ CORRECTO" if old_match
  puts "  ✗ INCORRECTO" unless old_match
  old_fails += 1 unless old_match
  
  puts
  puts "Versión PROPUESTA: #{new_result.inspect}"
  puts "  ✓ CORRECTO" if new_match
  puts "  ✗ INCORRECTO" unless new_match
  new_fails += 1 unless new_match
  
  puts "-" * 100
end

puts "\n" + "=" * 100
puts "RESUMEN"
puts "=" * 100
puts "Total casos: #{test_cases.length}"
puts "Versión ACTUAL:   #{test_cases.length - old_fails}/#{test_cases.length} casos correctos (#{old_fails} fallos)"
puts "Versión PROPUESTA: #{test_cases.length - new_fails}/#{test_cases.length} casos correctos (#{new_fails} fallos)"
puts "=" * 100
