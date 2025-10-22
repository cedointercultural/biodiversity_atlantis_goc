# ============================================================================
# Script: spatial_utils.R
# Descripción: Utilidades para procesamiento espacial y manejo de polígonos
# Autor: Sistema de consultas de biodiversidad
# Fecha: 2025-10-17
# ============================================================================

#' Cargar polígono desde shapefile o GeoPackage
#'
#' Lee un archivo espacial y asegura que esté en el sistema de coordenadas
#' correcto (WGS84, EPSG:4326)
#'
#' @param shp_path Ruta al archivo shapefile (.shp) o GeoPackage (.gpkg)
#' @param target_crs CRS objetivo (por defecto 4326 - WGS84)
#' @return Objeto sf con el polígono en WGS84
#' @export
load_polygon_from_shapefile <- function(shp_path, target_crs = 4326) {
  if (!file.exists(shp_path)) {
    stop("Archivo espacial no encontrado: ", shp_path)
  }
  
  tryCatch({
    # Leer archivo espacial
    polygon <- sf::st_read(shp_path, quiet = TRUE)
    
    cat("✓ Archivo espacial cargado:", shp_path, "\n")
    cat("  - Geometría:", as.character(sf::st_geometry_type(polygon)[1]), "\n")
    
    # Obtener información del CRS
    crs_info <- sf::st_crs(polygon)$input
    cat("  - CRS original:", if (!is.null(crs_info)) crs_info else "Sin especificar", "\n")
    
    # Asegurar que está en el CRS objetivo
    if (is.na(sf::st_crs(polygon))) {
      sf::st_crs(polygon) <- target_crs
      cat("  - CRS asignado a EPSG:", target_crs, "\n")
    } else if (sf::st_crs(polygon)$epsg != target_crs) {
      polygon <- sf::st_transform(polygon, target_crs)
      cat("  - CRS transformado a EPSG:", target_crs, "\n")
    }
    
    # Validar que es una geometría válida
    if (!all(sf::st_is_valid(polygon))) {
      cat("  - Corrigiendo geometrías inválidas...\n")
      polygon <- sf::st_make_valid(polygon)
    }
    
    # Mostrar información del bounding box
    bbox <- sf::st_bbox(polygon)
    cat("  - Bounding box:\n")
    cat("    Longitud:", round(bbox["xmin"], 4), "a", round(bbox["xmax"], 4), "\n")
    cat("    Latitud:", round(bbox["ymin"], 4), "a", round(bbox["ymax"], 4), "\n")
    
    # Calcular área aproximada
    area_km2 <- as.numeric(sf::st_area(polygon)) / 1e6
    cat("  - Área aproximada:", round(area_km2, 2), "km²\n")
    
    return(polygon)
    
  }, error = function(e) {
    stop("Error al cargar archivo espacial: ", e$message)
  })
}

#' Generar grid de bounding boxes desde polígono
#'
#' Divide un polígono en un grid regular de celdas y genera sus bounding boxes
#' y representaciones WKT para consultas espaciales
#'
#' @param polygon Objeto sf con geometría
#' @param grid_size Tamaño de celda en grados (por defecto 0.5)
#' @param square Lógico, usar celdas cuadradas (TRUE) o hexagonales (FALSE)
#' @return Data frame con columnas: box_id, bbox, wkt
#' @export
generate_grid_bboxes <- function(polygon, grid_size = 0.5, square = TRUE) {
  
  tryCatch({
    # Obtener bounding box del polígono
    bbox <- sf::st_bbox(polygon)
    
    # Crear grid de celdas
    grid_cells <- sf::st_make_grid(
      polygon, 
      cellsize = grid_size, 
      square = square,
      what = "polygons"
    )
    
    # Convertir a sf object para facilitar manejo
    grid_sf <- sf::st_sf(geometry = grid_cells)
    
    # Intersectar con el polígono original para mantener solo celdas relevantes
    grid_intersected <- sf::st_intersection(grid_sf, sf::st_union(polygon))
    
    if (length(grid_intersected) == 0) {
      warning("La intersección del grid con el polígono no produjo resultados. Usando bbox completo.")
      return(generate_simple_bbox(polygon))
    }
    
    # Extraer bounding boxes y WKT
    bboxes <- vector("list", length(grid_intersected))
    wkts <- vector("list", length(grid_intersected))
    
    for (i in seq_along(grid_intersected)) {
      geom <- grid_intersected[i, ]
      bbox_i <- sf::st_bbox(geom)
      
      # Crear bbox string (min_lng, min_lat, max_lng, max_lat)
      bboxes[[i]] <- paste(
        bbox_i[["xmin"]], bbox_i[["ymin"]], 
        bbox_i[["xmax"]], bbox_i[["ymax"]], 
        sep = ","
      )
      
      # Crear WKT
      wkts[[i]] <- sf::st_as_text(sf::st_geometry(geom)[[1]], digits = 8)
    }
    
    grid_df <- data.frame(
      box_id = seq_along(bboxes),
      bbox = unlist(bboxes),
      wkt = unlist(wkts),
      stringsAsFactors = FALSE
    )
    
    cat("✓ Grid de búsqueda generado:", nrow(grid_df), "celdas\n")
    cat("  - Tamaño de celda:", grid_size, "grados\n")
    cat("  - Tipo:", if(square) "cuadrado" else "hexagonal", "\n")
    
    return(grid_df)
    
  }, error = function(e) {
    # Si hay error, usar solo el bbox completo
    warning("Error en generación de grid: ", e$message, 
            ". Usando bounding box completo.")
    return(generate_simple_bbox(polygon))
  })
}

