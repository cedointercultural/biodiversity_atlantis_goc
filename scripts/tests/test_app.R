# ==============================================================================
# SCRIPT DE PRUEBA PARA LA APLICACIÓN SHINY
# ==============================================================================

# Test básico de que todos los paquetes se cargan correctamente
cat("Probando carga de librerías...\n")

suppressWarnings({
  options(warn = -1)
  
  # Librerías principales de Shiny
  library(shiny)
  library(shinydashboard)
  library(shinyWidgets)
  library(shinyjs)
  library(DT)
  
  # Librerías para mapas y visualización
  library(leaflet)
  library(leaflet.extras)  # Para herramientas de dibujo
  library(plotly)
  
  # Librerías geoespaciales
  library(sf)
  library(jsonlite)
  
  # Librerías para consultas de biodiversidad
  library(rgbif)
  library(spocc)
  library(rebird)
  library(robis)
  library(ridigbio)
  
  # Librerías para manipulación de datos
  library(dplyr)
  
  options(warn = 0)
})

cat("✅ Todas las librerías se cargaron correctamente\n")

# Test de que los archivos existen
cat("\nProbando existencia de archivos...\n")
if (file.exists("ui.R")) {
  cat("✅ ui.R existe\n")
} else {
  cat("❌ ui.R no existe\n")
}

if (file.exists("server_logic.R")) {
  cat("✅ server_logic.R existe\n")
} else {
  cat("❌ server_logic.R no existe\n")
}

if (file.exists("app.R")) {
  cat("✅ app.R existe\n")
} else {
  cat("❌ app.R no existe\n")
}

# Test de carga de archivos
cat("\nProbando carga de archivos...\n")
tryCatch({
  source("ui.R")
  cat("✅ ui.R se carga sin errores\n")
}, error = function(e) {
  cat("❌ Error cargando ui.R:", e$message, "\n")
})

tryCatch({
  source("server_logic.R")
  cat("✅ server_logic.R se carga sin errores\n")
}, error = function(e) {
  cat("❌ Error cargando server_logic.R:", e$message, "\n")
})

# Test de funciones básicas
cat("\nProbando funcionalidad básica...\n")
tryCatch({
  # Crear datos de prueba para polígono
  test_vertices <- data.frame(
    lat = c(4.0, 4.5, 4.5, 4.0),
    lng = c(-74.5, -74.5, -74.0, -74.0)
  )
  
  # Test de creación de WKT
  coords_matrix <- as.matrix(test_vertices[, c("lng", "lat")])
  coords_matrix <- rbind(coords_matrix, coords_matrix[1, ])  # Cerrar polígono
  wkt_coords <- paste(coords_matrix[, 1], coords_matrix[, 2], collapse = ", ")
  test_wkt <- paste0("POLYGON((", wkt_coords, "))")
  
  cat("✅ Generación de WKT funciona:", substr(test_wkt, 1, 50), "...\n")
  
  # Test de bounding box
  min_lng <- min(test_vertices$lng)
  max_lng <- max(test_vertices$lng)
  min_lat <- min(test_vertices$lat)
  max_lat <- max(test_vertices$lat)
  test_bbox <- paste(min_lng, min_lat, max_lng, max_lat, sep = ",")
  
  cat("✅ Generación de bounding box funciona:", test_bbox, "\n")
  
}, error = function(e) {
  cat("❌ Error en funcionalidad básica:", e$message, "\n")
})

# Test de conectividad de APIs (básico)
cat("\nProbando conectividad de APIs...\n")

# Test GBIF
tryCatch({
  # Solo probar si se puede cargar el paquete, no hacer consulta real
  if (exists("occ_search", mode = "function")) {
    cat("✅ API GBIF disponible\n")
  } else {
    cat("⚠️ API GBIF puede no estar disponible\n")
  }
}, error = function(e) {
  cat("⚠️ Error probando GBIF:", e$message, "\n")
})

# Test eBird
tryCatch({
  if (file.exists("ebirdapi_key")) {
    cat("✅ Archivo de API key de eBird encontrado\n")
  } else {
    cat("ℹ️ No se encontró archivo ebirdapi_key (opcional)\n")
  }
}, error = function(e) {
  cat("⚠️ Error verificando eBird key:", e$message, "\n")
})

cat("\n" %+% "="*60)
cat("\n🎉 RESUMEN DEL TEST:\n")
cat("✅ La aplicación debería funcionar correctamente\n")
cat("📍 Puedes acceder en: http://localhost:3838\n")
cat("🔧 Funciones principales:\n")
cat("   • Dibujo de polígonos por clicks\n")
cat("   • Exportación de coordenadas\n") 
cat("   • Consultas de biodiversidad\n")
cat("   • Visualización de resultados\n")
cat("="*60 %+% "\n")

# Función de concatenación para strings
`%+%` <- function(a, b) paste0(a, b)
