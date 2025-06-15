require 'open-uri'
require 'nokogiri'
require 'cgi'
require 'date'

SPANISH_MONTHS = {
  'enero' => 1, 'febrero' => 2, 'marzo' => 3, 'abril' => 4,
  'mayo' => 5, 'junio' => 6, 'julio' => 7, 'agosto' => 8,
  'septiembre' => 9, 'octubre' => 10, 'noviembre' => 11, 'diciembre' => 12
}

def parse_spanish_date(text)
  if text =~ /(\d{1,2}) de (\w+) de (\d{4})/
    day, month_name, year = $1.to_i, $2.downcase, $3.to_i
    month = SPANISH_MONTHS[month_name]
    return Date.new(year, month, day) if month
  end
  nil
end

def fetch_birthday_from_wikipedia(full_name_variants)
  full_name_variants.each do |name_variant|
    wikipedia_url = "https://es.wikipedia.org/wiki/#{CGI.escape(name_variant)}"

    begin
      html = URI.open(wikipedia_url).read
      doc = Nokogiri::HTML(html)

      # Validar que el contenido mencione a México y Gobernador(a)
      page_text = doc.text
      unless page_text.include?("México") && (page_text.include?("Gobernador") || page_text.include?("Gobernadora"))
        puts "✗ #{name_variant.gsub('_', ' ')}: Página encontrada pero sin validación temática"
        next
      end

      birth_row = doc.at('table.infobox tr:contains("Nacimiento")')
      next unless birth_row

      raw_text = birth_row.search('td').text.strip
      date_text = raw_text.split('(').first.strip
      birth_date = parse_spanish_date(date_text)

      return birth_date if birth_date && birth_date.year >= 1930 && birth_date.year < 2005
    rescue OpenURI::HTTPError => e
      puts "✗ #{name_variant.gsub('_', ' ')}: Página no encontrada (#{wikipedia_url})"
      next
    rescue => e
      puts "✗ #{name_variant.gsub('_', ' ')}: Error inesperado: #{e.message}"
      next
    end
  end

  nil
end

# Obtener miembros gobernadores
my_members = Role.find_by(name: "Gobernador").members

my_members.each do |member|
  name1 = "#{member.firstname.split.first} #{member.lastname1}".strip.gsub(' ', '_')
  name2 = "#{member.firstname.split.first} #{member.lastname1} #{member.lastname2}".strip.gsub(' ', '_')
  name3 = "#{member.firstname} #{member.lastname1} #{member.lastname2}".strip.gsub(' ', '_')
  variants = [name1, name2, name3].uniq

  birthday = fetch_birthday_from_wikipedia(variants)

  if birthday
    member.update(birthday: birthday)
    puts "✓ #{member.firstname} #{member.lastname1}: Fecha de nacimiento actualizada a #{birthday}"
  else
    puts "✗ #{member.firstname} #{member.lastname1}: Fecha no válida o no encontrada"
  end
end


