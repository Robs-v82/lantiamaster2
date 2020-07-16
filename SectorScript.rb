sectorArr = []
rawData.each_line{|l| line = l.split("ç"); sectorArr.push(line)}
sectorArr.each{|x|x.each{|y|y.strip!}}
sectorArr.each{|x| Sector.create(scian2:x[0], name:x[1], description:x[2])}

rawData="11çAgricultura, cría y explotación de animales, aprovechamiento forestal, pesca y caza
21çMinería
22çGeneración, transmisión, distribución y comercialización de energía eléctrica, suministro de agua y de gas natural por ductos al consumidor final
23çConstrucción
31çIndustrias manufactureras
32çIndustrias manufactureras
33çIndustrias manufactureras
43çComercio al por mayor
46çComercio al por menor
48çTransportes, correos y almacenamiento
49çTransportes, correos y almacenamiento
52çServicios financieros y de seguros
53çServicios inmobiliarios y de alquiler de bienes muebles e intangibles
54çServicios profesionales, científicos y técnicos
55çCorporativos
56çServicios de apoyo a los negocios y manejo de residuos, y servicios de remediación
61çServicios educativos
62çServicios de salud y de asistencia social
71çServicios de esparcimiento culturales y deportivos, y otros servicios recreativos
72çServicios de alojamiento temporal y de preparación de alimentos y bebidas
81çOtros servicios excepto actividades gubernamentales
93çActividades legislativas, gubernamentales, de impartición de justicia y de organismos internacionales y extraterritoriales"

rawData=Sector.pluck(:id,:scian2)
rawData.each{|x| Division.create(sector_id:x[0],name:"General",scian3:x[1]*10)}


divisionArr = []
rawData.each_line{|l| line = l.split("ç"); divisionArr.push(line)}
divisionArr.each{|x|x.each{|y|y.strip!}}
# divisionArr.each{|x| y=x[0][0,2]; myid=Sector.where(:scian2=>y).last.id; Division.create(scian3:x[0], name:x[1]),sector_id:myid}


targetArr = []
divisionArr.each{|x| y=x[0][0,2]; myid=Sector.where(:scian2=>y).last.id; targetArr.push(myid)}
divisionArr.each{|x| x.push(targetArr[x])}
z=targetArr.length-1
(0..z).each{|x| Division.create(scian3:divisionArr[x][0],name:divisionArr[x][1],sector_id:targetArr[x])}






rawData="111çAgricultura
112çCría y explotación de animales
113çAprovechamiento forestal
114çPesca, caza y captura
115çServicios relacionados con las actividades agropecuarias y forestales
211çExtracción de petróleo y gas
212çMinería de minerales metálicos y no metálicos, excepto petróleo y gas
213çServicios relacionados con la minería
221çGeneración, transmisión, distribución y comercialización de energía eléctrica, suministro de agua y de gas natural por ductos al consumidor final
236çEdificación
237çConstrucción de obras de ingeniería civil
238çTrabajos especializados para la construcción
311çIndustria alimentaria
312çIndustria de las bebidas y del tabaco
313çFabricación de insumos textiles y acabado de textiles
314çFabricación de productos textiles, excepto prendas de vestir
315çFabricación de prendas de vestir
316çCurtido y acabado de cuero y piel, y fabricación de productos de cuero, piel y materiales sucedáneos
321çIndustria de la madera
322çIndustria del papel"

rawData="323çImpresión e industrias conexas
324çFabricación de productos derivados del petróleo y del carbón
325çIndustria química
326çIndustria del plástico y del hule
327çFabricación de productos a base de minerales no metálicos
331çIndustrias metálicas básicas
332çFabricación de productos metálicos
333çFabricación de maquinaria y equipo
334çFabricación de equipo de computación, comunicación, medición y de otros equipos, componentes y accesorios electrónicos
335çFabricación de accesorios, aparatos eléctricos y equipo de generación de energía eléctrica
336çFabricación de equipo de transporte
337çFabricación de muebles, colchones y persianas
339çOtras industrias manufactureras
431çComercio al por mayor de abarrotes, alimentos, bebidas, hielo y tabaco
432çComercio al por mayor de productos textiles y calzado
433çComercio al por mayor de productos farmacéuticos, de perfumería, artículos para el esparcimiento, electrodomésticos menores y aparatos de línea blanca
434çComercio al por mayor de materias primas agropecuarias y forestales, para la industria, y materiales de desecho
435çComercio al por mayor de maquinaria, equipo y mobiliario para actividades agropecuarias, industriales, de servicios y comerciales, y de otra maquinaria y equipo de uso general
436çComercio al por mayor de camiones y de partes y refacciones nuevas para automóviles, camionetas y camiones
437çIntermediación de comercio al por mayor
461çComercio al por menor de abarrotes, alimentos, bebidas, hielo y tabaco
462çComercio al por menor en tiendas de autoservicio y departamentales
463çComercio al por menor de productos textiles, bisutería, accesorios de vestir y calzado
464çComercio al por menor de artículos para el cuidado de la salud
465çComercio al por menor de artículos de papelería, para el esparcimiento y otros artículos de uso personal
466çComercio al por menor de enseres domésticos, computadoras, artículos para la decoración de interiores y artículos usados
467çComercio al por menor de artículos de ferretería, tlapalería y vidrios
468çComercio al por menor de vehículos de motor, refacciones, combustibles y lubricantes
469çComercio al por menor exclusivamente a través de internet, y catálogos impresos, televisión y similares
481çTransporte aéreo
482çTransporte por ferrocarril
483çTransporte por agua
484çAutotransporte de carga
485çTransporte terrestre de pasajeros, excepto por ferrocarril
486çTransporte por ductos
487çTransporte turístico"

rawData="488çServicios relacionados con el transporte
491çServicios postales
492çServicios de mensajería y paquetería
493çServicios de almacenamiento"

rawData="511çEdición de periódicos, revistas, libros, software y otros materiales, y edición de estas publicaciones integrada con la impresión
512çIndustria fílmica y del video, e industria del sonido
515çRadio y televisión
517çTelecomunicaciones
518çProcesamiento electrónico de información, hospedaje y otros servicios relacionados
519çOtros servicios de información"

rawData="521çBanca central
522çInstituciones de intermediación crediticia y financiera no bursátil
523çActividades bursátiles, cambiarias y de inversión financiera
524çCompañías de seguros, fianzas, y administración de fondos para el retiro
525çSociedades de inversión especializadas en fondos para el retiro y fondos de inversión
531çServicios inmobiliarios
532çServicios de alquiler de bienes muebles
533çServicios de alquiler de marcas registradas, patentes y franquicias
541çServicios profesionales, científicos y técnicos
551çCorporativos
561çServicios de apoyo a los negocios
562çManejo de residuos y servicios de remediación
611çServicios educativos
621çServicios médicos de consulta externa y servicios relacionados
622çHospitales
623çResidencias de asistencia social y para el cuidado de la salud
624çOtros servicios de asistencia social
711çServicios artísticos, culturales y deportivos, y otros servicios relacionados
712çMuseos, sitios históricos, zoológicos y similares
713çServicios de entretenimiento en instalaciones recreativas y otros servicios recreativos
721çServicios de alojamiento temporal
722çServicios de preparación de alimentos y bebidas
811çServicios de reparación y mantenimiento
812çServicios personales
813çAsociaciones y organizaciones
814çHogares con empleados domésticos
931çActividades legislativas, gubernamentales y de impartición de justicia
932çOrganismos internacionales y extraterritoriales"
