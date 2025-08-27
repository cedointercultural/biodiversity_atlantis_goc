# ============================================
# INTEGRACIÓN: Polígono Personalizado + Biodiversidad
# Combina los datos del generador_poligono.R con ocurrence_records_fixed.R
# ============================================

#' Este script muestra cómo integrar un polígono personalizado
#' generado con generador_poligono.R en el script de biodiversidad

# Limpiar entorno
rm(list=ls())
gc()

# Configurar CRAN
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Librerías necesarias
required_packages <- c(
  "sf", "rgbif", "spocc", "dplyr", "readxl"
)

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# ============================================
# PASO 1: CARGAR DATOS DEL POLÍGONO PERSONALIZADO
# ============================================

# IMPORTANTE: Reemplaza estas variables con los datos generados 
# por tu aplicación generador_poligono.R

# EJEMPLO DE DATOS GENERADOS (reemplaza con tus datos reales):
cat("🔄 Cargando datos del polígono personalizado...\n")

# WKT del polígono principal (viene del generador)
polygon_wkt <- "POLYGON((-110.0 25.0, -105.0 25.0, -105.0 30.0, -110.0 30.0, -110.0 25.0))"

# Grid de WKT polygons para consultas GBIF (viene del generador)
wkt.data <- c(
  "POLYGON((-110.0 25.0, -108.0 25.0, -108.0 27.0, -110.0 27.0, -110.0 25.0))",
  "POLYGON((-108.0 25.0, -106.0 25.0, -106.0 27.0, -108.0 27.0, -108.0 25.0))",
  "POLYGON((-106.0 25.0, -105.0 25.0, -105.0 27.0, -106.0 27.0, -106.0 25.0))",
  "POLYGON((-110.0 27.0, -108.0 27.0, -108.0 30.0, -110.0 30.0, -110.0 27.0))",
  "POLYGON((-108.0 27.0, -106.0 27.0, -106.0 30.0, -108.0 30.0, -108.0 27.0))",
  "POLYGON((-106.0 27.0, -105.0 27.0, -105.0 30.0, -106.0 30.0, -106.0 27.0))"
)

# Grid de bounding boxes para otras APIs (viene del generador)
boxes.data <- c(
  "-110.0,25.0,-108.0,27.0",
  "-108.0,25.0,-106.0,27.0", 
  "-106.0,25.0,-105.0,27.0",
  "-110.0,27.0,-108.0,30.0",
  "-108.0,27.0,-106.0,30.0",
  "-106.0,27.0,-105.0,30.0"
)

# Coordenadas del polígono para filtrado espacial (viene del generador)
coords_matrix <- matrix(c(
  -110.0, 25.0,
  -105.0, 25.0,
  -105.0, 30.0,
  -110.0, 30.0,
  -110.0, 25.0  # Cerrar polígono
), ncol = 2, byrow = TRUE)

# Crear polígono sf
custom_polygon <- st_polygon(list(coords_matrix))
custom_shape <- st_sfc(custom_polygon, crs = st_crs(4326))

cat("✅ Polígono personalizado cargado:\n")
cat("   - Boxes WKT:", length(wkt.data), "\n")
cat("   - Boxes bbox:", length(boxes.data), "\n")
cat("   - Área aprox:", round(5 * 5, 2), "grados²\n\n")

# ============================================
# PASO 2: CONSULTAS DE BIODIVERSIDAD
# ============================================

# Inicializar data frame de biodiversidad
biodiversity <- data.frame(
  species = character(0),
  lon = numeric(0),
  lat = numeric(0),
  year = numeric(0),
  month = numeric(0),
  day = numeric(0),
  date_recorded = character(0),
  source = character(0),
  stringsAsFactors = FALSE
)

# Consultar GBIF con el polígono personalizado
cat("🔍 Consultando GBIF con polígono personalizado...\n")

for (i in seq_len(min(3, length(wkt.data)))) {  # Limitar para demo
  tryCatch({
    cat("Consultando box", i, "de", length(wkt.data), "\n")
    
    gbif_data <- occ_search(
      geometry = wkt.data[i],
      limit = 200,
      hasCoordinate = TRUE
    )
    
    if (!is.null(gbif_data) && !is.null(gbif_data$data) && nrow(gbif_data$data) > 0) {
      data_df <- gbif_data$data
      
      # Procesar datos GBIF
      temp_df <- data.frame(
        species = data_df$scientificName,
        lon = as.numeric(data_df$decimalLongitude),
        lat = as.numeric(data_df$decimalLatitude),
        year = if("year" %in% names(data_df)) as.numeric(data_df$year) else NA,
        month = if("month" %in% names(data_df)) as.numeric(data_df$month) else NA,
        day = if("day" %in% names(data_df)) as.numeric(data_df$day) else NA,
        date_recorded = if("eventDate" %in% names(data_df)) as.character(data_df$eventDate) else NA,
        source = "GBIF",
        stringsAsFactors = FALSE
      )
      
      # Filtrar datos válidos
      temp_df <- temp_df[!is.na(temp_df$species) & !is.na(temp_df$lon) & !is.na(temp_df$lat), ]
      
      if (nrow(temp_df) > 0) {
        biodiversity <- rbind(biodiversity, temp_df)
        cat("   ✓ Box", i, "- agregados", nrow(temp_df), "registros\n")
      }
    }
  }, error = function(e) {
    cat("   ✗ Error en box", i, ":", e$message, "\n")
  })
  
  Sys.sleep(1)  # Pausa entre consultas
}

