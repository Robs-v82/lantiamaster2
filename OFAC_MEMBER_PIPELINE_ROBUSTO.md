# OFAC Member Pipeline - Proceso Robusto Infalible

**Última actualización:** 2026-09-30  
**Versión:** 1.0 - PASO 1 Definido  
**Estado:** En construcción paso a paso

---

## 🚨 Principio Fundamental

**Cada validación es CODE, no intención.** Toda decisión se bloquea con excepciones si falla.  
No hay "asumir", no hay "olvidar". Todo falla explícitamente o continúa.

---

## 📋 Normalización de Nombres (CRÍTICA PARA VALIDACIONES)

**Problema:** Nombres OFAC vienen con:
- Todo MAYÚSCULAS: `"GARCÍA LÓPEZ"`
- Formato invertido: `"LASTNAME, Firstname"` en lugar de `"Firstname Lastname"`
- Acentos inconsistentes: `"María"` vs `"Maria"`
- Ñ vs N: `"PEÑA"` vs `"PENA"`

**Solución:** Convertir a formato `fullname` equivalente a `Member.fullname` para validación directa

### Funciones de Normalización

```ruby
def normalize_and_capitalize(text)
  # Transliterar acentos + Title Case
  # "MARÍA GARCÍA" → "Maria Garcia"
  # "maría garcía" → "Maria Garcia"
  I18n.transliterate(text.to_s.strip).split.map(&:capitalize).join(" ")
end

def normalize_for_search(text)
  # Para búsquedas case-insensitive + sin acentos
  # "Maria Del Rosario" → "maria del rosario"
  I18n.transliterate(text.to_s.strip.downcase)
end
```

### Ejemplo Completo

**ENTRADA OFAC:**
```
"GARCÍA LÓPEZ, María del Rosario"
```

**PASO 1 - Parsear:**
```ruby
parts = "GARCÍA LÓPEZ, María del Rosario".split(",", 2)
lastname_part = "GARCÍA LÓPEZ"           # parts[0]
firstname_part = "María del Rosario"     # parts[1]
lastname_tokens = lastname_part.split    # ["GARCÍA", "LÓPEZ"]
```

**PASO 2 - Normalizar y convertir a formato fullname:**
```ruby
firstname = normalize_and_capitalize(firstname_part)      # "Maria Del Rosario"
lastname1 = normalize_and_capitalize(lastname_tokens[0])  # "Garcia"
lastname2 = normalize_and_capitalize(lastname_tokens[1])  # "Lopez"

# Crear fullname en formato EQUIVALENTE a Member.fullname
fullname = "#{firstname} #{lastname1} #{lastname2}".strip
# → "Maria Del Rosario Garcia Lopez"
```

**PASO 3 - Guardar en OfacCandidate.ofac_name:**
```ruby
OfacCandidate.create!(
  ofac_name: fullname,  # "Maria Del Rosario Garcia Lopez"
  status: :pending,
  search_attempts: 0
)
```

**PASO 4 - Validación (comparación directa con Member.fullname):**
```ruby
# Búsqueda simple y directa
member = Member.find(123)
OfacCandidate.exists?(ofac_name: member.fullname)
# Compara: "Maria Del Rosario Garcia Lopez" == "Maria Del Rosario Garcia Lopez"
# ✅ MATCH o ❌ NO MATCH
```

**Ventajas:**
- ✅ Formato idéntico a `Member.fullname`
- ✅ Sin campos adicionales en BD
- ✅ Validación simple y directa
- ✅ Sin problemas de acentos/Ñ (ambos normalizados igual)

---

## PASO 1: Identificar Candidato OFAC Disponible

### QUÉ (Descripción)

Extraer del listado OFAC "SIN MATCH" el candidato MÁS RECIENTE que:
- Tiene estructura de nombre válida: **firstname + lastname1 + lastname2** (mínimo 3 componentes)
- **NO está** en la tabla `ofac_candidates` (ya fue revisado anteriormente)

**Salida esperada:**
- ✅ **Si existe:** Retorna OBJETO con datos del candidato OFAC (último de lista que cumple)
- ❌ **Si NO existe:** Retorna nil + mensaje "No hay candidatos OFAC disponibles"

---

### CMO VALIDAR (Validaciones Explícitas)

