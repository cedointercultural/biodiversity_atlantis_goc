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
    area_km2 <- sum(as.numeric(sf::st_area(polygon))) / 1e6
    n_coords <- nrow(sf::st_coordinates(polygon))
    
    cat("  - Área aproximada:", round(area_km2, 2), "km²\n")
    cat("  - Número de coordenadas:", n_coords, "\n")
    
    # Simplificar automáticamente si el polígono es muy complejo
    if (n_coords > 50000) {
      cat("  - Polígono muy complejo, aplicando simplificación...\n")
      
      # Unir geometrías múltiples
      polygon_union <- sf::st_union(polygon)
      
      # Aplicar simplificación (tolerancia de 0.01 grados ≈ 1 km)
      polygon_simplified <- sf::st_simplify(polygon_union, dTolerance = 0.01)
      
      # Convertir de nuevo a sf dataframe
      polygon <- sf::st_sf(geometry = polygon_simplified)
      
      n_coords_new <- nrow(sf::st_coordinates(polygon))
      cat("    ✓ Coordenadas reducidas:", n_coords, "→", n_coords_new, 
          sprintf("(%.1f%% reducción)\n", 100 * (1 - n_coords_new / n_coords)))
    }
    
    return(polygon)
    
  }, error = function(e) {
    stop("Error al cargar archivo espacial: ", e$message)
  })
}