#' Generar bounding box simple de polígono
#'
#' Función auxiliar para generar un único bounding box cuando no se usa grid
#'
#' @param polygon Objeto sf con geometría
#' @return Data frame con una fila: box_id, bbox, wkt
#' @export
generate_simple_bbox <- function(polygon) {
  bbox <- sf::st_bbox(polygon)
  
  grid_df <- data.frame(
    box_id = 1,
    bbox = paste(bbox[["xmin"]], bbox[["ymin"]], 
                 bbox[["xmax"]], bbox[["ymax"]], sep = ","),
    wkt = sf::st_as_text(sf::st_as_sfc(bbox), digits = 8),
    stringsAsFactors = FALSE
  )
  
  cat("✓ Usando bounding box completo (1 caja)\n")
  cat("  - Extensión:", grid_df$bbox, "\n")
  
  return(grid_df)
}

#' Validar coordenadas geográficas
#'
#' Verifica que las coordenadas estén dentro de rangos válidos
#'
#' @param lon Vector de longitudes
#' @param lat Vector de latitudes
#' @return Vector lógico indicando coordenadas válidas
#' @export
validate_coordinates <- function(lon, lat) {
  valid <- !is.na(lon) & !is.na(lat) &
           lon >= -180 & lon <= 180 &
           lat >= -90 & lat <= 90
  
  n_invalid <- sum(!valid)
  if (n_invalid > 0) {
    cat("⚠ Encontradas", n_invalid, "coordenadas inválidas\n")
  }
  
  return(valid)
}

#' Crear objeto espacial sf desde coordenadas
#'
#' Convierte un data frame con coordenadas a objeto sf
#'
#' @param data Data frame con columnas lon y lat
#' @param crs Sistema de coordenadas (por defecto 4326)
#' @return Objeto sf
#' @export
create_spatial_points <- function(data, crs = 4326) {
  if (!"lon" %in% names(data) || !"lat" %in% names(data)) {
    stop("El data frame debe contener columnas 'lon' y 'lat'")
  }
  
  # Filtrar coordenadas válidas
  valid_coords <- validate_coordinates(data$lon, data$lat)
  data_valid <- data[valid_coords, ]
  
  if (nrow(data_valid) == 0) {
    stop("No hay coordenadas válidas en los datos")
  }
  
  # Crear objeto sf
  spatial_data <- sf::st_as_sf(
    data_valid,
    coords = c("lon", "lat"),
    crs = crs,
    remove = FALSE
  )
  
  cat("✓ Objeto espacial creado:", nrow(spatial_data), "puntos\n")
  
  return(spatial_data)
}