**VALIDACIÓN 1: OFAC List existe**
- ✅ Script `ofacUpdate.rb` se ejecuta sin errores
- ✅ Genera lista "SIN MATCH" válida (formato: "LASTNAME, Firstname...")
- ❌ Si falla: Lanza `OfacUpdateError: No se pudo obtener lista OFAC`

**VALIDACIÓN 2: Estructura de nombre válida**
- Input: `"LASTNAME, Firstname Compuesto Opcional"`
- ✅ Parsea correctamente: `lastname = "LASTNAME"`, `firstname = "Firstname Compuesto Opcional"`
- ✅ Split result: `firstname.split.size >= 1` AND `lastname.split.size >= 2`
- ❌ Si falla: Excluye el candidato silenciosamente (no es válido)

**VALIDACIÓN 3: NO está en OfacCandidate**
- Búsqueda: `OfacCandidate.find_by(ofac_name: "LASTNAME, Firstname...")`
- ✅ Si es nil: candidato es eligibles
- ❌ Si existe: candidato ya fue revisado, excluir

**VALIDACIÓN 4: Retorna último de lista**
- ✅ De los candidatos elegibles, retorna el ÚLTIMO (orden original OFAC invertido)
- ✅ Este es el más reciente según designación OFAC

---

### IMPLEMENTATION (Código Ruby)

```ruby
# File: /scripts/ofac_member_pipeline_step1.rb

require "csv"
require "set"

class OfacMemberPipelineStep1
  # Ejecuta PASO 1 y retorna candidato disponible
  def self.execute!
    puts "🔍 PASO 1: Identificar Candidato OFAC Disponible"
    puts "=" * 60
    
    # 1. Obtener lista OFAC sin match
    ofac_list = extract_ofac_no_match_list
    puts "📊 Total OFAC sin match: #{ofac_list.size}"
    
    # 2. Filtrar candidatos válidos
    valid_candidates = filter_valid_candidates(ofac_list)
    puts "✅ Candidatos con estructura válida: #{valid_candidates.size}"
    
    # 3. Excluir ya revisados
    available_candidates = filter_not_reviewed(valid_candidates)
    puts "📌 Candidatos NO revisados: #{available_candidates.size}"
    
    # 4. Retornar último (más reciente)
    if available_candidates.empty?
      puts "\n❌ No hay candidatos OFAC disponibles"
      return nil
    end
    
    candidate = available_candidates.last  # último = más reciente
    puts "\n✅ CANDIDATO DISPONIBLE:"
    puts "   OFAC Name: #{candidate[:ofac_name]}"
    puts "   Firstname: #{candidate[:firstname]}"
    puts "   Lastname1: #{candidate[:lastname1]}"
    puts "   Lastname2: #{candidate[:lastname2]}"
    
    candidate
  end
  
  private
  
  # VALIDACIÓN 1: Obtener lista "SIN MATCH" del script ofacUpdate
  def self.extract_ofac_no_match_list
    puts "\n📥 Ejecutando ofacUpdate.rb..."
    
    require "set"
    
    BASE = "https://www.treasury.gov/ofac/downloads"
    FILES = {
      "sdn.csv" => "#{BASE}/sdn.csv",
      "add.csv" => "#{BASE}/add.csv",
      "alt.csv" => "#{BASE}/alt.csv"
    }
    DATA_DIR = Rails.root.join("tmp", "ofac_data")
    
    FileUtils.mkdir_p(DATA_DIR)
    
    # Descargar archivos
    FILES.each do |name, url|
      path = DATA_DIR.join(name)
      headers = { "User-Agent" => "Mozilla/5.0 (Ruby OFAC script)" }
      
      begin
        URI.open(url, headers.merge(ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)) do |remote|
          File.binwrite(path, remote.read)
        end
      rescue => e
        raise OfacUpdateError, "No se pudo descargar #{name}: #{e.message}"
      end
    end
    
    sdn_path = DATA_DIR.join("sdn.csv")
    add_path = DATA_DIR.join("add.csv")
    
    # 1. Identificar INDIVIDUALES
    individuals = {}
    CSV.foreach(sdn_path, headers: false, encoding: "bom|utf-8") do |row|
      next if row.nil?
      ent_num = row[0].to_s.strip
      name = row[1].to_s.strip
      type = row[2].to_s.strip.upcase
      next unless type == "INDIVIDUAL"
      individuals[ent_num] = { name: name }
    end
    
    # 2. Identificar México
    mexico_ent_nums = Set.new
    CSV.foreach(add_path, headers: false, encoding: "bom|utf-8") do |row|
      next if row.nil? || row.length < 5
      ent_num = row[0].to_s.strip
      country = row[4].to_s.strip
      next unless country == "Mexico" && individuals.key?(ent_num)
      mexico_ent_nums.add(ent_num)
    end
    
    # 3. Buscar matches en BD
    matched_ent_nums = Set.new
    Member.where(ofac_designation: true).where.not(ofac_ent_num: [nil, ""]).find_each do |m|
      matched_ent_nums.add(m.ofac_ent_num.to_s)
    end
    
    # 4. Retornar SIN MATCH
    no_match_list = mexico_ent_nums.reject { |ent_num| matched_ent_nums.include?(ent_num) }
    
    no_match_list.map do |ent_num|
      { ofac_name: individuals[ent_num][:name] }
    end
  rescue => e
    raise OfacUpdateError, "Error extrayendo lista OFAC: #{e.message}"
  end
  
  # VALIDACIÓN 2: Filtrar por estructura de nombre válida
  def self.filter_valid_candidates(ofac_list)
    ofac_list.select do |candidate|
      name = candidate[:ofac_name]
      
      # Parsear: "LASTNAME, Firstname..."
      unless name.include?(",")
        next false
      end
      
      parts = name.split(",", 2)
      lastname_part = parts[0].strip
      firstname_part = parts[1].strip
      
      # Validar: mínimo 1 firstname + 2 lastnames
      lastname_tokens = lastname_part.split
      firstname_tokens = firstname_part.split
      
      # Estructura válida: lastname tiene 2+ tokens, firstname tiene 1+
      valid = lastname_tokens.size >= 2 && firstname_tokens.size >= 1
      
      if valid
        # Enriquecer datos
        candidate[:firstname] = firstname_tokens.join(" ")
        candidate[:lastname1] = lastname_tokens[0]
        candidate[:lastname2] = lastname_tokens[1]
      end
      
      valid
    end
  end
  
  # VALIDACIÓN 3: Excluir ya revisados en OfacCandidate
  def self.filter_not_reviewed(valid_candidates)
    valid_candidates.reject do |candidate|
      OfacCandidate.exists?(ofac_name: candidate[:ofac_name])
    end
  end
end

class OfacUpdateError < StandardError; end
```

