# ============================================================================
# Script: query_functions.R
# Descripción: Funciones para consultar diferentes bases de datos de biodiversidad
# Autor: Sistema de consultas de biodiversidad
# Fecha: 2025-10-17
# ============================================================================

# ============================================================================
# FUNCIONES DE CONSULTA A BASES DE DATOS
# ============================================================================

#' Consultar GBIF (Global Biodiversity Information Facility)
#'
#' @param wkt WKT (Well-Known Text) string para la geometría de búsqueda
#' @param config Lista de configuración GBIF con parámetros de consulta
#' @param box_id ID de la caja de búsqueda (para logging)
#' @param log_function Función para registrar mensajes (opcional)
#' @return Data frame con registros de GBIF formateados
#' @export
query_gbif <- function(wkt, config, box_id = 1, log_function = NULL) {
  if (is.null(log_function)) {
    log_function <- function(msg) cat(msg, "\n")
  }
  
  tryCatch({
    log_function(paste("Consultando GBIF - Box", box_id, "..."))
    
    # Validar parámetros requeridos
    if (is.null(wkt) || nchar(trimws(wkt)) == 0) {
      log_function(paste("✗ Error GBIF - Box", box_id, ": geometría WKT vacía"))
      return(data.frame())
    }
    
    # Construir parámetros de consulta
    params <- list(
      geometry = wkt,
      limit = config$params$records_per_box,
      hasCoordinate = config$params$has_coordinate
    )
    
    # Agregar filtro de año si está configurado
    if (!is.null(config$params$year_start) && !is.null(config$params$year_end)) {
      params$year <- paste0(config$params$year_start, ",", config$params$year_end)
    }
    
    # Agregar filtros opcionales
    if (!is.null(config$params$rank) && config$params$rank != "") {
      params$rank <- config$params$rank
    }
    
    # Ejecutar consulta con timeout implícito
    gbif_result <- do.call(rgbif::occ_search, params)
    
    # Verificar resultados de forma segura
    if (is.null(gbif_result) || 
        is.null(gbif_result$data) || 
        !is.data.frame(gbif_result$data) || 
        nrow(gbif_result$data) == 0) {
      log_function(paste("⚠ GBIF - Box", box_id, ": sin resultados"))
      return(data.frame())
    }
    
    # Procesar datos
    data <- gbif_result$data
    
    result_df <- data.frame(
      species = sapply(data$scientificName, function(x) 
        if (!is.na(x)) clean_species_name(x) else NA_character_),
      lon = as.numeric(data$decimalLongitude),
      lat = as.numeric(data$decimalLatitude),
      year = if("year" %in% names(data)) as.numeric(data$year) else NA_real_,
      month = if("month" %in% names(data)) as.numeric(data$month) else NA_real_,
      day = if("day" %in% names(data)) as.numeric(data$day) else NA_real_,
      date_recorded = if("eventDate" %in% names(data)) as.character(data$eventDate) else NA_character_,
      taxonRank = if("taxonRank" %in% names(data)) as.character(data$taxonRank) else NA_character_,
      stringsAsFactors = FALSE
    )
    
    log_function(paste("✓ GBIF - Box", box_id, ":", nrow(result_df), "registros"))
    
    return(format_biodiversity_data(result_df, "GBIF"))
    
  }, error = function(e) {
    log_function(paste("✗ Error GBIF - Box", box_id, ":", e$message))
    return(data.frame())
  })
}