cat("\n📊 Resultados de consultas:\n")
cat("   - Total registros descargados:", nrow(biodiversity), "\n")

# ============================================
# PASO 3: FILTRADO ESPACIAL CON POLÍGONO PERSONALIZADO
# ============================================

if (nrow(biodiversity) > 0) {
  cat("\n🗺️ Aplicando filtrado espacial con polígono personalizado...\n")
  
  # Convertir a sf
  biodiversity_sf <- st_as_sf(
    biodiversity,
    coords = c("lon", "lat"),
    crs = st_crs(4326)
  )
  
  # Intersección espacial con polígono personalizado
  custom_subset <- st_intersection(biodiversity_sf, custom_shape)
  
  if (nrow(custom_subset) > 0) {
    # Convertir de vuelta a data frame
    coords <- st_coordinates(custom_subset)
    biodiversity_final <- data.frame(
      species = custom_subset$species,
      lon = coords[, "X"],
      lat = coords[, "Y"],
      year = if("year" %in% names(custom_subset)) custom_subset$year else NA,
      month = if("month" %in% names(custom_subset)) custom_subset$month else NA,
      day = if("day" %in% names(custom_subset)) custom_subset$day else NA,
      date_recorded = if("date_recorded" %in% names(custom_subset)) custom_subset$date_recorded else NA,
      source = custom_subset$source,
      stringsAsFactors = FALSE
    )
    
    cat("   ✅ Registros dentro del polígono:", nrow(biodiversity_final), "\n")
  } else {
    cat("   ⚠️ No se encontraron registros dentro del polígono\n")
    biodiversity_final <- biodiversity[0, ]  # Data frame vacío con estructura correcta
  }
} else {
  cat("   ⚠️ No hay datos para filtrar espacialmente\n")
  biodiversity_final <- biodiversity
}

# ============================================
# PASO 4: GUARDAR RESULTADOS
# ============================================

cat("\n💾 Guardando resultados...\n")

# Guardar dataset final
filename <- paste0("biodiversity_custom_polygon_", Sys.Date(), ".csv")
write.csv(biodiversity_final, file = filename, row.names = FALSE)

cat("   ✅ Archivo guardado:", filename, "\n")
cat("   📈 Registros finales:", nrow(biodiversity_final), "\n")

# Resumen de especies únicas
if (nrow(biodiversity_final) > 0) {
  unique_species <- length(unique(biodiversity_final$species[!is.na(biodiversity_final$species)]))
  cat("   🐾 Especies únicas:", unique_species, "\n")
  
  # Mostrar algunas especies como ejemplo
  cat("\n📋 Ejemplos de especies encontradas:\n")
  sample_species <- head(unique(biodiversity_final$species[!is.na(biodiversity_final$species)]), 5)
  for (sp in sample_species) {
    cat("   -", sp, "\n")
  }
}

# ============================================
# RESUMEN DE LA INTEGRACIÓN
# ============================================

# Función de ayuda para concatenar strings
'%+%' <- function(x, y) paste0(x, y)

cat("\n", paste(rep("=", 50), collapse = ""), "\n")
cat("🎉 INTEGRACIÓN COMPLETADA\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

cat("📋 Resumen del proceso:\n")
cat("1. ✅ Polígono personalizado cargado\n")
cat("2. ✅ Consultas GBIF realizadas\n") 
cat("3. ✅ Filtrado espacial aplicado\n")
cat("4. ✅ Resultados guardados\n\n")

cat("📁 Archivos generados:\n")
cat("   -", filename, "\n\n")

cat("🔧 Para usar tu propio polígono:\n")
cat("1. Ejecuta: Rscript generador_poligono.R\n")
cat("2. Dibuja tu polígono en la aplicación web\n")
cat("3. Descarga el código R generado\n")
cat("4. Reemplaza las variables en este script\n")
cat("5. Ejecuta este script con tus datos\n\n")

cat("✨ ¡Proceso completado exitosamente!\n")