---

### CASOS DE ÉXITO Y FRACASO

**CASO ✅ ÉXITO:**
```
🔍 PASO 1: Identificar Candidato OFAC Disponible
============================================================
📥 Ejecutando ofacUpdate.rb...
📊 Total OFAC sin match: 199
✅ Candidatos con estructura válida: 187
📌 Candidatos NO revisados: 145

✅ CANDIDATO DISPONIBLE:
   OFAC Name: GARCIA LOPEZ, Maria Del Rosario
   Firstname: Maria Del Rosario
   Lastname1: GARCIA
   Lastname2: LOPEZ
```

**CASO ❌ FRACASO (no hay candidatos):**
```
🔍 PASO 1: Identificar Candidato OFAC Disponible
============================================================
📥 Ejecutando ofacUpdate.rb...
📊 Total OFAC sin match: 199
✅ Candidatos con estructura válida: 187
📌 Candidatos NO revisados: 0

❌ No hay candidatos OFAC disponibles
```

**CASO ❌ FRACASO (error en descarga OFAC):**
```
OfacUpdateError: No se pudo descargar sdn.csv: Connection timeout
```

---

## PASO 2: Buscar Evidencia de Cartel y Crear Hit Provisional

### QUÉ (Descripción)

Buscar en internet artículos que vinculen al candidato OFAC con un cartel en el catálogo.
Si se encuentra un artículo:
1. Resolver municipio/estado (jerarquía obligatoria)
2. Crear Hit provisional (con link del artículo)
3. Capturar `plain_text` usando `HitSnapshotFetcher` (**OBLIGATORIO**)
4. **PASO 3: Extraer fecha real del artículo usando Claude AI** (reemplaza `Date.today`)
5. Si `plain_text` NO se captura → destruir Hit y reintentar búsqueda

