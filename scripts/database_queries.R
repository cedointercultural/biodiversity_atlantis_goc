# ============================================================================
# Script: database_queries.R (Refactorizado)
# Descripción: Script principal para ejecutar consultas a múltiples bases de 
#              datos de biodiversidad usando parámetros configurables en JSON
# Autor: Sistema de consultas de biodiversidad
# Fecha: 2025-10-17
# ============================================================================

# ============================================================================
# 1. LIBRERÍAS NECESARIAS
# ============================================================================

# Librerías de manejo de datos
library(jsonlite)      # Leer configuración JSON
library(dplyr)         # Manipulación de datos
library(lubridate)     # Manipulación de fechas

# Librerías espaciales
library(sf)            # Procesamiento de shapefiles
library(sp)            # Spatial features
library(raster)        # Funciones espaciales

# Librerías de APIs de biodiversidad
library(rgbif)         # Consultas GBIF
library(robis)         # Consultas OBIS
library(spocc)         # Consultas de múltiples fuentes (iNat, eBird)
library(rebird)        # Consultas eBird
library(ridigbio)      # Consultas iDigBio

# Librería de exportación
library(openxlsx)      # Exportar a Excel (opcional)

# ============================================================================
# 2. CARGAR MÓDULOS PERSONALIZADOS
# ============================================================================

# Obtener directorio del script actual o del proyecto
get_script_dir <- function() {
  # Intentar obtener el directorio del script actual
  if (exists("script_dir")) {
    return(script_dir)
  }
  
  # Si se está ejecutando con Rscript
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg)
    return(dirname(script_path))
  }
  
  # Si se está ejecutando desde RStudio
  if (requireNamespace("rstudioapi", quietly = TRUE) && 
      rstudioapi::isAvailable()) {
    return(dirname(rstudioapi::getActiveDocumentContext()$path))
  }
  
  # Por defecto, asumir que estamos en el directorio del proyecto
  # y este script está en scripts/
  return(file.path(getwd(), "scripts"))
}

script_dir <- get_script_dir()

# Cargar módulos desde scripts/utils/
utils_dir <- file.path(script_dir, "utils")

tryCatch({
  source(file.path(utils_dir, "data_utils.R"))
  source(file.path(utils_dir, "spatial_utils.R"))
  source(file.path(utils_dir, "query_functions.R"))
  
  # Cargar funciones de paralelización (opcional)
  parallel_file <- file.path(utils_dir, "parallel_query_functions.R")
  if (file.exists(parallel_file)) {
    source(parallel_file)
    cat("✓ Módulos cargados correctamente (incluyendo paralelización) desde:", utils_dir, "\n")
  } else {
    cat("✓ Módulos cargados correctamente desde:", utils_dir, "\n")
    cat("ℹ Paralelización no disponible (opcional)\n")
  }
}, error = function(e) {
  stop("Error al cargar módulos: ", e$message, 
       "\nAsegúrese de que los archivos existen en: ", utils_dir)
})

# ============================================================================
# 3. FUNCIÓN PRINCIPAL DE EJECUCIÓN
# ============================================================================

