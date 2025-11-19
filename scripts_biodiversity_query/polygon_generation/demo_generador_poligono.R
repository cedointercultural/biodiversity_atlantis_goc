# ============================================
# DEMOSTRACIÓN: Uso del Generador de Polígonos
# ============================================

# Para ejecutar el generador de polígonos:
# 1. Asegúrate de tener las librerías instaladas
# 2. Ejecuta: Rscript generador_poligono.R
# 3. Abre tu navegador en la URL que aparezca (usualmente http://127.0.0.1:XXXX)

# Cuando ejecutes el generador de polígonos podrás:
# 1. Dibujar un polígono personalizado en el mapa
# 2. Generar automáticamente los datos necesarios para el script de biodiversidad
# 3. Exportar código R listo para usar

# Ejemplo de uso después de generar un polígono:

# ============================================
# CÓDIGO GENERADO AUTOMÁTICAMENTE 
# (Este ejemplo muestra el formato de salida)
# ============================================

library(sf)
library(rgbif)

# Ejemplo de datos que generará la aplicación:

# WKT del polígono principal (ejemplo)
polygon_wkt <- "POLYGON((-110.0 25.0, -105.0 25.0, -105.0 30.0, -110.0 30.0, -110.0 25.0))"

# Bounding box principal (min_lng,min_lat,max_lng,max_lat)
main_bbox <- "-110.0,25.0,-105.0,30.0"

# Grid de WKT polygons para consultas GBIF (ejemplo con grid de 2x2 grados)
wkt.data <- c(
  "POLYGON((-110.0 25.0, -108.0 25.0, -108.0 27.0, -110.0 27.0, -110.0 25.0))",
  "POLYGON((-108.0 25.0, -106.0 25.0, -106.0 27.0, -108.0 27.0, -108.0 25.0))",
  "POLYGON((-106.0 25.0, -105.0 25.0, -105.0 27.0, -106.0 27.0, -106.0 25.0))",
  "POLYGON((-110.0 27.0, -108.0 27.0, -108.0 30.0, -110.0 30.0, -110.0 27.0))",
  "POLYGON((-108.0 27.0, -106.0 27.0, -106.0 30.0, -108.0 30.0, -108.0 27.0))",
  "POLYGON((-106.0 27.0, -105.0 27.0, -105.0 30.0, -106.0 30.0, -106.0 27.0))"
)

# Grid de bounding boxes para otras APIs
boxes.data <- c(
  "-110.0,25.0,-108.0,27.0",
  "-108.0,25.0,-106.0,27.0", 
  "-106.0,25.0,-105.0,27.0",
  "-110.0,27.0,-108.0,30.0",
  "-108.0,27.0,-106.0,30.0",
  "-106.0,27.0,-105.0,30.0"
)

# Crear polígono sf para filtrado espacial
coords_matrix <- matrix(c(
  -110.0, 25.0,
  -105.0, 25.0,
  -105.0, 30.0,
  -110.0, 30.0,
  -110.0, 25.0  # Cerrar polígono
), ncol = 2, byrow = TRUE)

custom_polygon <- st_polygon(list(coords_matrix))
custom_shape <- st_sfc(custom_polygon, crs = st_crs(4326))

# ============================================
# INTEGRACIÓN CON SCRIPT DE BIODIVERSIDAD
# ============================================

# Para usar estos datos en el script de biodiversidad:
# 1. Reemplaza las variables wkt.data y boxes.data en ocurrence_records_fixed.R
# 2. Reemplaza goc.shape con custom_shape para el filtrado espacial
# 3. Ejecuta el script normalmente

cat('Datos del polígono personalizado cargados:\n')
cat('- WKT polygons:', length(wkt.data), '\n')
cat('- Bounding boxes:', length(boxes.data), '\n')
cat('- Área aproximada:', round(5 * 5, 2), 'grados cuadrados\n')

# ============================================
# INSTRUCCIONES DE USO
# ============================================

cat('\n=== INSTRUCCIONES DE USO ===\n')
cat('1. Ejecuta el generador de polígonos:\n')
cat('   Rscript generador_poligono.R\n\n')
cat('2. En la aplicación web:\n')
cat('   - Ve a la pestaña "Mapa"\n')
cat('   - Haz clic en "Comenzar Dibujo"\n')
cat('   - Dibuja tu polígono en el mapa\n')
cat('   - Haz clic en "Finalizar Polígono"\n\n')
cat('3. Ve a la pestaña "Datos para Scripts":\n')
cat('   - Ajusta el tamaño de grid si es necesario\n')
cat('   - Descarga el código R generado\n')
cat('   - Integra los datos en tu script de biodiversidad\n\n')
cat('4. Uso en script de biodiversidad:\n')
cat('   - Reemplaza wkt.data con los datos generados\n')
cat('   - Reemplaza boxes.data con los datos generados\n')
cat('   - Usa custom_shape para filtrado espacial\n')