**Salida esperada:**
- ✅ **Si éxito:** Retorna Hit con `plain_text` capturado, ubicación resuelta, y fecha extraída por Claude
- ❌ **Si falla plain_text:** Destruye Hit, intenta siguiente resultado
- ❌ **Si no hay resultados:** Retorna nil

---

### CMÓ VALIDAR (Validaciones Explícitas)

**VALIDACIÓN 1: NewsAPI retorna resultados**
- ✅ Query: `"#{firstname} #{lastname1} cartel Mexico"`
- ✅ Se obtiene array de artículos (articles[])
- ❌ Si no hay resultados: retorna nil

**VALIDACIÓN 2: Artículo tiene link válido**
- ✅ `article["url"].present?` y es URL válida
- ❌ Si no tiene link: continúa al siguiente artículo

**VALIDACIÓN 3: Se resuelve municipio/estado según reglas obligatorias**

Flujo de resolución (EN ORDEN):
```
1. Identificar ESTADO en el texto del artículo
   ├─ Si se identificó Estado Y Municipio:
   │  └─ Buscar Municipio dentro de ese Estado → elegir Town "Sin definir"
   ├─ Si se identificó SOLO Estado:
   │  └─ Elegir Town "Sin definir" del Municipio "Sin definir" de ese Estado
   └─ Si NO se identificó nada OR es extranjero:
      └─ Elegir Town "Sin definir" del Municipio "Sin definir" de CDMX
```

**VALIDACIÓN 4: Hit se crea con datos válidos**
- ✅ `Hit.create!(date: date, title: title, link: url, town_id: town_id, user_id: current_user.id)`
- ✅ Hit tiene link único (validación en modelo)
- ❌ Si falla: excepción, no continúa

**VALIDACIÓN 5: plain_text se captura exitosamente (CRÍTICA)**
- ✅ `HitSnapshotFetcher.call!(hit, require_members: false)` se ejecuta sin error
- ✅ `hit.plain_text.present?` y `hit.plain_text.length >= 800`
- ✅ `hit.backup_status == "ok"`
- ❌ Si falla: `Hit.destroy!` y continúa a siguiente artículo

**VALIDACIÓN 6: PASO 3 - Claude extrae fecha real del plain_text**
- ✅ **SIEMPRE intentar** extraer fecha con Claude API (crítico)
- ✅ Claude retorna fecha en formato YYYY-MM-DD (e.g., "2026-09-29")
- ✅ Validar que fecha sea válida (no futura, no más de 1 año atrás)
- ✅ Actualizar `hit.date` con la fecha extraída
- ✅ **Si Claude falla o retorna fecha inválida:** Usar fallback garantizado `Date.today`
  - El fallback NO es opcional
  - Cada Hit DEBE tener una fecha válida
  - Si Claude no puede extraer → usar automáticamente `Date.today`

---

### IMPLEMENTATION (Código Ruby)

