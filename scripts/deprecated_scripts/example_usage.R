# ============================================================================
# Script: example_usage.R
# Descripción: Ejemplos de uso del script de consultas a bases de datos
#              de biodiversidad
# ============================================================================

# ============================================================================
# EJEMPLO 1: Uso Básico - Consulta con Configuración por Defecto
# ============================================================================

example_basic_usage <- function() {
  cat("=== EJEMPLO 1: USO BÁSICO ===\n")
  
  # Cargar el script
  source("scripts/database_queries.R")
  
  # Ejecutar consultas con configuración por defecto
  results <- execute_biodiversity_queries(
    config_file = "scripts/query_config.json"
  )
  
  # Ver resultados
  cat("\nDimensiones de resultados:", nrow(results$results), "x", 
      ncol(results$results), "\n")
  cat("\nPrimeras filas:\n")
  print(head(results$results))
  
  return(results)
}

# ============================================================================
# EJEMPLO 2: Consulta Personalizada - Modificar Parámetros
# ============================================================================

example_custom_parameters <- function() {
  cat("=== EJEMPLO 2: CONSULTA PERSONALIZADA ===\n")
  
  source("scripts/database_queries.R")
  
  # Cargar configuración por defecto
  config <- load_query_config("scripts/query_config.json")
  
  # Personalizar parámetros
  # Solo GBIF y OBIS
  config$databases$inat$enabled <- FALSE
  config$databases$ebird$enabled <- FALSE
  config$databases$idigbio$enabled <- FALSE
  
  # Restricción temporal: últimos 5 años
  config$databases$gbif$params$year_start <- 2020
  config$databases$gbif$params$year_end <- 2025
  config$databases$obis$params$year_start <- 2020
  config$databases$obis$params$year_end <- 2025
  
  # Reducir número de cajas para pruebas rápidas
  config$spatial$max_boxes <- 10
  
  # Reducir registros por caja
  config$databases$gbif$params$records_per_box <- 100
  config$databases$obis$params$records_per_box <- 100
  
  # Guardar configuración modificada
  output_config <- "scripts/query_config_custom.json"
  write_json(config, output_config, pretty = TRUE)
  cat("✓ Configuración personalizada guardada:", output_config, "\n")
  
  # Ejecutar con configuración personalizada
  results <- execute_biodiversity_queries(
    config_file = output_config
  )
  
  return(results)
}

# ============================================================================
# EJEMPLO 3: Consulta a Una Sola Base de Datos
# ============================================================================

example_single_database <- function() {
  cat("=== EJEMPLO 3: CONSULTA A UNA SOLA BASE DE DATOS ===\n")
  
  source("scripts/database_queries.R")
  
  # Cargar configuración
  config <- load_query_config("scripts/query_config.json")
  
  # Cargar polígono
  polygon <- load_polygon_from_shapefile(config$general$polygon_path)
  
  # Generar grid de búsqueda
  grid <- generate_grid_bboxes(
    polygon, 
    grid_size = config$spatial$grid_size_degrees
  )
  
  # Limitar a las primeras 5 cajas
  grid <- grid[1:min(5, nrow(grid)), ]
  
  cat("Consultando GBIF en", nrow(grid), "cajas...\n\n")
  
  # Consultar solo GBIF
  gbif_results <- data.frame()
  
  for (i in 1:nrow(grid)) {
    cat("Procesando caja", i, "de", nrow(grid), "...\n")
    
    box_data <- query_gbif(
      bbox = grid$bbox[i],
      config = config$databases$gbif,
      box_id = i
    )
    
    gbif_results <- rbind(gbif_results, box_data)
  }
  
  cat("\n--- Resumen GBIF ---\n")
  cat("Total de registros:", nrow(gbif_results), "\n")
  cat("Especies únicas:", n_distinct(gbif_results$species), "\n")
  cat("Rango de años:", min(gbif_results$year, na.rm = TRUE), "-",
      max(gbif_results$year, na.rm = TRUE), "\n")
  
  return(gbif_results)
}

# ============================================================================
# EJEMPLO 4: Análisis de Resultados
# ============================================================================

