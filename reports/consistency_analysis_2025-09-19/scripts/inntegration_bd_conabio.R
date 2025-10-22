# =============================================================================
# SCRIPT DE INTEGRACIÓN DE DATOS CONABIO
# =============================================================================
# Objetivo: Integrar datos de ocurrencia de CONABIO con el archivo de biodiversidad existente
# Fuente: Archivos ZIP de CONABIO por grupos taxonómicos
# Destino: biodiversity_integrated_2025-09-19.csv actualizado
#
# Autor: GitHub Copilot
# Fecha: 2025-09-19
# =============================================================================

# Limpiar workspace
rm(list = ls())

# Cargar librerías necesarias
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(stringr)
})

# =============================================================================
# CONFIGURACIÓN Y FUNCIONES AUXILIARES
# =============================================================================

# Definir rutas
conabio_downloads_dir <- "/home/atlantis/biodiversity_atlantis_goc/data/conabio/conabio_downloads"
current_biodiversity_file <- "/home/atlantis/biodiversity_atlantis_goc/data/occurrence/biodiversity_integrated_2025-09-19.csv"
output_dir <- "/home/atlantis/biodiversity_atlantis_goc/data/occurrence"

# Función para limpiar nombres de especies
clean_species_name <- function(species_name) {
  sapply(species_name, function(x) {
    if (is.na(x) || x == "" || is.null(x)) return(NA)
    
    # Convertir a minúsculas y limpiar espacios extra
    cleaned <- tolower(trimws(as.character(x)))
    cleaned <- gsub("\\s+", " ", cleaned)
    
    return(cleaned)
  }, USE.NAMES = FALSE)
}

# Función para validar coordenadas
validate_coordinates <- function(lon, lat) {
  valid_lon <- !is.na(lon) & lon >= -180 & lon <= 180 & lon != 0
  valid_lat <- !is.na(lat) & lat >= -90 & lat <= 90 & lat != 0
  return(valid_lon & valid_lat)
}

# Función para determinar rango taxonómico basado en CONABIO data
determine_taxon_rank <- function(especie, genero, familia, orden, clase) {
  case_when(
    !is.na(especie) & especie != "" ~ "SPECIES",
    !is.na(genero) & genero != "" ~ "GENUS", 
    !is.na(familia) & familia != "" ~ "FAMILY",
    !is.na(orden) & orden != "" ~ "ORDER",
    !is.na(clase) & clase != "" ~ "CLASS",
    TRUE ~ "UNKNOWN"
  )
}

# =============================================================================
# CARGAR ARCHIVO DE BIODIVERSIDAD EXISTENTE
# =============================================================================

cat("Cargando archivo de biodiversidad existente...\n")
existing_data <- read_csv(current_biodiversity_file, show_col_types = FALSE)
cat(sprintf("Registros existentes: %d\n", nrow(existing_data)))

# =============================================================================
# PROCESAR ARCHIVOS ZIP DE CONABIO
# =============================================================================

cat("Procesando archivos ZIP de CONABIO...\n")

# Obtener lista de archivos ZIP
zip_files <- list.files(conabio_downloads_dir, pattern = "\\.zip$", full.names = TRUE)
cat(sprintf("Archivos ZIP encontrados: %d\n", length(zip_files)))

# Inicializar lista para almacenar datos de CONABIO
conabio_records_list <- list()

