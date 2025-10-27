# ============================================================================
# Script: polygon_simplification.R
# Descripción: Simplificación de polígonos complejos para consultas a APIs
# Autor: Sistema de consultas de biodiversidad
# Fecha: 2025-10-22
# ============================================================================

#' Extraer coordenadas de vértices de un polígono complejo
#'
#' Convierte un MULTIPOLYGON complejo en coordenadas de vértices simples
#' apropiadas para consultas a bases de datos
#'
#' @param polygon Objeto sf con geometría compleja
#' @param simplify_tolerance Tolerancia para simplificación (grados, default: 0.01)
#' @param convex_hull Usar convex hull para simplificar (default: FALSE)
#' @return Lista con coordenadas de vértices y polígono simplificado
#' @export
extract_polygon_vertices <- function(polygon, simplify_tolerance = 0.01, convex_hull = FALSE) {
  
  cat("📐 ANÁLISIS DEL POLÍGONO ORIGINAL:\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  
  # Información básica
  geom_type <- st_geometry_type(polygon)[1]
  n_features <- nrow(polygon)
  bbox_orig <- st_bbox(polygon)
  coords_orig <- st_coordinates(polygon)
  n_points_orig <- nrow(coords_orig)
  
  cat(sprintf("• Tipo de geometría: %s\n", geom_type))
  cat(sprintf("• Número de features: %d\n", n_features))
  cat(sprintf("• Número de puntos: %d\n", n_points_orig))
  cat(sprintf("• Bounding box: [%.4f, %.4f] a [%.4f, %.4f]\n", 
              bbox_orig[1], bbox_orig[2], bbox_orig[3], bbox_orig[4]))
  
  area_orig <- sum(as.numeric(st_area(polygon))) / 1e6
  cat(sprintf("• Área total: %.2f km²\n\n", area_orig))
  
  # Unir todas las geometrías en una sola
  cat("🔄 PROCESANDO POLÍGONO:\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  
  # Unir todos los polígonos en uno solo
  polygon_union <- st_union(polygon)
  cat("✓ Polígonos unidos en geometría única\n")
  
  # Aplicar simplificación si se especifica
  if (simplify_tolerance > 0) {
    polygon_simplified <- st_simplify(polygon_union, dTolerance = simplify_tolerance)
    cat(sprintf("✓ Polígono simplificado (tolerancia: %.3f grados)\n", simplify_tolerance))
  } else {
    polygon_simplified <- polygon_union
  }
  
  # Aplicar convex hull si se especifica
  if (convex_hull) {
    polygon_simplified <- st_convex_hull(polygon_simplified)
    cat("✓ Aplicado convex hull (envolvente convexa)\n")
  }
  
  # Extraer coordenadas del polígono simplificado
  coords_simplified <- st_coordinates(polygon_simplified)
  n_points_simplified <- nrow(coords_simplified)
  
  cat(sprintf("✓ Puntos reducidos: %d → %d (reducción: %.1f%%)\n", 
              n_points_orig, n_points_simplified, 
              100 * (1 - n_points_simplified / n_points_orig)))
  
  # Calcular nueva área
  area_simplified <- as.numeric(st_area(polygon_simplified)) / 1e6
  cat(sprintf("✓ Área conservada: %.2f km² (%.1f%% del original)\n\n", 
              area_simplified, 100 * area_simplified / area_orig))
  
  # Extraer vértices únicos
  vertices <- unique(coords_simplified[, c("X", "Y")])
  colnames(vertices) <- c("lon", "lat")
  
  # Obtener bounding box del polígono simplificado
  bbox_simplified <- st_bbox(polygon_simplified)
  
  cat("📊 RESULTADOS:\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat(sprintf("• Vértices únicos extraídos: %d\n", nrow(vertices)))
  cat(sprintf("• Rango longitudinal: %.4f° a %.4f° (amplitud: %.4f°)\n", 
              min(vertices[, "lon"]), max(vertices[, "lon"]), 
              diff(range(vertices[, "lon"]))))
  cat(sprintf("• Rango latitudinal: %.4f° a %.4f° (amplitud: %.4f°)\n", 
              min(vertices[, "lat"]), max(vertices[, "lat"]), 
              diff(range(vertices[, "lat"]))))
  
  return(list(
    vertices = vertices,
    polygon_simplified = polygon_simplified,
    bbox_original = bbox_orig,
    bbox_simplified = bbox_simplified,
    coordinates_original = coords_orig,
    coordinates_simplified = coords_simplified,
    stats = list(
      n_features_original = n_features,
      n_points_original = n_points_orig,
      n_points_simplified = n_points_simplified,
      area_original_km2 = area_orig,
      area_simplified_km2 = area_simplified,
      reduction_percentage = 100 * (1 - n_points_simplified / n_points_orig),
      area_conservation_percentage = 100 * area_simplified / area_orig
    )
  ))
}


#' Crear polígono apropiado para consultas a bases de datos
#'
#' Genera diferentes versiones de polígono optimizadas para APIs específicas
#'
#' @param vertices Matrix o data frame con columnas lon, lat
#' @param method Método de simplificación: "bbox", "convex_hull", "simplified", "grid_friendly"
#' @return Lista con polígono y parámetros para APIs
#' @export
create_api_friendly_polygon <- function(vertices, method = "grid_friendly") {
  
  cat(sprintf("\n🎯 CREANDO POLÍGONO PARA APIs (método: %s):\n", method))
  cat("═══════════════════════════════════════════════════════════════\n")
  
  result <- list(method = method)
  
  if (method == "bbox") {
    # Método 1: Bounding box simple (rectángulo)
    min_lon <- min(vertices[, "lon"])
    max_lon <- max(vertices[, "lon"])
    min_lat <- min(vertices[, "lat"])
    max_lat <- max(vertices[, "lat"])
    
    # Crear rectángulo
    bbox_coords <- matrix(c(
      min_lon, min_lat,
      max_lon, min_lat,
      max_lon, max_lat,
      min_lon, max_lat,
      min_lon, min_lat
    ), ncol = 2, byrow = TRUE)
    
    result$coordinates <- bbox_coords
    result$wkt <- sprintf("POLYGON((%s))", 
                         paste(apply(bbox_coords, 1, function(x) paste(x[1], x[2])), collapse = ","))
    result$bbox_string <- paste(min_lon, min_lat, max_lon, max_lat, sep = ",")
    
    cat("✓ Polígono rectangular (bounding box)\n")
    cat(sprintf("  Coordenadas: [%.4f, %.4f] a [%.4f, %.4f]\n", min_lon, min_lat, max_lon, max_lat))
    
  } else if (method == "convex_hull") {
    # Método 2: Convex hull de los vértices
    vertices_sf <- st_sfc(st_multipoint(vertices), crs = 4326)
    hull <- st_convex_hull(vertices_sf)
    hull_coords <- st_coordinates(hull)[, c("X", "Y")]
    
    result$coordinates <- hull_coords
    result$wkt <- st_as_text(hull)
    
    # Calcular bbox del convex hull
    hull_bbox <- st_bbox(hull)
    result$bbox_string <- paste(hull_bbox[1], hull_bbox[2], hull_bbox[3], hull_bbox[4], sep = ",")
    
    cat("✓ Polígono convex hull (envolvente convexa)\n")
    cat(sprintf("  Vértices: %d\n", nrow(hull_coords)))
    
  } else if (method == "simplified") {
    # Método 3: Polígono simplificado manteniendo forma aproximada
    # Tomar cada N vértices para reducir complejidad
    n_vertices <- nrow(vertices)
    step <- max(1, round(n_vertices / 50))  # Máximo 50 vértices
    simplified_indices <- seq(1, n_vertices, by = step)
    
    simplified_coords <- vertices[simplified_indices, ]
    
    # Asegurar que el polígono esté cerrado
    if (!all(simplified_coords[1, ] == simplified_coords[nrow(simplified_coords), ])) {
      simplified_coords <- rbind(simplified_coords, simplified_coords[1, ])
    }
    
    result$coordinates <- simplified_coords
    result$wkt <- sprintf("POLYGON((%s))", 
                         paste(apply(simplified_coords, 1, function(x) paste(x[1], x[2])), collapse = ","))
    
    # Calcular bbox
    bbox <- c(min(simplified_coords[, "lon"]), min(simplified_coords[, "lat"]),
              max(simplified_coords[, "lon"]), max(simplified_coords[, "lat"]))
    result$bbox_string <- paste(bbox, collapse = ",")
    
    cat("✓ Polígono simplificado\n")
    cat(sprintf("  Vértices: %d → %d (cada %d puntos)\n", n_vertices, nrow(simplified_coords), step))
    
  } else if (method == "grid_friendly") {
    # Método 4: Optimizado para generar grids efectivos
    # Usar bounding box pero expandido ligeramente para asegurar cobertura
    min_lon <- min(vertices[, "lon"])
    max_lon <- max(vertices[, "lon"])
    min_lat <- min(vertices[, "lat"])
    max_lat <- max(vertices[, "lat"])
    
    # Expandir 1% en cada dirección para asegurar cobertura
    lon_range <- max_lon - min_lon
    lat_range <- max_lat - min_lat
    expansion <- 0.01  # 1%
    
    min_lon <- min_lon - lon_range * expansion
    max_lon <- max_lon + lon_range * expansion
    min_lat <- min_lat - lat_range * expansion
    max_lat <- max_lat + lat_range * expansion
    
    # Crear rectángulo expandido
    bbox_coords <- matrix(c(
      min_lon, min_lat,
      max_lon, min_lat,
      max_lon, max_lat,
      min_lon, max_lat,
      min_lon, min_lat
    ), ncol = 2, byrow = TRUE)
    
    result$coordinates <- bbox_coords
    result$wkt <- sprintf("POLYGON((%s))", 
                         paste(apply(bbox_coords, 1, function(x) paste(x[1], x[2])), collapse = ","))
    result$bbox_string <- paste(min_lon, min_lat, max_lon, max_lat, sep = ",")
    
    # Calcular dimensiones para grid
    result$grid_info <- list(
      lon_range = max_lon - min_lon,
      lat_range = max_lat - min_lat,
      recommended_grid_size = min(2.0, max(0.5, min(lon_range, lat_range) / 10)),
      max_cells_1deg = ceiling((max_lon - min_lon)) * ceiling((max_lat - min_lat)),
      max_cells_05deg = ceiling((max_lon - min_lon) * 2) * ceiling((max_lat - min_lat) * 2)
    )
    
    cat("✓ Polígono optimizado para grid\n")
    cat(sprintf("  Coordenadas expandidas: [%.4f, %.4f] a [%.4f, %.4f]\n", min_lon, min_lat, max_lon, max_lat))
    cat(sprintf("  Expansión aplicada: %.1f%%\n", expansion * 100))
    cat(sprintf("  Dimensiones: %.2f° × %.2f°\n", lon_range, lat_range))
    cat(sprintf("  Grid recomendado: %.1f°\n", result$grid_info$recommended_grid_size))
    cat(sprintf("  Celdas estimadas (1°): %d\n", result$grid_info$max_cells_1deg))
    cat(sprintf("  Celdas estimadas (0.5°): %d\n", result$grid_info$max_cells_05deg))
  }
  
  return(result)
}


#' Generar grid optimizado para polígono simplificado
#'
#' Crea un grid eficiente basado en las características del polígono
#'
#' @param api_polygon Resultado de create_api_friendly_polygon()
#' @param target_cells Número objetivo de celdas (default: 20)
#' @param max_cells Número máximo de celdas (default: 50)
#' @return Data frame con grid optimizado
#' @export
generate_optimized_grid <- function(api_polygon, target_cells = 20, max_cells = 50) {
  
  cat(sprintf("\n🔢 GENERANDO GRID OPTIMIZADO (objetivo: %d celdas, máximo: %d):\n", target_cells, max_cells))
  cat("═══════════════════════════════════════════════════════════════\n")
  
  if (api_polygon$method == "grid_friendly" && !is.null(api_polygon$grid_info)) {
    # Usar información del grid calculada
    grid_info <- api_polygon$grid_info
    
    # Calcular tamaño de grid basado en número objetivo de celdas
    total_area_deg2 <- grid_info$lon_range * grid_info$lat_range
    target_cell_size <- sqrt(total_area_deg2 / target_cells)
    
    # Ajustar a valores estándar de grid
    standard_sizes <- c(0.1, 0.25, 0.5, 1.0, 2.0, 5.0)
    grid_size <- standard_sizes[which.min(abs(standard_sizes - target_cell_size))]
    
    # Verificar que no exceda el máximo de celdas
    estimated_cells <- ceiling(grid_info$lon_range / grid_size) * ceiling(grid_info$lat_range / grid_size)
    
    if (estimated_cells > max_cells) {
      # Aumentar tamaño de grid para reducir número de celdas
      grid_size <- standard_sizes[which(ceiling(grid_info$lon_range / standard_sizes) * 
                                       ceiling(grid_info$lat_range / standard_sizes) <= max_cells)[1]]
      estimated_cells <- ceiling(grid_info$lon_range / grid_size) * ceiling(grid_info$lat_range / grid_size)
    }
    
    cat(sprintf("✓ Tamaño de grid optimizado: %.2f°\n", grid_size))
    cat(sprintf("✓ Celdas estimadas: %d\n", estimated_cells))
    cat(sprintf("✓ Eficiencia: %.1f celdas/grado²\n", estimated_cells / total_area_deg2))
    
  } else {
    # Fallback para otros métodos
    bbox_parts <- as.numeric(strsplit(api_polygon$bbox_string, ",")[[1]])
    lon_range <- bbox_parts[3] - bbox_parts[1]
    lat_range <- bbox_parts[4] - bbox_parts[2]
    
    total_area_deg2 <- lon_range * lat_range
    target_cell_size <- sqrt(total_area_deg2 / target_cells)
    
    standard_sizes <- c(0.1, 0.25, 0.5, 1.0, 2.0, 5.0)
    grid_size <- standard_sizes[which.min(abs(standard_sizes - target_cell_size))]
    
    estimated_cells <- ceiling(lon_range / grid_size) * ceiling(lat_range / grid_size)
    
    cat(sprintf("✓ Tamaño de grid calculado: %.2f°\n", grid_size))
    cat(sprintf("✓ Celdas estimadas: %d\n", estimated_cells))
  }
  
  return(list(
    grid_size = grid_size,
    estimated_cells = estimated_cells,
    bbox_string = api_polygon$bbox_string,
    wkt = api_polygon$wkt,
    method_used = api_polygon$method
  ))
}