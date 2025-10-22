# ============================================================================
# Script: test_query.R
# Descripción: Script de prueba para ejecutar consultas de biodiversidad
# Fecha: 2025-10-17
# ============================================================================

# Establecer directorio de trabajo
setwd("/home/atlantis/biodiversity_atlantis_goc")

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  PRUEBA DEL SISTEMA DE CONSULTAS DE BIODIVERSIDAD\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Cargar el script principal
cat("Cargando módulos...\n")
tryCatch({
  source("scripts/database_queries.R")
  cat("✓ Módulos cargados exitosamente\n\n")
}, error = function(e) {
  cat("✗ Error al cargar módulos:\n")
  cat(e$message, "\n")
  stop(e)
})

# Ejecutar consultas
cat("Iniciando consultas de biodiversidad...\n")
cat("───────────────────────────────────────────────────────────────\n\n")

results <- tryCatch({
  execute_biodiversity_queries(
    config_file = "scripts/query_config.json",
    polygon_file = "shapefiles/study_zone.gpkg",
    output_dir = "data/query_results"
  )
}, error = function(e) {
  cat("\n✗ ERROR EN LA EJECUCIÓN:\n")
  cat(e$message, "\n")
  traceback()
  return(NULL)
})

# Mostrar resultados
if (!is.null(results)) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("  RESUMEN DE RESULTADOS\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
  
  if (nrow(results$results) > 0) {
    cat("Total de registros:", nrow(results$results), "\n")
    cat("Especies únicas:", length(unique(results$results$species)), "\n")
    cat("Fuentes de datos:\n")
    print(table(results$results$source))
    
    if (!is.null(results$summary)) {
      cat("\nRango temporal:", 
          results$summary$year_range[1], "-", 
          results$summary$year_range[2], "\n")
      cat("Rango espacial:\n")
      cat("  Longitud:", 
          round(results$summary$coord_range$lon[1], 4), "a", 
          round(results$summary$coord_range$lon[2], 4), "\n")
      cat("  Latitud:", 
          round(results$summary$coord_range$lat[1], 4), "a", 
          round(results$summary$coord_range$lat[2], 4), "\n")
    }
    
    cat("\nPrimeros 10 registros:\n")
    print(head(results$results, 10))
    
  } else {
    cat("⚠ No se encontraron registros\n")
  }
  
  cat("\n═══════════════════════════════════════════════════════════════\n")
  cat("✓ Prueba completada\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
} else {
  cat("\n✗ La ejecución falló\n\n")
}