# Procesar cada archivo ZIP
for (zip_file in zip_files) {
  
  cat(sprintf("Procesando: %s\n", basename(zip_file)))
  
  tryCatch({
    # Extraer grupo taxonómico del nombre del archivo
    group_name <- gsub("\\.202503\\.csv\\.zip$", "", basename(zip_file))
    
    # Crear directorio temporal
    temp_dir <- tempdir()
    
    # Extraer archivo ZIP
    unzip(zip_file, exdir = temp_dir)
    
    # Buscar archivos CSV principales (no los específicos por UTM o región)
    csv_files <- list.files(temp_dir, pattern = paste0("^", group_name, "\\.csv$"), full.names = TRUE)
    
    if (length(csv_files) > 0) {
      main_csv <- csv_files[1]
      
      cat(sprintf("  Leyendo archivo principal: %s\n", basename(main_csv)))
      
      # Leer datos de CONABIO
      conabio_data <- read_csv(main_csv, 
                               show_col_types = FALSE,
                               locale = locale(encoding = "UTF-8"))
      
      cat(sprintf("  Registros en archivo: %d\n", nrow(conabio_data)))
      
      # Procesar y estandarizar datos
      processed_data <- conabio_data %>%
        # Filtrar registros con coordenadas válidas
        filter(!is.na(longitud) & !is.na(latitud)) %>%
        filter(validate_coordinates(longitud, latitud)) %>%
        # Filtrar registros con especies válidas
        filter(!is.na(especievalida) & especievalida != "") %>%
        # Crear campos estándar
        mutate(
          species = clean_species_name(especievalida),
          lon = as.numeric(longitud),
          lat = as.numeric(latitud),
          year = as.numeric(aniocolecta),
          month = as.numeric(mescolecta), 
          day = as.numeric(diacolecta),
          date_recorded = case_when(
            !is.na(fechacolecta) & fechacolecta != "" ~ as.character(fechacolecta),
            !is.na(year) & !is.na(month) & !is.na(day) ~ 
              paste(year, sprintf("%02d", month), sprintf("%02d", day), sep = "-"),
            !is.na(year) & !is.na(month) ~ 
              paste(year, sprintf("%02d", month), "01", sep = "-"),
            !is.na(year) ~ paste(year, "01", "01", sep = "-"),
            TRUE ~ NA_character_
          ),
          taxonRank = determine_taxon_rank(especievalida, generovalido, familiavalida, ordenvalido, clasevalida),
          source = paste0("CONABIO_", stringr::str_to_title(group_name)),
          original_source = fuente,
          integration_source = "CONABIO_Mexico"
        ) %>%
        # Seleccionar solo columnas necesarias
        select(species, lon, lat, year, month, day, date_recorded, taxonRank, 
               source, original_source, integration_source) %>%
        # Remover registros con especies NA después de la limpieza
        filter(!is.na(species)) %>%
        # Remover duplicados exactos
        distinct()
      
      cat(sprintf("  Registros procesados válidos: %d\n", nrow(processed_data)))
      
      # Agregar a la lista
      conabio_records_list[[group_name]] <- processed_data
      
      # Limpiar archivos temporales
      unlink(temp_dir, recursive = TRUE)
      
    } else {
      cat(sprintf("  No se encontró archivo CSV principal para %s\n", group_name))
    }
    
  }, error = function(e) {
    cat(sprintf("  Error procesando %s: %s\n", basename(zip_file), e$message))
  })
}

# =============================================================================
# COMBINAR DATOS DE CONABIO
# =============================================================================

cat("Combinando datos de CONABIO...\n")

if (length(conabio_records_list) > 0) {
  # Combinar todos los grupos de CONABIO
  all_conabio_data <- bind_rows(conabio_records_list)
  
  cat(sprintf("Total de registros CONABIO procesados: %d\n", nrow(all_conabio_data)))
  
  # Estadísticas por grupo
  cat("Registros por grupo taxonómico:\n")
  group_stats <- table(all_conabio_data$source)
  for(i in 1:length(group_stats)) {
    cat(sprintf("  %s: %d\n", names(group_stats)[i], group_stats[i]))
  }
  
} else {
  stop("No se procesaron datos de CONABIO exitosamente")
}

# =============================================================================
# INTEGRAR CON DATOS EXISTENTES
# =============================================================================

cat("Integrando con datos existentes...\n")

# Preparar datos existentes (asegurar que tengan las mismas columnas)
existing_data_clean <- existing_data %>%
  mutate(
    # Asegurar que las columnas existan y sean del tipo correcto
    year = as.numeric(year),
    month = as.numeric(month),
    day = as.numeric(day),
    lon = as.numeric(lon),
    lat = as.numeric(lat)
  ) %>%
  # Asegurar que tengan todas las columnas necesarias
  select(species, lon, lat, year, month, day, date_recorded, taxonRank, 
         source, original_source, integration_source)