example_results_analysis <- function(results = NULL) {
  cat("=== EJEMPLO 4: ANÁLISIS DE RESULTADOS ===\n")
  
  if (is.null(results)) {
    source("scripts/database_queries.R")
    results <- execute_biodiversity_queries(
      config_file = "scripts/query_config.json"
    )
  }
  
  data <- results$results
  
  # Estadísticas generales
  cat("\n--- ESTADÍSTICAS GENERALES ---\n")
  cat("Total de registros:", nrow(data), "\n")
  cat("Registros únicos:", nrow(distinct(data, species, lon, lat, year, source)), "\n")
  cat("Especies únicas:", n_distinct(data$species), "\n")
  cat("Fuentes de datos:", paste(unique(data$source), collapse = ", "), "\n")
  
  # Registros por fuente
  cat("\n--- REGISTROS POR FUENTE ---\n")
  by_source <- table(data$source)
  print(by_source)
  
  # Especies por fuente
  cat("\n--- ESPECIES POR FUENTE ---\n")
  by_source_species <- data %>%
    group_by(source) %>%
    summarise(
      n_species = n_distinct(species),
      n_records = n(),
      .groups = "drop"
    ) %>%
    arrange(desc(n_records))
  print(as.data.frame(by_source_species))
  
  # Rango temporal
  cat("\n--- RANGO TEMPORAL ---\n")
  temporal <- data %>%
    filter(!is.na(year)) %>%
    summarise(
      year_min = min(year),
      year_max = max(year),
      n_with_year = n(),
      n_without_year = sum(is.na(year)) + nrow(data) - n()
    )
  print(as.data.frame(temporal))
  
  # Top especies
  cat("\n--- TOP 10 ESPECIES ---\n")
  top_species <- data %>%
    group_by(species) %>%
    summarise(n = n(), .groups = "drop") %>%
    arrange(desc(n)) %>%
    head(10)
  print(as.data.frame(top_species))
  
  # Cobertura espacial
  cat("\n--- COBERTURA ESPACIAL ---\n")
  spatial <- data %>%
    summarise(
      lon_min = min(lon, na.rm = TRUE),
      lon_max = max(lon, na.rm = TRUE),
      lat_min = min(lat, na.rm = TRUE),
      lat_max = max(lat, na.rm = TRUE),
      area_width = lon_max - lon_min,
      area_height = lat_max - lat_min
    )
  print(as.data.frame(spatial))
  
  return(list(
    general_stats = list(
      total_records = nrow(data),
      unique_species = n_distinct(data$species)
    ),
    by_source = by_source_species,
    top_species = top_species,
    spatial_coverage = spatial
  ))
}

# ============================================================================
# EJEMPLO 5: Integración con Shiny App
# ============================================================================

example_shiny_integration <- function() {
  cat("=== EJEMPLO 5: INTEGRACIÓN CON SHINY APP ===\n")
  
  # Este es el código que se debe añadir a server_logic.R
  
  example_code <- '
  # En server_logic.R, agregar después de las funciones existentes:
  
  # Cargar script de consultas a bases de datos
  source("scripts/database_queries.R")
  
  # Observar botón para ejecutar consultas desde ShinyApp
  observeEvent(input$execute_external_queries, {
    tryCatch({
      # Mostrar notificación de inicio
      showNotification(
        "Iniciando consultas a bases de datos...",
        type = "message",
        duration = 3
      )
      
      # Actualizar estado
      values$query_status <- "working"
      values$start_time <- Sys.time()
      
      # Ejecutar consultas
      query_results <- execute_biodiversity_queries(
        config_file = "scripts/query_config.json",
        polygon_file = if (!is.null(polygon)) "temp_polygon.shp" else NULL,
        output_dir = "data/query_results"
      )
      
      # Consolidar con datos existentes
      if (nrow(query_results$results) > 0) {
        values$biodiversity_data <- rbind(
          values$biodiversity_data,
          query_results$results
        )
        
        # Eliminar duplicados
        values$biodiversity_data <- values$biodiversity_data %>%
          distinct(species, lon, lat, year, source, .keep_all = TRUE)
      }
      
      # Actualizar estado
      values$query_status <- "completed"
      values$total_records_found <- nrow(values$biodiversity_data)
      values$unique_species_count <- n_distinct(values$biodiversity_data$species)
      
      # Mostrar resultados
      showNotification(
        paste("✓ Consultas completadas. Registros totales:",
              values$total_records_found),
        type = "message",
        duration = 5
      )
      
    }, error = function(e) {
      values$query_status <- "error"
      showNotification(
        paste("Error en consultas:", e$message),
        type = "error",
        duration = 5
      )
    })
  })
  
  # En ui.R, agregar botón para ejecutar consultas:
  actionButton("execute_external_queries", 
               "Ejecutar Consultas Externas",
               icon = icon("download"))
  '
  
  cat(example_code)
  cat("\n")
  
  return(example_code)
}

# ============================================================================
# EJEMPLO 6: Consulta con Shapefile Personalizado
# ============================================================================

example_custom_shapefile <- function(shp_path) {
  cat("=== EJEMPLO 6: CONSULTA CON SHAPEFILE PERSONALIZADO ===\n")
  
  source("scripts/database_queries.R")
  
  # Validar que el shapefile existe
  if (!file.exists(shp_path)) {
    cat("Error: Shapefile no encontrado:", shp_path, "\n")
    return(NULL)
  }
  
  # Cargar configuración
  config <- load_query_config("scripts/query_config.json")
  
  # Actualizar ruta del shapefile en configuración
  config$general$polygon_path <- shp_path
  
  # Guardar configuración temporal
  temp_config_file <- "scripts/query_config_temp.json"
  write_json(config, temp_config_file, pretty = TRUE)
  
  # Ejecutar consultas
  results <- execute_biodiversity_queries(
    config_file = temp_config_file
  )
  
  # Limpiar archivo temporal
  file.remove(temp_config_file)
  
  return(results)
}

