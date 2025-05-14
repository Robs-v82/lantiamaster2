require 'csv'
require 'open-uri'
require 'timeout'

user_agent = "WickedPdf/1.0 (Lantia Intelligence)"
# USER_ID = 18
USER_ID = 1164

# ⚠️ Pega aquí todo el contenido CSV como string entre comillas triples
csv_data = <<~CSV
legacy_id,fecha,estado,municipio o localidad,clave INEGI,título,reporte,link
23-04-25-NOTA-01,2024-11-11,Jalisco,Guadalajara,14039,En Jalisco SSPC detiene a La Güera presunta operadora de los Mayos en Colima,,https://www.angulo7.com.mx/2024/nacional/en-jalisco-sspc-detiene-a-la-guera-presunta-operadora-de-los-mayos-en-colima/591346/
23-04-25-NOTA-02,2024-12-28,Guerrero,Acapulco,12001,Detenido en Acapulco El Panadero líder de una célula criminal en la ciudad del Pacífico,,https://elpais.com/mexico/2024-12-28/detenido-en-acapulco-el-panadero-lider-de-una-celula-criminal-en-la-ciudad-del-pacifico.html
23-04-25-NOTA-03,2015-11-06,Baja California Sur,Los Cabos,3008,Detienen a El Gus,,https://www.noroeste.com.mx/nacional/detienen-a-el-gus-CVNO19105
23-04-25-NOTA-04,2024-02-13,Estado de México,Naucalpan,15057,Capturan a integrantes del Cártel Nuevo Imperio en Naucalpan les encuentran pistolas y vehículos de alta gama,,https://www.infobae.com/mexico/2024/02/13/capturan-a-integrantes-del-cartel-nuevo-imperio-en-naucalpan-les-encuentran-pistolas-y-vehiculos-de-alta-gama/
23-04-25-NOTA-05,2025-03-10,Estado de México,Ecatepec,15033,Líder de Los 300 de Ecatepec fue recluido en el penal de Tenango,,https://lajornadaestadodemexico.com/lider-de-los-300-de-ecatepec-fue-recluido-en-el-penal-de-tenango/
23-04-25-NOTA-06,2025-03-12,Chiapas,Comitán de Domínguez,7019,Cae en Chiapas La Chicharra líder máximo de Los Huistas y el criminal más buscado en Guatemala,,https://www.infobae.com/mexico/2025/03/12/cae-en-chiapas-la-chicharra-lider-maximo-de-los-huistas-y-el-criminal-mas-buscado-en-guatemala/
23-04-25-NOTA-07,2025-04-20,Guerrero,Chilpancingo,12014,Los Ardillos: líderes y autoridades coludidas en Chilpancingo,,https://graficos.gruporeforma.com/los-ardillos-elementor-alcaldesa/
23-04-25-NOTA-08,2025-01-20,Chiapas,San Cristóbal de las Casas,7078,Detienen a líder de Los Motonetos en San Cristóbal de las Casas,,https://www.jornada.com.mx/2025/01/20/estados/029n1est
23-04-25-NOTA-09,2025-03-15,Chiapas,Yajalón,7101,Detienen a El Chorizo líder del grupo criminal Karma en Yajalón,,https://www.telediario.mx/comunidad/chiapas-detienen-a-el-chorizo-lider-del-grupo-criminal-karma
23-04-25-NOTA-10,2025-03-31,Chiapas,Tila,7102,FGE de Chiapas ofrece recompensa por presunto líder criminal en Tila,,https://www.milenio.com/estados/fge-de-chiapas-ofrece-recompensa-por-presunto-lider-criminal-en-tila
23-04-25-NOTA-11,2025-03-10,Estado de México,Ecatepec,15033,Operativo conjunto logra captura de líder criminal,,https://www.elmanana.com/noticias/nacional/operativo-conjunto-logra-captura-de-lider-criminal/5949776
23-04-25-NOTA-12,2025-02-22,Morelos,Cuernavaca,17001,Cae El Mija líder de La Familia Michoacana en Morelos,,https://www.nacion321.com/estados/2025/02/22/cae-el-mija-lider-de-la-familia-michoacana-en-morelos/
23-04-25-NOTA-13,2025-02-05,Tabasco,Centro,27002,El licenciado Tomasín o El 12 líder de La Barredora es vinculado a proceso,,https://www.excelsior.com.mx/nacional/el-licenciado-tomasin-o-el-12-lider-de-la-barredora-es-vinculado-a-proceso/1698248
23-04-25-NOTA-14,2024-11-14,Guerrero,Tecoanapa,12060,Detienen a La Garza cabecilla de Los Ardillos en Tecoanapa Guerrero,,https://www.jornada.com.mx/noticia/2024/11/14/politica/detienen-a-la-garza-cabecilla-de-los-ardillos-en-tecoanapa-guerrero-6304
23-04-25-NOTA-15,2025-03-24,Sinaloa,Culiacán,25006,Vinculan a dos detenidos en Culiacán con Fuerzas Especiales Avendaño brazo armado de Los Chapitos,,https://oem.com.mx/elsoldesinaloa/policiaca/vinculan-a-dos-detenidos-en-culiacan-con-fuerzas-especiales-avendano-brazo-armado-de-los-chapitos-22341931
23-04-25-NOTA-16,2025-04-12,Oaxaca,Matías Romero,20057,Identifican a grupo criminal ligado al CJNG en Matías Romero Oaxaca se dedican al huachicol robo y extorsión,,https://www.infobae.com/mexico/2025/04/12/identifican-a-grupo-criminal-ligado-al-cjng-en-matias-romero-oaxaca-se-dedican-al-huachicol-robo-y-extorsion/
23-04-25-NOTA-17,2025-03-20,Querétaro,Querétaro,22001,Detienen Alfa 1 líder criminal del Cártel del Golfo,,https://abcnoticias.mx/nacional/2025/3/20/detienen-alfa-1-lider-criminal-del-cartel-del-golfo-243643.html
23-04-25-NOTA-18,2025-03-27,Estado de México,Toluca,15093,Cae objetivo relevante de la Familia Michoacana que operaba en el Edomex es investigado por homicidio,,https://www.infobae.com/mexico/2025/03/27/cae-objetivo-relevante-de-la-familia-michoacana-que-operaba-en-el-edomex-es-investigado-por-homicidio/
23-04-25-NOTA-19,2025-02-25,Michoacán,Zacapu,16097,¿Quién es El Chuy líder criminal capturado en Zacapu?,,https://heraldodemexico.com.mx/nacional/2025/2/25/quien-es-el-chuy-lider-criminal-capturado-en-zacapu-679025.html
23-04-25-NOTA-20,2025-02-19,Michoacán,Pátzcuaro,16067,Los Panchitos Michoacán quiénes son cártel que opera en Pátzcuaro aliados del CJNG Francisco Manuel Flores El Panchito,,https://www.elfinanciero.com.mx/nacional/2025/02/19/los-panchitos-michoacan-quienes-son-cartel-que-opera-en-patzcuaro-aliados-del-cjng-francisco-manuel-flores-el-panchito/
23-04-25-NOTA-21,2025-03-15,Michoacán,Apatzingán,16009,Capturan a familiares de presunto líder extorsionador de limoneros y aguacateros,,https://forbes.com.mx/capturan-a-familiares-de-presunto-lider-extorsionador-de-limoneros-y-aguacateros/
23-04-25-NOTA-22,2025-02-19,Sinaloa,Culiacán,25006,Detienen a El Güerito presunto lugarteniente de Los Chapitos,,https://www.jornada.com.mx/noticia/2025/02/19/politica/detienen-a-2018el-guerito2019-presunto-lugarteniente-de-2018los-chapitos2019-8722
23-04-25-NOTA-23,2025-03-23,Ciudad de México,Cuajimalpa,9010,José Gregorio N de desaparecido a presunto reclutador del CJNG el caso que conecta Chiapas y Jalisco,,https://www.infobae.com/mexico/2025/03/23/jose-gregorio-n-de-desaparecido-a-presunto-reclutador-del-cjng-el-caso-que-conecta-chiapas-y-jalisco/
23-04-25-NOTA-24,2023-12-12,Oaxaca,Santiago Jamiltepec,20077,Detienen a Manuel Iglesias 'El Pantera' hijo de presidenta municipal de Jamiltepec Oaxaca,,https://www.milenio.com/policia/detienen-hijo-presidenta-jamiltepec-crimen-organizado
23-04-25-NOTA-25,2025-01-06,Chiapas,Frontera Comalapa,7034,¿Quién es José Antonio Villatoro el alcalde de Frontera Comalapa detenido y vinculado con el CJNG?,,https://www.infobae.com/mexico/2025/01/06/quien-es-jose-antonio-villatoro-el-alcalde-de-frontera-comalapa-detenido-y-vinculado-con-el-cjng/
23-04-25-NOTA-26,2025-03-20,Michoacán,Coalcomán,16017,Alcaldesa de Michoacán con presuntos nexos con el CJNG y El Mencho podría ir a juicio político MC niega notificación,,https://www.infobae.com/mexico/2025/03/20/alcaldesa-de-michoacan-con-presuntos-nexos-con-el-cjng-y-el-mencho-podria-ir-a-juicio-politico-mc-niega-notificacion/
23-04-25-NOTA-27,2025-02-09,Estado de México,Santo Tomás de los Plátanos,15084,Arrestan al alcalde electo de Santo Tomás Edomex prófugo 50 días,,https://www.jornada.com.mx/2025/02/09/estados/021n1est
24-04-25-NOTA-01,2025-01-10,Tamaulipas,Aldama,28003,Recompensas millonarias en Tamaulipas estos son los líderes criminales más buscados,,https://laverdadnoticias.com/crimen/recompensas-millonarias-en-tamaulipas-estos-son-los-lideres-criminales-mas-buscados-20250110
24-04-25-NOTA-02,2025-04-10,Tamaulipas,San Fernando,28033,Cae El Flaco jefe regional de los Zetas Vieja Escuela en San Fernando Tamaulipas,,https://www.infobae.com/mexico/2025/04/10/cae-el-flaco-jefe-regional-de-los-zetas-vieja-escuela-en-san-fernando-tamaulipas/
24-04-25-NOTA-03,2025-04-09,Jalisco,Tlajomulco de Zúñiga,14098,En Jalisco detienen a La Barbie uno de los líderes de Los Zetas la Vieja Escuela narco delincuente,,https://oem.com.mx/elsoldemexico/mexico/en-jalisco-detienen-a-la-barbie-uno-de-los-lideres-de-los-zetas-la-vieja-escuela-narco-delincuente-15922396?token=-1535492604
24-04-25-NOTA-04,2025-03-24,Guanajuato,Celaya,11010,Detienen a El Agus principal colaborador de El Marro líder Cártel Santa Rosa FGR Marina,,https://oem.com.mx/elsoldemexico/mexico/detienen-a-el-agus-principal-colaborador-de-el-marro-lider-cartel-santa-rosa-fgr-marina-15927181
24-04-25-NOTA-05,2025-03-17,Guanajuato,Cortazar,11013,Detienen a 2 hombres vinculados a El Marro,,https://aristeguinoticias.com/editorial/1703/mexico/detienen-a-2-hombres-vinculados-a-el-marro/
24-04-25-NOTA-06,2025-03-17,Ciudad de México,Ciudad de México,9000,FGR detiene a dos sujetos ligados a El Marro Ciudad de México Guanajuato Cártel de Santa Rosa de Lima El Flaco El Bala,,https://oem.com.mx/elsoldemexico/mexico/fgr-detiene-a-dos-sujetos-ligados-a-el-marro-ciudad-de-mexico-guanajuato-cartel-de-santa-rosa-de-lima-el-flaco-el-bala-16613205
24-04-25-NOTA-07,2020-06-24,San Luis Potosí,San Luis Potosí,24028,Capturan a Noé Lara Belman El Puma ex mano derecha de El Marro,,https://lasillarota.com/guanajuato/estado/2020/6/24/capturan-noe-lara-belman-el-puma-ex-mano-derecha-de-el-marro-235172.html
24-04-25-NOTA-08,2020-06-24,Baja California,Tijuana,2004,Vinculan a proceso a La Vieja cercano a El Marro del Cártel de Santa Rosa de Lima,,https://www.capitalmexico.com.mx/cdmx/vinculan-a-proceso-a-la-vieja-cercano-a-el-marro-del-cartel-de-santa-rosa-de-lima/
24-04-25-NOTA-09,2020-02-22,Guanajuato,Celaya,11010,El Tortugo uno de los principales operadores de El Marro fue detenido en Celaya,,https://lasillarota.com/estados/2020/2/22/el-tortugo-uno-de-los-principales-operadores-de-el-marro-fue-detenido-en-celaya-217957.html
24-04-25-NOTA-10,2025-04-24,Jalisco,Ixtlahuacán del Río,14045,Presunta detención de El Doble R habría detonado narcobloqueos en tres estados Saucedo,,https://aristeguinoticias.com/2404/mexico/presunta-detencion-de-el-doble-r-habria-detonado-narcobloqueos-en-tres-estados-saucedo/
24-04-25-NOTA-11,2024-12-02,Guanajuato,Apaseo el Grande,11003,Cae Burras Prietas líder de banda criminal dedicada al robo de autotransportes rescatan a 5 migrantes,,https://www.eluniversal.com.mx/nacion/cae-burras-prietas-lider-de-banda-criminal-dedicada-al-robo-de-autotransportes-rescatan-a-5-migrantes/
24-04-25-NOTA-12,2025-01-31,Guanajuato,León,11020,Cae El Flaco líder de una célula del CJNG en Guanajuato es investigado por el asesinato de dos custodios en León,,https://www.infobae.com/mexico/2025/01/31/cae-el-flaco-lider-de-una-celula-del-cjng-en-guanajuato-es-investigado-por-el-asesinato-de-dos-custodios-en-leon/
24-04-25-NOTA-13,2025-03-28,Guanajuato,Silao,11030,Vinculan a proceso Big Mama presunto integrante del CJNG por robo de transporte secuestro,,https://mvsnoticias.com/nacional/policiaca/2025/3/28/vinculan-proceso-big-mama-presunto-integrante-del-cjng-por-robo-de-transporte-secuestro-685223.html
24-04-25-NOTA-14,2025-02-27,Guanajuato,León,11020,Así capturaron Don Arturo y La Chepina del CJNG en León,,https://www.excelsior.com.mx/nacional/asi-capturaron-don-arturo-y-la-chepina-del-cjng-en-leon/1702254
24-04-25-NOTA-15,2024-11-16,Jalisco,Zapopan,14067,Detienen a Armando Gómez Núñez alias Delta 1 operador del CJNG en Zapopan,,https://www.jornada.com.mx/2024/11/16/politica/011n3pol
24-04-25-NOTA-16,2024-11-18,Morelos,Amacuzac,17004,Detienen a Jaime Bahena Landa alias La Parka líder de La Nueva Familia Michoacana en Morelos,,https://latinus.us/mexico/2024/11/18/la-parka-integrante-de-la-familia-michoacana-detenido-en-morelos-fue-candidato-regidor-del-pt-en-amacuzac-128661.html
24-04-25-NOTA-17,2023-12-23,Ciudad de México,Ciudad de México,9000,Sentencian a 43 años de cárcel a El Betito ex líder de la Unión Tepito,,https://www.infobae.com/mexico/2023/12/23/sentencian-a-43-anos-de-carcel-a-el-betito-ex-lider-de-la-union-tepito/
24-04-25-NOTA-18,2025-01-22,Ciudad de México,Benito Juárez,9015,A prisión El Tiger operador financiero de La Unión Tepito,,https://www.excelsior.com.mx/comunidad/a-prision-el-tiger-operador-financiero-la-union-tepito/1696214
24-04-25-NOTA-19,2024-07-29,Quintana Roo,Cancún,23005,El Huguito detenido en Cancún se queda en el Reclusorio Oriente por homicidio,,https://www.eluniversal.com.mx/metropoli/el-huguito-detenido-en-cancun-se-queda-en-el-reclusorio-oriente-por-homicidio/
24-04-25-NOTA-20,2024-08-04,Estado de México,Almoloya de Alquisiras,15006,Dan prisión vitalicia a El 47 jefe de plaza de la Familia Michoacana en el Edomex por homicidio,,https://www.infobae.com/mexico/2024/08/04/dan-prision-vitalicia-a-el-47-jefe-de-plaza-de-la-familia-michoacana-en-el-edomex-por-homicidio/
24-04-25-NOTA-21,2020-08-19,Ciudad de México,Cuauhtémoc,9005,Cae El Galleta líder delictivo de la zona del Ajusco,,https://es-us.noticias.yahoo.com/cae-galleta-l%C3%ADder-delictivo-zona-192745066.html
24-04-25-NOTA-22,2018-10-02,Baja California Sur,La Paz,3003,La caída de El Colores y/o El Patreño,,https://zetatijuana.com/2018/10/la-caida-de-el-colores-y-o-el-patreno/
24-04-25-NOTA-23,2018-08-30,Nuevo León,Monterrey,19039,Detienen en Monterrey a El Pelonchas y El Penco líderes del Cártel del Golfo,,https://aristeguinoticias.com/3008/mexico/detienen-en-monterrey-a-el-pelonchas-y-el-penco-lideres-del-cartel-del-golfo/
24-04-25-NOTA-24,2018-08-24,Nuevo León,Monterrey,19039,Cae La Yegua líder de célula criminal del Cártel del Golfo,,https://oem.com.mx/elsoldelalaguna/mexico/cae-la-yegua-lider-de-celula-criminal-del-cartel-del-golfo-18722785
24-04-25-NOTA-25,2018-08-15,Chihuahua,Ciudad Juárez,8037,Cae El Sexto el último líder del Cártel de Juárez,,https://lasillarota.com/nacion/2018/8/15/cae-el-sexto-el-ultimo-lider-del-cartel-de-juarez-166574.html
24-04-25-NOTA-26,2018-02-16,Guanajuato,San José Iturbide,11031,El Cholo de la Familia Michoacana jefe de sicarios de El Ojos,,https://lasillarota.com/metropoli/2018/2/16/el-cholo-de-la-familia-michoacana-jefe-de-sicarios-de-el-ojos-152234.html
24-04-25-NOTA-27,2011-10-18,Estado de México,Ecatepec de Morelos,15033,Detienen a líder de grupo criminal La Barredora,,https://animalpolitico.com/2011/10/detienen-a-lider-de-grupo-criminal-la-barredora
24-04-25-NOTA-28,2024-05-18,Querétaro,Querétaro,22006,Caen El Tuto; El May y El Zapato; líderes criminales en la CDMX capturados en Querétaro,,https://heraldodemexico.com.mx/nacional/2024/5/18/caen-el-tuto-el-may-el-zapato-lideres-criminales-en-la-cdmx-capturados-en-queretaro-604181.html
24-04-25-NOTA-29,2024-01-27,Sinaloa,Sinaloa,25027,Quién es Edwin Antonio Rubio López; alias el Max; detenido en Sinaloa y cuál es su relación con el Mayo Zambada,,https://www.ambito.com/mexico/informacion-general/quien-es-edwin-antonio-rubio-lopez-alias-el-max-detenido-sinaloa-y-cual-es-su-relacion-el-mayo-zambada-n6073396
24-04-25-NOTA-30,2024-11-19,Estado de México,Huixquilucan,15037,Confirman 20 años de cárcel para El Indio; líder del Cártel de los Beltrán Leyva detenido en el Edomex,,https://www.infobae.com/mexico/2024/11/19/confirman-20-anos-de-carcel-para-el-indio-lider-del-cartel-de-los-beltran-leyva-detenido-en-el-edomex/
24-04-25-NOTA-31,2020-01-29,Coahuila,Torreón,5031,Quién es El Irakí; el enemigo público número 1 de Chihuahua señalado por la masacre de 21 personas este fin de semana,,https://www.infobae.com/america/mexico/2020/01/29/quien-es-el-iraki-el-enemigo-publico-numero-1-de-chihuahua-senalado-por-la-masacre-de-21-personas-este-fin-de-semana/
24-04-25-NOTA-32,2024-11-28,Estado de México,Cuautitlán Izcalli,15029,Procesan a El Buchanans involucrado en ataque a bar Bling Bling Edomex,,https://www.milenio.com/policia/procesan-a-el-buchanans-involucrado-en-ataque-a-bar-bling-bling-edomex
24-04-25-NOTA-33,2024-05-16,Ciudad de México,Tlalpan,9010,Así fue como autoridades aprehendieron a El Tortas; líder de la Fuerza Anti-Unión,,https://www.infobae.com/mexico/2024/05/16/asi-fue-como-autoridades-aprehendieron-a-el-tortas-lider-de-la-fuerza-anti-union/
24-04-25-NOTA-34,2023-12-25,Chihuahua,Chihuahua,8020,Dictan prisión preventiva a El Cumbias; líder de Gente Nueva del Cártel de Sinaloa,,https://www.infobae.com/mexico/2023/12/25/dictan-prision-preventiva-a-el-cumbias-lider-de-gente-nueva-del-cartel-de-sinaloa/
24-04-25-NOTA-35,2023-01-03,Chihuahua,Ciudad Juárez,8037,¿Quién es El Neto; líder de Los Mexicles de Ciudad Juárez?,,https://www.excelsior.com.mx/nacional/el-neto-lider-mexicles-ciudad-juarez/1561853
24-04-25-NOTA-36,2018-10-30,Ciudad de México,Xochimilco,9016,Unión Tepito: cae El Cabezas; presunto líder de Fuerza Anti Unión Tepito,,https://www.milenio.com/policia/union-tepito-detienen-cabezas-presunto-lider-fuerza-anti-union-tepito
24-04-25-NOTA-37,2020-01-29,Chihuahua,Nuevo Casas Grandes,8045,Detienen a autor intelectual de masacre de familia LeBarón,,https://www.noroeste.com.mx/nacional/detienen-a-autor-intelectual-de-masacre-de-familia-lebaron-KANO1215681
24-04-25-NOTA-38,2024-02-19,CDMX,Iztacalco,9006,Cae 'Pícoro'; líder del Cártel de Tláhuac; acusado de invadir casas y predios,,https://aristeguinoticias.com/1902/mexico/cae-picoro-lider-del-cartel-de-tlahuac-acusado-de-invadir-casas-y-predios/
24-04-25-NOTA-39,2024-02-20,CDMX,Cuauhtémoc,9002,Detienen a 11 miembros de escisión del cártel de Tláhuac; uno es el líder,,https://www.jornada.com.mx/2024/02/20/capital/028n1cap
24-04-25-NOTA-40,2025-04-23,CDMX,Venustiano Carranza,9015,Detienen líder célula CJNG cartel Jalisco Nueva Generacion en CDMX narcotrafico,,https://oem.com.mx/elsoldemexico/mexico/detienen-lider-celula-cjng-cartel-jalisco-nueva-generacion-en-cdmx-narcotrafico-16610370
24-04-25-NOTA-41,2019-08-21,Guerrero,Chilapa de Álvarez,12027,Detienen en Guerrero a Zenén Nava; El Chaparro; el otro líder de Los Rojos,,https://zetatijuana.com/2019/08/detienen-en-guerrero-a-zenen-nava-el-chaparro-el-otro-lider-de-los-rojos/
24-04-25-NOTA-42,2022-12-06,Estado de México,Nicolás Romero,15058,‘El Mirra’; uno de los criminales más buscados del Edomex; pasará el resto de su vida en prisión,,https://www.infobae.com/america/mexico/2022/12/06/el-mirra-uno-de-los-criminales-mas-buscados-del-edomex-pasara-el-resto-de-su-vida-en-prision/
24-04-25-NOTA-43,2024-04-09,CDMX,Xochimilco,9016,Vinculan a proceso a ‘El Cindy’; presunto líder del Cártel de Tláhuac,,https://www.jornada.com.mx/noticia/2024/04/09/capital/vinculan-a-proceso-a-2018el-cindy2019-presunto-lider-del-cartel-de-tlahuac-7722
24-04-25-NOTA-44,2024-04-18,Ciudad de México,Cuauhtémoc,9002,Cae integrante de La Unión Tepito identificado como El Yerson,,https://www.milenio.com/policia/cae-integrante-de-la-union-tepito-identificado-como-el-yerson
24-04-25-NOTA-45,2024-10-16,Ciudad de México,Cuauhtémoc,9002,Así es como la UIF y la SEIDO buscan acabar de raíz con La Unión Tepito en la CDMX,,https://www.infobae.com/mexico/2024/10/16/asi-es-como-la-uif-y-la-seido-buscan-acabar-de-raiz-con-la-union-tepito-en-la-cdmx/
21-04-25-OFAC-01,12/02/2022,Jalisco,Puente Grande,140000001,Juez concede suspensión provisional a El Elvis; cuñado de El Mencho; contra orden de captura,,https://www.eluniversal.com.mx/nacion/cjng-juez-concede-suspension-provisional-el-elvis-cunado-de-el-mencho-contra-orden-de-captura/
21-04-25-OFAC-02,09/08/2017,Jalisco,Guadalajara,140000001,EE.UU. incluye en lista ‘negra’ a nueve miembros de CJNG y Los Cuinis,,https://www.contramuro.com/ee-uu-incluye-en-lista-negra-a-nueve-miembros-de-cjng-y-los-cuinis/
21-04-25-OFAC-03,25/05/2017,Sinaloa,Choix,250060001,Cártel de los Ruelas Torres es incluido en lista negra,,https://www.debate.com.mx/mexico/Cartel-de-los-Ruelas-Torres--es-incluido-en-lista-negra-20170524-0294.html
21-04-25-OFAC-04,12/01/2024,Jalisco,Guadalajara,140000001,Condenan a 21 años de cárcel al mexicano Raúl Flores por narcotráfico en EU,,https://abcnoticias.mx/global/2024/1/12/condenan-21-anos-de-carcel-al-mexicano-raul-flores-por-narcotrafico-en-eu-207172.html
21-04-25-OFAC-05,09/08/2017,Jalisco,Guadalajara,140000001,El capo desconocido que enlodó a Márquez y a Álvarez,,https://zetatijuana.com/2017/08/el-capo-desconocido-que-enlodo-a-marquez-y-a-alvarez/
21-04-25-OFAC-06,10/08/2017,Ciudad de México,Ciudad de México,90000001,De muy bajo perfil; pero con alto poder,,https://www.reforma.com/de-muy-bajo-perfil-pero-con-alto-poder/ar1182209
21-04-25-OFAC-07,06/03/2018,Sinaloa,Guasave,250120001,EU sanciona a 8 personas y 8 empresas ligadas a grupo del narco Los Ruelas,,https://www.eluniversal.com.mx/nacion/seguridad/eu-sanciona-8-personas-y-8-empresas-ligadas-grupo-del-narco-los-ruelas/
21-04-25-OFAC-08,14/09/2017,Jalisco,Guadalajara,140390001,Tesoro de EU vincula a empresas e individuos con CJNG y los Cuinis,,https://www.elimparcial.com/mundo/2017/09/14/tesoro-de-eu-vincula-a-empresas-e-individuos-con-cjng-y-los-cuinis/
21-04-25-OFAC-09,12/05/2021,Sinaloa,Batamote,250250001,Quién es Chuy González Peñuelas y cómo es su vínculo con los Mazatlecos y Caro Quintero,,https://www.infobae.com/america/mexico/2021/05/13/quien-es-chuy-gonzalez-penuelas-y-cual-es-su-vinculo-con-los-mazatlecos-y-caro-quintero/
21-04-25-OFAC-10,12/05/2021,Sinaloa,Batamote,250250001,Jesús González Peñuelas narcotraficante mexicano Quién es y qué hizo,,https://www.milenio.com/policia/jesus-gonzalez-penuelas-narcotraficante-mexicano-quien-es-y-que-hizo
21-04-25-OFAC-11,14/09/2017,Jalisco,Guadalajara,140390001,EU sanciona a empresas ligadas a Los Cuinis y al CJNG,,https://www.zocalo.com.mx/eu-sanciona-a-empresas-ligadas-a-los-cuinis-y-al-cjng/
21-04-25-OFAC-12,25/12/2024,Ciudad de México,Polanco,90000001,Jesús Pérez Alvear promotor musical asesinado en Polanco y ligado al CJNG era testigo colaborador en EEUU,,https://www.infobae.com/mexico/2024/12/25/jesus-perez-alvear-promotor-musical-asesinado-en-polanco-y-ligado-al-cjng-era-testigo-colaborador-en-eeuu/
21-04-25-OFAC-13,06/03/2018,Sinaloa,Desconocido,250000000,Tesoro sanciona a 16 personas y empresas por tráfico de heroína desde México,,https://www.latimes.com/espanol/noticas-mas/articulo/2018-03-06/efe-3544534-13922709-20180306
21-04-25-OFAC-14,17/05/2019,Nayarit,Tepic,180390001,Esposa e hijos de Roberto Sandoval en la mira de EU por ser prestanombres,,https://www.eluniversal.com.mx/nacion/esposa-e-hijos-de-roberto-sandoval-en-la-mira-de-eu-por-ser-prestanombres/
21-04-25-OFAC-15,17/05/2019,Nayarit,Tepic,180390001,Lidy Alejandra quien es la hija del exgobernador de Nayarit Roberto Sandoval,,https://www.eluniversal.com.mx/nacion/lidy-alejandra-quien-es-la-hija-del-exgobernador-de-nayarit-roberto-sandoval/
21-04-25-OFAC-16,17/05/2019,Nayarit,Tepic,180390001,OFAC sanciona a Pablo Roberto Sandoval López por actuar en nombre de su padre,,https://home.treasury.gov/news/press-releases/sm692
21-04-25-OFAC-17,13/06/2023,Nayarit,Tepic,180390001,Fiscalía de Nayarit gira orden de aprehensión contra exgobernador Roberto Sandoval,,https://www.noroeste.com.mx/nacional/fiscalia-de-nayarit-gira-orden-de-aprehension-contra-ex-gobernador-roberto-sandoval-GANO1214534
21-04-25-OFAC-18,03/03/2024,Jalisco,Tecalitlán,140930001,Fiscalía Jalisco apunta a El Sapo por operar narcorrancho CJNG,,https://www.milenio.com/estados/fiscalia-jalisco-apunta-a-el-sapo-por-operar-narcorrancho-cjng
21-04-25-OFAC-19,10/01/2023,Jalisco,Guadalajara,140390001,Las mujeres dentro del Cártel de Jalisco Nueva Generación,,https://www.mural.com.mx/las-mujeres-dentro-del-cartel-de-jalisco-nueva-generacion/ar2055794
21-04-25-OFAC-20,10/10/2022,Sinaloa,Bacayopa,260530001,Adelmo Núñez Molina señalado por la DEA como miembro de González Peñuelas DTO,,https://www.dea.gov/es/node/214661
21-04-25-OFAC-21,12/10/2022,Sinaloa,Desconocido,260000000,El Tesoro identifica a mexicano traficante de narcóticos con sede en Sinaloa que ayuda a alimentar la epidemia de opioides en EEUU,,https://mx.usembassy.gov/es/el-tesoro-identifica-a-mexicano-traficante-de-narcoticos-con-sede-en-sinaloa-que-ayuda-a-alimentar-la-epidemia-de-opioides-en-los-estados-unidos/
21-04-25-OFAC-22,23/01/2024,Sinaloa,Mazatlán,260230001,Dónde está Lucio Rodríguez Serrano la mano derecha de Caro Quintero que EEUU anhela atrapar,,https://www.infobae.com/mexico/2024/01/23/donde-esta-lucio-rodriguez-serrano-la-mano-derecha-de-caro-quintero-que-eeuu-anhela-atrapar/
21-04-25-OFAC-23,23/01/2024,Sinaloa,Mazatlán,260230001,Lucio Rodríguez Serrano mano derecha de Caro Quintero,,https://www.excelsior.com.mx/nacional/lucio-rodriguez-serrano-mano-derecha-caro-quintero/1527472
21-04-25-OFAC-24,06/04/2021,Oregon,Desconocido,0,Cae presunto integrante de un cártel mexicano en Oregon,,https://kunptv.com/news/local/cae-presunto-integrante-de-un-crtel-mexicano-en-oregon
21-04-25-OFAC-25,06/04/2021,Jalisco,Guadalajara,140390001,Quién es Alejandro Chacón el supuesto agente de viajes del CJNG,,https://lasillarota.com/nacion/2021/4/6/quien-es-alejandro-chacon-el-supuesto-agente-de-viajes-del-cjng-274553.html
21-04-25-OFAC-26,01/03/2024,Jalisco,Guadalajara,140390001,Extraditan a Estados Unidos a El Escorpión miembro de alto rango del Cartel Jalisco Nueva Generacion,,https://oem.com.mx/eloccidental/policiaca/extraditan-a-estados-unidos-a-el-escorpion-miembro-de-alto-rango-del-cartel-jalisco-nueva-generacion-13149402
21-04-25-OFAC-27,21/08/2024,Colima,Colima,60010001,Dan prision preventiva a Aldrin Miguel El Chaparrito del CJNG que operaba en Colima,,https://www.infobae.com/mexico/2024/08/21/dan-prision-preventiva-a-aldrin-miguel-el-chaparrito-del-cjng-que-operaba-en-colima/
21-04-25-OFAC-28,20/08/2024,Colima,Colima,60010001,Quien es El Chaparrito y por que su detencion es un duro golpe para El Mencho y el CJNG,,https://www.infobae.com/mexico/2024/08/20/quien-es-el-chaparrito-y-por-que-su-detencion-es-un-duro-golpe-para-el-mencho-y-el-cjng/
21-04-25-OFAC-29,11/04/2024,Sinaloa,Culiacan,250060001,Cual es la falsa identidad de El Gigio jefe del Cartel de Sinaloa responsable del 44 por ciento de fentanilo enviado a EEUU,,https://www.infobae.com/mexico/2024/04/11/cual-es-la-falsa-identidad-de-el-gigio-jefe-del-cartel-de-sinaloa-responsable-del-44-de-fentanilo-enviado-a-eeuu/
21-04-25-OFAC-30,10/04/2024,Colima,Colima,60010001,Va EEUU contra jefes de plaza de los carteles de Sinaloa y Jalisco Nueva Generacion,,https://diariodecolima.com/noticias/detalle/2024-04-10-va-eeuu-contra-jefes-de-plaza-de-los-crteles-de-sinaloa-y-jalisco-nueva-generacin
21-04-25-OFAC-31,15/04/2024,Sonora,Nogales,260390001,EU investiga a presunto narcotraficante de El Mayo Zambada en Nogales Sonora,,https://oem.com.mx/elsoldemexico/mexico/eu-investiga-a-presunto-narcotraficante-de-el-mayo-zambada-en-nogales-sonora-16602836
21-04-25-OFAC-32,12/03/2024,Yucatan,Merida,310500001,Capturan en Yucatan a presunto lider del CJNG,,https://es-us.noticias.yahoo.com/capturan-yucatán-presunto-líder-cjng-125810811.html
21-04-25-OFAC-33,25/02/2025,Sinaloa,Culiacan,250060001,Extraditan a EEUU a presunto colaborador de Dona Lupe la lider de una grupo criminal ligado al Cartel de Sinaloa,,https://www.infobae.com/mexico/2025/02/25/extraditan-a-eeuu-a-presunto-colaborador-de-dona-lupe-la-lider-de-una-grupo-criminal-ligado-al-cartel-de-sinaloa/
21-04-25-OFAC-34,15/03/2024,Estados Unidos,Desconocido,0,Mexicana ligada al Cartel de Sinaloa se declara culpable en EU lideraba red de trafico de personas,,https://www.eluniversal.com.mx/mundo/mexicana-ligada-al-cartel-de-sinaloa-se-declara-culpable-en-eu-lideraba-red-de-trafico-de-personas/
21-04-25-OFAC-34,19/12/2024,Baja California,Mexicali,20020001,Doña Lupe se declaró culpable en EU de traficar miles de migrantes desde Mexicali,,https://www.enlineabc.com.mx/2024/12/19/dona-lupe-se-declaro-culpable-en-eu-de-traficar-miles-de-migrantes-desde-mexicali/
21-04-25-OFAC-35,19/12/2024,Ciudad de México,Ciudad de México,90000001,Sanción del Tesoro a importantes narcotraficantes ecuatoriano y mexicano con lazos al Cartel de Sinaloa y CJNG,,https://mx.usembassy.gov/es/sancion-del-tesoro-a-importantes-narcotraficantes-ecuatoriano-y-mexicano-con-lazos-al-cartel-de-sinaloa-y-cartel-jalisco-nueva-generacion/
21-04-25-OFAC-36,19/12/2024,Ciudad de México,Ciudad de México,90000001,Ella es la mexicana que se declaró culpable de tráfico de personas en EU,,https://lasillarota.com/nacion/2024/12/19/ella-es-la-mexicana-que-se-declaro-culpable-de-trafico-de-personas-en-eu-515142.html
21-04-25-OFAC-37,19/10/2022,Sinaloa,Culiacán,250060001,EU va contra red de fentanilo de Juan Francisco Valenzuela operador del Cartel de Sinaloa,,https://www.proceso.com.mx/nacional/2022/10/19/eu-va-contra-red-de-fentanilo-de-juan-francisco-valenzuela-operador-del-cartel-de-sinaloa-295397.html
21-04-25-OFAC-38,02/06/2022,Ciudad de México,Ciudad de México,90000001,Tesoro sanciona a importante red de transportistas de drogas del Cartel de Sinaloa,,https://mx.usembassy.gov/es/tesoro-sanciona-a-importante-red-de-transportistas-de-drogas-del-cartel-de-sinaloa/
21-04-25-OFAC-39,02/06/2022,Ciudad de México,Ciudad de México,90000001,Congelan activos a cabecillas de célula de Cartel de Sinaloa,,https://www.reforma.com/congelan-activos-a-cabecillas-de-celula-de-cartel-de-sinaloa/ar2489189
21-04-25-OFAC-40,15/06/2022,Jalisco,Guadalajara,140390001,Quién es El Rey Mago el jefe policial señalado en EEUU por vínculos con el CJNG,,https://www.infobae.com/america/mexico/2022/06/15/quien-es-el-rey-mago-el-jefe-policial-senalado-en-eeuu-por-vinculos-con-el-cjng/
21-04-25-OFAC-41,01/09/2024,Jalisco,Guadalajara,140390001,Sentencian a El Moy miembro del CJNG vinculado al asesinato del exgobernador Aristóteles Sandoval,,https://www.infobae.com/mexico/2024/09/01/sentencian-a-el-moy-miembro-del-cjng-vinculado-al-asesinato-del-exgobernador-aristoteles-sandoval/
21-04-25-OFAC-42,01/04/2024,Jalisco,Guadalajara,140390001,CJNG ocho brazos armados y una estructura casi intacta,,https://contralinea.com.mx/interno/semana/cjng-ocho-brazos-armados-y-una-estructura-casi-intacta/
21-04-25-OFAC-43,02/06/2022,Ciudad de México,Ciudad de México,90000001,EU incluye en lista negra a seis mexicanos acusados de nexos con CJNG,,https://www.jornada.com.mx/notas/2022/06/02/politica/eu-incluye-en-lista-negra-a-seis-mexicanos-acusados-de-nexos-con-cjng/
21-04-25-OFAC-44,02/06/2022,Ciudad de México,Ciudad de México,90000001,EU México imponen sanciones a miembros del CJNG y un policía municipal,,https://www.proceso.com.mx/nacional/2022/6/2/eu-mexico-imponen-sanciones-miembros-del-cjng-un-policia-municipal-286929.html
21-04-25-OFAC-45,24/09/2024,Ciudad de México,Ciudad de México,90000001,Detecta EU nieves y farmacia Cartel Sinaloa,,https://www.eleconomista.com.mx/politica/detecta-eu-nieves-y-farmacia-cartel-sinaloa-20240924-727127.html
21-04-25-OFAC-46,11/11/2023,Sonora,Nogales,260390001,Funcionario de Nogales vinculado al Cartel de Sinaloa es investigado por la FGR fue acusado por EEUU,,https://www.infobae.com/mexico/2023/11/11/funcionario-de-nogales-vinculado-al-cartel-de-sinaloa-es-investigado-por-la-fgr-fue-acusado-por-eeuu/
21-04-25-OFAC-47,07/11/2023,Sinaloa,Culiacán,250060001,Quiénes son los Morgan Huerta el clan familiar del Cartel de Sinaloa que trafica fentanilo a EEUU,,https://www.infobae.com/mexico/2023/11/07/quienes-son-los-morgan-huerta-el-clan-familiar-del-cartel-de-sinaloa-que-trafica-fentanilo-a-eeuu/
21-04-25-OFAC-48,07/11/2023,Sinaloa,Culiacán,250060001,EEUU sanciona a empresas y miembros del Cartel de Sinaloa por tráfico de fentanilo,,https://www.swissinfo.ch/spa/ee-uu-sanciona-a-empresas-y-miembros-del-c%C3%A1rtel-de-sinaloa-por-tr%C3%A1fico-de-fentanilo/48959952
21-04-25-OFAC-49,20/02/2024,Sonora,Nogales,260390001,Ficha EU a funcionario de Nogales por tráfico de fentanilo,,https://www.reforma.com/ficha-eu-a-funcionario-de-nogales-por-trafico-de-fentanilo/ar2707368
21-04-25-OFAC-50,08/11/2023,Sonora,Hermosillo,260300001,EU sanciona a cuatro empresas de Sonora y a 13 presuntos miembros del Cártel de Sinaloa por tráfico de fentanilo,,https://aristeguinoticias.com/0811/mexico/eu-sanciona-a-cuatro-empresas-de-sonora-y-a-13-presuntos-miembros-del-cartel-de-sinaloa-por-trafico-de-fentanilo/
21-04-25-OFAC-51,06/06/2023,Jalisco,Guadalajara,140390001,EEUU sancionó a traficantes de armas y una empresa mexicana que lavaba dinero para el CJNG,,https://www.infobae.com/mexico/2023/06/06/eeuu-sanciono-a-traficantes-de-armas-y-una-empresa-mexicana-que-lavaba-dinero-para-el-cjng/
21-04-25-OFAC-52,02/05/2024,Ciudad de México,Ciudad de México,90000001,Cártel de Sinaloa Quién es El Flaco el principal operador de El Mayo Zambada en la CDMX,,https://www.infobae.com/mexico/2024/05/02/cartel-de-sinaloa-quien-es-el-flaco-el-principal-operador-de-el-mayo-zambada-en-la-cdmx/
21-04-25-OFAC-53,31/01/2023,Sonora,Hermosillo,260300001,Dos mexicanos a la lista negra de EU por tráfico de fentanilo Quiénes son,,https://www.elfinanciero.com.mx/nacional/2023/01/31/dos-mexicanos-a-la-lista-negra-de-eu-por-trafico-de-fentanilo-quienes-son/
21-04-25-OFAC-54,17/11/2023,Jalisco,Guadalajara,140390001,Estados Unidos sanciona a jalisciense por traficar armas para el CJNG pesan sobre él 22 cargos relacionados a ese delito,,https://oem.com.mx/eloccidental/policiaca/estados-unidos-sanciona-a-jalisciense-por-traficar-armas-para-el-cjng-pesan-sobre-el-22-cargos-relacionados-a-ese-delito-15746888
21-04-25-OFAC-55,21/11/2024,Sinaloa,Culiacán,250060001,Revelan investigación de la FGR contra Joaquín Guzmán López y su red para traficar precursores químicos,,https://www.infobae.com/mexico/2024/11/21/revelan-investigacion-de-la-fgr-contra-joaquin-guzman-lopez-y-su-red-para-traficar-precursores-quimicos/
22-04-25-OFAC-01,2023-04-14,Sinaloa,Culiacán,25006,EEUU sanciona a seis mexicanos por tráfico de metanfetaminas y fentanilo,,https://www.swissinfo.ch/spa/eeuu-sanciona-a-seis-mexicanos-por-tr%C3%A1fico-de-metanfetaminas-y-fentanilo/48307396
22-04-25-OFAC-02,2023-05-09,Sinaloa,Culiacán,25006,Quiénes son los socios de Los Chapitos que sancionó EEUU por el trasiego de drogas sintéticas,,https://www.infobae.com/mexico/2023/05/09/quienes-son-los-socios-de-los-chapitos-que-sanciono-eeuu-por-el-trasiego-de-drogas-sinteticas/
22-04-25-OFAC-03,2023-08-16,Veracruz,Vega de Alatorre,30192,Mary Cruz Rodríguez Aguirre dejó la política para lavar dinero para el CJNG,,https://www.univision.com/noticias/narcotrafico/mary-cruz-rodriguez-aguirre-dejo-politica-lavar-dinero-cartel-jalisco-nueva-generacion-cjng
22-04-25-OFAC-04,2023-10-24,Jalisco,Puerto Vallarta,14067,EEUU sanciona empresas del CJNG que operan desde Puerto Vallarta,,https://www.meganoticias.mx/los-mochis/noticia/eeuu-sanciona-empresas-del-cjng-que-operan-desde-puerto-vallarta/419467
22-04-25-OFAC-05,2023-12-14,Sonora,Sin dato,26000,Sanciona EU a organización criminal vinculada al Cártel de Sinaloa,,https://www.jornada.com.mx/noticia/2023/12/14/politica/sanciona-eu-a-organizacion-criminal-vinculada-al-cartel-de-sinaloa-6223
22-04-25-OFAC-06,2024-12-15,Baja California,Mexicali,2002,Doña Lupe pollera de Mexicali ligada al Cártel de Sinaloa se declara culpable en EU,,https://zetatijuana.com/2024/12/dona-lupe-pollera-de-mexicali-ligada-al-cartel-de-sinaloa-se-declara-culpable-en-eu/
22-04-25-OFAC-07,2023-04-27,Jalisco,Puerto Vallarta,14067,Estados Unidos incluye en lista negra a siete personas ligadas al CJNG,,https://cntamaulipas.mx/2023/04/27/estados-unidos-incluye-en-lista-negra-a-siete-personas-ligadas-al-cjng/
22-04-25-OFAC-08,2024-11-21,Sinaloa,Culiacán,25006,Joaquín Guzmán López el narcojunior que dio la estocada final al Cártel de Sinaloa,,https://www.infobae.com/mexico/2024/11/21/joaquin-guzman-lopez-el-narcojunior-que-dio-la-estocada-final-al-cartel-de-sinaloa/
22-04-25-OFAC-09,2023-05-10,Sinaloa,Culiacán,25006,Estados Unidos sancionó al hijo del Chapo Guzmán y miembros del Cártel de Sinaloa,,https://www.france24.com/es/ee-uu-y-canad%C3%A1/20230510-estados-unidos-sancion%C3%B3-al-hijo-del-chapo-guzm%C3%A1n-y-miembros-del-c%C3%A1rtel-de-sinaloa
22-04-25-OFAC-10,2023-06-22,Chihuahua,Chihuahua,8026,Mexpacking la empresa de los Chapitos para producir fentanilo con máquinas de prensas,,https://www.univision.com/noticias/narcotrafico/mexpacking-empresa-chapitos-produccion-fentanilo-maquinas-prensas-cartel-sinaloa
22-04-25-OFAC-11,2023-05-30,Jalisco,Puerto Vallarta,14067,El CJNG recurre a las estafas con los tiempos compartidos alerta Estados Unidos,,https://www.proceso.com.mx/nacional/estados/2023/5/30/el-cjng-recurre-las-estafas-con-los-tiempos-compartidos-alerta-estados-unidos-307937.html
22-04-25-OFAC-12,2023-06-15,Guerrero,Sin dato,12000,El Tesoro sanciona a narcotraficante afiliado con La Nueva Familia Michoacana,,https://mx.usembassy.gov/es/el-tesoro-sanciona-narcotraficante-afiliada-con-la-nueva-familia-michoacana/
22-04-25-OFAC-13,2023-11-30,Sinaloa,Culiacán,25006,Por qué Óscar Noe Medina El Panu miembro del Cártel de Sinaloa es el próximo objetivo de EU,,https://www.elfinanciero.com.mx/nacional/2023/11/30/por-que-oscar-noe-medina-el-panu-miembro-del-cartel-de-sinaloa-es-el-proximo-objetivo-de-eu/
22-04-25-OFAC-14,2025-04-04,Ciudad de México,Tlalpan,9010,Albergó al Chapo Guzmán en su primera fuga y fue socio del Mayo Zambada el perfil criminal de Leo,,https://www.infobae.com/mexico/2025/04/04/albergo-al-chapo-guzman-en-su-primera-fuga-y-fue-socio-del-mayo-zambada-el-perfil-criminal-de-leo/
22-04-25-OFAC-15,2024-08-18,Sinaloa,Elota,25008,Quién era Martin García Corrales exsocio del Mayo Zambada que habría sido ejecutado al sur de Sinaloa,,https://www.infobae.com/mexico/2024/08/18/quien-era-martin-garcia-corrales-exsocio-del-mayo-zambada-que-habria-sido-ejecutado-al-sur-de-sinaloa/
22-04-25-OFAC-16,2024-11-05,Sinaloa,Culiacán,25006,Extraditan a El Nini EU lo procesará por tráfico de fentanilo,,https://emeequis.com/al-dia/extraditan-a-el-nini-estados-unidos-lo-procesara-por-trafico-de-fentanilo/
22-04-25-OFAC-17,2024-09-22,Sinaloa,Culiacán,25006,Humberto Figueroa La Perris El 27 sicario de Los Chapitos escapa por una alcantarilla en Culiacán,,https://www.elfinanciero.com.mx/nacional/2024/09/22/humberto-figueroa-la-perris-el-27-quien-es-sicario-de-los-chapitos-escapa-por-una-alcantarilla-en-culiacan/
22-04-25-OFAC-18,2025-02-07,Sinaloa,Culiacán,25006,Qué se sabe de Samuel León Alvarado operador de los Chapitos cuya casa habría sido incendiada en Culiacán,,https://www.infobae.com/mexico/2025/02/07/que-se-sabe-de-samuel-leon-alvarado-operador-de-los-chapitos-cuya-casa-habria-sido-incendiada-en-culiacan/
22-04-25-OFAC-19,2023-12-20,Sinaloa,Culiacán,25006,EEUU vs Cártel de Sinaloa DEA ofrece más de mil 200 mdp por la captura de 18 líderes y operadores,,https://www.infobae.com/mexico/2023/12/20/eeuu-vs-cartel-de-sinaloa-dea-ofrece-mas-de-mil-200-mdp-por-la-captura-de-18-lideres-y-operadores/
22-04-25-OFAC-20,2023-08-13,Sinaloa,Culiacán,25006,EU liga a exdirector del Hospital General de Culiacán con Los Chapitos y es líder sindical,,https://aristeguinoticias.com/1308/investigaciones-especiales/eu-liga-a-exdirector-del-hospital-general-de-culiacan-con-los-chapitos-y-es-lider-sindical/
22-04-25-OFAC-21,2023-07-15,Sinaloa,Culiacán,25006,EU sanciona red ilícita de fentanilo dirigida por familiares cercanos de Los Chapitos y El Chapo,,https://zetatijuana.com/2023/07/eu-sanciona-red-ilicita-de-fentanilo-dirigida-por-familiares-cercanos-de-los-chapitos-y-el-chapo/
22-04-25-OFAC-22,2024-04-18,Sinaloa,Culiacán,25006,EU sanciona a familiares de Los Chapitos por tráfico de fentanilo,,https://oem.com.mx/elsoldemexico/mexico/eu-sanciona-a-familiares-de-los-chapitos-por-trafico-de-fentanilo-16608329
22-04-25-OFAC-23,2024-04-16,Estado de México,Calimaya,15018,Asesinan a El Kastor presunto operador de Los Chapitos,,https://www.eluniversal.com.mx/metropoli/asesinan-a-el-kastor-presunto-operador-de-los-chapitos-eu-ofrecia-recompensa-de-un-millon-de-dolares-por-su-captura/
22-04-25-OFAC-24,2024-04-10,Sinaloa,Culiacán,25006,Tesoro actúa contra operaciones de tráfico de fentanilo del Cártel de Sinaloa y líder colombiano,,https://cl.usembassy.gov/es/tesoro-actua-contra-operaciones-de-trafico-de-fentanilo-del-cartel-de-sinaloa-y-contra-lider-de-cartel-colombiano/
22-04-25-OFAC-25,2023-11-30,Jalisco,Puerto Vallarta,14067,EU sanciona por fraude mediante tiempos compartidos en Puerto Vallarta,,https://latinus.us/eu/2023/11/30/eu-sanciona-por-fraude-mediante-tiempos-compartidos-en-puerto-vallarta-tres-mexicanos-13-empresas-102475.html
22-04-25-OFAC-26,2023-12-07,Ciudad de México,Ciudad de México,9000,Quién es El Músico vinculado a los Beltrán Leyva y sancionado por EE.UU.,,https://lasillarota.com/nacion/2023/12/7/quien-es-el-musico-vinculado-los-beltran-leyva-sancionado-por-estados-unidos-460210.html
22-04-25-OFAC-27,2024-01-20,Jalisco,Guadalajara,14039,Estados Unidos boletina a presunta red familiar de los Beltrán Leyva en Sinaloa,,https://oem.com.mx/elsoldesinaloa/local/estados-unidos-boletina-a-presunta-red-familiar-de-los-beltran-leyva-en-sinaloa-13289564
22-04-25-OFAC-28,2023-12-06,Ciudad de México,Ciudad de México,9000,Golpe a los Beltrán Leyva EEUU sanciona a jefes de plaza y traficantes,,https://www.infobae.com/mexico/2023/12/06/golpe-a-los-beltran-leyva-eeuu-sanciona-a-empresas-jefes-de-plaza-y-traficantes-de-drogas/
22-04-25-OFAC-29,2023-12-26,Sinaloa,Culiacán,25006,Por qué las autoridades de EEUU apodaron Methzilla a un cargamento de drogas ligado a los Beltrán Leyva,,https://www.infobae.com/mexico/2023/12/26/por-que-las-autoridades-de-eeuu-apodaron-methzilla-a-un-cargamento-de-drogas-ligado-a-los-beltran-leyva/
22-04-25-OFAC-30,2023-12-06,Ciudad de México,Ciudad de México,9000,Golpe a los Beltrán Leyva EEUU sanciona a jefes de plaza y traficantes de drogas,,https://www.infobae.com/mexico/2023/12/06/golpe-a-los-beltran-leyva-eeuu-sanciona-a-empresas-jefes-de-plaza-y-traficantes-de-drogas/
22-04-25-OFAC-31,2024-10-31,Chihuahua,Ciudad Juárez,8037,Quién es Josefa Carrasco Leyva la Wera de Palenque sancionada por el Tesoro de EEUU por vínculos con La Línea,,https://www.infobae.com/mexico/2024/10/31/quien-es-josefa-carrasco-leyva-la-wera-de-palenque-mujer-sancionada-por-el-departamento-del-tesoro-de-eeuu-por-vinculos-con-la-linea/
22-04-25-OFAC-32,2024-06-06,Sinaloa,Culiacán,25006,Quiénes son los más jóvenes en la cúpula del Cártel de Sinaloa según EEUU,,https://www.infobae.com/mexico/2024/06/06/quienes-son-los-mas-jovenes-en-la-cupula-del-cartel-de-sinaloa-segun-eeuu/
22-04-25-OFAC-33,2024-03-24,Durango,Sierra,10033,Quién es El Güero de las Trancas operador de Los Chapitos que controla laboratorios de fentanilo,,https://www.infobae.com/mexico/2024/03/24/quien-es-el-guero-de-las-trancas-el-operador-de-los-chapitos-que-controla-laboratorios-de-fentanilo/
22-04-25-OFAC-34,2024-03-25,Sinaloa,Culiacán,25006,Quiénes son los operadores de El Mayo Zambada y El Chapo Isidro sancionados por EEUU,,https://www.infobae.com/mexico/2024/03/25/quienes-son-los-operadores-de-el-mayo-zambada-y-el-chapo-isidro-sancionados-por-eeuu/
22-04-25-OFAC-35,2024-03-22,Sonora,San Luis Río Colorado,26055,Así es como el Cártel de Sinaloa lava las ganancias del tráfico de fentanilo a través de equipos celulares,,https://www.infobae.com/mexico/2024/03/22/asi-es-como-el-cartel-de-sinaloa-lava-las-ganancias-del-trafico-de-fentanilo-a-traves-de-equipos-celulares/
22-04-25-OFAC-36,2024-07-03,Guerrero,Zihuatanejo,12094,Quién es Don José alto mando de La Nueva Familia Michoacana por quien el CJNG ofrecía 5 millones de pesos,,https://www.infobae.com/mexico/2024/07/03/quien-es-don-jose-alto-mando-de-la-nueva-familia-michoacana-por-quien-el-cjng-ofrecia-5-millones-de-pesos/
22-04-25-OFAC-37,2024-06-26,Ciudad de México,Ciudad de México,9000,Quién es El Tuerto jefe de El Comandante Pecha de La Familia Michoacana detenido en el Edomex,,https://www.infobae.com/mexico/2024/06/26/quien-es-el-tuerto-jefe-de-el-comandante-pecha-de-la-familia-michoacana-detenido-en-el-edomex/
22-04-25-OFAC-38,2024-06-20,Michoacán,Sin dato,16000,Estados Unidos sanciona a líderes del cártel La Nueva Familia Michoacana,,https://www.debate.com.mx/mundo/Estados-Unidos-sanciona-a-lideres-del-cartel-La-Nueva-Familia-Michoacana-20240620-0158.html
28-04-25-NOTA-01,2025-04-28,Zacatecas,Apulco,32004,Piden desafuero al alcalde de Zacatecas ligado al CJNG,,https://www.milenio.com/policia/piden-desafuero-alcalde-zacatecas-ligado-cjng
28-04-25-NOTA-02,2025-04-28,Chihuahua,Ciudad Juárez,8037,Detuvieron al Abuelo jefe de plaza del Cártel del Noreste en Coahuila Nuevo León y Zacatecas,,https://www.infobae.com/america/mexico/2022/01/23/detuvieron-al-abuelo-jefe-de-plaza-del-cartel-del-noreste-en-coahuila-nuevo-leon-y-zacatecas/
28-04-25-NOTA-03,2025-04-28,Jalisco,Tequila,14093,Vincularon a proceso al F25 jefe de plaza del CJNG en Zacatecas y Jalisco,,https://www.infobae.com/america/mexico/2022/12/21/vincularon-a-proceso-al-f25-jefe-de-plaza-del-cjng-en-zacatecas-y-jalisco/
28-04-25-NOTA-04,2025-04-28,Estado de México,,,Quién es El Guerito líder del CJNG que trafica fentanilo y tiene vínculos con El Jardinero,,https://www.infobae.com/mexico/2024/07/24/quien-es-el-guerito-lider-del-cjng-que-trafica-fentanilo-y-tiene-vinculos-con-el-jardinero/
28-04-25-NOTA-05,2025-04-28,Ciudad de México,,,El Mudo narco del Cártel de Sinaloa que distribuía metanfetamina en EEUU fue detenido y extraditado,,https://www.infobae.com/america/mexico/2023/01/01/el-mudo-narco-del-cartel-de-sinaloa-quien-distribuia-metanfetamina-en-eeuu-fue-detenido-y-extraditado/
28-04-25-NOTA-06,2025-04-28,Estado de México,,,Quién es El Tilico presunta cabecilla del CJNG que fue detenido después de amenazar a una periodista,,https://www.infobae.com/mexico/2023/12/22/quien-es-el-tilico-presunta-cabecilla-del-cjng-que-fue-detenido-despues-de-amenazar-a-una-periodista/
28-04-25-NOTA-07,2025-04-28,Aguascalientes,Rincón de Romos,1009,Ejército y Guardia Nacional capturan a cabecilla del CJNG,,https://www.heraldo.mx/ejercito-y-guardia-nacional-capturan-a-cabecilla-del-c-j/
28-04-25-NOTA-08,2025-04-28,Aguascalientes,Rincón de Romos,1009,Procesan a El Kike del CJNG amenazas a periodista Aguascalientes,,https://www.excelsior.com.mx/nacional/procesan-el-kike-cjng-amenazas-periodista-aguascalientes/1655693
28-04-25-NOTA-09,2025-04-28,Colima,,,En qué zonas de Colima opera El Chorro yerno de El Mencho que ha librado la prisión dos veces,,https://www.infobae.com/mexico/2024/04/16/en-que-zonas-de-colima-opera-el-chorro-yerno-de-el-mencho-que-ha-librado-la-prision-dos-veces/
28-04-25-NOTA-10,2025-04-28,Nayarit,,,Capturan en Nayarit al F1 operaba en Zacatecas,,https://oem.com.mx/la-prensa/mexico/capturan-en-nayarit-al-f1-operaba-en-zacatecas-15482199
28-04-25-NOTA-11,2025-04-28,Zacatecas,,,Batalla en Zacatecas por pacto Jalisco Golfo,,https://laopiniondemexico.mx/batalla-en-zacatecas-por-pacto-jalisco-golfo-2/
28-04-25-NOTA-12,2020-11-03,Guanajuato,,,Capturan a El Yeyo sicario de El Marro que se fue con el CJNG,,https://lasillarota.com/guanajuato/estado/2020/11/3/capturan-el-yeyo-sicario-de-el-marro-que-se-fue-con-el-cjng-253100.html
28-04-25-NOTA-13,2012-09-03,Zacatecas,Guadalupe,32022,Detienen a El Cochiloco jefe de plaza de Los Zetas,,https://www.excelsior.com.mx/2012/09/03/nacional/857072
28-04-25-NOTA-14,2023-11-29,Tamaulipas,Nuevo Laredo,28025,Detienen en Nuevo Laredo a El Tartas jefe de plaza del Cártel del Noreste,,https://www.jornada.com.mx/noticia/2023/11/29/politica/detienen-en-nuevo-laredo-a-el-tartas-jefe-de-plaza-del-cartel-del-noreste-7089
28-04-25-NOTA-15,2016-05-04,Jalisco,Zapopan,14066,PGR detiene a José Pineda El Avispón del CJNG,,https://www.eleconomista.com.mx/ultimas-noticias/PGR-detiene-Jose-Pineda--El-Avispon-del-CJNG-20160504-0199.html
28-04-25-NOTA-16,2022-04-01,Puebla,Amozoc,21015,El Pino del CJNG fue detenido por el asesinato de un periodista veracruzano,,https://www.infobae.com/america/mexico/2022/04/01/el-pino-del-cjng-fue-detenido-por-el-asesinato-de-un-periodista-veracruzano/
28-04-25-NOTA-17,2025-04-27,Veracruz,,,Detienen en Veracruz a El Comandante Meca miembro del CJNG y a El Gordo,,https://lopezdoriga.com/entretenimiento/mana-queda-fuera-salon-fama-rock-roll-2025-agradecen-historica-nominacion/
28-04-25-NOTA-18,2025-04-04,Tabasco,Cárdenas,27003,Quién es La Geisha operador del CJNG detenido en Cárdenas Tabasco,,https://www.infobae.com/mexico/2025/04/04/quien-es-la-geisha-operador-del-cjng-detenido-en-cardenas-tabasco/
28-04-25-NOTA-19,2025-03-25,Jalisco,Santa María del Oro,14078,Condenan a 11 integrantes del CJNG a 18 años de prisión por atacar al Ejército en 2022,,https://www.infobae.com/mexico/2025/03/25/condenan-a-11-integrantes-del-cjng-a-18-anos-de-prision-por-atacar-al-ejercito-en-2022/
28-04-25-NOTA-20,2025-04-25,Veracruz,Omealca,30111,Captura SSP a Gregorio alias Wester jefe de plaza del CJNG de los 10 más buscados,,https://www.excelsior.com.mx/nacional/captura-ssp-a-gregorio-alias-wester-jefe-de-plaza-del-cjng-de-los-10-mas-buscados-en
28-04-25-NOTA-21,2019-02-11,Coahuila,Saltillo,5029,Cae El Tucán Zeta ligado a desapariciones en Piedras Negras,,https://www.excelsior.com.mx/nacional/cae-el-tucan-zeta-ligado-a-desapariciones-en-piedras-negras/1301825
28-04-25-NOTA-22,2025-04-20,Veracruz,,,Quién es El Comandante 80 el ex policía que se unió al CJNG,,https://vanguardia.com.mx/noticias/nacional/quien-es-el-comandante-80-el-ex-policia-que-se-unio-al-cartel-jalisco-nueva-generacion-y-es-NRVG3454779
28-04-25-NOTA-23,2020-04-30,Veracruz,Tlalnehuayocan,30158,Detuvieron a La Cuija jefe de plaza del CJNG en el sur de Veracruz,,https://www.infobae.com/america/mexico/2020/04/30/detuvieron-a-la-cuija-jefe-de-plaza-del-cjng-en-el-sur-de-veracruz/
28-04-25-NOTA-24,2020-04-30,Veracruz,Coatzacoalcos,30021,El 50 presunto jefe de plaza del CJNG en Coatzacoalcos y ligado a masacre en un bar es detenido,,https://www.noroeste.com.mx/nacional/el-50-presunto-jefe-de-plaza-del-cjng-en-coatzacoalcos-y-ligado-a-masacre-en-un-bar-es-detenido-por-la-marina-KTNO1183786
28-04-25-NOTA-25,2025-04-27,Ciudad de México,,,Detienen a El Cabezón líder de La Unión Tepito y generador de violencia en CDMX,,https://www.nmas.com.mx/ciudad-de-mexico/detienen-a-el-cabezon-lider-de-la-union-tepito-y-generador-de-violencia-en-cdmx/
28-04-25-NOTA-26,2021-10-20,Ciudad de México,Cuauhtémoc,9002,Así fue la captura en Garibaldi de El Rex líder de Los Hades y cabecilla del CJNG,,https://www.infobae.com/america/mexico/2021/10/20/asi-fue-la-captura-en-garibaldi-del-rex-lider-de-los-hades-y-cabecilla-del-cjng/
28-04-25-NOTA-27,2022-09-13,Veracruz,Orizaba,30111,El Momo líder criminal que el gobierno liga a balacera en Orizaba,,https://lasillarota.com/veracruz/estado/2022/9/13/el-momo-lider-criminal-que-el-gobierno-liga-balacera-en-orizaba-392522.html
28-04-25-NOTA-28,2023-06-01,Veracruz,,,Sentenciaron con 34 años de cárcel al Comandante Kalim jefe de plaza de Los Zetas en Veracruz,,https://www.infobae.com/mexico/2023/06/01/setenciaron-con-34-anos-de-carcel-al-comandante-kalim-jefe-de-plaza-de-los-zetas-en-veracruz/
28-04-25-NOTA-29,2025-03-01,Veracruz,,,Quién es El Compa Playa narco enviado a EU tenía un amparo y había librado la justicia en varias ocasiones,,https://www.elfinanciero.com.mx/nacional/2025/03/01/quien-es-el-compa-playa-narco-enviado-a-eu-tenia-un-amparo-y-habia-librado-la-justicia-en-varias-ocasiones/
28-04-25-NOTA-30,2023-01-08,Nuevo León,San José de las Boquillas,,Detuvieron a El Gato jefe regional de los Beltrán Leyva en Nuevo León era buscado por el FBI,,https://www.infobae.com/america/mexico/2023/01/08/detuvieron-a-el-gato-jefe-regional-de-los-beltran-leyva-en-nuevo-leon-era-buscado-por-el-fbi/
28-04-25-NOTA-31,2018-05-23,Nuevo León,,,Cae El Mon operador financiero de los Beltrán Leyva,,https://lasillarota.com/estados/2018/5/23/cae-el-mon-operador-financiero-de-los-beltran-leyva-159438.html
28-04-25-NOTA-32,2020-12-15,Veracruz,Pueblo Viejo,30073,El Cuñado quien es el peligroso operador del Cártel del Golfo sentenciado a 544 años de prisión,,https://www.infobae.com/america/mexico/2020/12/15/el-cunado-quien-es-el-peligroso-operador-del-cartel-del-golfo-sentenciado-a-544-anos-de-prision/
28-04-25-NOTA-33,2022-02-09,Tamaulipas,Reynosa,28032,El Barbas líder del Cártel del Golfo fue condenado a 20 años de cárcel,,https://www.infobae.com/america/mexico/2022/02/09/el-barbas-lider-del-cartel-del-golfo-fue-condenado-a-20-anos-de-carcel/
28-04-25-NOTA-34,2025-03-06,Estado de México,Atizapán de Zaragoza,15012,Socialitos operador financiero de los Beltrán Leyva se declara no culpable en EEUU,,https://www.infobae.com/mexico/2025/03/06/socialitos-operador-financiero-de-los-beltran-leyva-se-declara-no-culpable-en-eeuu/
29-04-25-NOTA-01,2012-01-27,Jalisco,Zapopan,14066,Detienen en Jalisco a El Güero Abundio,,https://www.eleconomista.com.mx/ultimas-noticias/Detienen-en-Jalisco-a-El-Guero-Abundio-20120127-0035.html
29-04-25-NOTA-02,2021-02-06,Nayarit,Compostela,18007,Detienen al M3 presunto líder del CJNG en Nayarit,,https://www.excelsior.com.mx/nacional/detienen-al-m3-presunto-lider-del-cjng-en-nayarit/1438926
29-04-25-NOTA-03,2021-05-06,Nayarit,Compostela,18007,Vincularon a proceso a tres miembros del CJNG entre ellos El M3 presunto lugarteniente del Mencho en Nayarit,,https://www.infobae.com/america/mexico/2021/05/06/vincularon-a-proceso-a-tres-miembros-del-cjng-entre-ellos-el-m3-presunto-lugarteniente-del-mencho-en-nayarit/
29-04-25-NOTA-04,2025-04-29,Estado de México,Toluca,15093,Detienen a 27 presuntos miembros de la Nueva Familia Michoacana en Toluca,,https://www.noroeste.com.mx/nacional/detienen-a-27-presuntos-miembros-de-la-familia-BCNO214041
29-04-25-NOTA-05,2025-04-29,Nayarit,,,Caen cuatro presuntos integrantes del Cártel de Sinaloa en Nayarit,,https://www.noroeste.com.mx/nacional/caen-cuatro-presuntos-integrantes-del-cartel-de-sinaloa-KPNO975690
29-04-25-NOTA-06,2020-09-22,Nayarit,Bahía de Banderas,18009,Juez vincula a proceso a El Manotas presunto líder del CJNG en Vallarta,,https://www.eleconomista.com.mx/politica/Juez-vincula-a-proceso-a-El-Manotas-presunto-lider-del-CJNG-en-Vallarta-20200922-0062.html
29-04-25-NOTA-07,2025-04-29,Jalisco,Tlajomulco de Zúñiga,14098,Detienen en Jalisco a compadre de El Mencho líder del CJNG,,https://www.elfinanciero.com.mx/nacional/detienen-en-jalisco-a-compadre-de-el-mencho-lider-del-cjng/
29-04-25-NOTA-08,2025-04-29,Nayarit,Bahía de Banderas,18009,Caen 18 por asesinato de 2 agentes en Nayarit,,https://www.milenio.com/policia/caen-18-asesinato-2-agentes-nayarit
29-04-25-NOTA-09,2025-04-29,Sinaloa,Los Mochis,25017,Cae otro integrante de la banda Los Mazatlecos,,https://www.noroeste.com.mx/seguridad/cae-otro-integrante-de-la-banda-los-mazatlecos-AGNO346879
29-04-25-NOTA-10,2025-04-29,Sinaloa,Culiacán,25006,Recapturan a integrante del Cártel de Sinaloa,,https://www.elsoldenayarit.mx/nota-roja/31024-recapturan-a-integrante-del-cartel-de-sinaloa
29-04-25-NOTA-11,2018-04-19,Jalisco,Puerto Vallarta,14067,Cae en Nayarit El Tolín cuñado de El Menchito operador del CJNG en Puerto Vallarta,,https://www.proceso.com.mx/nacional/2018/4/19/cae-en-nayarit-el-tolin-cunado-de-el-menchito-operador-del-cjng-en-puerto-vallarta-203543.html
29-04-25-NOTA-12,2025-04-29,Jalisco,Zapopan,14066,PGR detienen a El Sobrino por atentado a exfiscal de Jalisco,,https://www.diariodemexico.com/mi-nacion/pgr-detienen-el-sobrino-por-atentado-exfiscal-de-jalisco
29-04-25-NOTA-13,2025-04-29,Ciudad de México,,,Se fuga El Vic hijo del consuegro de El Chapo Guzmán del Reclusorio Sur de la CDMX,,https://www.noroeste.com.mx/culiacan/se-fuga-el-vic-hijo-del-consuegro-de-el-chapo-guzman-del-reclusorio-sur-de-la-cdmx-CTNO1186015
29-04-25-NOTA-14,2021-12-22,Nayarit,,,Condena a 29 y 31 años de prisión a dos mujeres integrantes del Cártel del Poniente,,https://www.eleconomista.com.mx/politica/Condena-a-29-y-31-anos-de-prision-a-dos-mujeres-integrantes-del-Cartel-del-Poniente-20211222-0040.html
29-04-25-NOTA-15,2018-05-28,Jalisco,Zapopan,14066,Dan golpe al CJNG,,https://www.am.com.mx/news/2018/5/28/dan-golpe-al-cjng-346174.html
29-04-25-NOTA-16,2018-05-21,Michoacán,Tepalcatepec,16090,Detienen a El Abuelo miembro del CJNG en Tepalcatepec,,https://www.reforma.com/aplicaciones/articulo/default.aspx?id=1404778
29-04-25-NOTA-17,2024-03-16,Sonora,San Luis Río Colorado,26061,Vincularon a proceso al hijo de El Pía líder de una célula criminal ligada a Los Chapitos en Sonora,,https://www.infobae.com/mexico/2024/03/16/vincularon-a-proceso-al-hijo-de-el-pia-lider-de-una-celula-criminal-ligada-a-los-chapitos-en-sonora/
29-04-25-NOTA-18,2025-04-29,Nayarit,Tepic,18018,Juez impone casi medio siglo de sentencia a integrante de la Familia Michoacana,,https://www.excelsior.com.mx/nacional/juez-impone-casi-medio-siglo-sentencia-integrante-familia-michoacana/1701452
29-04-25-NOTA-19,2025-01-11,Jalisco,Tonalá,14098,FGR recaptura a integrante del CJNG fugado de penal en diciembre,,https://diariodecolima.com/noticias/detalle/2025-01-11-fgr-recaptura-a-integrante-del-cjng-fugado-de-penal-en-diciembre
29-04-25-NOTA-20,2020-06-28,Colima,Colima,6003,Tras asesinato de juez en Colima capturan a dos vinculados con el CJNG,,https://www.reporteindigo.com/opinion/Tras-asesinato-de-juez-en-Colima-capturan-a-dos-vinculados-con-el-CJNG-20200628-0018.html
29-04-25-NOTA-21,2020-06-29,Colima,Colima,6003,Capturan a 2 sospechosos por asesinatos de juez y diputada,,https://diariodecolima.com/noticias/detalle/2020-06-29-capturan-a-2-sospechosos-por-asesinatos-de-juez-y-diputada
29-04-25-NOTA-22,2022-07-06,Colima,Tecomán,6010,Dieron 16 años de cárcel al Chochis y al Roño de los Caballeros Templarios,,https://www.infobae.com/america/mexico/2022/07/06/dieron-16-anos-de-carcel-al-chochis-y-al-rono-de-los-caballeros-templarios/
29-04-25-NOTA-23,2021-05-18,Colima,Manzanillo,6007,Ejército y FGR capturan a seis operadores del CJNG en el puerto de Manzanillo,,https://www.eleconomista.com.mx/politica/Ejercito-y-FGR-capturan-a-seis-operadores-del-CJNG-en-el-puerto-de-Manzanillo-20210518-0075.html
29-04-25-NOTA-24,2025-04-29,Colima,Colima,6003,PGJE captura en Colima a operadores del CJNG en Guerrero y Michoacán,,https://www.afmedios.com/pgje-captura-en-colima-a-operador-del-cjng-en-guerrero-y-michoacan/
29-04-25-NOTA-25,2018-05-28,Jalisco,Guadalajara,14039,Cae El Peque principal proveedor de químicos para el CJNG,,https://www.proceso.com.mx/nacional/2018/5/28/cae-el-peque-principal-proveedor-de-quimicos-para-el-cjng-205804.html
29-04-25-NOTA-26,2012-08-06,Colima,Manzanillo,6007,Arrestan al presunto líder de grupo criminal en Manzanillo,,https://www.informador.mx/Mexico/Arrestan-al-presunto-lider-de-grupo-criminal-en-Manzanillo-20120806-0047.html
29-04-25-NOTA-27,2025-04-29,Jalisco,Guadalajara,14039,14 integrantes del CJNG fueron vinculados a proceso por diversos delitos,,https://www.capitalmexico.com.mx/politica/14-integrantes-del-cjng-fueron-vinculados-a-proceso-por-diversos-delitos/
30-04-25-NOTA-01,2024-12-02,Michoacán,Tacámbaro,16080,Alcalde de Tacámbaro organizó reuniones habituales con líderes del CJNG según pesquisa de la FGR,,https://latinus.us/mexico/2024/12/2/alcalde-de-tacambaro-organizo-reuniones-habituales-con-lideres-del-cjng-segun-pesquisa-de-la-fgr-129671.html
30-04-25-NOTA-02,2021-03-31,Michoacán,Aguililla,16003,Cayó en Guatemala Adalberto Comparán ex alcalde de Aguililla acusado de narcotráfico y de nexos con Cárteles Unidos,,https://www.infobae.com/america/mexico/2021/03/31/cayo-en-guatemala-adalberto-comparan-ex-alcalde-de-aguililla-acusado-de-narcotrafico-y-de-nexos-con-carteles-unidos/
30-04-25-NOTA-03,2021-03-18,Guerrero,Zirándaro,12088,Gregorio Portillo Mendoza el alcalde de Zirándaro presuntamente vinculado al CJNG fue levantado por un comando armado,,https://www.infobae.com/america/mexico/2021/03/18/gregorio-portillo-mendoza-el-alcalde-de-zirandaro-presuntamente-vinculado-al-cjng-fue-levantado-por-un-comando-armado/
30-04-25-NOTA-04,2022-03-08,Michoacán,Marcos Castellanos,16052,Alcalde habría asistido al funeral de una víctima de El Pelón en San José de Gracia,,https://www.infobae.com/america/mexico/2022/03/08/alcalde-habria-asistido-al-funeral-de-una-victima-de-el-pelon-en-san-jose-de-gracia/
30-04-25-NOTA-05,2016-11-19,Coahuila,Allende,5002,Autoridad coludida liberado Sergio Lozano Rodríguez alcalde de Allende Coahuila coludido con Los Zetas,,https://www.jornada.com.mx/2016/11/19/estados/027n1est
30-04-25-NOTA-06,2012-04-19,Veracruz,Minatitlán,30110,Detienen en Minatitlán a alcalde de Chinameca y a integrantes de Los Zetas,,https://www.excelsior.com.mx/2012/04/19/nacional/827728
30-04-25-NOTA-07,2020-06-16,Jalisco,Ixtlahuacán de los Membrillos,14044,Congelaron las cuentas del edil de Ixtlahuacán por presuntos nexos con el Cártel Jalisco Nueva Generación,,https://www.infobae.com/america/mexico/2020/06/16/congelaron-las-cuentas-del-edil-de-ixtlahuacan-por-presuntos-nexos-con-el-cartel-jalisco-nueva-generacion/
30-04-25-NOTA-08,2017-09-13,Oaxaca,,,Narcofamilia quiere su partido en Oaxaca,,https://oaxaca.eluniversal.com.mx/politica/13-09-2017/narcofamilia-quiere-su-partido-en-oaxaca/
30-04-25-NOTA-09,2025-04-29,Chiapas,Benemérito de las Américas,7018,Procesan a 12 del Cártel de Sinaloa que operaban en Chiapas,,https://www.reforma.com/procesan-a-12-del-cartel-de-sinaloa-que-operaban-en-chiapas/ar2866876
30-04-25-NOTA-10,2024-09-30,Chiapas,Villa de Corzo,7115,Vinculan a proceso a integrantes de una célula delictiva en Chiapas,,https://www.jornada.com.mx/noticia/2024/09/30/estados/vinculan-a-proceso-a-integrantes-de-una-celula-delictiva-en-chiapas-8933
CSV