# Combinar datos existentes con nuevos datos de CONABIO
integrated_data <- bind_rows(
  existing_data_clean,
  all_conabio_data
) %>%
  # Agregar ID único
  mutate(record_id = row_number()) %>%
  # Reordenar columnas para coincidir con el formato original
  select(record_id, species, lon, lat, year, month, day, date_recorded, 
         taxonRank, source, original_source, integration_source)

# =============================================================================
# VALIDACIÓN Y ESTADÍSTICAS
# =============================================================================

cat("Generando estadísticas finales...\n")

# Estadísticas generales
total_records <- nrow(integrated_data)
existing_records <- nrow(existing_data)
new_conabio_records <- nrow(all_conabio_data)
unique_species <- length(unique(integrated_data$species[!is.na(integrated_data$species)]))
records_with_coords <- sum(validate_coordinates(integrated_data$lon, integrated_data$lat))

cat("\n=== RESUMEN DE INTEGRACIÓN CONABIO ===\n")
cat(sprintf("Registros existentes: %d\n", existing_records))
cat(sprintf("Nuevos registros CONABIO: %d\n", new_conabio_records))
cat(sprintf("Total registros integrados: %d\n", total_records))
cat(sprintf("Especies/taxa únicos: %d\n", unique_species))
cat(sprintf("Registros con coordenadas válidas: %d (%.1f%%)\n", 
            records_with_coords, (records_with_coords/total_records)*100))

# Estadísticas por fuente de integración
cat("\nRegistros por fuente de integración:\n")
source_stats <- table(integrated_data$integration_source)
for(i in 1:length(source_stats)) {
  cat(sprintf("  %s: %d\n", names(source_stats)[i], source_stats[i]))
}

# Estadísticas por rango taxonómico
cat("\nRegistros por rango taxonómico:\n")
rank_stats <- table(integrated_data$taxonRank, useNA = "ifany")
for(i in 1:length(rank_stats)) {
  cat(sprintf("  %s: %d\n", names(rank_stats)[i], rank_stats[i]))
}

# =============================================================================
# GUARDAR RESULTADOS
# =============================================================================

cat("Guardando archivo integrado...\n")

# Crear nombre del archivo de salida
output_filename <- file.path(output_dir, paste0("biodiversity_integrated_conabio_", Sys.Date(), ".csv"))

# Guardar datos integrados
write_csv(integrated_data, output_filename)

cat(sprintf("Archivo guardado como: %s\n", output_filename))

# Guardar reporte de integración
report_filename <- file.path(output_dir, paste0("conabio_integration_report_", Sys.Date(), ".txt"))
sink(report_filename)
cat("REPORTE DE INTEGRACIÓN CONABIO\n")
cat("==============================\n")
cat(sprintf("Fecha de integración: %s\n", Sys.Date()))
cat(sprintf("Hora de integración: %s\n", Sys.time()))
cat("\nARCHIVOS FUENTE:\n")
cat("1. biodiversity_integrated_2025-09-19.csv (datos existentes)\n")
cat("2. Archivos ZIP CONABIO por grupos taxonómicos:\n")
for(zip_file in zip_files) {
  cat(sprintf("   - %s\n", basename(zip_file)))
}
cat(sprintf("\nREGISTROS EXISTENTES: %d\n", existing_records))
cat(sprintf("NUEVOS REGISTROS CONABIO: %d\n", new_conabio_records))
cat(sprintf("TOTAL REGISTROS INTEGRADOS: %d\n", total_records))
cat(sprintf("ESPECIES/TAXA ÚNICOS: %d\n", unique_species))
cat(sprintf("REGISTROS CON COORDENADAS: %d\n", records_with_coords))
cat("\nDETALLE POR FUENTE:\n")
for(i in 1:length(source_stats)) {
  cat(sprintf("%s: %d registros\n", names(source_stats)[i], source_stats[i]))
}
cat("\nDETALLE POR GRUPO CONABIO:\n")
for(i in 1:length(group_stats)) {
  cat(sprintf("%s: %d registros\n", names(group_stats)[i], group_stats[i]))
}
sink()

cat(sprintf("Reporte guardado como: %s\n", report_filename))
cat("\n=== INTEGRACIÓN CONABIO COMPLETADA EXITOSAMENTE ===\n")