#' Ejecutar consultas a bases de datos de biodiversidad
#'
#' Función principal que coordina todo el proceso de consulta, desde la carga
#' de configuración hasta la exportación de resultados
#'
#' @param config_file Ruta al archivo JSON de configuración
#' @param polygon_file Ruta al shapefile (opcional, si no está en config)
#' @param output_dir Directorio de salida (opcional)
#' @param parallel Usar paralelización (TRUE/FALSE, default: "auto" decide automáticamente)
#' @param n_cores Número de núcleos para paralelización (NULL = auto-detectar)
#' @return Lista con resultados de todas las consultas y metadatos
#' @export
execute_biodiversity_queries <- function(config_file, 
                                         polygon_file = NULL, 
                                         output_dir = NULL,
                                         parallel = "auto",
                                         n_cores = NULL) {
  
  # Registrar tiempo de inicio
  start_time <- Sys.time()
  
  # ========================================================================
  # PASO 1: Cargar configuración
  # ========================================================================
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("  SISTEMA DE CONSULTAS DE BIODIVERSIDAD\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
  
  config <- load_query_config(config_file)
  
  # Determinar directorio de salida
  if (is.null(output_dir)) {
    output_dir <- config$general$output_dir
  }
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    cat("✓ Directorio de salida creado:", output_dir, "\n")
  }
  
  # Configurar archivo de log
  log_file <- file.path(output_dir, 
                        basename(config$logging$log_file))
  
  # Función de logging que escribe en archivo y consola
  log_fn <- function(msg, level = "INFO") {
    log_message(msg, log_file, level)
  }
  
  log_fn("═══════════════════════════════════════════════════════════════")
  log_fn("INICIANDO CONSULTAS DE BIODIVERSIDAD")
  log_fn("═══════════════════════════════════════════════════════════════")
  log_fn(paste("Configuración:", config_file))
  log_fn(paste("Directorio de salida:", output_dir))
  
  # ========================================================================
  # PASO 2: Cargar y procesar polígono
  # ========================================================================
  log_fn("Cargando área de estudio...")
  
  if (is.null(polygon_file)) {
    polygon_file <- config$general$polygon_path
  }
  
  polygon <- load_polygon_from_shapefile(polygon_file)
  log_fn(paste("Polígono cargado desde:", polygon_file))
  
  # ========================================================================
  # PASO 3: Generar grid de búsqueda
  # ========================================================================
  log_fn("Generando grid de búsqueda...")
  
  if (config$spatial$grid_enabled) {
    grid <- generate_grid_bboxes(
      polygon = polygon, 
      grid_size = config$spatial$grid_size_degrees,
      square = TRUE
    )
    log_fn(paste("Grid generado:", nrow(grid), "celdas de", 
                 config$spatial$grid_size_degrees, "grados"))
  } else {
    grid <- generate_simple_bbox(polygon)
    log_fn("Usando bounding box completo (sin subdivisión)")
  }
  
  # Limitar número de boxes si es necesario
  if (!is.null(config$spatial$max_boxes) && 
      nrow(grid) > config$spatial$max_boxes) {
    log_fn(paste("Limitando a", config$spatial$max_boxes, "cajas de", 
                 nrow(grid), "disponibles"))
    grid <- grid[1:config$spatial$max_boxes, ]
  }
  
  # ========================================================================
  # PASO 4: Ejecutar consultas a bases de datos
  # ========================================================================
  log_fn("───────────────────────────────────────────────────────────────")
  log_fn("EJECUTANDO CONSULTAS")
  log_fn("───────────────────────────────────────────────────────────────")
  
  # Decidir estrategia de ejecución (secuencial vs paralela)
  use_parallel <- FALSE
  
  if (parallel == "auto") {
    # Usar paralelización si hay más de 5 celdas y está disponible
    use_parallel <- (nrow(grid) >= 5 && exists("execute_all_queries_adaptive"))
  } else if (is.logical(parallel)) {
    use_parallel <- parallel && exists("execute_all_queries_adaptive")
  }
  
  # Ejecutar consultas con la estrategia apropiada
  if (use_parallel) {
    log_fn("🚀 Modo: PARALELO")
    all_results <- execute_all_queries_adaptive(
      grid = grid,
      config = config,
      log_function = log_fn,
      parallel_threshold = 5,
      n_cores = n_cores
    )
  } else {
    log_fn("📊 Modo: SECUENCIAL")
    all_results <- execute_all_queries(
      grid = grid,
      config = config,
      log_function = log_fn
    )
  }
  
  # ========================================================================
  # PASO 5: Procesar y limpiar resultados
  # ========================================================================
  log_fn("───────────────────────────────────────────────────────────────")
  log_fn("PROCESANDO RESULTADOS")
  log_fn("───────────────────────────────────────────────────────────────")
  log_fn(paste("Total de registros recolectados:", nrow(all_results)))
  
  # Inicializar variable para resultados únicos
  all_results_unique <- data.frame()
  
  if (nrow(all_results) > 0) {
    # Eliminar duplicados
    all_results_unique <- remove_duplicates(all_results)
    log_fn(paste("Registros únicos después de eliminar duplicados:", 
                 nrow(all_results_unique)))
    
    # Generar resumen estadístico
    summary_stats <- summarize_biodiversity_data(all_results_unique)
    log_fn(paste("Especies únicas encontradas:", summary_stats$unique_species))
    log_fn(paste("Fuentes de datos:"))
    for (source in names(summary_stats$sources)) {
      log_fn(paste("  -", source, ":", summary_stats$sources[[source]], "registros"))
    }
    
    if (!all(is.na(summary_stats$year_range))) {
      log_fn(paste("Rango temporal:", 
                   summary_stats$year_range[1], "-", 
                   summary_stats$year_range[2]))
    }
    
    # ======================================================================
    # PASO 6: Exportar resultados
    # ======================================================================
    log_fn("───────────────────────────────────────────────────────────────")
    log_fn("EXPORTANDO RESULTADOS")
    log_fn("───────────────────────────────────────────────────────────────")
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    base_name <- paste0("biodiversity_", timestamp)
    
    # Exportar datos en formatos configurados
    exported_files <- export_biodiversity_data(
      data = all_results_unique,
      output_dir = output_dir,
      base_name = base_name,
      formats = config$output$formats,
      log_function = log_fn
    )
    
    # ======================================================================
    # PASO 7: Generar y exportar metadatos
    # ======================================================================
    if (config$output$include_metadata) {
      execution_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      
      metadata <- generate_metadata(
        config = config,
        results = all_results_unique,
        grid = grid,
        execution_time = execution_time
      )
      
      metadata$config_file <- config_file
      metadata$polygon_file <- polygon_file
      metadata$output_files <- exported_files
      
      metadata_file <- file.path(output_dir, 
                                 paste0("metadata_", timestamp, ".json"))
      jsonlite::write_json(metadata, metadata_file, pretty = TRUE, auto_unbox = TRUE)
      log_fn(paste("✓ Metadatos exportados:", metadata_file))
    }
    
  } else {
    log_fn("⚠ No se encontraron registros en ninguna base de datos", "WARNING")
  }
  
  # ========================================================================
  # FINALIZACIÓN
  # ========================================================================
  end_time <- Sys.time()
  execution_time <- difftime(end_time, start_time, units = "secs")
  
  log_fn("───────────────────────────────────────────────────────────────")
  log_fn("PROCESO COMPLETADO")
  log_fn("───────────────────────────────────────────────────────────────")
  log_fn(paste("Tiempo de ejecución:", round(execution_time, 2), "segundos"))
  log_fn(paste("Registros finales:", nrow(all_results_unique)))
  log_fn(paste("Archivo de log:", log_file))
  log_fn("═══════════════════════════════════════════════════════════════")
  
  cat("\n✓ Proceso finalizado exitosamente\n")
  cat("  Resultados guardados en:", output_dir, "\n\n")
  
  # Retornar objeto con todos los resultados
  return(list(
    results = all_results_unique,
    grid = grid,
    polygon = polygon,
    config = config,
    execution_time = execution_time,
    summary = if(nrow(all_results_unique) > 0) 
      summarize_biodiversity_data(all_results_unique) else NULL
  ))
}

