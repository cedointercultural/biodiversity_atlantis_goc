# ============================================================================
# Script: data_utils.R
# Descripción: Utilidades para procesamiento y formateo de datos de biodiversidad
# Autor: Sistema de consultas de biodiversidad
# Fecha: 2025-10-17
# ============================================================================

#' Limpiar nombre de especie
#'
#' Elimina información adicional del nombre científico (autor, año, etc.)
#' y convierte a minúsculas para normalización
#'
#' @param species_name Nombre de la especie (puede incluir autor, año, etc.)
#' @return Nombre limpio en minúsculas
#' @export
#' @examples
#' clean_species_name("Homo sapiens Linnaeus, 1758")  # "homo sapiens"
#' clean_species_name("Canis lupus (L.)")             # "canis lupus"
clean_species_name <- function(species_name) {
  if (is.na(species_name) || is.null(species_name)) {
    return(NA_character_)
  }
  
  # Convertir a character si no lo es
  species_name <- as.character(species_name)
  
  # Eliminar contenido entre paréntesis (autores abreviados)
  cleaned_name <- gsub("\\s*\\(.*?\\)", "", species_name)
  
  # Eliminar contenido después de coma (autor y año)
  cleaned_name <- gsub("\\s*,.*$", "", cleaned_name)
  
  # Eliminar año (4 dígitos) y texto posterior
  cleaned_name <- gsub("\\s*\\d{4}.*$", "", cleaned_name)
  
  # Eliminar espacios múltiples
  cleaned_name <- gsub("\\s+", " ", cleaned_name)
  
  # Eliminar espacios al inicio y final
  cleaned_name <- trimws(cleaned_name)
  
  # Convertir a minúsculas para normalización
  cleaned_name <- tolower(cleaned_name)
  
  return(cleaned_name)
}

#' Formatear datos de biodiversidad a estructura estándar
#'
#' Convierte datos de diferentes fuentes a un formato unificado con
#' validación de tipos y eliminación de registros inválidos
#'
#' @param data Data frame con datos brutos de biodiversidad
#' @param source Nombre de la fuente de datos (ej: "GBIF", "OBIS")
#' @param required_cols Vector con nombres de columnas requeridas
#' @return Data frame formateado y validado
#' @export
format_biodiversity_data <- function(data, 
                                     source, 
                                     required_cols = c("species", "lon", "lat", "year")) {
  
  # Retornar data frame vacío con estructura correcta si no hay datos
  if (is.null(data) || nrow(data) == 0) {
    return(data.frame(
      species = character(0),
      lon = numeric(0),
      lat = numeric(0),
      year = numeric(0),
      month = numeric(0),
      day = numeric(0),
      date_recorded = character(0),
      taxonRank = character(0),
      source = character(0),
      stringsAsFactors = FALSE
    ))
  }
  
  # Verificar que las columnas requeridas existen
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    warning(paste("Columnas faltantes en datos de", source, ":", 
                  paste(missing_cols, collapse = ", ")))
  }
  
  # Crear data frame formateado con validación de tipos
  formatted_data <- data.frame(
    species = if("species" %in% names(data)) tolower(as.character(data$species)) else NA_character_,
    lon = if("lon" %in% names(data)) as.numeric(data$lon) else NA_real_,
    lat = if("lat" %in% names(data)) as.numeric(data$lat) else NA_real_,
    year = if("year" %in% names(data)) as.numeric(data$year) else NA_real_,
    month = if("month" %in% names(data)) as.numeric(data$month) else NA_real_,
    day = if("day" %in% names(data)) as.numeric(data$day) else NA_real_,
    date_recorded = if("date_recorded" %in% names(data)) as.character(data$date_recorded) else NA_character_,
    taxonRank = if("taxonRank" %in% names(data)) as.character(data$taxonRank) else NA_character_,
    source = source,
    stringsAsFactors = FALSE
  )
  
  # Validar rangos de coordenadas
  formatted_data <- formatted_data[
    !is.na(formatted_data$lon) & 
    !is.na(formatted_data$lat) &
    formatted_data$lon >= -180 & 
    formatted_data$lon <= 180 &
    formatted_data$lat >= -90 & 
    formatted_data$lat <= 90,
  ]
  
  # Eliminar registros sin nombre de especie
  formatted_data <- formatted_data[
    !is.na(formatted_data$species) & 
    nchar(trimws(formatted_data$species)) > 0,
  ]
  
  # Validar años (deben ser razonables)
  if (any(!is.na(formatted_data$year))) {
    formatted_data <- formatted_data[
      is.na(formatted_data$year) | 
      (formatted_data$year >= 1600 & formatted_data$year <= as.numeric(format(Sys.Date(), "%Y"))),
    ]
  }
  
  return(formatted_data)
}

#' Registrar mensaje en log con timestamp
#'
#' Función para registrar mensajes tanto en consola como en archivo de log
#'
#' @param message Mensaje a registrar
#' @param log_file Ruta del archivo de log (opcional)
#' @param level Nivel del mensaje: "INFO", "WARNING", "ERROR"
#' @export
log_message <- function(message, log_file = NULL, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", level, "] ", message)
  
  # Imprimir en consola
  cat(log_entry, "\n")
  
  # Escribir en archivo si se especifica
  if (!is.null(log_file)) {
    tryCatch({
      cat(log_entry, "\n", file = log_file, append = TRUE)
    }, error = function(e) {
      warning(paste("No se pudo escribir en el archivo de log:", e$message))
    })
  }
  
  invisible(log_entry)
}

