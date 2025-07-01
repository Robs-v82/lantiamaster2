require 'ferrum'

browser = Ferrum::Browser.new(
  headless: false,
  timeout: 30,
  window_size: [1200, 900]
)

puts "Abriendo la página..."
browser.goto("https://www.cedulaprofesional.sep.gob.mx/cedula/presidencia/indexAvanzada.action")

# Esperar a que aparezca el campo de nombre
max_intentos = 5
intento = 1
campo_visible = false

while intento <= max_intentos
  campo = browser.at_css("input#nombre")
  if campo && campo.evaluate("this.offsetParent !== null")
    campo_visible = true
    puts "✅ Campo 'nombre' encontrado y visible."

puts "🖋️ Llenando el formulario..."

    browser.at_css("input#nombre")&.focus
    browser.at_css("input#nombre")&.type("ROBERTO")

    browser.at_css("input#paterno")&.focus
    browser.at_css("input#paterno")&.type("VALLADARES")

    browser.at_css("input#materno")&.focus
    browser.at_css("input#materno")&.type("PIEDRAS")

    puts "📨 Enviando formulario..."
    boton = browser.at_xpath("//span[contains(text(),'Consultar')]/ancestor::span[contains(@class, 'dijitButtonNode')]")
    boton&.click

    sleep 5  # Esperamos carga de resultados
    browser.screenshot(path: "tmp_resultado.png")
    puts "✅ Formulario enviado. Captura guardada como tmp_resultado.png"

    puts "Esperando a que aparezca el contenedor de resultados..."

    max_intentos = 10
    encontrado = false

    max_intentos.times do |i|
      if browser.at_css('#cedulasGrid')
        encontrado = true
        puts "✅ Contenedor de resultados encontrado en intento #{i + 1}."
        break
      else
        puts "⏳ Intento #{i + 1}: contenedor no encontrado todavía..."
        browser.screenshot(path: "tmp_resultado_#{i + 1}.png", full: true)
        sleep 1
      end
    end

    if browser.at_css('#cedulasGrid')
      puts "✅ Contenedor de resultados encontrado."

      contenido = browser.at_css('#cedulasGrid').inner_text
      puts "📄 Texto de resultados guardado como 'tmp_resultado.txt'"

      # Valores de búsqueda exactos (ajusta si estás probando con otro nombre)
      nombre_esperado = "ROBERTO"
      apellido1_esperado = "VALLADARES"
      apellido2_esperado = "PIEDRAS"

      puts "🔍 Buscando coincidencias exactas en resultados..."

      # Recolectar todas las filas
      filas = browser.css(".dojoxGridRow")

      coincidencia = filas.find do |fila|
        celdas = fila.css(".dojoxGridCell").map(&:text).map(&:strip)
        next false unless celdas.size >= 4

        nombre, ape1, ape2 = celdas[1], celdas[2], celdas[3]
        nombre == nombre_esperado && ape1 == apellido1_esperado && ape2 == apellido2_esperado
      end

      if coincidencia
        puts "✅ Coincidencia exacta encontrada. Haciendo clic en la fila..."

        # Simula clic sobre el primer <td> (columna de cédula) de la fila encontrada
        first_cell = coincidencia.css("td").first
        if first_cell
          first_cell.focus
          first_cell.click
          puts "🖱️ Clic simulado sobre la celda de la fila seleccionada."
        else
          puts "⚠️ No se pudo hacer clic en la celda."
        end
      else
        puts "❌ No se encontró coincidencia exacta en los resultados."
        exit
      end

      # Esperar a que cargue la pestaña de detalle
      sleep 2  # brecha visual

      puts "⏳ Esperando a que aparezca el detalle..."

      max_intentos = 20
      intento = 1
      detalle_visible = false

      while intento <= max_intentos
        sleep 1
        nombre_div = browser.at_css("#detalleNombre")
        if nombre_div && !nombre_div.text.strip.empty?
          detalle_visible = true
          break
        else
          puts "⏳ Intento #{intento}: esperando que el detalle tenga contenido..."
          intento += 1
        end
      end

      unless detalle_visible
        puts "❌ El detalle no se cargó correctamente tras varios intentos."
        browser.screenshot(path: "tmp_fallo_detalle.png")
        exit
      end

      puts "✅ Detalle cargado. Extrayendo información..."

      detalle = {
        cedula: browser.at_css("#detalleCedula")&.text&.strip,
        nombre: browser.at_css("#detalleNombre")&.text&.strip,
        genero: browser.at_css("#detalleGenero")&.text&.strip,
        profesion: browser.at_css("#detalleProfesion")&.text&.strip,
        institucion: browser.at_css("#detalleInstitucion")&.text&.strip,
        fecha: browser.at_css("#detalleFecha")&.text&.strip,
        tipo: browser.at_css("#detalleTipo")&.text&.strip
      }

      puts "📄 Datos del detalle:"
      detalle.each { |k, v| puts "  #{k}: #{v}" }

      # Guardar captura de respaldo
      browser.screenshot(path: "tmp_detalle.png")
      puts "🖼️ Captura del detalle guardada como tmp_detalle.png"

    else
      puts "❌ No se encontró el contenedor de resultados."
    end


    break
  else
    puts "⏳ Intento #{intento}: campo no visible aún. Captura guardada en tmp_step_#{intento}.png"
    browser.screenshot(path: "tmp_step_#{intento}.png")
    sleep 2
    intento += 1
  end
end


unless campo_visible
  puts "❌ No se encontró el campo 'nombre' visible después de varios intentos"
end

browser.quit