# ============================================================================
# 4. FUNCIÓN DE AYUDA Y DOCUMENTACIÓN
# ============================================================================

#' Mostrar ayuda sobre el uso del sistema
#'
#' @export
show_help <- function() {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("  SISTEMA DE CONSULTAS DE BIODIVERSIDAD - AYUDA\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
  cat("USO BÁSICO:\n")
  cat("  results <- execute_biodiversity_queries(\n")
  cat("    config_file = 'scripts/query_config.json',\n")
  cat("    polygon_file = 'shapefiles/study_zone.gpkg',\n")
  cat("    output_dir = 'data/query_results'\n")
  cat("  )\n\n")
  cat("PARÁMETROS:\n")
  cat("  - config_file: Ruta al archivo JSON de configuración\n")
  cat("  - polygon_file: Ruta al shapefile o GeoPackage del área de estudio\n")
  cat("  - output_dir: Directorio donde se guardarán los resultados\n\n")
  cat("BASES DE DATOS SOPORTADAS:\n")
  cat("  - GBIF: Global Biodiversity Information Facility\n")
  cat("  - OBIS: Ocean Biodiversity Information System\n")
  cat("  - iNaturalist: Red social de naturalistas\n")
  cat("  - eBird: Base de datos de aves\n")
  cat("  - iDigBio: Integrated Digitized Biocollections\n\n")
  cat("MÓDULOS CARGADOS:\n")
  cat("  - data_utils.R: Utilidades de procesamiento de datos\n")
  cat("  - spatial_utils.R: Utilidades espaciales\n")
  cat("  - query_functions.R: Funciones de consulta a bases de datos\n\n")
  cat("PARA MÁS INFORMACIÓN:\n")
  cat("  Consulte el archivo README_database_queries.md\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
}

# ============================================================================
# 5. PUNTO DE ENTRADA PARA EJECUCIÓN DIRECTA
# ============================================================================

# Si este script se ejecuta directamente (no se carga con source()),
# mostrar mensaje de ayuda
if (sys.nframe() == 0) {
  show_help()
  cat("Para ejecutar consultas, use la función execute_biodiversity_queries()\n")
  cat("o consulte el archivo example_usage.R para ver ejemplos.\n\n")
}