#' Consultar OBIS (Ocean Biodiversity Information System)
#'
#' @param bbox Bounding box como string "min_lng,min_lat,max_lng,max_lat"
#' @param config Lista de configuración OBIS con parámetros de consulta
#' @param box_id ID de la caja de búsqueda (para logging)
#' @param log_function Función para registrar mensajes (opcional)
#' @return Data frame con registros de OBIS formateados
#' @export
query_obis <- function(bbox, config, box_id = 1, log_function = NULL) {
  if (is.null(log_function)) {
    log_function <- function(msg) cat(msg, "\n")
  }
  
  tryCatch({
    log_function(paste("Consultando OBIS - Box", box_id, "..."))
    
    # Validar y parsear bbox
    if (is.null(bbox) || nchar(trimws(bbox)) == 0) {
      log_function(paste("✗ Error OBIS - Box", box_id, ": bbox vacío"))
      return(data.frame())
    }
    
    bbox_parts <- as.numeric(strsplit(bbox, ",")[[1]])
    
    if (length(bbox_parts) != 4 || any(is.na(bbox_parts))) {
      log_function(paste("✗ Error OBIS - Box", box_id, ": formato de bbox inválido"))
      return(data.frame())
    }
    
    # OBIS requiere formato WKT POLYGON
    # Construir polígono desde bbox: minLng,minLat,maxLng,maxLat
    min_lng <- bbox_parts[1]
    min_lat <- bbox_parts[2]
    max_lng <- bbox_parts[3]
    max_lat <- bbox_parts[4]
    
    # Crear WKT polygon (en sentido antihorario)
    wkt_polygon <- sprintf("POLYGON((%f %f,%f %f,%f %f,%f %f,%f %f))",
                           min_lng, min_lat,
                           max_lng, min_lat,
                           max_lng, max_lat,
                           min_lng, max_lat,
                           min_lng, min_lat)
    
    # Ejecutar consulta a OBIS con parámetros adicionales
    obis_params <- list(
      geometry = wkt_polygon,
      size = min(config$params$records_per_box, 10000)  # OBIS tiene límite de 10000
    )
    
    # Agregar filtro de años si está configurado
    if (!is.null(config$params$year_start) && !is.null(config$params$year_end)) {
      obis_params$startdate <- paste0(config$params$year_start, "-01-01")
      obis_params$enddate <- paste0(config$params$year_end, "-12-31")
    }
    
    obis_result <- do.call(robis::occurrence, obis_params)
    
    # Verificar resultados
    if (is.null(obis_result) || 
        !is.data.frame(obis_result) || 
        nrow(obis_result) == 0) {
      log_function(paste("⚠ OBIS - Box", box_id, ": sin resultados"))
      return(data.frame())
    }
    
    # Procesar datos
    data <- obis_result
    
    result_df <- data.frame(
      species = sapply(data$scientificName, function(x) 
        if (!is.na(x)) clean_species_name(x) else NA_character_),
      lon = as.numeric(data$decimalLongitude),
      lat = as.numeric(data$decimalLatitude),
      year = if("year" %in% names(data)) as.numeric(data$year) else NA_real_,
      month = if("month" %in% names(data)) as.numeric(data$month) else NA_real_,
      day = if("day" %in% names(data)) as.numeric(data$day) else NA_real_,
      date_recorded = if("eventDate" %in% names(data)) as.character(data$eventDate) else NA_character_,
      taxonRank = if("taxonRank" %in% names(data)) as.character(data$taxonRank) else NA_character_,
      stringsAsFactors = FALSE
    )
    
    log_function(paste("✓ OBIS - Box", box_id, ":", nrow(result_df), "registros"))
    
    return(format_biodiversity_data(result_df, "OBIS"))
    
  }, error = function(e) {
    log_function(paste("✗ Error OBIS - Box", box_id, ":", e$message))
    return(data.frame())
  })
}