#' Generar grid de bounding boxes desde polígono
#'
#' Divide un polígono en un grid regular de celdas y genera sus bounding boxes
#' y representaciones WKT para consultas espaciales. Optimizado para cobertura
#' completa del área de estudio.
#'
#' @param polygon Objeto sf con geometría
#' @param grid_size Tamaño de celda en grados (por defecto 2.0)
#' @param square Lógico, usar celdas cuadradas (TRUE) o hexagonales (FALSE)
#' @param buffer_percent Porcentaje de buffer para extender grid (por defecto 2%)
#' @return Data frame con columnas: box_id, bbox, wkt, bbox_array, geometry
#' @export
generate_grid_bboxes <- function(polygon, grid_size = 2.0, square = TRUE, buffer_percent = 2) {
  
  tryCatch({
    # Obtener bounding box del polígono
    bbox <- sf::st_bbox(polygon)
    
    cat("  - Bounding box para grid:", 
        sprintf("[%.3f, %.3f] a [%.3f, %.3f]", bbox[1], bbox[2], bbox[3], bbox[4]), "\n")
    
    # Aplicar buffer para asegurar cobertura completa
    buffer_factor <- buffer_percent / 100
    width <- bbox[["xmax"]] - bbox[["xmin"]]
    height <- bbox[["ymax"]] - bbox[["ymin"]]
    
    buffer_x <- width * buffer_factor
    buffer_y <- height * buffer_factor
    
    # Expandir bounding box con buffer
    min_lon <- bbox[["xmin"]] - buffer_x
    max_lon <- bbox[["xmax"]] + buffer_x
    min_lat <- bbox[["ymin"]] - buffer_y
    max_lat <- bbox[["ymax"]] + buffer_y
    
    cat("  - Grid expandido con buffer", sprintf("%.1f%%:", buffer_percent),
        sprintf("[%.3f, %.3f] a [%.3f, %.3f]", min_lon, min_lat, max_lon, max_lat), "\n")
    
    # Alinear grid a múltiplos exactos de grid_size para consistencia
    min_lon_aligned <- floor(min_lon / grid_size) * grid_size
    min_lat_aligned <- floor(min_lat / grid_size) * grid_size
    max_lon_aligned <- ceiling(max_lon / grid_size) * grid_size
    max_lat_aligned <- ceiling(max_lat / grid_size) * grid_size
    
    # Calcular número de celdas en cada dirección
    n_cols <- round((max_lon_aligned - min_lon_aligned) / grid_size)
    n_rows <- round((max_lat_aligned - min_lat_aligned) / grid_size)
    
    cat("  - Grid alineado:", n_cols, "columnas ×", n_rows, "filas =", n_cols * n_rows, "celdas\n")
    
    # Verificar si el grid es razonable
    if (n_cols * n_rows > 200) {
      warning("Grid muy grande (", n_cols * n_rows, " celdas). Considere aumentar grid_size.")
    }
    
    # Generar celdas del grid
    grid_boxes <- list()
    grid_wkts <- list()
    grid_bbox_arrays <- list()
    grid_geometries <- list()
    box_count <- 0
    
    for (i in 1:n_cols) {
      for (j in 1:n_rows) {
        box_count <- box_count + 1
        
        # Calcular límites de la celda con grid alineado
        cell_min_lon <- min_lon_aligned + (i - 1) * grid_size
        cell_max_lon <- min_lon_aligned + i * grid_size
        cell_min_lat <- min_lat_aligned + (j - 1) * grid_size
        cell_max_lat <- min_lat_aligned + j * grid_size
        
        # Crear bbox string estándar (min_lng, min_lat, max_lng, max_lat)
        grid_boxes[[box_count]] <- paste(
          cell_min_lon, cell_min_lat, cell_max_lon, cell_max_lat, sep = ","
        )
        
        # Crear array numérico para APIs que lo requieren
        grid_bbox_arrays[[box_count]] <- c(cell_min_lon, cell_min_lat, cell_max_lon, cell_max_lat)
        
        # Crear WKT polygon en sentido ANTIHORARIO (estándar OGC)
        # Orden correcto: SW → SE → NE → NW → SW
        grid_wkts[[box_count]] <- sprintf(
          "POLYGON((%f %f,%f %f,%f %f,%f %f,%f %f))",
          cell_min_lon, cell_min_lat,  # SW (bottom-left)
          cell_max_lon, cell_min_lat,  # SE (bottom-right)  
          cell_max_lon, cell_max_lat,  # NE (top-right)
          cell_min_lon, cell_max_lat,  # NW (top-left)
          cell_min_lon, cell_min_lat   # SW (cierre)
        )
        
        # Crear geometría sf para validaciones futuras
        cell_coords <- matrix(c(
          cell_min_lon, cell_min_lat,
          cell_max_lon, cell_min_lat,
          cell_max_lon, cell_max_lat,
          cell_min_lon, cell_max_lat,
          cell_min_lon, cell_min_lat
        ), ncol = 2, byrow = TRUE)
        
        cell_polygon <- sf::st_polygon(list(cell_coords))
        grid_geometries[[box_count]] <- cell_polygon
      }
    }
    
    # Crear data frame con resultados mejorados
    grid_df <- data.frame(
      box_id = 1:length(grid_boxes),
      bbox = unlist(grid_boxes),
      wkt = unlist(grid_wkts),
      stringsAsFactors = FALSE
    )
    
    # Agregar arrays de bbox como columnas separadas para facilidad de uso
    bbox_matrix <- do.call(rbind, grid_bbox_arrays)
    grid_df$min_lon <- bbox_matrix[, 1]
    grid_df$min_lat <- bbox_matrix[, 2]
    grid_df$max_lon <- bbox_matrix[, 3]
    grid_df$max_lat <- bbox_matrix[, 4]
    
    # Agregar columna de geometría sf para validaciones
    grid_df$geometry <- sf::st_sfc(grid_geometries, crs = 4326)
    
    # Convertir a sf object para facilitar operaciones espaciales
    grid_sf <- sf::st_sf(grid_df)
    
    if (nrow(grid_df) == 0) {
      warning("Grid no generó celdas válidas. Usando bbox completo.")
      return(generate_simple_bbox(polygon))
    }
    
    cat("✓ Grid de búsqueda generado:", nrow(grid_df), "celdas\n")
    cat("  - Tamaño de celda:", grid_size, "grados\n")
    cat("  - Tipo:", if(square) "cuadrado" else "hexagonal", "\n")
    cat("  - Formato WKT: Antihorario (estándar OGC)\n")
    cat("  - Buffer aplicado:", sprintf("%.1f%%", buffer_percent), "\n")
    
    # Opcional: mostrar estadísticas de cobertura
    total_grid_area <- n_cols * n_rows * (grid_size^2) * 111^2  # km² aproximado
    polygon_area_km2 <- sum(as.numeric(sf::st_area(polygon))) / 1e6
    coverage_ratio <- total_grid_area / polygon_area_km2
    
    cat("  - Cobertura estimada:", sprintf("%.1fx", coverage_ratio), "del área original\n")
    
    return(grid_sf)
    
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

#' Convertir bbox a formato WKT optimizado para API específica
#'
#' @param bbox String "min_lon,min_lat,max_lon,max_lat" o vector numérico
#' @param api_type Tipo de API: "gbif", "obis", "inat", "idigbio"
#' @return String WKT optimizado para la API específica
#' @export
bbox_to_wkt <- function(bbox, api_type = "gbif") {
  # Parsear bbox si es string
  if (is.character(bbox)) {
    bbox_parts <- as.numeric(strsplit(bbox, ",")[[1]])
  } else {
    bbox_parts <- as.numeric(bbox)
  }
  
  if (length(bbox_parts) != 4 || any(is.na(bbox_parts))) {
    stop("Formato de bbox inválido. Debe ser: min_lon,min_lat,max_lon,max_lat")
  }
  
  min_lon <- bbox_parts[1]
  min_lat <- bbox_parts[2]
  max_lon <- bbox_parts[3]
  max_lat <- bbox_parts[4]
  
  # Formato estándar WKT (antihorario)
  wkt <- sprintf(
    "POLYGON((%f %f,%f %f,%f %f,%f %f,%f %f))",
    min_lon, min_lat,  # SW
    max_lon, min_lat,  # SE
    max_lon, max_lat,  # NE
    min_lon, max_lat,  # NW
    min_lon, min_lat   # SW (cierre)
  )
  
  return(wkt)
}

#' Obtener formato espacial apropiado para API específica
#'
#' @param api_type Tipo de API: "gbif", "obis", "inat", "idigbio", "ebird"
#' @param grid_row Fila del grid (debe tener columnas bbox, wkt, min_lon, etc.)
#' @return Lista con formato apropiado para la API
#' @export
get_spatial_format_for_api <- function(api_type, grid_row) {
  
  switch(api_type,
    "gbif" = {
      # GBIF prefiere WKT directo
      list(
        type = "wkt",
        value = grid_row$wkt,
        param_name = "geometry"
      )
    },
    "obis" = {
      # OBIS requiere WKT pero desde bbox
      list(
        type = "wkt",
        value = bbox_to_wkt(grid_row$bbox, "obis"),
        param_name = "geometry"
      )
    },
    "inat" = {
      # iNaturalist usa parámetros de bbox nativos
      list(
        type = "bbox_params",
        value = list(
          swlat = grid_row$min_lat,
          swlng = grid_row$min_lon,
          nelat = grid_row$max_lat,
          nelng = grid_row$max_lon
        ),
        param_name = "bbox_params"
      )
    },
    "idigbio" = {
      # iDigBio usa formato geopoint específico
      list(
        type = "geopoint",
        value = list(
          type = "geo_bounding_box",
          top_left = list(
            lon = grid_row$min_lon,
            lat = grid_row$max_lat
          ),
          bottom_right = list(
            lon = grid_row$max_lon,
            lat = grid_row$min_lat
          )
        ),
        param_name = "geopoint"
      )
    },
    "ebird" = {
      # eBird usa punto central y radio
      center_lon <- (grid_row$min_lon + grid_row$max_lon) / 2
      center_lat <- (grid_row$min_lat + grid_row$max_lat) / 2
      # Calcular radio aproximado para cubrir el bbox
      radius_km <- max(
        111 * abs(grid_row$max_lon - grid_row$min_lon),
        111 * abs(grid_row$max_lat - grid_row$min_lat)
      ) / 2 * 1.1  # 10% extra para asegurar cobertura
      
      list(
        type = "point_radius",
        value = list(
          lat = center_lat,
          lng = center_lon,
          dist = min(radius_km, 50)  # eBird limita a 50km
        ),
        param_name = "point_radius"
      )
    },
    {
      # Formato por defecto: bbox estándar
      list(
        type = "bbox",
        value = grid_row$bbox,
        param_name = "bbox"
      )
    }
  )
}

#' Validar y optimizar grid para área de estudio
#'
#' Aplica filtros inteligentes al grid para optimizar consultas, preservando
#' áreas oceánicas relevantes para biodiversidad marina
#'
#' @param grid Grid sf object generado por generate_grid_bboxes
#' @param original_polygon Polígono original del área de estudio
#' @param validation_type Tipo de validación: "intersects", "contains", "buffer", "none"
#' @param ocean_buffer_km Buffer en km para incluir áreas oceánicas adyacentes
#' @return Grid validado y optimizado
#' @export
validate_grid_spatial <- function(grid, original_polygon, 
                                 validation_type = "intersects", 
                                 ocean_buffer_km = 10) {
  
  cat("🔍 Aplicando validación espacial del grid...\n")
  
  if (validation_type == "none") {
    cat("  - Validación deshabilitada: conservando todas las celdas\n")
    return(grid)
  }
  
  tryCatch({
    # Crear buffer del polígono original para incluir áreas oceánicas
    if (ocean_buffer_km > 0) {
      # Convertir km a grados aproximadamente (1 grado ≈ 111 km)
      buffer_degrees <- ocean_buffer_km / 111
      polygon_buffered <- sf::st_buffer(original_polygon, buffer_degrees)
      cat("  - Buffer oceánico aplicado:", ocean_buffer_km, "km\n")
    } else {
      polygon_buffered <- original_polygon
    }
    
    # Aplicar validación según el tipo
    valid_cells <- switch(validation_type,
      "intersects" = {
        # Celdas que intersectan con el polígono (más permisivo)
        intersections <- sf::st_intersects(grid$geometry, polygon_buffered, sparse = FALSE)
        apply(intersections, 1, any)
      },
      "contains" = {
        # Solo celdas completamente dentro del polígono (más restrictivo)
        within_checks <- sf::st_within(grid$geometry, polygon_buffered, sparse = FALSE)
        apply(within_checks, 1, any)
      },
      "buffer" = {
        # Celdas dentro del polígono + buffer oceánico
        intersections <- sf::st_intersects(grid$geometry, polygon_buffered, sparse = FALSE)
        apply(intersections, 1, any)
      },
      {
        # Default: todas las celdas son válidas
        rep(TRUE, nrow(grid))
      }
    )
    
    original_count <- nrow(grid)
    filtered_grid <- grid[valid_cells, ]
    final_count <- nrow(filtered_grid)
    
    cat("  - Validación:", validation_type, "\n")
    cat("  - Celdas originales:", original_count, "\n")
    cat("  - Celdas válidas:", final_count, sprintf("(%.1f%%)\n", 
                                                   100 * final_count / original_count))
    cat("  - Celdas removidas:", original_count - final_count, "\n")
    
    # Recalcular box_ids para mantener secuencia
    if (final_count > 0) {
      filtered_grid$box_id <- 1:final_count
    }
    
    cat("✅ Validación espacial completada\n")
    
    return(filtered_grid)
    
  }, error = function(e) {
    warning("Error en validación espacial: ", e$message, 
            ". Conservando grid completo.")
    return(grid)
  })
}

#' Obtener estadísticas del grid optimizado
#'
#' @param grid Grid sf object
#' @param original_polygon Polígono original
#' @return Lista con estadísticas del grid
#' @export
get_grid_statistics <- function(grid, original_polygon) {
  
  # Área del polígono original
  polygon_area_km2 <- sum(as.numeric(sf::st_area(original_polygon))) / 1e6
  
  # Área total del grid
  if (nrow(grid) > 0) {
    cell_area_km2 <- as.numeric(sf::st_area(grid$geometry[1])) / 1e6
    total_grid_area_km2 <- cell_area_km2 * nrow(grid)
    
    # Bounding box del grid
    grid_bbox <- sf::st_bbox(grid$geometry)
    
    list(
      n_cells = nrow(grid),
      cell_area_km2 = cell_area_km2,
      total_grid_area_km2 = total_grid_area_km2,
      polygon_area_km2 = polygon_area_km2,
      coverage_ratio = total_grid_area_km2 / polygon_area_km2,
      grid_bbox = grid_bbox,
      efficiency = polygon_area_km2 / total_grid_area_km2
    )
  } else {
    list(
      n_cells = 0,
      cell_area_km2 = 0,
      total_grid_area_km2 = 0,
      polygon_area_km2 = polygon_area_km2,
      coverage_ratio = 0,
      grid_bbox = c(xmin = NA, ymin = NA, xmax = NA, ymax = NA),
      efficiency = 0
    )
  }
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
