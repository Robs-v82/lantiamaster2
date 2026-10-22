require_relative 'config/environment'

def normalize(str)
  I18n.transliterate(str.to_s.downcase.strip)
end

def split_name(name)
  clean = name.gsub(/\s+/, " ").strip

  if clean.include?(",")
    last, first = clean.split(",", 2)
    last_normalized = normalize(last)
    first_normalized = normalize(first)

    # Split en tokens
    last_tokens = last_normalized.split

    # Preposiciones españolas que típicamente van con el siguiente token
    prepositions = ["de", "del", "da", "la", "el"]

    # Agrupar preposiciones con el siguiente token
    grouped_last = []
    i = 0
    while i < last_tokens.length
      current = last_tokens[i]

      # Si es preposición y hay siguiente token, combina ambos
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

# Test cases
test_names = [
  "DE ANDA LEDEZMA, Miguel Angel",
  "DE ANDA LEDEZMA, Miguel Ángel",  
  "DE ANDA, Miguel Angel",
  "ANDA LEDEZMA, Miguel Angel",
]

test_names.each do |name|
  result = split_name(name)
  puts "Input: #{name.inspect}"
  puts "  firstname: #{result[:firstname].inspect}"
  puts "  lastname1: #{result[:lastname1].inspect}"
  puts "  lastname2: #{result[:lastname2].inspect}"
  puts
end