#' Consultar iNaturalist
#'
#' @param bbox Bounding box como string "min_lng,min_lat,max_lng,max_lat"
#' @param config Lista de configuración iNaturalist con parámetros de consulta
#' @param box_id ID de la caja de búsqueda (para logging)
#' @param log_function Función para registrar mensajes (opcional)
#' @return Data frame con registros de iNaturalist formateados
#' @export
query_inat <- function(bbox, config, box_id = 1, log_function = NULL) {
  if (is.null(log_function)) {
    log_function <- function(msg) cat(msg, "\n")
  }
  
  tryCatch({
    log_function(paste("Consultando iNaturalist - Box", box_id, "..."))
    
    # Validar y parsear bbox
    if (is.null(bbox) || nchar(trimws(bbox)) == 0) {
      log_function(paste("✗ Error iNaturalist - Box", box_id, ": bbox vacío"))
      return(data.frame())
    }
    
    bbox_parts <- as.numeric(strsplit(bbox, ",")[[1]])
    
    if (length(bbox_parts) != 4 || any(is.na(bbox_parts))) {
      log_function(paste("✗ Error iNaturalist - Box", box_id, ": formato de bbox inválido"))
      return(data.frame())
    }
    
    # Formato para spocc: "minLng,minLat,maxLng,maxLat"
    inat_result <- spocc::occ(
      from = "inat",
      geometry = paste(bbox_parts, collapse = ","),
      limit = config$params$records_per_box
    )
    
    # Verificar resultados con chequeos de seguridad
    if (is.null(inat_result) || 
        is.null(inat_result$inat) || 
        is.null(inat_result$inat$data) ||
        !is.data.frame(inat_result$inat$data) || 
        nrow(inat_result$inat$data) == 0) {
      log_function(paste("⚠ iNaturalist - Box", box_id, ": sin resultados"))
      return(data.frame())
    }
    
    # Procesar datos
    data <- inat_result$inat$data
    
    result_df <- data.frame(
      species = sapply(data$name, function(x) 
        if (!is.na(x)) clean_species_name(x) else NA_character_),
      lon = as.numeric(data$longitude),
      lat = as.numeric(data$latitude),
      year = if("year" %in% names(data)) as.numeric(data$year) else NA_real_,
      month = if("month" %in% names(data)) as.numeric(data$month) else NA_real_,
      day = if("day" %in% names(data)) as.numeric(data$day) else NA_real_,
      date_recorded = if("date_observed" %in% names(data)) as.character(data$date_observed) else NA_character_,
      taxonRank = NA_character_,
      stringsAsFactors = FALSE
    )
    
    log_function(paste("✓ iNaturalist - Box", box_id, ":", nrow(result_df), "registros"))
    
    return(format_biodiversity_data(result_df, "iNaturalist"))
    
  }, error = function(e) {
    log_function(paste("✗ Error iNaturalist - Box", box_id, ":", e$message))
    return(data.frame())
  })
}

#' Consultar eBird
#'
#' @param bbox Bounding box como string "min_lng,min_lat,max_lng,max_lat"
#' @param config Lista de configuración eBird con parámetros de consulta
#' @param box_id ID de la caja de búsqueda (para logging)
#' @param log_function Función para registrar mensajes (opcional)
#' @return Data frame con registros de eBird formateados
#' @export
#' @note eBird requiere API key configurada en config$params$api_key
query_ebird <- function(bbox, config, box_id = 1, log_function = NULL) {
  if (is.null(log_function)) {
    log_function <- function(msg) cat(msg, "\n")
  }
  
  tryCatch({
    log_function(paste("Consultando eBird - Box", box_id, "..."))
    
    # Verificar API key
    if (is.null(config$params$api_key) || config$params$api_key == "") {
      log_function("⚠ eBird: API key no configurada. Configure una API key en el archivo de configuración.")
      return(data.frame())
    }
    
    # Validar bbox
    if (is.null(bbox) || nchar(trimws(bbox)) == 0) {
      log_function(paste("✗ Error eBird - Box", box_id, ": bbox vacío"))
      return(data.frame())
    }
    
    bbox_parts <- as.numeric(strsplit(bbox, ",")[[1]])
    
    if (length(bbox_parts) != 4 || any(is.na(bbox_parts))) {
      log_function(paste("✗ Error eBird - Box", box_id, ": formato de bbox inválido"))
      return(data.frame())
    }
    
    # Nota: eBird tiene una API compleja que requiere configuración específica
    # Esta es una implementación básica que puede necesitar ajustes
    # Para consultas por región, usar ebirdregioncheck
    # Para consultas por coordenadas, usar ebirdgeo
    
    if (!is.null(config$params$region_code) && config$params$region_code != "") {
      ebird_result <- rebird::ebirdregioncheck(
        region = config$params$region_code,
        species = NULL
      )
    } else {
      # Usar punto central del bbox
      center_lon <- mean(c(bbox_parts[1], bbox_parts[3]))
      center_lat <- mean(c(bbox_parts[2], bbox_parts[4]))
      
      ebird_result <- rebird::ebirdgeo(
        lat = center_lat,
        lng = center_lon,
        dist = 50  # Radio en km
      )
    }
    
    if (is.null(ebird_result) || 
        !is.data.frame(ebird_result) || 
        nrow(ebird_result) == 0) {
      log_function(paste("⚠ eBird - Box", box_id, ": sin resultados"))
      return(data.frame())
    }
    
    log_function(paste("✓ eBird - Box", box_id, ":", nrow(ebird_result), "registros"))
    
    return(format_biodiversity_data(ebird_result, "eBird"))
    
  }, error = function(e) {
    log_function(paste("✗ Error eBird - Box", box_id, ":", e$message))
    return(data.frame())
  })
}

