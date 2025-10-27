# ============================================================================
# Script: maxima_query_parallel.R
# Descripción: Consulta optimizada PARALELA para obtener el máximo de registros
# Fecha: 2025-10-18
# ============================================================================

# Establecer directorio de trabajo
setwd("/home/atlantis/biodiversity_atlantis_goc")

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════════╗\n")
cat("║                                                                   ║\n")
cat("║   CONSULTA PARALELA - MÁXIMA BIODIVERSIDAD                        ║\n")
cat("║                                                                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════════╝\n\n")

# Cargar el script principal
cat("📦 Cargando sistema de consultas...\n")
source("scripts/database_queries.R")

cat("\n⚙️  CONFIGURACIÓN DE CONSULTA PARALELA:\n")
cat("   • Bases de datos: GBIF, OBIS, iNaturalist, iDigBio\n")
cat("   • Período: 2000-2025 (25 años)\n")
cat("   • Grid: 2.0° × 2.0° (optimizado para paralelización)\n")
cat("   • Procesamiento: PARALELO con múltiples núcleos\n")
cat("   • Registros por celda: hasta 10,000\n")
cat("   • Área: Toda la zona de estudio\n\n")

# Detectar núcleos disponibles
n_cores_available <- parallel::detectCores()
n_cores_use <- max(1, n_cores_available - 1)

cat(sprintf("🖥️  RECURSOS DE CÓMPUTO:\n"))
cat(sprintf("   • Núcleos CPU disponibles: %d\n", n_cores_available))
cat(sprintf("   • Núcleos a utilizar: %d\n", n_cores_use))
cat(sprintf("   • Núcleo reservado para sistema: 1\n\n"))

# Mostrar advertencia de tiempo
cat("⚠️  NOTA: Esta consulta paralela puede ser más rápida pero consumirá\n")
cat("   más recursos del sistema. Se recomienda cerrar aplicaciones pesadas.\n\n")

# Preguntar confirmación
cat("🚀 Iniciando consulta paralela en 3 segundos...\n")
Sys.sleep(3)

# Ejecutar consultas con paralelización
start_time <- Sys.time()

results <- tryCatch({
  execute_biodiversity_queries(
    config_file = "scripts/config/query_config_maxima.json",
    polygon_file = "shapefiles/study_zone.gpkg",
    output_dir = "data/query_results",
    parallel = TRUE,           # ✨ Habilitar paralelización
    n_cores = n_cores_use      # ✨ Especificar núcleos
  )
}, error = function(e) {
  cat("\n❌ ERROR EN LA EJECUCIÓN:\n")
  cat("   ", e$message, "\n\n")
  cat("💡 SUGERENCIAS:\n")
  cat("   1. Verificar conectividad a Internet\n")
  cat("   2. Revisar los logs en data/query_results/\n")
  cat("   3. Intentar con parallel = FALSE (modo secuencial)\n")
  cat("   4. Reducir el tamaño del grid\n\n")
  return(NULL)
})

# Calcular tiempo de ejecución
end_time <- Sys.time()
execution_time <- difftime(end_time, start_time, units = "mins")

