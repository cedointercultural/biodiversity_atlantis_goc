#!/usr/bin/env Rscript

# ============================================================================
# Script: run_query.R
# Descripción: Script para ejecutar consultas de biodiversidad con el 
#              archivo study_zone.gpkg
# ============================================================================

# Establecer directorio de trabajo
setwd("/home/atlantis/biodiversity_atlantis_goc")

cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║   EJECUTANDO CONSULTAS DE BIODIVERSIDAD                    ║\n")
cat("║   Usando: study_zone.gpkg                                  ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n\n")

# Cargar script de consultas
cat("1. Cargando script de consultas...\n")
source("scripts/database_queries.R")

# Ejecutar consultas con configuración por defecto
cat("\n2. Ejecutando consultas...\n\n")

results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json",
  polygon_file = "shapefiles/study_zone.gpkg",
  output_dir = "data/query_results"
)

# Mostrar resumen de resultados
cat("\n")
cat("═════════════════════════════════════════════════════════════\n")
cat("RESUMEN DE RESULTADOS\n")
cat("═════════════════════════════════════════════════════════════\n\n")

if (nrow(results$results) > 0) {
  cat("✓ Total de registros:", nrow(results$results), "\n")
  cat("✓ Especies únicas:", n_distinct(results$results$species), "\n")
  cat("✓ Fuentes de datos:", paste(unique(results$results$source), collapse = ", "), "\n")
  cat("✓ Rango de años:", min(results$results$year, na.rm = TRUE), "-",
      max(results$results$year, na.rm = TRUE), "\n\n")
  
  # Registros por fuente
  cat("Registros por fuente:\n")
  by_source <- table(results$results$source)
  for (source in names(by_source)) {
    cat("  •", source, ":", by_source[[source]], "\n")
  }
  
  cat("\nTop 10 especies encontradas:\n")
  top_sp <- results$results %>%
    group_by(species) %>%
    summarise(n = n(), .groups = "drop") %>%
    arrange(desc(n)) %>%
    head(10)
  
  for (i in 1:nrow(top_sp)) {
    cat("  ", i, ".", top_sp$species[i], "-", top_sp$n[i], "registros\n")
  }
} else {
  cat("⚠ No se encontraron registros en la consulta\n")
}

cat("\n═════════════════════════════════════════════════════════════\n")
cat("✓ Consultas finalizadas\n")
cat("✓ Resultados guardados en: data/query_results/\n")
cat("═════════════════════════════════════════════════════════════\n\n")
