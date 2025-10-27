# ============================================================================
# Script: maxima_query.R
# Descripción: Consulta optimizada para obtener el máximo de registros
# Fecha: 2025-10-17
# ============================================================================

# Establecer directorio de trabajo
setwd("/home/atlantis/biodiversity_atlantis_goc")

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════════╗\n")
cat("║                                                                   ║\n")
cat("║   CONSULTA MÁXIMA DE BIODIVERSIDAD - ZONA DE ESTUDIO COMPLETA    ║\n")
cat("║                                                                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════════╝\n\n")

# Cargar el script principal
cat("📦 Cargando sistema de consultas...\n")
source("scripts/database_queries.R")

cat("\n⚙️  CONFIGURACIÓN DE CONSULTA MÁXIMA:\n")
cat("   • Bases de datos: GBIF, OBIS, iNaturalist, iDigBio\n")
cat("   • Período: 2000-2025 (25 años)\n")
cat("   • Grid: 1.0° × 1.0° (hasta 50 celdas)\n")
cat("   • Registros por celda: hasta 10,000\n")
cat("   • Área: Toda la zona de estudio\n\n")

# Mostrar advertencia de tiempo
cat("⚠️  NOTA: Esta consulta puede tomar varios minutos debido al volumen de datos.\n")
cat("   Se consultarán múltiples bases de datos con amplios parámetros.\n\n")

# Preguntar confirmación
cat("🚀 Iniciando consulta en 3 segundos...\n")
Sys.sleep(3)

# Ejecutar consultas con manejo de errores robusto
start_time <- Sys.time()

results <- tryCatch({
  execute_biodiversity_queries(
    config_file = "scripts/config/query_config_maxima.json",
    polygon_file = "shapefiles/study_zone.gpkg",
    output_dir = "data/query_results"
  )
}, error = function(e) {
  cat("\n❌ ERROR EN LA EJECUCIÓN:\n")
  cat("   ", e$message, "\n\n")
  cat("💡 SUGERENCIAS:\n")
  cat("   1. Verificar conectividad a Internet\n")
  cat("   2. Revisar los logs en data/query_results/\n")
  cat("   3. Reducir el tamaño del grid o número de boxes\n")
  cat("   4. Intentar con menos bases de datos habilitadas\n\n")
  return(NULL)
})

end_time <- Sys.time()
total_time <- difftime(end_time, start_time, units = "mins")