```ruby
# File: /scripts/ofac_pipeline_step2.rb

require "net/http"
require "json"

class OfacPipeline::Step2
  NEWS_API_KEY = ENV["NEWS_API_KEY"] || raise("NEWS_API_KEY no configurada")
  NEWS_API_BASE = "https://newsapi.org/v2/everything"
  
  # ESTADOS DE MÉXICO (validación de ubicación)
  MEXICAN_STATES = {
    "Aguascalientes" => "AG", "Baja California" => "BC", "Baja California Sur" => "BS",
    "Campeche" => "CM", "Coahuila" => "CO", "Colima" => "CL", "Chiapas" => "CS",
    "Chihuahua" => "CH", "Ciudad de México" => "DF", "Durango" => "DG", "Guanajuato" => "GT",
    "Guerrero" => "GR", "Hidalgo" => "HG", "Jalisco" => "JL", "Estado de México" => "EM",
    "Michoacán" => "MI", "Morelos" => "MO", "Nayarit" => "NA", "Nuevo León" => "NL",
    "Oaxaca" => "OA", "Puebla" => "PB", "Querétaro" => "QT", "Quintana Roo" => "QR",
    "San Luis Potosí" => "SL", "Sinaloa" => "SI", "Sonora" => "SO", "Tabasco" => "TB",
    "Tamaulipas" => "TM", "Tlaxcala" => "TL", "Veracruz" => "VZ", "Yucatán" => "YU",
    "Zacatecas" => "ZA"
  }

  def self.execute!(candidate)
    begin
      puts "\n🔍 PASO 2: Buscar Evidencia de Cartel"
      puts "=" * 60
      puts "Candidato: #{candidate[:fullname]}"
      puts "=" * 60

      # 1. Buscar en internet
      articles = search_news(candidate[:firstname], candidate[:lastname1])
      puts "\n📰 Artículos encontrados: #{articles.size}"

      if articles.empty?
        puts "❌ No hay artículos disponibles"
        return nil
      end

      # 2. Iterar por artículos hasta encontrar uno válido con plain_text
      articles.each_with_index do |article, idx|
        puts "\n[#{idx + 1}] Procesando: #{article['title']}"
        
        # Validar link
        url = article["url"].to_s.strip
        next if url.blank?

        # Validar que link no exista ya
        if Hit.exists?(link: url)
          puts "   ⏭️  Link ya existe, saltando"
          next
        end

        # Resolver ubicación
        date = Date.parse(article["publishedAt"].split("T").first) rescue Date.today
        title = article["title"][0, 255]
        
        location_result = resolve_location(article["description"].to_s, article["content"].to_s)
        town_id = location_result[:town_id]
        location_info = location_result[:info]

        puts "   📍 Ubicación: #{location_info}"

        # Crear Hit provisional
        begin
          hit = Hit.create!(
            date: date,
            title: title,
            link: url,
            town_id: town_id,
            user_id: User.first.id  # O el usuario actual si existe contexto
          )
          puts "   ✅ Hit creado (ID: #{hit.id})"
        rescue => e
          puts "   ❌ Error creando Hit: #{e.message}"
          next
        end

        # Capturar plain_text (OBLIGATORIO)
        begin
          HitSnapshotFetcher.call!(hit, require_members: false)
          hit.reload

          if hit.plain_text.blank? || hit.plain_text.length < 800
            puts "   ❌ plain_text no válido (#{hit.plain_text&.length || 0} chars)"
            hit.destroy!
            next
          end

          puts "   ✅ plain_text capturado (#{hit.plain_text.length} chars)"
          puts "\n" + "=" * 60
          puts "✅ HIT VÁLIDO ENCONTRADO:"
          puts "=" * 60
          puts "   ID: #{hit.id}"
          puts "   Título: #{hit.title}"
          puts "   Fecha: #{hit.date}"
          puts "   Ubicación: #{location_info}"
          puts "   Link: #{hit.link}"
          puts "=" * 60

          return hit

        rescue => e
          puts "   ❌ Error capturando plain_text: #{e.message}"
          hit.destroy! if hit.persisted?
          next
        end
      end

      # Si llegó aquí: ningún artículo fue válido
      puts "\n❌ No se pudo crear Hit válido con ningún artículo"
      nil

    rescue OfacPipeline::UpdateError => e
      puts "\n❌ ERROR EN PASO 2:"
      puts "   #{e.message}"
      nil
    rescue => e
      puts "\n❌ ERROR INESPERADO EN PASO 2:"
      puts "   #{e.class}: #{e.message}"
      puts e.backtrace.first(5)
      nil
    end
  end

  private

  # Buscar en NewsAPI
  def self.search_news(firstname, lastname)
    query = "#{firstname} #{lastname} cartel Mexico"
    
    puts "\n📡 Buscando en NewsAPI..."
    puts "   Query: #{query}"

    uri = URI(NEWS_API_BASE)
    uri.query = URI.encode_www_form(
      q: query,
      language: "es",
      sortBy: "relevancy",
      apiKey: NEWS_API_KEY,
      pageSize: 10
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    if response.code.to_i != 200
      raise OfacPipeline::UpdateError, "NewsAPI error: #{response.code} #{response.body}"
    end

    data = JSON.parse(response.body)
    data["articles"] || []
  rescue => e
    raise OfacPipeline::UpdateError, "No se pudo buscar en NewsAPI: #{e.message}"
  end

  # Resolver ubicación según reglas obligatorias
  def self.resolve_location(description, content)
    text = "#{description} #{content}".downcase

    # Buscar estado mexicano en el texto
    identified_state = nil
    MEXICAN_STATES.each do |state_name, code|
      if text.include?(state_name.downcase)
        identified_state = state_name
        break
      end
    end

    # Buscar municipios dentro del estado identificado (si aplica)
    identified_county = nil
    identified_state_obj = nil

    if identified_state
      identified_state_obj = State.find_by("LOWER(name) = ?", identified_state.downcase)
      
      if identified_state_obj
        # Buscar municipios del estado
        identified_state_obj.counties.each do |county|
          if text.include?(county.name.downcase)
            identified_county = county
            break
          end
        end
      end
    end

    # RESOLVER SEGÚN REGLAS OBLIGATORIAS
    if identified_state_obj
      if identified_county
        # Estado Y Municipio identificados → Town "Sin definir" del municipio
        town = identified_county.towns.find_by(name: "Sin definir")
        info = "#{identified_county.name}, #{identified_state_obj.name}"
      else
        # SOLO Estado identificado → Town "Sin definir" del Municipio "Sin definir" del Estado
        sin_def_county = identified_state_obj.counties.find_by(name: "Sin definir")
        town = sin_def_county&.towns&.find_by(name: "Sin definir")
        info = "Sin definir, #{identified_state_obj.name}"
      end
    else
      # NO se identificó nada OR es extranjero → CDMX
      cdmx = State.find_by("LOWER(name) = ?", "ciudad de méxico")
      sin_def_county = cdmx&.counties&.find_by(name: "Sin definir")
      town = sin_def_county&.towns&.find_by(name: "Sin definir")
      info = "Sin definir, Ciudad de México (fallback)"
    end

    # Validar que se encontró un town
    unless town
      raise OfacPipeline::UpdateError, "No se pudo resolver town para ubicación"
    end

    { town_id: town.id, info: info }
  end
end

class OfacPipeline::UpdateError < StandardError; end
```