#' Consultar iDigBio (Integrated Digitized Biocollections)
#'
#' @param bbox Bounding box como string "min_lng,min_lat,max_lng,max_lat"
#' @param config Lista de configuración iDigBio con parámetros de consulta
#' @param box_id ID de la caja de búsqueda (para logging)
#' @param log_function Función para registrar mensajes (opcional)
#' @return Data frame con registros de iDigBio formateados
#' @export
query_idigbio <- function(bbox, config, box_id = 1, log_function = NULL) {
  if (is.null(log_function)) {
    log_function <- function(msg) cat(msg, "\n")
  }
  
  tryCatch({
    log_function(paste("Consultando iDigBio - Box", box_id, "..."))
    
    # Validar y parsear bbox
    if (is.null(bbox) || nchar(trimws(bbox)) == 0) {
      log_function(paste("✗ Error iDigBio - Box", box_id, ": bbox vacío"))
      return(data.frame())
    }
    
    bbox_parts <- as.numeric(strsplit(bbox, ",")[[1]])
    
    if (length(bbox_parts) != 4 || any(is.na(bbox_parts))) {
      log_function(paste("✗ Error iDigBio - Box", box_id, ": formato de bbox inválido"))
      return(data.frame())
    }
    
    # Construcción del query para iDigBio con formato correcto
    # iDigBio usa 'geopoint' (minúscula) y formato específico
    idigbio_result <- ridigbio::idig_search_records(
      rq = list(
        geopoint = list(
          type = "geo_bounding_box",
          top_left = list(
            lon = bbox_parts[1],  # min_lng
            lat = bbox_parts[4]   # max_lat
          ),
          bottom_right = list(
            lon = bbox_parts[3],  # max_lng
            lat = bbox_parts[2]   # min_lat
          )
        )
      ),
      limit = min(config$params$records_per_box, 100000)  # iDigBio permite hasta 100k
    )
    
    if (is.null(idigbio_result) || 
        !is.data.frame(idigbio_result) || 
        nrow(idigbio_result) == 0) {
      log_function(paste("⚠ iDigBio - Box", box_id, ": sin resultados"))
      return(data.frame())
    }
    
    # Procesar datos
    data <- idigbio_result
    
    result_df <- data.frame(
      species = sapply(data$scientificname, function(x) 
        if (!is.na(x)) clean_species_name(x) else NA_character_),
      lon = as.numeric(data$geopoint_lon),
      lat = as.numeric(data$geopoint_lat),
      year = if("yearcollected" %in% names(data)) as.numeric(data$yearcollected) else NA_real_,
      month = NA_real_,
      day = NA_real_,
      date_recorded = if("datecollected" %in% names(data)) as.character(data$datecollected) else NA_character_,
      taxonRank = NA_character_,
      stringsAsFactors = FALSE
    )
    
    log_function(paste("✓ iDigBio - Box", box_id, ":", nrow(result_df), "registros"))
    
    return(format_biodiversity_data(result_df, "iDigBio"))
    
  }, error = function(e) {
    log_function(paste("✗ Error iDigBio - Box", box_id, ":", e$message))
    return(data.frame())
  })
}