# Mostrar resumen si hay resultados
if (!is.null(results) && !is.null(results$data) && nrow(results$data) > 0) {
  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════════╗\n")
  cat("║                                                                   ║\n")
  cat("║                   ANÁLISIS COMPLETO DE RESULTADOS                 ║\n")
  cat("║                                                                   ║\n")
  cat("╚═══════════════════════════════════════════════════════════════════╝\n\n")
  
  data <- results$data
  
  # Estadísticas generales
  cat("📊 ESTADÍSTICAS GENERALES\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat(sprintf("  • Total de registros recuperados: %d \n", nrow(data)))
  cat(sprintf("  • Especies únicas identificadas: %d \n", 
              length(unique(data$species[!is.na(data$species)]))))
  cat(sprintf("  • Tiempo total de ejecución: %.2f minutos\n", as.numeric(execution_time)))
  
  if (!is.null(results$metadata$grid_info)) {
    cat(sprintf("  • Celdas del grid consultadas: %d \n", 
                results$metadata$grid_info$n_boxes))
    cat(sprintf("  • Velocidad: %.1f registros/minuto\n", 
                nrow(data) / as.numeric(execution_time)))
  }
  cat("\n")
  
  # Distribución por fuente
  cat("🗄️  DISTRIBUCIÓN POR BASE DE DATOS\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  source_counts <- table(data$source)
  for (source in names(source_counts)) {
    pct <- 100 * source_counts[source] / nrow(data)
    cat(sprintf("  %-20s: %6d registros (%5.1f%%)\n", source, 
                source_counts[source], pct))
  }
  cat("\n")
  
  # Análisis temporal
  if ("year" %in% colnames(data) && any(!is.na(data$year))) {
    cat("📅 ANÁLISIS TEMPORAL\n")
    cat("═══════════════════════════════════════════════════════════════════\n")
    years <- data$year[!is.na(data$year)]
    cat(sprintf("  • Período de datos: %d - %d \n", min(years), max(years)))
    cat(sprintf("  • Amplitud temporal: %d años\n", max(years) - min(years)))
    
    # Distribución por década
    decades <- floor(years / 10) * 10
    decade_counts <- table(decades)
    cat("  • Distribución por década:\n")
    for (decade in sort(names(decade_counts))) {
      cat(sprintf("    %s-%s: %d registros\n", decade, 
                  as.numeric(decade) + 9, decade_counts[decade]))
    }
    cat("\n")
  }
  
  # Análisis espacial
  if ("lon" %in% colnames(data) && "lat" %in% colnames(data)) {
    cat("🌍 ANÁLISIS ESPACIAL\n")
    cat("═══════════════════════════════════════════════════════════════════\n")
    valid_coords <- !is.na(data$lon) & !is.na(data$lat)
    cat(sprintf("  • Extensión longitudinal: %.4f ° a %.4f °\n", 
                min(data$lon[valid_coords]), max(data$lon[valid_coords])))
    cat(sprintf("  • Extensión latitudinal: %.4f ° a %.4f °\n", 
                min(data$lat[valid_coords]), max(data$lat[valid_coords])))
    cat(sprintf("  • Amplitud longitudinal: %.2f °\n", 
                max(data$lon[valid_coords]) - min(data$lon[valid_coords])))
    cat(sprintf("  • Amplitud latitudinal: %.2f °\n", 
                max(data$lat[valid_coords]) - min(data$lat[valid_coords])))
    cat("\n")
  }
  
  # Top especies
  cat("🦎 ANÁLISIS TAXONÓMICO - TOP 20 ESPECIES\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  species_counts <- sort(table(data$species), decreasing = TRUE)
  top_species <- head(species_counts, 20)
  for (i in 1:length(top_species)) {
    cat(sprintf("  %2d. %-40s : %5d registros\n", i, 
                names(top_species)[i], top_species[i]))
  }
  cat("\n")
  
  # Calidad de datos
  cat("✅ CALIDAD DE DATOS\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat(sprintf("  • Registros con coordenadas: %d (%.1f%%)\n", 
              sum(!is.na(data$lon) & !is.na(data$lat)),
              100 * sum(!is.na(data$lon) & !is.na(data$lat)) / nrow(data)))
  
  if ("date" %in% colnames(data)) {
    cat(sprintf("  • Registros con fecha: %d (%.1f%%)\n", 
                sum(!is.na(data$date)),
                100 * sum(!is.na(data$date)) / nrow(data)))
  }
  
  if ("year" %in% colnames(data)) {
    cat(sprintf("  • Registros con año: %d (%.1f%%)\n", 
                sum(!is.na(data$year)),
                100 * sum(!is.na(data$year)) / nrow(data)))
  }
  
  cat("\n")
  
  # Muestra de datos
  cat("📝 MUESTRA DE DATOS (10 registros aleatorios)\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  sample_indices <- sample(1:nrow(data), min(10, nrow(data)))
  sample_data <- data[sample_indices, c("species", "lon", "lat", "year", "source")]
  print(sample_data)
  cat("\n")
  
  # Archivos generados
  if (!is.null(results$files)) {
    cat("📂 ARCHIVOS GENERADOS\n")
    cat("═══════════════════════════════════════════════════════════════════\n")
    for (file in results$files) {
      if (file.exists(file)) {
        size_mb <- file.info(file)$size / 1024 / 1024
        cat(sprintf("  ✓ %s (%.2f MB)\n", basename(file), size_mb))
      }
    }
    cat("\n")
  }
  
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
  cat("   • Error en el procesamiento paralelo (intente modo secuencial)\n\n")
}

# Resumen final
cat("╔═══════════════════════════════════════════════════════════════════╗\n")
cat("║                                                                   ║\n")
cat("║                    ✅ CONSULTA PARALELA COMPLETADA                ║\n")
cat("║                                                                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════════╝\n\n")

if (!is.null(results)) {
  cat("📍 UBICACIÓN DE RESULTADOS:\n")
  cat("   Directorio: data/query_results/\n")
  cat("   Log: data/query_results/query_execution_maxima.log\n\n")
  
  if (!is.null(results$data)) {
    cat("📊 RESUMEN EJECUTIVO:\n")
    cat(sprintf("   • %d registros de biodiversidad\n", nrow(results$data)))
    cat(sprintf("   • %d especies únicas\n", 
                length(unique(results$data$species[!is.na(results$data$species)]))))
    cat(sprintf("   • %d fuentes de datos\n", length(unique(results$data$source))))
    cat(sprintf("   • %.1f minutos de procesamiento\n", as.numeric(execution_time)))
    cat(sprintf("   • %.1f registros/minuto (velocidad paralela)\n\n", 
                nrow(results$data) / as.numeric(execution_time)))
  }
  
  cat("🎯 PRÓXIMOS PASOS SUGERIDOS:\n")
  cat("   1. Revisar los archivos CSV/JSON generados\n")
  cat("   2. Realizar análisis estadísticos adicionales\n")
  cat("   3. Generar visualizaciones y mapas\n")
  cat("   4. Validar la calidad de los datos\n")
  cat("   5. Exportar subconjuntos por taxonomía o región\n\n")
}

cat("═══════════════════════════════════════════════════════════════════\n")
cat("Consulta finalizada:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("═══════════════════════════════════════════════════════════════════\n")
