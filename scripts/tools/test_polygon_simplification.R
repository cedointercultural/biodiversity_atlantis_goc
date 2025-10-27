# ============================================================================
# Script: test_polygon_simplification.R
# Descripción: Probar simplificación del polígono del Golfo de California
# Fecha: 2025-10-22
# ============================================================================

# Cargar librerías necesarias
library(sf)

# Establecer directorio de trabajo
setwd("/home/atlantis/biodiversity_atlantis_goc")

# Cargar funciones de simplificación
source("scripts/utils/polygon_simplification.R")

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════════╗\n")
cat("║                                                                   ║\n")
cat("║              SIMPLIFICACIÓN DEL POLÍGONO DE ESTUDIO              ║\n")
cat("║                                                                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════════╝\n\n")

# Cargar polígono original
cat("📂 Cargando polígono original...\n")
polygon_original <- st_read("shapefiles/study_zone.gpkg", quiet = TRUE)

# Extraer coordenadas y simplificar
cat("\n🔄 Extrayendo vértices y simplificando...\n")
vertices_data <- extract_polygon_vertices(
  polygon = polygon_original,
  simplify_tolerance = 0.01,  # 0.01 grados ≈ 1 km
  convex_hull = FALSE
)

cat("\n🎯 Probando diferentes métodos de simplificación:\n")
cat("═══════════════════════════════════════════════════════════════════\n")

# Método 1: Bounding Box
cat("\n--- MÉTODO 1: BOUNDING BOX ---\n")
polygon_bbox <- create_api_friendly_polygon(vertices_data$vertices, method = "bbox")

# Método 2: Convex Hull
cat("\n--- MÉTODO 2: CONVEX HULL ---\n")
polygon_convex <- create_api_friendly_polygon(vertices_data$vertices, method = "convex_hull")

# Método 3: Simplificado
cat("\n--- MÉTODO 3: SIMPLIFICADO ---\n")
polygon_simplified <- create_api_friendly_polygon(vertices_data$vertices, method = "simplified")

# Método 4: Grid-Friendly (RECOMENDADO)
cat("\n--- MÉTODO 4: GRID-FRIENDLY (RECOMENDADO) ---\n")
polygon_grid_friendly <- create_api_friendly_polygon(vertices_data$vertices, method = "grid_friendly")

cat("\n📊 COMPARACIÓN DE MÉTODOS:\n")
cat("═══════════════════════════════════════════════════════════════════\n")

methods <- list(
  "Bounding Box" = polygon_bbox,
  "Convex Hull" = polygon_convex,
  "Simplificado" = polygon_simplified,
  "Grid-Friendly" = polygon_grid_friendly
)

for (method_name in names(methods)) {
  method_data <- methods[[method_name]]
  cat(sprintf("%-15s: %s\n", method_name, method_data$bbox_string))
  
  if (method_name == "Grid-Friendly" && !is.null(method_data$grid_info)) {
    cat(sprintf("%-15s  Grid recomendado: %.1f° (%d celdas estimadas)\n", 
                "", method_data$grid_info$recommended_grid_size, 
                method_data$grid_info$max_cells_1deg))
  }
}

cat("\n🔢 Generando grids optimizados:\n")
cat("═══════════════════════════════════════════════════════════════════\n")

# Generar grids con diferentes objetivos
grid_configs <- list(
  "Rápido (10 celdas)" = list(target = 10, max = 15),
  "Equilibrado (20 celdas)" = list(target = 20, max = 30),
  "Detallado (40 celdas)" = list(target = 40, max = 50)
)

for (config_name in names(grid_configs)) {
  config <- grid_configs[[config_name]]
  cat(sprintf("\n--- %s ---\n", toupper(config_name)))
  
  optimized_grid <- generate_optimized_grid(
    polygon_grid_friendly, 
    target_cells = config$target,
    max_cells = config$max
  )
  
  cat(sprintf("Configuración sugerida para JSON:\n"))
  cat(sprintf('  "grid_size_degrees": %.1f,\n', optimized_grid$grid_size))
  cat(sprintf('  "max_boxes": %d\n', optimized_grid$estimated_cells))
}

cat("\n📝 RECOMENDACIONES:\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("1. Usar método 'Grid-Friendly' para mejor cobertura\n")
cat("2. Grid de 1.0° para consultas rápidas (≈15 celdas)\n")
cat("3. Grid de 0.5° para más detalle (≈60 celdas, usar paralelización)\n")
cat("4. Expandir bbox 1% asegura no perder datos en bordes\n\n")

# Generar configuración JSON recomendada
recommended_config <- generate_optimized_grid(polygon_grid_friendly, target_cells = 20, max_cells = 30)

cat("🎯 CONFIGURACIÓN JSON RECOMENDADA:\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat('{\n')
cat('  "spatial": {\n')
cat('    "grid_enabled": true,\n')
cat(sprintf('    "grid_size_degrees": %.1f,\n', recommended_config$grid_size))
cat('    "grid_type": "square",\n')
cat(sprintf('    "max_boxes": %d,\n', recommended_config$estimated_cells))
cat('    "overlap": 0.0\n')
cat('  }\n')
cat('}\n\n')

# Guardar datos para uso posterior
cat("💾 Guardando datos procesados...\n")
save(
  vertices_data,
  polygon_grid_friendly,
  recommended_config,
  file = "data/processed_polygon_data.RData"
)

cat("✓ Datos guardados en: data/processed_polygon_data.RData\n")

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════════╗\n")
cat("║                                                                   ║\n")
cat("║                    ✅ SIMPLIFICACIÓN COMPLETADA                   ║\n")
cat("║                                                                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════════╝\n\n")

cat("🚀 PRÓXIMO PASO:\n")
cat("   Actualizar scripts/config/query_config_maxima.json con la configuración recomendada\n")
cat("   y ejecutar consulta con polígono optimizado.\n\n")