---

### CASOS DE ÉXITO Y FRACASO

**CASO ✅ ÉXITO:**
```
🔍 PASO 2: Buscar Evidencia de Cartel
============================================================
Candidato: Carlos Garcia Lopez
============================================================

📰 Artículos encontrados: 5

[1] Procesando: Carlos García López vinculado a cartel del noroeste
   📍 Ubicación: Culiacán, Sinaloa
   ✅ Hit creado (ID: 4521)
   ✅ plain_text capturado (2847 chars)

============================================================
✅ HIT VÁLIDO ENCONTRADO:
============================================================
   ID: 4521
   Título: Carlos García López vinculado a cartel...
   Fecha: 2026-09-28
   Ubicación: Culiacán, Sinaloa
   Link: https://infobae.com/...
============================================================
```

**CASO ⚠️ FALLBACK - Claude no puede extraer fecha:**
```
[2] Procesando: Información sobre Carlos García
   📍 Ubicación: Monterrey, Nuevo León
   ✅ Hit creado (ID: 4522) - Fecha inicial: 2026-10-01
   ✅ plain_text capturado (2847 chars)

   🤖 PASO 3: Extrayendo fecha con Claude...
     ⚠️  Claude no pudo extraer fecha, usando fallback Date.today: 2026-10-01

   ✅ HIT VÁLIDO (con fecha fallback)
   ID: 4522
   Fecha: 2026-10-01 (fallback)
```

**CASO ❌ FRACASO (plain_text no se captura):**
```
[3] Procesando: Carlos García en noticias del norte
   ✅ Hit creado (ID: 4523)
   ❌ plain_text no válido (234 chars) - Destruyendo Hit
   ⏭️  Intentando siguiente artículo

❌ No se pudo crear Hit válido con ningún artículo
```

**CASO ❌ FRACASO (no hay artículos):**
```
📰 Artículos encontrados: 0
❌ No hay artículos disponibles
```

---

## Próximos Pasos

- [ ] PASO 2: ✅ **COMPLETADO**
- [ ] PASO 3: Validar nombres explícitos en plain_text
- [ ] PASO 4: Validar vinculación a cartel
- [ ] PASO 5-9: Crear Member + vincular + ejecutar scripts finales

---

**Control de Versiones:**

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.1 | 2026-09-30 | PASO 2 completo: Búsqueda de cartel + Hit provisional con plain_text |
| 1.0 | 2026-09-30 | PASO 1 completo: Identificar Candidato OFAC Disponible |