# ============================================================================
# EJEMPLO 7: Exportar Resultados en Diferentes Formatos
# ============================================================================

example_export_results <- function(results = NULL) {
  cat("=== EJEMPLO 7: EXPORTAR RESULTADOS ===\n")
  
  if (is.null(results)) {
    source("scripts/database_queries.R")
    results <- execute_biodiversity_queries(
      config_file = "scripts/query_config.json"
    )
  }
  
  data <- results$results
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  output_dir <- "data/exports"
  
  # Crear directorio si no existe
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Exportar CSV
  csv_file <- file.path(output_dir, paste0("results_", timestamp, ".csv"))
  write.csv(data, csv_file, row.names = FALSE)
  cat("✓ CSV exportado:", csv_file, "\n")
  
  # Exportar JSON
  json_file <- file.path(output_dir, paste0("results_", timestamp, ".json"))
  write_json(data, json_file, pretty = TRUE)
  cat("✓ JSON exportado:", json_file, "\n")
  
  # Exportar Excel
  xlsx_file <- file.path(output_dir, paste0("results_", timestamp, ".xlsx"))
  
  # Crear workbook con múltiples hojas
  wb <- createWorkbook()
  
  # Hoja 1: Datos completos
  addWorksheet(wb, "Resultados")
  writeData(wb, "Resultados", data)
  
  # Hoja 2: Resumen por fuente
  summary_by_source <- data %>%
    group_by(source) %>%
    summarise(
      n_records = n(),
      n_species = n_distinct(species),
      .groups = "drop"
    )
  addWorksheet(wb, "Resumen por Fuente")
  writeData(wb, "Resumen por Fuente", summary_by_source)
  
  # Hoja 3: Top especies
  top_species <- data %>%
    group_by(species) %>%
    summarise(
      n_records = n(),
      sources = paste(unique(source), collapse = ", "),
      .groups = "drop"
    ) %>%
    arrange(desc(n_records)) %>%
    head(50)
  addWorksheet(wb, "Top 50 Especies")
  writeData(wb, "Top 50 Especies", top_species)
  
  # Guardar workbook
  saveWorkbook(wb, xlsx_file, overwrite = TRUE)
  cat("✓ Excel exportado:", xlsx_file, "\n")
  
  # Exportar resumen de metadatos
  metadata <- list(
    export_date = Sys.time(),
    total_records = nrow(data),
    unique_species = n_distinct(data$species),
    data_sources = unique(data$source),
    temporal_range = c(
      min_year = min(data$year, na.rm = TRUE),
      max_year = max(data$year, na.rm = TRUE)
    ),
    spatial_extent = c(
      lon_range = c(min(data$lon), max(data$lon)),
      lat_range = c(min(data$lat), max(data$lat))
    )
  )
  
  metadata_file <- file.path(output_dir, paste0("metadata_", timestamp, ".json"))
  write_json(metadata, metadata_file, pretty = TRUE)
  cat("✓ Metadatos exportados:", metadata_file, "\n")
  
  return(output_dir)
}

# ============================================================================
# FUNCIÓN PARA EJECUTAR TODOS LOS EJEMPLOS
# ============================================================================

run_all_examples <- function() {
  cat("\n")
  cat("╔════════════════════════════════════════════════════════════╗\n")
  cat("║   EJEMPLOS DE USO - DATABASE QUERIES SCRIPT                ║\n")
  cat("╚════════════════════════════════════════════════════════════╝\n\n")
  
  # Preguntar qué ejemplo ejecutar
  cat("Selecciona un ejemplo para ejecutar:\n")
  cat("1. Uso básico (configuración por defecto)\n")
  cat("2. Consulta personalizada (modificar parámetros)\n")
  cat("3. Consulta a una sola base de datos (GBIF)\n")
  cat("4. Análisis de resultados\n")
  cat("5. Ver código de integración con Shiny\n")
  cat("6. Exportar resultados\n")
  cat("0. Salir\n\n")
  
  choice <- as.numeric(readline("Ingresa el número del ejemplo: "))
  
  switch(choice,
    {
      # Opción 1
      results <- example_basic_usage()
      invisible(results)
    },
    {
      # Opción 2
      results <- example_custom_parameters()
      invisible(results)
    },
    {
      # Opción 3
      results <- example_single_database()
      invisible(results)
    },
    {
      # Opción 4
      example_results_analysis()
    },
    {
      # Opción 5
      example_shiny_integration()
    },
    {
      # Opción 6
      example_export_results()
    },
    {
      # Opción 0
      cat("Saliendo...\n")
    },
    {
      cat("Opción no válida\n")
    }
  )
}

# ============================================================================
# INSTRUCCIONES DE USO
# ============================================================================

# Para ejecutar los ejemplos, desde la consola de R:
#
# source("scripts/example_usage.R")
#
# # Ejecutar un ejemplo específico:
# example_basic_usage()
#
# # O ejecutar el menú interactivo:
# run_all_examples()