# Mostrar resultados detallados
if (!is.null(results) && nrow(results$results) > 0) {
  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════════╗\n")
  cat("║                                                                   ║\n")
  cat("║                   ANÁLISIS COMPLETO DE RESULTADOS                 ║\n")
  cat("║                                                                   ║\n")
  cat("╚═══════════════════════════════════════════════════════════════════╝\n\n")
  
  # Estadísticas generales
  cat("📊 ESTADÍSTICAS GENERALES\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat("  • Total de registros recuperados:", nrow(results$results), "\n")
  cat("  • Especies únicas identificadas:", length(unique(results$results$species)), "\n")
  cat("  • Tiempo total de ejecución:", round(total_time, 2), "minutos\n")
  cat("  • Celdas del grid consultadas:", nrow(results$grid), "\n\n")
  
  # Distribución por fuente
  cat("🗄️  DISTRIBUCIÓN POR BASE DE DATOS\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  sources_table <- table(results$results$source)
  total_records <- sum(sources_table)
  for (src in names(sources_table)) {
    percentage <- round(sources_table[src] / total_records * 100, 1)
    cat(sprintf("  %-20s: %6d registros (%5.1f%%)\n", 
                src, sources_table[src], percentage))
  }
  cat("\n")
  
  # Análisis temporal
  if (!is.null(results$summary) && !all(is.na(results$summary$year_range))) {
    cat("📅 ANÁLISIS TEMPORAL\n")
    cat("═══════════════════════════════════════════════════════════════════\n")
    cat("  • Período de datos:", results$summary$year_range[1], "-", 
        results$summary$year_range[2], "\n")
    cat("  • Amplitud temporal:", 
        results$summary$year_range[2] - results$summary$year_range[1], "años\n")
    
    # Distribución por década
    results$results$decade <- floor(results$results$year / 10) * 10
    decade_dist <- table(results$results$decade)
    cat("  • Distribución por década:\n")
    for (dec in sort(names(decade_dist))) {
      cat(sprintf("    %s-%s: %d registros\n", dec, as.numeric(dec)+9, decade_dist[dec]))
    }
    cat("\n")
  }
  
  # Análisis espacial
  cat("🌍 ANÁLISIS ESPACIAL\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  if (!is.null(results$summary)) {
    cat("  • Extensión longitudinal:", 
        round(results$summary$coord_range$lon[1], 4), "° a", 
        round(results$summary$coord_range$lon[2], 4), "°\n")
    cat("  • Extensión latitudinal:", 
        round(results$summary$coord_range$lat[1], 4), "° a", 
        round(results$summary$coord_range$lat[2], 4), "°\n")
    
    lon_range <- diff(results$summary$coord_range$lon)
    lat_range <- diff(results$summary$coord_range$lat)
    cat("  • Amplitud longitudinal:", round(lon_range, 2), "°\n")
    cat("  • Amplitud latitudinal:", round(lat_range, 2), "°\n\n")
  }
  
  # Análisis taxonómico
  cat("🦎 ANÁLISIS TAXONÓMICO - TOP 20 ESPECIES\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  top_species <- sort(table(results$results$species), decreasing = TRUE)[1:20]
  for (i in 1:min(20, length(top_species))) {
    cat(sprintf("  %2d. %-40s: %5d registros\n", 
                i, names(top_species)[i], top_species[i]))
  }
  cat("\n")
  
  # Rangos taxonómicos
  if ("taxonRank" %in% names(results$results)) {
    cat("📚 DISTRIBUCIÓN POR RANGO TAXONÓMICO\n")
    cat("═══════════════════════════════════════════════════════════════════\n")
    rank_dist <- table(results$results$taxonRank)
    for (rank in names(rank_dist)) {
      cat(sprintf("  %-20s: %6d registros\n", rank, rank_dist[rank]))
    }
    cat("\n")
  }
  
  # Calidad de datos
  cat("✅ CALIDAD DE DATOS\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat("  • Registros con coordenadas:", nrow(results$results), "(100%)\n")
  cat("  • Registros con fecha:", sum(!is.na(results$results$date_recorded)), 
      sprintf("(%.1f%%)\n", sum(!is.na(results$results$date_recorded))/nrow(results$results)*100))
  cat("  • Registros con año:", sum(!is.na(results$results$year)), 
      sprintf("(%.1f%%)\n", sum(!is.na(results$results$year))/nrow(results$results)*100))
  cat("  • Registros con mes:", sum(!is.na(results$results$month)), 
      sprintf("(%.1f%%)\n", sum(!is.na(results$results$month))/nrow(results$results)*100))
  cat("  • Registros con rango taxonómico:", sum(!is.na(results$results$taxonRank)), 
      sprintf("(%.1f%%)\n", sum(!is.na(results$results$taxonRank))/nrow(results$results)*100))
  cat("\n")
  
  # Muestra de datos
  cat("📝 MUESTRA DE DATOS (10 registros aleatorios)\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  sample_idx <- sample(1:nrow(results$results), min(10, nrow(results$results)))
  print(results$results[sample_idx, c("species", "lon", "lat", "year", "source")])
  cat("\n")
  
  # Archivos generados
  cat("📂 ARCHIVOS GENERADOS\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  output_files <- list.files("data/query_results", 
                             pattern = "biodiversity_.*\\.(csv|json|xlsx)$", 
                             full.names = TRUE)
  output_files <- tail(output_files, 3)
  for (f in output_files) {
    size <- file.size(f)
    size_mb <- round(size / 1024 / 1024, 2)
    cat("  ✓", basename(f), sprintf("(%.2f MB)\n", size_mb))
  }
  cat("\n")
  
  # Resumen final
  cat("╔═══════════════════════════════════════════════════════════════════╗\n")
  cat("║                                                                   ║\n")
  cat("║                    ✅ CONSULTA COMPLETADA EXITOSAMENTE            ║\n")
  cat("║                                                                   ║\n")
  cat("╚═══════════════════════════════════════════════════════════════════╝\n\n")
  
  cat("📍 UBICACIÓN DE RESULTADOS:\n")
  cat("   Directorio: data/query_results/\n")
  cat("   Log: data/query_results/query_execution_maxima.log\n\n")
  
  cat("📊 RESUMEN EJECUTIVO:\n")
  cat(sprintf("   • %d registros de biodiversidad\n", nrow(results$results)))
  cat(sprintf("   • %d especies únicas\n", length(unique(results$results$species))))
  cat(sprintf("   • %d fuentes de datos\n", length(unique(results$results$source))))
  cat(sprintf("   • %.1f minutos de procesamiento\n", total_time))
  cat("\n")
  
  cat("🎯 PRÓXIMOS PASOS SUGERIDOS:\n")
  cat("   1. Revisar los archivos CSV/JSON generados\n")
  cat("   2. Realizar análisis estadísticos adicionales\n")
  cat("   3. Generar visualizaciones y mapas\n")
  cat("   4. Validar la calidad de los datos\n")
  cat("   5. Exportar subconjuntos por taxonomía o región\n\n")
  
} else {
  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════════╗\n")
  cat("║                                                                   ║\n")
  cat("║                    ⚠️  SIN RESULTADOS ENCONTRADOS                 ║\n")
  cat("║                                                                   ║\n")
  cat("╚═══════════════════════════════════════════════════════════════════╝\n\n")
  
  cat("❓ POSIBLES CAUSAS:\n")
  cat("   • Área geográfica sin registros en las bases de datos consultadas\n")
  cat("   • Problemas de conectividad con las APIs\n")
  cat("   • Filtros temporales o espaciales muy restrictivos\n")
  cat("   • Tiempo de espera agotado en las consultas\n\n")
  
  cat("💡 RECOMENDACIONES:\n")
  cat("   1. Verificar conectividad a Internet\n")
  cat("   2. Revisar los logs en data/query_results/query_execution_maxima.log\n")
  cat("   3. Intentar con un área más pequeña o menos boxes\n")
  cat("   4. Ampliar el rango temporal (ej: desde 1900)\n")
  cat("   5. Consultar una base de datos a la vez para diagnosticar\n\n")
  
  cat("📞 DIAGNÓSTICO:\n")
  cat("   Tiempo total:", round(total_time, 2), "minutos\n")
  if (!is.null(results)) {
    cat("   Grid generado:", nrow(results$grid), "celdas\n")
  }
  cat("\n")
}

cat("═══════════════════════════════════════════════════════════════════\n")
cat("Consulta finalizada:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("═══════════════════════════════════════════════════════════════════\n\n")
