require_relative 'config/environment'

def normalize(str)
  I18n.transliterate(str.to_s.downcase.strip)
end

def match_token(a, b)
  return false if b.blank?
  return true if a.blank?
  a.include?(b) || b.include?(a)
end

def split_name(name)
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

# OFAC data
ofac_parsed = split_name("LELO DE LARREA VENTIMILLA, Horacio Edmundo")

puts "OFAC parsed:"
puts "  firstname: #{ofac_parsed[:firstname].inspect}"
puts "  lastname1: #{ofac_parsed[:lastname1].inspect}"
puts "  lastname2: #{ofac_parsed[:lastname2].inspect}"
puts

# Member data
member_firstname = "Horacio Edmundo"
member_lastname1 = "Lelo De Larrea"
member_lastname2 = "Ventimilla"

puts "Member:"
puts "  firstname: #{member_firstname.inspect}"
puts "  lastname1: #{member_lastname1.inspect}"
puts "  lastname2: #{member_lastname2.inspect}"
puts

# Test matching
puts "Match results:"
puts "  firstname match? #{match_token(ofac_parsed[:firstname], normalize(member_firstname))}"
puts "  lastname1 match? #{match_token(ofac_parsed[:lastname1], normalize(member_lastname1))}"
puts "  lastname2 match? #{match_token(ofac_parsed[:lastname2], normalize(member_lastname2))}"
puts

# Detail
puts "Detail lastname1 comparison:"
puts "  OFAC: #{ofac_parsed[:lastname1].inspect} vs Member: #{normalize(member_lastname1).inspect}"
puts "  OFAC.include?(Member)? #{ofac_parsed[:lastname1]&.include?(normalize(member_lastname1).to_s)}"
puts "  Member.include?(OFAC)? #{normalize(member_lastname1).include?(ofac_parsed[:lastname1].to_s)}"
puts

puts "Detail lastname2 comparison:"
puts "  OFAC: #{ofac_parsed[:lastname2].inspect} vs Member: #{normalize(member_lastname2).inspect}"
puts "  OFAC.include?(Member)? #{ofac_parsed[:lastname2]&.include?(normalize(member_lastname2).to_s)}"
puts "  Member.include?(OFAC)? #{normalize(member_lastname2).include?(ofac_parsed[:lastname2].to_s)}"
