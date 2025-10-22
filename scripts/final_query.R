# ============================================================================
# Script: final_query.R
# Descripción: Script para ejecutar consulta final de biodiversidad
# Fecha: 2025-10-17
# ============================================================================

# Establecer directorio de trabajo
setwd("/home/atlantis/biodiversity_atlantis_goc")

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  CONSULTA FINAL DE BIODIVERSIDAD\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Cargar el script principal
source("scripts/database_queries.R")

# Ejecutar consultas
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config_final.json",
  polygon_file = "shapefiles/study_zone.gpkg",
  output_dir = "data/query_results"
)

# Mostrar resultados detallados
if (!is.null(results) && nrow(results$results) > 0) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("  ANÁLISIS DETALLADO DE RESULTADOS\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
  
  cat("📊 ESTADÍSTICAS GENERALES:\n")
  cat("  • Total de registros:", nrow(results$results), "\n")
  cat("  • Especies únicas:", length(unique(results$results$species)), "\n")
  cat("  • Tiempo de ejecución:", round(results$execution_time, 2), "segundos\n\n")
  
  cat("🗺️  DISTRIBUCIÓN POR FUENTE:\n")
  sources_table <- table(results$results$source)
  for (src in names(sources_table)) {
    cat("  •", src, ":", sources_table[src], "registros\n")
  }
  
  if (!is.null(results$summary)) {
    cat("\n📅 RANGO TEMPORAL:\n")
    if (!all(is.na(results$summary$year_range))) {
      cat("  De", results$summary$year_range[1], "a", results$summary$year_range[2], "\n")
    }
    
    cat("\n🌍 EXTENSIÓN GEOGRÁFICA:\n")
    cat("  Longitud:", round(results$summary$coord_range$lon[1], 4), "°W a", 
        round(results$summary$coord_range$lon[2], 4), "°W\n")
    cat("  Latitud:", round(results$summary$coord_range$lat[1], 4), "°N a", 
        round(results$summary$coord_range$lat[2], 4), "°N\n")
  }
  
  cat("\n🦎 TOP 10 ESPECIES MÁS REGISTRADAS:\n")
  top_species <- sort(table(results$results$species), decreasing = TRUE)[1:10]
  for (i in 1:min(10, length(top_species))) {
    cat("  ", i, ".", names(top_species)[i], ":", top_species[i], "registros\n")
  }
  
  cat("\n📝 MUESTRA DE DATOS (primeros 5 registros):\n")
  print(head(results$results[, c("species", "lon", "lat", "year", "source")], 5))
  
  cat("\n═══════════════════════════════════════════════════════════════\n")
  cat("✓ Consulta completada exitosamente\n")
  cat("  Archivos guardados en: data/query_results/\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
  
} else {
  cat("\n⚠️  No se encontraron registros en esta consulta.\n")
  cat("   Esto puede deberse a:\n")
  cat("   - Área geográfica sin registros en las bases de datos\n")
  cat("   - Filtros temporales muy restrictivos\n")
  cat("   - Problemas de conectividad con las APIs\n\n")
  cat("   Sugerencias:\n")
  cat("   - Ampliar el rango de años en la configuración\n")
  cat("   - Aumentar el tamaño del grid\n")
  cat("   - Habilitar más bases de datos\n\n")
}
