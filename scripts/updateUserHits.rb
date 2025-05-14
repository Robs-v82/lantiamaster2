require 'csv'
require 'open-uri'
require 'timeout'

user_agent = "WickedPdf/1.0 (Lantia Intelligence)"
# USER_ID = 18
USER_ID = 1164

# ⚠️ Pega aquí todo el contenido CSV como string entre comillas triples
csv_data = <<~CSV
legacy_id,fecha,estado,municipio o localidad,clave INEGI,título,reporte,link
05-05-25-NOTA-01,2025-05-05,Oaxaca,,,Ex diputado de Oaxaca acusa que Fiscalía le ha fabricado delitos,,https://www.milenio.com/estados/ex-diputado-oaxaca-acusa-fiscalia-le-ha-fabricado-delitos
05-05-25-NOTA-02,2025-05-05,Oaxaca,Valles Centrales,,Detienen a El Oaxaco presunto líder del Cártel del Golfo,,https://www.elfinanciero.com.mx/nacional/detienen-a-el-oaxaco-presunto-lider-del-cartel-del-golfo/
05-05-25-NOTA-03,2025-04-23,Oaxaca,Oaxaca de Juárez,20067,Cae presidente de la Unión Ganadera del Istmo de Oaxaca tenía vínculos con el Cártel de Sinaloa,,https://www.infobae.com/mexico/2025/04/23/cae-presidente-de-la-union-ganadera-del-istmo-de-oaxaca-tenia-vinculos-con-el-cartel-de-sinaloa/
05-05-25-NOTA-04,2025-01-15,Oaxaca,Pinotepa Nacional,20069,Detienen a Martín Caro Monge líder del Cártel de Caborca en Oaxaca,,https://www.publimetro.com.mx/noticias/2025/01/15/detienen-a-martin-caro-monge-lider-del-cartel-de-caborca-en-oaxaca/
05-05-25-NOTA-05,2022-01-03,Oaxaca,,,Sentencian a El Cabrito líder de Los Zetas en Oaxaca a 91 años de prisión,,https://www.jornada.com.mx/noticia/2022/01/03/politica/sentencian-a-el-cabrito-lider-de-los-zetas-en-oaxaca-a-91-anos-de-prision-3734
05-05-25-NOTA-06,2018-01-13,Oaxaca,,,Cae El Junior operador del Cártel del Golfo en Oaxaca,,https://lasillarota.com/estados/2018/1/13/cae-el-junior-operador-del-cartel-del-golfo-en-oaxaca-149602.html
05-05-25-NOTA-07,2025-05-05,Oaxaca,Villa de Etla,20338,Cae El Amarillo fundador de Los Zetas,,https://www.noroeste.com.mx/nacional/cae-el-amarillo-fundador-de-los-zetas-DDNO312346
05-05-25-NOTA-08,2022-01-01,Oaxaca,San Jacinto Amilpas,20200,Condenaron a 20 años al Lagarto de Los Zetas en Oaxaca,,https://www.infobae.com/america/mexico/2022/01/01/condenaron-a-20-anos-al-lagarto-de-los-zetas-en-oaxaca/
05-05-25-NOTA-09,2025-05-05,Oaxaca,Miahuatlán de Porfirio Díaz,20055,Condenan a 58 años de prisión a 3 integrantes de Los Zetas,,https://www.excelsior.com.mx/nacional/condenan-a-58-anos-de-prision-a-3-integrantes-de-los-zetas/1481137
05-05-25-NOTA-10,2025-05-05,Veracruz,Villa Aldama,30198,Zetas juez da 55 años de prisión a integrantes,,https://www.milenio.com/policia/zetas-juez-55-anos-prision-integrantes
05-05-25-NOTA-11,2025-05-05,Oaxaca,Tlacolula de Matamoros,20403,Detienen a 16 narcos,,https://www.noroeste.com.mx/nacional/detienen-a-16-narcos-BSNO29614
05-05-25-NOTA-12,2025-05-05,Oaxaca,,,Cae Carlos Terán líder del Cártel de Juchitán,,https://oem.com.mx/la-prensa/policiaca/cae-carlos-teran-lider-del-cartel-de-juchitan-14914601
05-05-25-NOTA-13,2025-05-05,Oaxaca,,,Homicidio de empresario italiano 44 años de prisión a Zeta,,https://www.milenio.com/policia/homicidio-empresario-italiano-44-anos-prision-zeta
05-05-25-NOTA-14,2009-03-01,Oaxaca,Puerto Escondido,20482,Detienen en Zicatela a líderes e integrantes de Los Zetas,,https://www.jornada.com.mx/2009/03/01/politica/004n2pol
05-05-25-NOTA-15,2025-05-05,México,,,Detención de El Manuelón,,https://www.tvazteca.com/aztecanoticias/seguridad-y-justicia/seguridad-y-justicia/notas/detencion-de-el-manuelon
05-05-25-NOTA-16,2025-05-05,Veracruz,,,Violencia en Veracruz; presencia de 5 grupos criminales: Sedena,,https://www.milenio.com/policia/violencia-veracruz-presencia-5-grupos-criminales-sedena
05-05-25-NOTA-17,2025-05-05,Campeche,,,Crimen organizado pelea el estado,,https://laopiniondemexico.mx/crimen-organizado-pelea-el-estado/
05-05-25-NOTA-18,2022-10-11,Yucatán,,,Guacamaya Leaks; Yucatán entre los estados del sureste azotados por los cárteles,,https://www.yucatan.com.mx/mexico/2022/10/11/guacamaya-leaks-yucatan-entre-los-estados-del-sureste-de-mexico-azotados-por-los-carteles-353335.html
05-05-25-NOTA-19,2025-05-05,Michoacán,Buenavista,16013,Sedena: funcionarios del gobierno de Michoacán y alcalde de Buenavista protegen a Cárteles Unidos,,https://www.dw.com/es/sedena-funcionarios-del-gobierno-de-michoac%C3%A1n-y-alcalde-de-buenavista-protegen-a-carteles-unidos/a-66128516
05-05-25-NOTA-20,2024-10-18,Sonora,Sonoyta,26054,Procesan a Cuza cabecilla de Los Salazar los exsocios de Los Chapitos en Sonora,,https://www.infobae.com/mexico/2024/10/18/procesan-a-cuza-cabecilla-de-los-salazar-los-ex-socios-de-los-chapitos-en-sonora/
05-05-25-NOTA-21,2022-07-15,Sonora,San Miguel de Horcasitas,26061,El Comandante de la AMIC de Sonora es requerido por narcotráfico en Arizona,,https://www.infobae.com/america/mexico/2022/07/15/el-comandante-de-la-amic-de-sonora-es-requerido-por-narcotrafico-en-arizona/
05-05-25-NOTA-22,2025-03-25,Sonora,Hermosillo,26030,Capturan a Saúl Francisco alias El Ponchis quien es y qué relación tiene con Los Chapitos,,https://mvsnoticias.com/nacional/policiaca/2025/3/25/capturan-saul-francisco-n-alias-el-ponchis-quien-es-que-relacion-tiene-conloschapitos-684671.html
05-05-25-NOTA-23,2025-05-05,Sonora,Hermosillo,26030,Detienen en México a un líder criminal vinculado con Los Chapitos y buscado por EE.UU.,,https://www.swissinfo.ch/spa/detienen-en-m%C3%A9xico-a-un-l%C3%ADder-criminal-vinculado-con-los-chapitos-y-buscado-por-ee.uu./89070870
05-05-25-NOTA-24,2025-03-14,Durango,Victoria de Durango,10039,Procesan a El Sierra operador financiero y segundo al mando de Los Deltas brazo armado de Los Chapitos en Sonora,,https://www.infobae.com/mexico/2025/03/14/procesan-a-el-sierra-operador-financiero-y-segundo-al-mando-de-los-deltas-brazo-armado-de-los-chapitos-en-sonora/
05-05-25-NOTA-25,2025-03-18,Sonora,Cajeme,26018,Quién es El Chino líder de Los Salazar rival de Los Chapitos detenido en Sonora,,https://lasillarota.com/estados/2025/3/18/quien-es-el-chino-lider-de-los-salazar-rival-de-los-chapitos-detenido-en-sonora-527810.html
05-05-25-NOTA-26,2024-12-10,Sonora,Hermosillo,26030,Vinculan a proceso a El Muerto presunto jefe de sicarios de célula de Los Chapitos,,https://www.jornada.com.mx/noticia/2024/12/10/politica/vinculan-a-proceso-a-el-muerto-presunto-jefe-de-sicarios-de-celula-de-los-chapitos-4896
05-05-25-NOTA-27,2024-11-16,Sonora,,,El Pelón líder de Los Chapitos también era buscado por el asesinato de exmarine estadounidense en Sonora,,https://www.elfinanciero.com.mx/estados/2024/11/16/el-pelon-lider-de-los-chapitos-tambien-era-buscando-por-el-asesinato-de-exmarine-estadounidense-en-sonora/
05-05-25-NOTA-28,2021-06-11,Sonora,Altar,26006,Cae Chubeto presunto jefe de una célula del Cártel de Sinaloa,,https://www.proceso.com.mx/nacional/2021/6/11/cae-chubeto-presunto-jefe-de-una-celula-del-cartel-de-sinaloa-265808.html
05-05-25-NOTA-29,2025-05-05,Sonora,Nogales,26043,Vinculan a proceso a presunto líder de banda de tráfico de armas,,https://www.milenio.com/policia/vinculan-proceso-presunto-lider-banda-trafico-armas
05-05-25-NOTA-30,2015-08-10,Sonora,Hermosillo,26030,Fuerzas federales detienen en Sonora a jefe de un grupo delictivo vinculado a Caro Quintero,,https://www.gob.mx/segob/prensa/fuerzas-federales-detienen-en-sonora-a-jefe-de-un-grupo-delictivo-vinculado-a-caro-quintero
05-05-25-NOTA-31,2024-01-30,Sonora,,,Quién es El Comanche el criminal por el que la Fiscalía de Sonora ofrece un millón de pesos,,https://www.infobae.com/mexico/2024/01/30/quien-es-el-comanche-el-criminal-por-el-que-la-fiscalia-de-sonora-ofrece-un-millon-de-pesos/
06-05-25-NOTA-01,2024-12-17,Hidalgo,Pachuca de Soto,13048,Capturan en Hidalgo a El Tigre integrante del Cártel de Sinaloa,,https://www.cronica.com.mx/nacional/2024/12/17/capturan-en-hidalgo-al-tigre-integrante-del-cartel-de-sinaloa/
06-05-25-NOTA-02,2025-03-16,Hidalgo,Pachuca de Soto,13048,Capturan a El H líder huachicolero y narcomenudista en Tula Hidalgo,,https://www.jornada.com.mx/noticia/2025/03/16/estados/capturan-a-el-h-lider-huachicolero-y-narcomenudista-en-tula-hidalgo
06-05-25-NOTA-03,2025-02-24,Hidalgo,Dolores,13024,Detienen a El Cholo presunto jefe de sicarios y coordinador del Cártel de Santa Rosa de Lima,,https://latinus.us/mexico/2025/2/24/detienen-el-cholo-presunto-jefe-de-sicarios-coordinador-de-la-venta-de-droga-del-cartel-de-santa-rosa-de-lima-135817.html
06-05-25-NOTA-04,2025-03-16,Hidalgo,Pachuca de Soto,13048,Por homicidio doloso vinculan a Uriel N,,https://www.eluniversalhidalgo.com.mx/seguridad/por-homicidio-doloso-vinculan-a-uriel-n/
06-05-25-NOTA-05,2024-09-20,Hidalgo,Tolcayuca,13102,Detienen a El Chino Mayoreo líder de narcomenudeo que operaba en Valle del Mezquital,,https://hidalgo.periodicocentral.mx/pagina-negra/detienen-a-el-chino-mayoreo-lider-de-narcomenudeo-que-operaba-en-valle-del-mezquital/39309/
06-05-25-NOTA-06,2024-09-20,CDMX,Cuauhtémoc,9002,Cae El Metra de La Unión Tepito se le responsabiliza de un doble homicidio,,https://liberalmetropolitano.com.mx/2024/09/20/cae-el-metra-de-la-union-tepito-se-le-responsabiliza-de-un-doble-homicidio/
06-05-25-NOTA-07,2023-09-13,Chihuahua,Año de Hidalgo,8070,Detienen a El Ruso presunto líder criminal de Gente Nueva del Jaguar brazo del Cártel de Sinaloa,,https://www.elfinanciero.com.mx/estados/2023/09/13/detienen-a-el-ruso-presunto-lider-criminal-de-gente-nueva-del-jaguar-brazo-del-cartel-de-sinaloa/
06-05-25-NOTA-08,2021-10-23,Chihuahua,Madera,8038,Cayó El Jaguar junto con otros tres vinculados a la masacre de Bavispe,,https://www.infobae.com/america/mexico/2021/10/23/cayo-el-jaguar-junto-con-otros-tres-vinculados-a-la-masacre-de-bavispe/
06-05-25-NOTA-09,2022-04-18,Hidalgo,Pachuca de Soto,13048,SSPC recaptura a El Michoacano líder delictivo que se fugó de un penal de Hidalgo,,https://www.eleconomista.com.mx/politica/SSPC-recaptura-a-El-Michoacano-lider-delictivo-que-se-fugo-de-un-penal-de-Hidalgo-20220418-0070.html
06-05-25-NOTA-10,2025-05-06,Estado de México,Zumpango,15096,Detienen a presunto líder del Cártel Imperio en Tlalnepantla,,https://www.milenio.com/policia/detienen-presunto-lider-cartel-imperio-tlalnpantla
06-05-25-NOTA-11,2021-08-23,Hidalgo,Cuautepec de Hinojosa,13021,Cae El Marino líder huachicolero en Hidalgo; quién es y dónde opera,,https://lasillarota.com/hidalgo/estado/2021/8/23/cae-el-marino-lider-huachicolero-en-hidalgo-quien-es-donde-opera-293373.html
06-05-25-NOTA-12,2012-03-27,Hidalgo,Tepeapulco,13071,Detienen a El Comandante Capulina líder de Los Zetas,,https://www.excelsior.com.mx/2012/03/27/nacional/821936
06-05-25-NOTA-13,2020-05-13,Nuevo León,Monterrey,19030,Cayeron exintegrantes de Los Zetas que planeaban atentado contra edificio de gobierno en Monterrey,,https://www.infobae.com/america/mexico/2020/05/13/cayeron-ex-integrantes-de-los-zetas-que-planeaban-atentado-contra-edificio-de-gobierno-en-monterrey/
06-05-25-NOTA-14,2022-03-30,Michoacán,Zinapécuaro,16113,Los Correa; quién es el grupo criminal detrás de la masacre de Zinapécuaro,,https://www.infobae.com/america/mexico/2022/03/30/los-correa-quien-es-el-grupo-criminal-detras-de-la-masacre-de-zinapecuaro/
06-05-25-NOTA-15,2020-01-26,Tamaulipas,Reynosa,28043,El Duro; el líder de secuestradores de Los Zetas que fue sentenciado a 90 años de prisión,,https://www.infobae.com/america/mexico/2020/01/26/el-duro-el-lider-de-secuestradores-de-los-zetas-que-fue-sentenciado-a-90-anos-de-prision/
06-05-25-NOTA-16,2022-02-20,Chihuahua,Hidalgo del Parral,8032,Capturan a jefe del Cártel de Sinaloa en Parral con armas,,https://oem.com.mx/elsoldeparral/local/capturan-a-jefe-del-cartel-de-sinaloa-en-parral-con-armas-20394898
06-05-25-NOTA-17,2019-10-28,Morelos,Amacuzac,17005,La infame historia del alcalde que gobierna desde la cárcel y es familiar de El Carrete líder de Los Rojos,,https://www.infobae.com/america/mexico/2019/10/28/la-infame-historia-del-alcalde-mexicano-que-gobierna-desde-la-carcel-y-es-familiar-de-el-carrete-lider-de-los-rojos/
06-05-25-NOTA-18,2023-08-02,Hidalgo,San Juan Hueyapan,13060,El Peluche segundo al mando de Los Cenobios fue funcionario municipal en Cuautepec Hidalgo,,https://www.proceso.com.mx/nacional/estados/2023/8/2/el-peluche-segundo-al-mando-de-los-cenobios-fue-funcionario-municipal-en-cuautepec-hidalgo-311973.html
06-05-25-NOTA-19,2023-12-04,CDMX,Tlalpan,9010,Cae líder de célula de La Unión Tepito,,https://www.reforma.com/cae-lider-de-celula-de-la-union-tepito/ar1867378
06-05-25-NOTA-20,2023-09-14,Jalisco,Tlajomulco de Zúñiga,14097,Detienen a El H3 líder del Cártel de los Beltrán Leyva,,https://lopezdoriga.com/economia-y-finanzas/trump-dice-mexico-canada-no-respetan-t-mec-pronto-renegociara/
06-05-25-NOTA-21,2019-05-09,Veracruz,Tantoyuca,30206,Detienen a El Tompo jefe de plaza de Grupo Sombra en el norte de Veracruz,,https://www.proceso.com.mx/nacional/estados/2019/5/9/detienen-el-tompo-jefe-de-plaza-de-grupo-sombra-en-el-norte-de-veracruz-224658.html
06-05-25-NOTA-22,2019-02-06,Oaxaca,Unión Hidalgo,20582,Detienen a ocho presuntos integrantes de grupo criminal que opera en el Istmo,,https://www.proceso.com.mx/nacional/2019/2/6/detienen-ocho-presuntos-integrantes-de-grupo-criminal-que-opera-en-el-istmo-219840.html
06-05-25-NOTA-23,2020-05-13,CDMX,Cuauhtémoc,9002,Elementos de Fiscalía detienen a El Santero,,https://www.elsiglodetorreon.com.mx/noticia/2020/elementos-de-fiscalia-detienen-a-el-santero.html
06-05-25-NOTA-24,2021-02-04,CDMX,,,Cayó Don Agus presunto líder criminal ligado al tráfico de drogas y armas al sur de CDMX,,https://www.infobae.com/america/mexico/2021/02/04/cayo-don-agus-presunto-lider-criminal-ligado-al-trafico-de-drogas-y-armas-al-sur-de-cdmx/
06-05-25-NOTA-25,2020-05-13,Nuevo León,Monterrey,19030,Exclusiva narcoterrorista es detenido tratando de volar edificio de gobierno en estado fronterizo,,https://www.breitbart.com/border/2020/05/13/exclusiva-narcoterrorista-es-detenido-tratando-de-volar-edificio-de-gobierno-en-estado-fronterizo/
06-05-25-NOTA-26,2020-05-13,CDMX,Cuauhtémoc,9002,Detienen en Colonia Roma al líder operador de una división del Cártel de los Beltrán Leyva,,https://24-horas.mx/justicia/detienen-en-colonia-roma-al-lider-operador-de-una-division-del-cartel-de-los-beltran-leyva/
06-05-25-NOTA-27,2021-01-23,CDMX,,,Detienen a líder de banda dedicada al robo a casa habitación,,https://www.jornada.com.mx/noticia/2021/01/23/capital/detienen-a-lider-de-banda-dedicada-al-robo-a-casa-habitacion-9747
06-05-25-NOTA-28,2021-08-11,CDMX,,,Así fue la recaptura de Don Goyo presunto fundador del Cártel de Tláhuac,,https://www.infobae.com/america/mexico/2021/08/11/asi-fue-la-recaptura-de-don-goyo-presunto-fundador-del-cartel-de-tlahuac/
06-05-25-NOTA-29,2023-12-04,CDMX,,,Cae El Kalusha presunto integrante de La Unión Tepito; fue detenido con arma y droga,,https://www.eluniversal.com.mx/metropoli/cae-el-kalusha-presunto-integrante-de-la-union-tepito-fue-detenido-con-arma-y-droga/
06-05-25-NOTA-30,2022-04-18,CDMX,,,"En la boca del lobo; detienen frente a la fiscalía CDMX a El Rabias, fugado del penal de Hidalgo",,https://www.elfinanciero.com.mx/cdmx/2022/04/18/en-la-boca-del-lobo-detienen-frente-a-la-fiscalia-cdmx-a-el-rabias-fugado-del-penal-de-hidalgo/
06-05-25-NOTA-31,2023-12-22,Hidalgo,Huejutla de Reyes,13029,Quién es El Contador Asesino; jefe de plaza de Los Zetas en Hidalgo; fue sentenciado a 21 años de cárcel,,https://www.infobae.com/mexico/2023/12/22/quien-es-el-contador-asesino-jefe-de-plaza-de-los-zetas-en-hidalgo-que-fue-sentenciado-a-21-anos-de-carcel/
06-05-25-NOTA-32,2025-01-20,Estado de México,,,Así operaba El Águila jefe del CJNG en el Edomex que recibió una doble sentencia por secuestro,,https://www.infobae.com/mexico/2025/01/20/asi-operaba-el-aguila-jefe-del-cjng-en-el-edomex-que-recibio-una-doble-sentencia-por-secuestro/
06-05-25-NOTA-33,2022-02-09,Michoacán,Los Reyes,16045,El Michoacano y El Guicho de Cárteles Unidos aparecieron en Palenque con Lupillo Rivera,,https://www.infobae.com/america/mexico/2022/02/09/el-michoacano-y-el-guicho-de-carteles-unidos-aparecieron-en-palenque-con-lupillo-rivera/
06-05-25-NOTA-34,2025-03-14,Tamaulipas,San Fernando,28025,Procesan a 11 sicarios del Cártel del Golfo que atacaron a la Marina en Tamaulipas,,https://www.infobae.com/mexico/2025/03/14/procesan-a-11-sicarios-del-cartel-del-golfo-que-atacaron-a-la-marina-en-tamaulipas/
06-05-25-NOTA-35,2015-04-09,Quintana Roo,Cancún,23002,Detenidos en Cancún líderes y miembros del Cártel del Golfo y de Los Zetas,,https://www.excelsior.com.mx/nacional/2015/04/09/1017636
07-05-25-NOTA-01,06-05-25,Sinaloa,Culiacán,25006,Golpe al Cártel de Sinaloa: Detienen a El Chuy quien cuenta con orden de extradición a EU,,https://www.elfinanciero.com.mx/nacional/2025/05/06/golpe-al-cartel-de-sinaloa-detienen-a-el-chuy-quien-cuenta-con-orden-de-extradicion-a-eu/
08-05-25-NOTA-01,2025-04-08,Michoacán,Los Reyes,16045,Captan a uno de los líderes de Cárteles Unidos en concierto de Panchito Arredondo en Los Reyes Michoacán,,https://www.infobae.com/mexico/2025/04/08/captan-a-uno-de-los-lideres-de-carteles-unidos-en-concierto-de-panchito-arredondo-en-los-reyes-michoacan/
08-05-25-NOTA-02,2025-02-23,CDMX,Cuauhtémoc,9002,Detienen a El Chabelo y otros dos integrantes de La Unión Tepito,,https://www.proceso.com.mx/nacional/cdmx/2025/2/23/detienen-el-chabelo-otros-dos-integrantes-de-la-union-tepito-346129.html
08-05-25-NOTA-03,2025-04-07,CDMX,Cuauhtémoc,9002,Cae El Gatillo; sicario colombiano ligado al Cártel de Los Reyes Michoacán,,https://www.eluniversal.com.mx/metropoli/cae-el-gatillo-sicario-colombiano-ligado-al-cartel-de-los-reyes-michoacan/
08-05-25-NOTA-04,2025-04-06,CDMX,Gustavo A. Madero,9006,Detienen a El Perro; sicario del Cártel del Centro en operativo en Candelaria Ticomán,,https://www.eluniversal.com.mx/edomex/detienen-a-el-perro-sicario-del-cartel-del-centro-en-operativo-en-candelaria-ticoman/
08-05-25-NOTA-05,2025-03-30,Nuevo León,Monterrey,19066,Detenidos integrantes de Los Zetas en Monterrey,,https://www.reforma.com/aplicacioneslibre/preacceso/articulo/default.aspx?__rval=1&urlredirect=https://www.reforma.com/aplicaciones/articulo/default.aspx?id=1593821&referer=--7d616165662f3a3a6262623b727a7a7279703b767a783a--
08-05-25-NOTA-06,2025-04-10,Jalisco,Magdalena,14054,Detienen a operadora del CJNG con orden de captura en EU; le aseguran arma larga dorada,,https://www.eluniversal.com.mx/nacion/detienen-a-operadora-del-cjng-con-orden-de-captura-en-eu-le-aseguran-arma-larga-dorada/
08-05-25-NOTA-07,2025-04-08,Jalisco,Teuchitlán,14104,Detienen al alcalde de Teuchitlán Jalisco José Asunción Murguía Santiago,,https://oem.com.mx/elsoldemexico/mexico/detienen-al-alcalde-de-teuchitlan-jalisco-jose-asuncion-murguia-santiago-23108070
08-05-25-NOTA-08,2025-04-11,Chiapas,Tuxtla Gutiérrez,7084,Capturan a Ataulfo López Flores alias El Mango; líder del Cártel Chiapas Guatemala,,https://www.proceso.com.mx/nacional/2025/4/11/capturan-ataulfo-lopez-flores-alias-el-mango-lider-del-cartel-chiapas-guatemala-349200.html
08-05-25-NOTA-09,2025-04-09,Chiapas,Yajalón,7101,Detienen a El Chorizo; líder de Karma ligado al Cártel de Sinaloa,,https://www.milenio.com/policia/detienen-el-chorizo-lider-de-karma-ligado-cartel-de-sinaloa
08-05-25-NOTA-10,2025-04-05,San Luis Potosí,,24000,Detienen a jefe regional del Cártel del Golfo en San Luis Potosí; sobrino de Osiel Cárdenas,,https://oem.com.mx/elsoldemexico/mexico/detienen-jefe-regional-cartel-del-golfo-san-luis-potosi-sobrino-osiel-cardenas-guillej-jose-aflredro-cardenas-16610026
08-05-25-NOTA-11,2025-04-01,San Luis Potosí,Tierra Nueva,24042,Detienen a líder CJNG en San Luis Potosí,,https://pulsoslp.com.mx/seguridad/detienen-a-lider-cjng-en-san-luis-potosi/1908125
08-05-25-NOTA-12,2018-10-23,Nuevo León,Monterrey,19066,Cae El Gafe; presunto líder del Cártel del Noreste,,https://www.proceso.com.mx/nacional/2018/10/23/cae-el-gafe-presunto-lider-del-cartel-del-noreste-214361.html
08-05-25-NOTA-13,2025-04-04,Jalisco,Ciudad Guzmán,14121,Detiene Marina a 4 ligados a líder del Cártel de Jalisco,,https://www.noroeste.com.mx/nacional/detiene-marina-a-4-ligados-a-lider-de-cartel-de-jalisco-FDNO463723
08-05-25-NOTA-14,2025-04-08,Jalisco,Teuchitlán,14104,Detienen al alcalde de Teuchitlán Jalisco José Asunción Murguía Santiago,,https://oem.com.mx/elsoldemexico/mexico/detienen-al-alcalde-de-teuchitlan-jalisco-jose-asuncion-murguia-santiago-23108070
08-05-25-NOTA-15,2025-04-10,Querétaro,San Juan del Río,22011,Cae Ajenjo; jefe del Cártel Nuevo Imperio en alcaldía Azcapotzalco fue detenido en Querétaro,,https://www.eluniversal.com.mx/metropoli/cae-ajenjo-jefe-del-cartel-nuevo-imperio-en-alcaldia-azcapotzalco-fue-detenido-en-queretaro/
08-05-25-NOTA-16,2025-04-11,San Luis Potosí,Xilitla,24149,Cae El Billetón; operador financiero ligado al Cártel del Golfo,,https://www.milenio.com/policia/cae-el-billeton-operador-financiero-ligado-cartel-golfo
08-05-25-NOTA-17,2018-08-20,San Luis Potosí,Cedral,24007,Capturan a integrantes de grupo delincuencial que operaba en SLP,,https://sanluispotosi.quadratin.com.mx/san-luis-potosi/capturan-a-integrantes-de-grupo-delincuencial-que-operaba-en-slp/
08-05-25-NOTA-18,2025-02-10,CDMX,,9000,SSC desarticula célula criminal de Los Mojarras; suma 8 detenidos incluidos 2 líderes clave,,https://www.eluniversal.com.mx/metropoli/ssc-desarticula-celula-criminal-de-los-mojarras-suma-8-detenidos-incluidos-2-lideres-clave/
08-05-25-NOTA-19,2025-02-09,CDMX,Tlalpan,9010,Detienen en Topilejo a El Mojarras y El Harry; extorsionadores y generadores de violencia al sur de la CDMX,,https://www.capitalmexico.com.mx/cdmx/detienen-en-topilejo-a-el-mojarras-y-el-harry-extorsionadores-y-generadores-de-violencia-al-sur-de-la-cdmx/
08-05-25-NOTA-20,2025-02-11,CDMX,Tlalpan,9010,Tras persecución y balacera atoran a El Mojarras; líder de Los Mojarras en CDMX,,https://www.elgrafico.mx/la-roja/2025/02/11/tras-persecucion-y-balacera-atoran-a-el-mojarras-lider-de-los-mojarras-en-cdmx/
08-05-25-NOTA-21,2025-04-15,Puebla,,21000,Vinculan a proceso a líder de Sangre Zeta Nueva en Puebla,,https://www.milenio.com/estados/vinculan-a-proceso-a-lider-de-sangre-zeta-nueva-en-puebla
08-05-25-NOTA-22,2021-07-20,Baja California,Tijuana,2004,Vinculan a proceso a integrante del CJNG por andar armado en vía pública,,https://zetatijuana.com/2021/07/vinculan-a-proceso-a-integrante-del-cjng-por-andar-armado-en-via-publica/#google_vignette
08-05-25-NOTA-23,2025-04-12,Tlaxcala,Santa Cruz Tlaxcala,29029,Vinculan a proceso a El Secre; líder huachicolero de la Nueva Sangre Zeta,,https://www.tvazteca.com/aztecanoticias/vinculan-proceso-el-secre-lider-huachicolero-la-nueva-sangre-zeta
09-05-25-NOTA-01,2022-01-13,Aguascalientes,Aguascalientes,1001,Detienen en Aguascalientes a El Hormiga; jefe de plaza del CJNG,,https://www.jornada.com.mx/noticia/2022/01/13/estados/detienen-en-aguascalientes-a-201cel-hormiga201d-jefe-de-plaza-del-cjng-8215
09-05-25-NOTA-02,2022-01-20,Estado de México,Almoloya de Juárez,15006,Tribunal concede prisión domiciliar al magistrado Avelar Gutiérrez,,https://www.jornada.com.mx/noticia/2022/01/20/politica/tribunal-concede-prision-domiciliar-al-magistrado-avelar-gutierrez-4466
09-05-25-NOTA-03,2022-02-06,Jalisco,Puerto Vallarta,14067,Inicia juicio a Don Carlos; lugarteniente del Cártel Jalisco Nueva Generación,,https://www.elfinanciero.com.mx/estados/2022/02/06/inicia-juicio-a-don-carlos-lugarteniente-del-cartel-jalisco-nueva-generacion/
09-05-25-NOTA-04,2022-03-20,Baja California,Mexicali,2002,Detienen a tres presuntos miembros del CJNG en Mexicali,,https://www.jornada.com.mx/notas/2022/03/20/estados/detienen-a-tres-presuntos-miembros-del-cjng-en-mexicali/
09-05-25-NOTA-05,2025-02-15,Ciudad de México,Venustiano Carranza,9015,Detienen a El Traumado; presunto jefe de Cártel Independiente de Acapulco,,https://www.jornada.com.mx/noticia/2025/02/15/politica/detienen-a-2018el-traumado2019-presunto-jefe-de-cartel-independiente-de-acapulco-3546
09-05-25-NOTA-06,2022-04-18,Jalisco,Yahualica de González Gallo,14045,Sentencian a 34 años de prisión a El Antiguo del CJNG,,https://www.jornada.com.mx/noticia/2022/04/18/sociedad/sentencian-a-34-anos-de-prision-a-el-antiguo-del-cjng-8986
09-05-25-NOTA-07,2022-04-30,Sinaloa,Mazatlán,25006,SEMAR captura a El Señorón; presunto operador del CJNG en Morelos,,https://www.jornada.com.mx/noticia/2022/04/30/politica/semar-captura-a-2018el-senoron2019-presunto-operador-del-cjng-en-morelos-3733
09-05-25-NOTA-08,2022-05-31,Zacatecas,Zacatecas,32056,Vinculan a proceso a La Mosca; jefe regional del CJNG,,https://www.jornada.com.mx/noticia/2022/05/31/sociedad/vinculan-a-proceso-a-la-mosca-jefe-regional-del-cjng-6410
09-05-25-NOTA-09,2022-06-03,Jalisco,Ameca,14005,Despiden a director de la policía de Ameca; informante del CJNG,,https://www.jornada.com.mx/noticia/2022/06/03/estados/despiden-a-director-de-la-policia-de-ameca-201cinformante201d-del-cjng-6895
09-05-25-NOTA-10,2023-01-04,Baja California,Tijuana,2004,Capturan a líder de célula del CJNG en Playas de Tijuana,,https://www.jornada.com.mx/notas/2023/01/04/estados/capturan-a-lider-de-celula-del-cjng-en-playas-de-tijuana/
09-05-25-NOTA-11,2023-01-12,Jalisco,Tapalpa,14126,Detienen a Manuel Pizano; hermano de El CR; líder del CJNG,,https://www.jornada.com.mx/noticia/2023/01/12/politica/detienen-a-manuel-pizano-hermano-de-el-cr-lider-del-cjng-5965
09-05-25-NOTA-12,2023-06-13,Tamaulipas,Reynosa,28034,Capturan a Ernesto Sánchez Metro 22; integrante del Cártel del Golfo en Reynosa,,https://www.milenio.com/policia/capturan-ernesto-sanchez-metro-22-integrante-cartel-golfo-reynosa
09-05-25-NOTA-13,2023-06-16,Puebla,Cholula,21034,Detienen en Puebla a El Tory; líder de las Tropas del Infierno,,https://www.jornada.com.mx/noticia/2023/06/16/politica/detienen-en-puebla-a-el-tory-lider-de-las-tropas-del-infierno-2094
09-05-25-NOTA-14,2024-01-06,Jalisco,Guadalajara,14039,Dos personas son sentenciadas a prisión por nexos con el CJNG,,https://www.milenio.com/estados/dos-personas-son-sentenciadas-a-prision-por-nexos-con-el-cjng
09-05-25-NOTA-15,2025-01-10,Jalisco,Tonalá,14106,Reaprehenden a El Cevichón en Tonalá; Jalisco,,https://www.jornada.com.mx/noticia/2025/01/10/politica/reaprehenden-a-el-cevichon-en-tonala-jalisco-6755
09-05-25-NOTA-16,2025-02-14,Guanajuato,León,11020,Detienen a 7 presuntos integrantes del CJNG en León; Guanajuato,,https://www.jornada.com.mx/noticia/2025/02/14/politica/detienen-a-7-presuntos-integrantes-del-cjng-en-leon-guanajato-9932
09-05-25-NOTA-17,2021-03-10,Tamaulipas,Reynosa,28032,Vinculan a proceso a cinco del Cártel del Golfo,,https://www.reforma.com/vinculan-a-proceso-a-cinco-del-cartel-del-golfo/ar2141233
09-05-25-NOTA-18,2021-07-14,Tamaulipas,Reynosa,28032,Grupo armado libera a líder del Cártel del Golfo en Reynosa,,https://www.jornada.com.mx/noticia/2021/07/14/estados/grupo-armado-liberan-a-lider-del-cartel-del-golfo-en-reynosa-6494
09-05-25-NOTA-19,2022-06-27,Oaxaca,Oaxaca de Juárez,20067,Cien años de prisión a presunto integrante del Cártel del Golfo,,https://www.jornada.com.mx/noticia/2022/06/27/politica/dictan-cien-anos-de-prision-a-presunto-integrante-del-2018cartel-del-golfo2019-9612
09-05-25-NOTA-20,2022-09-15,Tamaulipas,Matamoros,28022,EU sentencia a cadena perpetua a Jorge Costilla; exlíder del Cártel del Golfo,,https://www.proceso.com.mx/nacional/2022/9/15/eu-sentencia-cadena-perpetua-jorge-costilla-el-coss-exlider-del-cartel-del-golfo-293382.html
09-05-25-NOTA-21,2017-05-24,Zacatecas,Tabasco,32045,Detiene Sedena a El Hamburguesa,,https://www.eluniversal.com.mx/articulo/nacion/seguridad/2017/05/24/detiene-sedena-el-hamburguesa/
09-05-25-NOTA-22,2022-11-29,Tamaulipas,Nuevo Laredo,28025,Capturan al capo El Negrolo tras tiroteo en Nuevo Laredo,,https://www.jornada.com.mx/noticia/2022/11/29/estados/capturan-al-capo-el-negrolo-tras-tiroteo-en-nuevo-laredo-4761
09-05-25-NOTA-23,2023-03-13,Tamaulipas,Reynosa,28032,Sentencian a 12 años de prisión a Bambam; integrante del Cártel del Golfo,,https://www.jornada.com.mx/noticia/2023/03/13/politica/sentencian-a-12-anos-de-prision-a-bambam-integrante-del-cartel-del-golfo-9398
09-05-25-NOTA-24,2023-03-19,Tamaulipas,Reynosa,28032,Sentencian a 465 años de prisión a secuestrador del Cártel del Golfo,,https://www.jornada.com.mx/noticia/2023/03/19/politica/sentencian-465-anos-de-prision-a-secuestrador-del-cartel-del-golfo-3759
09-05-25-NOTA-25,2023-05-01,Tamaulipas,Miguel Alemán,28026,Detienen a jefe de plaza del Cártel del Golfo en Tamaulipas,,https://www.jornada.com.mx/noticia/2023/05/01/politica/detienen-a-jefe-de-plaza-del-2018cartel2019-del-golfo-en-tamaulipas-9628
09-05-25-NOTA-26,2024-03-15,Nuevo León,Escobedo,19020,Cae líder criminal en Escobedo,,https://www.elnorte.com/cae-lider-criminal-en-escobedo/ar2774014
09-05-25-NOTA-27,2024-09-02,Tamaulipas,Altamira,28005,Sentencian a 135 años de prisión a dos integrantes del Cártel del Golfo,,https://www.jornada.com.mx/noticia/2024/09/02/politica/sentencian-135-anos-de-prision-a-dos-integrantes-del-cartel-del-golfo-2085
09-05-25-NOTA-28,2024-09-29,Tamaulipas,Reynosa,28039,Vinculan a proceso de cinco integrantes del cártel el Golfo,,https://www.jornada.com.mx/noticia/2024/09/29/politica/vinculan-a-proceso-de-cinco-integrantes-del-cartel-el-golfo-3830
09-05-25-NOTA-29,2023-07-25,CDMX,Cuauhtémoc,9002,Vinculan a proceso a dos criminales; uno de ellos presuntamente del Cártel de Sinaloa,,https://www.jornada.com.mx/noticia/2023/07/25/politica/vinculan-a-proceso-a-dos-criminales-uno-de-ellos-presuntamente-del-cartel-de-sinaloa-6673
09-05-25-NOTA-30,2023-08-10,Sinaloa,Culiacán,25006,Confirma Sedena detención de presunto jefe de célula del cártel de Sinaloa,,https://www.jornada.com.mx/noticia/2023/08/10/politica/confirma-sedena-detencion-de-presunto-jefe-de-celula-del-cartel-de-sinaloa-7077
09-05-25-NOTA-31,2023-08-13,Sinaloa,Culiacán,25006,Procesan a presunto líder de célula del ‘Cártel de Sinaloa’,,https://www.jornada.com.mx/noticia/2023/08/13/politica/procesan-a-humberto-arredondo-presunto-lider-del-2018cartel-de-sinaloa2019-6609
09-05-25-NOTA-32,2024-06-03,Sinaloa,Culiacán,25006,Vinculan a proceso a dos personas por delitos contra la salud,,https://www.jornada.com.mx/noticia/2024/06/03/sociedad/vinculan-a-proceso-a-dos-personas-por-delitos-contra-la-salud-4558
09-05-25-NOTA-33,2024-06-27,Sinaloa,Culiacán,25006,Detienen en Sinaloa a El Oso; operador del Cártel de Sinaloa,,https://www.jornada.com.mx/noticia/2024/06/27/politica/detienen-en-sinaloa-a-el-oso-operador-del-cartel-de-sinaloa-4752
09-05-25-NOTA-34,2024-10-22,Sinaloa,Culiacán,25006,Detienen a El Oso; presunto operador del cártel del Pacífico en Culiacán,,https://www.jornada.com.mx/noticia/2024/10/22/estados/detiene-sedena-presunto-operador-del-cartel-del-pacifico-en-culiacan-4100
09-05-25-NOTA-35,2024-12-05,Sinaloa,Culiacán,25006,Detienen en Sinaloa a El Gallero; relacionado con histórico decomiso de fentanilo,,https://www.jornada.com.mx/noticia/2024/12/05/politica/detienen-en-sinaloa-a-el-gallero-relacionado-con-historico-decomiso-de-fentanilo-6777
09-05-25-NOTA-36,2024-12-12,Sinaloa,Culiacán,25006,Detienen a dos en Sinaloa con órdenes de extradición a EU,,https://www.jornada.com.mx/noticia/2024/12/12/politica/detienen-a-dos-en-sinaloa-con-ordenes-de-extradicion-a-eu-8077
09-05-25-NOTA-37,2024-12-25,Sinaloa,Culiacán,25006,Tras operativo en Sinaloa capturan a 4 integrantes de Los Chapitos,,https://www.jornada.com.mx/noticia/2024/12/25/politica/tras-operativo-en-sinaloa-capturan-a-4-integrantes-de-los-chapitos-5192
09-05-25-NOTA-38,2024-12-28,Sinaloa,Escuinapa,25009,Sinaloa; detienen al Drácula jefe de Los Chapitos en Escuinapa,,https://www.jornada.com.mx/noticia/2024/12/28/politica/detienen-a-bernal-hernandez-jefe-de-los-chapitos-en-escuinapa-sinaloa-9429
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