#' Cargar configuración desde archivo JSON
#'
#' @param config_file Ruta al archivo JSON de configuración
#' @return Lista con la configuración cargada
#' @export
load_query_config <- function(config_file) {
  if (!file.exists(config_file)) {
    stop("Archivo de configuración no encontrado: ", config_file)
  }
  
  tryCatch({
    config <- jsonlite::fromJSON(config_file)
    cat("✓ Configuración cargada desde:", config_file, "\n")
    return(config)
  }, error = function(e) {
    stop("Error al cargar configuración: ", e$message)
  })
}

#' Eliminar registros duplicados de biodiversidad
#'
#' Elimina duplicados basándose en combinación de especies, coordenadas,
#' año y fuente
#'
#' @param data Data frame con registros de biodiversidad
#' @param keep_first Lógico, mantener primera ocurrencia (TRUE) o última (FALSE)
#' @return Data frame sin duplicados
#' @export
remove_duplicates <- function(data, keep_first = TRUE) {
  if (is.null(data) || nrow(data) == 0) {
    return(data)
  }
  
  # Usar dplyr para eliminación eficiente de duplicados
  data_unique <- data %>%
    dplyr::distinct(species, lon, lat, year, source, .keep_all = TRUE)
  
  n_removed <- nrow(data) - nrow(data_unique)
  
  if (n_removed > 0) {
    cat("✓ Eliminados", n_removed, "registros duplicados\n")
  }
  
  return(data_unique)
}

#' Generar resumen estadístico de datos de biodiversidad
#'
#' @param data Data frame con registros de biodiversidad
#' @return Lista con estadísticas descriptivas
#' @export
summarize_biodiversity_data <- function(data) {
  if (is.null(data) || nrow(data) == 0) {
    return(list(
      total_records = 0,
      unique_species = 0,
      sources = character(0),
      year_range = c(NA, NA),
      coord_range = list(lon = c(NA, NA), lat = c(NA, NA))
    ))
  }
  
  summary <- list(
    total_records = nrow(data),
    unique_species = length(unique(data$species[!is.na(data$species)])),
    sources = table(data$source),
    year_range = if(any(!is.na(data$year))) 
      range(data$year, na.rm = TRUE) else c(NA, NA),
    coord_range = list(
      lon = range(data$lon, na.rm = TRUE),
      lat = range(data$lat, na.rm = TRUE)
    ),
    records_with_date = sum(!is.na(data$date_recorded)),
    records_with_taxonRank = sum(!is.na(data$taxonRank))
  )
  
  return(summary)
}

#' Exportar datos en múltiples formatos
#'
#' @param data Data frame a exportar
#' @param output_dir Directorio de salida
#' @param base_name Nombre base del archivo (sin extensión)
#' @param formats Vector de formatos: "csv", "json", "xlsx"
#' @param log_function Función para logging (opcional)
#' @export
export_biodiversity_data <- function(data, 
                                     output_dir, 
                                     base_name, 
                                     formats = c("csv", "json"),
                                     log_function = NULL) {
  
  if (is.null(log_function)) {
    log_function <- function(msg) cat(msg, "\n")
  }
  
  # Crear directorio si no existe
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    log_function(paste("✓ Directorio creado:", output_dir))
  }
  
  exported_files <- list()
  
  for (format in formats) {
    output_file <- file.path(output_dir, paste0(base_name, ".", format))
    
    tryCatch({
      if (format == "csv") {
        write.csv(data, output_file, row.names = FALSE)
        log_function(paste("✓ Exportado CSV:", output_file))
        exported_files$csv <- output_file
        
      } else if (format == "json") {
        jsonlite::write_json(data, output_file, pretty = TRUE)
        log_function(paste("✓ Exportado JSON:", output_file))
        exported_files$json <- output_file
        
      } else if (format == "xlsx") {
        if (requireNamespace("openxlsx", quietly = TRUE)) {
          openxlsx::write.xlsx(data, output_file)
          log_function(paste("✓ Exportado XLSX:", output_file))
          exported_files$xlsx <- output_file
        } else {
          log_function("⚠ Paquete 'openxlsx' no disponible, omitiendo formato XLSX")
        }
      } else {
        log_function(paste("⚠ Formato no soportado:", format))
      }
    }, error = function(e) {
      log_function(paste("✗ Error al exportar", format, ":", e$message))
    })
  }
  
  return(exported_files)
}

#' Generar metadatos de la consulta
#'
#' @param config Lista de configuración
#' @param results Data frame con resultados
#' @param grid Data frame con grid usado
#' @param execution_time Tiempo de ejecución (opcional)
#' @return Lista con metadatos
#' @export
generate_metadata <- function(config, results, grid, execution_time = NULL) {
  metadata <- list(
    execution_date = as.character(Sys.time()),
    execution_time_seconds = execution_time,
    total_records = nrow(results),
    unique_species = length(unique(results$species[!is.na(results$species)])),
    databases_queried = names(config$databases)[
      sapply(config$databases, function(x) x$enabled)
    ],
    grid_cells_used = nrow(grid),
    records_by_source = as.list(table(results$source)),
    year_range = if(any(!is.na(results$year))) 
      range(results$year, na.rm = TRUE) else c(NA, NA),
    spatial_extent = list(
      lon_range = range(results$lon, na.rm = TRUE),
      lat_range = range(results$lat, na.rm = TRUE)
    ),
    config_summary = list(
      grid_enabled = config$spatial$grid_enabled,
      grid_size = config$spatial$grid_size_degrees,
      max_boxes = config$spatial$max_boxes
    )
  )
  
  return(metadata)
}