#' Ejecutar consultas para todas las bases de datos habilitadas
#'
#' @param grid Data frame con columnas box_id, bbox, wkt
#' @param config Lista de configuración completa
#' @param log_function Función para registrar mensajes
#' @return Data frame con todos los resultados consolidados
#' @export
execute_all_queries <- function(grid, config, log_function = NULL) {
  if (is.null(log_function)) {
    log_function <- function(msg) cat(msg, "\n")
  }
  
  all_results <- data.frame()
  
  # Consultar GBIF
  if (config$databases$gbif$enabled) {
    log_function("Iniciando consultas a GBIF...")
    gbif_results <- data.frame()
    
    for (i in 1:nrow(grid)) {
      box_result <- query_gbif(
        wkt = grid$wkt[i], 
        config = config$databases$gbif, 
        box_id = i,
        log_function = log_function
      )
      if (nrow(box_result) > 0) {
        gbif_results <- rbind(gbif_results, box_result)
      }
    }
    
    if (nrow(gbif_results) > 0) {
      all_results <- rbind(all_results, gbif_results)
      log_function(paste("GBIF - Total:", nrow(gbif_results), "registros"))
    }
  }
  
  # Consultar OBIS
  if (config$databases$obis$enabled) {
    log_function("Iniciando consultas a OBIS...")
    obis_results <- data.frame()
    
    for (i in 1:nrow(grid)) {
      box_result <- query_obis(
        bbox = grid$bbox[i], 
        config = config$databases$obis, 
        box_id = i,
        log_function = log_function
      )
      if (nrow(box_result) > 0) {
        obis_results <- rbind(obis_results, box_result)
      }
    }
    
    if (nrow(obis_results) > 0) {
      all_results <- rbind(all_results, obis_results)
      log_function(paste("OBIS - Total:", nrow(obis_results), "registros"))
    }
  }
  
  # Consultar iNaturalist
  if (config$databases$inat$enabled) {
    log_function("Iniciando consultas a iNaturalist...")
    inat_results <- data.frame()
    
    for (i in 1:nrow(grid)) {
      box_result <- query_inat(
        bbox = grid$bbox[i], 
        config = config$databases$inat, 
        box_id = i,
        log_function = log_function
      )
      if (nrow(box_result) > 0) {
        inat_results <- rbind(inat_results, box_result)  # ✅ CORREGIDO: box_result en vez de inat_results
      }
    }
    
    if (nrow(inat_results) > 0) {
      all_results <- rbind(all_results, inat_results)
      log_function(paste("iNaturalist - Total:", nrow(inat_results), "registros"))
    }
  }
  
  # Consultar eBird
  if (config$databases$ebird$enabled) {
    log_function("Iniciando consultas a eBird...")
    ebird_results <- data.frame()
    
    for (i in 1:nrow(grid)) {
      box_result <- query_ebird(
        bbox = grid$bbox[i], 
        config = config$databases$ebird, 
        box_id = i,
        log_function = log_function
      )
      if (nrow(box_result) > 0) {
        ebird_results <- rbind(ebird_results, box_result)
      }
    }
    
    if (nrow(ebird_results) > 0) {
      all_results <- rbind(all_results, ebird_results)
      log_function(paste("eBird - Total:", nrow(ebird_results), "registros"))
    }
  }
  
  # Consultar iDigBio
  if (config$databases$idigbio$enabled) {
    log_function("Iniciando consultas a iDigBio...")
    idigbio_results <- data.frame()
    
    for (i in 1:nrow(grid)) {
      box_result <- query_idigbio(
        bbox = grid$bbox[i], 
        config = config$databases$idigbio, 
        box_id = i,
        log_function = log_function
      )
      if (nrow(box_result) > 0) {
        idigbio_results <- rbind(idigbio_results, box_result)
      }
    }
    
    if (nrow(idigbio_results) > 0) {
      all_results <- rbind(all_results, idigbio_results)
      log_function(paste("iDigBio - Total:", nrow(idigbio_results), "registros"))
    }
  }
  
  log_function(paste("Total de registros consolidados:", nrow(all_results)))
  
  return(all_results)
}