puts "⏳ Iniciando proceso de actualización/carga de hits..."
loaded = 0
updated = 0
errors = []

CSV.parse(csv_data, headers: true).each do |row|
  legacy_id = row["legacy_id"]&.strip
  date      = Date.parse(row["fecha"]) rescue nil
  state_name = row["estado"]&.strip
  municipio = row["municipio o localidad"]&.strip
  clave = row["clave INEGI"]&.strip
  clave = clave.rjust(5, "0") if clave.present?
  title = row["título"]&.strip
  report = row["reporte"]&.strip
  link = row["link"]&.strip

  next if link.blank? && report.blank?

  existing_by_link = Hit.find_by(link: link)
  if existing_by_link
    existing_by_link.update(user_id: USER_ID)
    updated += 1
    next
  end

  existing_by_legacy = Hit.find_by(legacy_id: legacy_id)
  if existing_by_legacy
    existing_by_legacy.update(legacy_id: "#{legacy_id}EA")
  end

  if date.nil?
    errors << { legacy_id: legacy_id, error: "Fecha inválida" }
    next
  end

  town = nil
  if clave.present?
    clave_full = clave + "0000"
    town = Town.find_by(full_code: clave_full)
  end

  if town.nil? && state_name.present?
    state = State.find_by(name: state_name)
    if state
      clave_fallback = state.code + "0000000"
      town = Town.find_by(full_code: clave_fallback)
    end
  end

  unless town
    errors << { legacy_id: legacy_id, error: "No se encontró municipio ni estado" }
    next
  end

  new_hit = Hit.create!(
    legacy_id: legacy_id,
    date: date,
    title: title,
    link: link,
    report: report,
    town_id: town.id,
    user_id: USER_ID
  )
  loaded += 1

  begin
    next unless new_hit.link.present? && new_hit.link.start_with?('http')
    puts "🌀 Generando PDF para: #{new_hit.link}"
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    image_url = "https://dashboard.lantiaintelligence.com/assets/Lantia_LogoPositivo.png"

    html_header = <<~HTML
      <div style='font-size: 14px; font-family: sans-serif; border-bottom: 1px solid #ccc; padding-bottom: 10px; margin-bottom: 20px;'>
        <img src='#{image_url}' style='width: 160px; display: block; margin-bottom: 10px;' alt='Lantia Logo'>
        <div style="font-size: 14px;">
          Fuente:<span style="font-weight: 800;"> #{new_hit.link}</span><br>
          Capturado:<span style="font-weight: 800;"> #{timestamp}</span><br>
          User-Agent:<span style="font-weight: 800;"> #{user_agent}</span><br>
          Organización:<span style="font-weight: 800;"> Estrategias, Decisiones y Mejores Prácticas</span>
        </div>
      </div>
    HTML

    Timeout.timeout(45) do
      html_body = URI.open(new_hit.link, "User-Agent" => user_agent).read
      pdf = WickedPdf.new.pdf_from_string(
        html_header + html_body,
        encoding: 'UTF-8',
        margin: { top: 20, bottom: 10 },
        disable_javascript: true,
        javascript_delay: 3000,
        print_media_type: true,
        zoom: 1.25,
        dpi: 150,
        viewport_size: '1280x1024'
      )
      io = StringIO.new(pdf)
      new_hit.pdf.attach(io: io, filename: "hit_#{new_hit.id}.pdf", content_type: 'application/pdf')
      puts "✅ PDF adjuntado a Hit ##{new_hit.id}"
    end
  rescue => e
    puts "⚠️ Error generando PDF para Hit ##{new_hit.id}: #{e.message}"
    new_hit.update(protected_link: true)
  end
end

puts "✅ Hits cargados: #{loaded}"
puts "🔁 Hits actualizados: #{updated}"
puts "❌ Errores:"
errors.each { |e| puts e.inspect }