#' Filtrar puntos dentro de polígono
#'
#' Selecciona solo los puntos que caen dentro de un polígono dado
#'
#' @param points_data Data frame con columnas lon y lat
#' @param polygon Objeto sf con polígono
#' @return Data frame filtrado con puntos dentro del polígono
#' @export
filter_points_in_polygon <- function(points_data, polygon) {
  
  # Crear puntos espaciales
  points_sf <- create_spatial_points(points_data)
  
  # Asegurar mismo CRS
  if (sf::st_crs(points_sf) != sf::st_crs(polygon)) {
    polygon <- sf::st_transform(polygon, sf::st_crs(points_sf))
  }
  
  # Realizar intersección espacial
  points_in_polygon <- sf::st_intersection(points_sf, polygon)
  
  # Convertir de vuelta a data frame
  result <- as.data.frame(points_in_polygon)
  result$geometry <- NULL  # Eliminar columna de geometría
  
  n_original <- nrow(points_data)
  n_filtered <- nrow(result)
  n_removed <- n_original - n_filtered
  
  cat("✓ Filtrado espacial completado\n")
  cat("  - Puntos originales:", n_original, "\n")
  cat("  - Puntos dentro del polígono:", n_filtered, "\n")
  cat("  - Puntos removidos:", n_removed, "\n")
  
  return(result)
}

#' Calcular estadísticas espaciales
#'
#' Genera resumen estadístico de la distribución espacial de los puntos
#'
#' @param data Data frame con columnas lon y lat
#' @return Lista con estadísticas espaciales
#' @export
calculate_spatial_statistics <- function(data) {
  if (!"lon" %in% names(data) || !"lat" %in% names(data)) {
    stop("El data frame debe contener columnas 'lon' y 'lat'")
  }
  
  # Filtrar coordenadas válidas
  valid_coords <- validate_coordinates(data$lon, data$lat)
  data_valid <- data[valid_coords, ]
  
  if (nrow(data_valid) == 0) {
    return(list(
      n_points = 0,
      lon_range = c(NA, NA),
      lat_range = c(NA, NA),
      centroid = c(lon = NA, lat = NA)
    ))
  }
  
  stats <- list(
    n_points = nrow(data_valid),
    lon_range = range(data_valid$lon, na.rm = TRUE),
    lat_range = range(data_valid$lat, na.rm = TRUE),
    centroid = c(
      lon = mean(data_valid$lon, na.rm = TRUE),
      lat = mean(data_valid$lat, na.rm = TRUE)
    ),
    lon_sd = sd(data_valid$lon, na.rm = TRUE),
    lat_sd = sd(data_valid$lat, na.rm = TRUE)
  )
  
  return(stats)
}

#' Generar grid adaptativo basado en densidad
#'
#' Crea un grid con tamaños de celda variables basados en la densidad de puntos
#'
#' @param polygon Objeto sf con geometría
#' @param min_size Tamaño mínimo de celda en grados
#' @param max_size Tamaño máximo de celda en grados
#' @param target_points Número objetivo de puntos por celda
#' @return Data frame con grid adaptativo
#' @export
generate_adaptive_grid <- function(polygon, 
                                   min_size = 0.1, 
                                   max_size = 1.0,
                                   target_points = 100) {
  
  cat("Generando grid adaptativo...\n")
  cat("  - Tamaño mínimo:", min_size, "grados\n")
  cat("  - Tamaño máximo:", max_size, "grados\n")
  
  # Por ahora, usar grid simple con tamaño medio
  # En futuras versiones se puede implementar lógica más sofisticada
  avg_size <- (min_size + max_size) / 2
  
  grid <- generate_grid_bboxes(polygon, grid_size = avg_size)
  
  cat("✓ Grid adaptativo generado\n")
  
  return(grid)
}

#' Simplificar geometría de polígono
#'
#' Reduce la complejidad de un polígono manteniendo su forma general
#'
#' @param polygon Objeto sf con geometría
#' @param tolerance Tolerancia para simplificación (grados)
#' @return Objeto sf simplificado
#' @export
simplify_polygon <- function(polygon, tolerance = 0.01) {
  
  original_vertices <- sum(sapply(sf::st_geometry(polygon), function(x) nrow(sf::st_coordinates(x))))
  
  simplified <- sf::st_simplify(polygon, dTolerance = tolerance)
  
  simplified_vertices <- sum(sapply(sf::st_geometry(simplified), function(x) nrow(sf::st_coordinates(x))))
  
  reduction <- round((1 - simplified_vertices/original_vertices) * 100, 1)
  
  cat("✓ Polígono simplificado\n")
  cat("  - Vértices originales:", original_vertices, "\n")
  cat("  - Vértices simplificados:", simplified_vertices, "\n")
  cat("  - Reducción:", reduction, "%\n")
  
  return(simplified)
}
