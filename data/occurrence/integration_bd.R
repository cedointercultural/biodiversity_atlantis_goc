# =============================================================================
# SCRIPT DE INTEGRACIÓN DE DATOS DE BIODIVERSIDAD
# =============================================================================
# Objetivo: Integrar datos de biodiversidad de tres fuentes:
# 1. biodiversity_results_2025-09-19.csv (archivo principal)
# 2. ForHem-31July2025-18S-GOC-CarabantesETAL.xlsx (datos OTU con metadatos)
# 3. Valdivia-2021-542OTUs-Location.xlsx (datos OTU con taxonomía)
#
# Autor: Script generado automáticamente
# Fecha: 2025-09-19
# =============================================================================

# Cargar librerías necesarias
suppressPackageStartupMessages({
  library(readr)
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(lubridate)
})

# =============================================================================
# FUNCIONES AUXILIARES
# =============================================================================

#' Limpiar nombres de especies
clean_species_name <- function(species_name) {
  # Función vectorizada para manejar múltiples valores
  sapply(species_name, function(x) {
    if (is.na(x) || x == "" || is.null(x)) return(NA)
    
    # Convertir a minúsculas y limpiar espacios extra
    cleaned <- tolower(trimws(as.character(x)))
    
    # Remover caracteres especiales al final
    cleaned <- gsub("\\s+", " ", cleaned)
    
    return(cleaned)
  }, USE.NAMES = FALSE)
}

#' Extraer año de fecha
extract_year_from_date <- function(date_col) {
  if (is.POSIXct(date_col) || is.Date(date_col)) {
    return(year(date_col))
  }
  return(NA)
}

#' Validar coordenadas
validate_coordinates <- function(lon, lat) {
  valid_lon <- !is.na(lon) & lon >= -180 & lon <= 180
  valid_lat <- !is.na(lat) & lat >= -90 & lat <= 90
  return(valid_lon & valid_lat)
}

# =============================================================================
# CARGAR DATOS
# =============================================================================

cat("Cargando datos...\n")

# 1. Cargar archivo principal
cat("1. Cargando archivo principal...\n")
main_data <- read_csv("biodiversity_results_2025-09-19.csv", 
                      show_col_types = FALSE)

cat(sprintf("   - Registros principales: %d\n", nrow(main_data)))

# 2. Cargar datos ForHem
cat("2. Cargando datos ForHem...\n")

# Metadatos (coordenadas y fechas)
forhem_meta <- read_excel("ForHem-31July2025-18S-GOC-CarabantesETAL.xlsx", 
                          sheet = "Sheet2", skip = 2) %>%
  filter(!is.na(`SAMPLE NUM`) & !is.na(ZONE)) %>%
  mutate(
    Latitude = as.numeric(Latitude),
    Longitude = as.numeric(Longitude),
    sample_id = paste0("ForHem_", `SAMPLE NUM`)
  ) %>%
  filter(!is.na(Latitude) & !is.na(Longitude))

# Datos de biodiversidad (OTUs) - simplificado
forhem_bio_raw <- read_excel("ForHem-31July2025-18S-GOC-CarabantesETAL.xlsx", 
                             sheet = "Sheet1", skip = 2)

cat(sprintf("   - Muestras ForHem con coordenadas: %d\n", nrow(forhem_meta)))

# 3. Cargar datos Valdivia
cat("3. Cargando datos Valdivia...\n")
valdivia_data <- read_excel("Valdivia-2021-542OTUs-Location.xlsx", 
                            sheet = "Sheet1")

cat(sprintf("   - OTUs Valdivia: %d\n", nrow(valdivia_data)))

# =============================================================================
# PROCESAMIENTO DE DATOS FORHEM
# =============================================================================

cat("Procesando datos ForHem...\n")

# Procesar datos de biodiversidad del Sheet1
# Las columnas 6 en adelante contienen las muestras
sample_cols_start <- 6  # Después de las columnas taxonómicas
sample_cols_end <- ncol(forhem_bio_raw)
sample_columns <- colnames(forhem_bio_raw)[sample_cols_start:sample_cols_end]

# Identificar columnas que corresponden a números de muestra
numeric_sample_cols <- sample_columns[grepl("^[0-9]+$", sample_columns)]

cat(sprintf("   - Columnas de muestras numéricas identificadas: %d\n", length(numeric_sample_cols)))

# Crear registros de ocurrencia para cada OTU en cada muestra
forhem_records <- forhem_bio_raw %>%
  # Filtrar filas con datos válidos
  filter(!is.na(otu) & otu == "otu") %>%
  # Seleccionar columnas relevantes
  select(all_of(c("otu", "#otu  ID", "NCBI Taxonomy", "Organismo", numeric_sample_cols))) %>%
  # Convertir a formato largo
  pivot_longer(cols = all_of(numeric_sample_cols), 
               names_to = "sample_num", 
               values_to = "abundance") %>%
  # Filtrar presencias (abundancia > 0)
  filter(!is.na(abundance) & abundance > 0) %>%
  # Convertir sample_num a numérico para hacer join
  mutate(sample_num = as.numeric(sample_num)) %>%
  # Hacer join con metadatos para obtener coordenadas
  left_join(forhem_meta %>% 
            filter(!is.na(`SAMPLE NUM`)) %>%
            select(`SAMPLE NUM`, Longitude, Latitude, `Collected date year`, ZONE, `SITE NAME`) %>%
            rename(sample_num = `SAMPLE NUM`), 
            by = "sample_num") %>%
  # Filtrar solo registros con coordenadas válidas
  filter(!is.na(Longitude) & !is.na(Latitude)) %>%
  # Crear campos estándar
  mutate(
    species = case_when(
      !is.na(`NCBI Taxonomy`) & `NCBI Taxonomy` != "" ~ 
        paste0("OTU_", `#otu  ID`, "_", gsub("[^A-Za-z0-9_]", "_", substr(`NCBI Taxonomy`, 1, 50))),
      !is.na(Organismo) & Organismo != "" ~ 
        paste0("OTU_", `#otu  ID`, "_", gsub("[^A-Za-z0-9_]", "_", Organismo)),
      TRUE ~ paste0("OTU_ForHem_", `#otu  ID`)
    ),
    lon = as.numeric(Longitude),
    lat = as.numeric(Latitude),
    year = extract_year_from_date(`Collected date year`),
    month = month(`Collected date year`),
    day = day(`Collected date year`),
    date_recorded = as.character(`Collected date year`),
    taxonRank = "OTU",
    source = paste0("ForHem_", ZONE, "_Sample_", sample_num)
  ) %>%
  # Seleccionar columnas finales
  select(species, lon, lat, year, month, day, date_recorded, taxonRank, source) %>%
  # Validar coordenadas
  filter(validate_coordinates(lon, lat)) %>%
  # Remover duplicados
  distinct()

cat(sprintf("   - Registros ForHem procesados: %d\n", nrow(forhem_records)))

# =============================================================================
# PROCESAMIENTO DE DATOS VALDIVIA
# =============================================================================

cat("Procesando datos Valdivia...\n")

# Obtener lista de estaciones con datos
site_columns <- colnames(valdivia_data)[17:46]

# Crear registros de ocurrencia para cada especie en cada sitio donde está presente
valdivia_records <- valdivia_data %>%
  # Limpiar nombres de especies
  mutate(
    clean_species = case_when(
      !is.na(Species) & Species != "" ~ clean_species_name(Species),
      !is.na(Genre) & Genre != "" ~ paste(clean_species_name(Genre), "sp."),
      !is.na(Family) & Family != "" ~ paste(clean_species_name(Family), "family"),
      TRUE ~ paste0("OTU_", Query)
    )
  ) %>%
  # Convertir a formato largo para cada sitio
  pivot_longer(cols = all_of(site_columns), 
               names_to = "site", 
               values_to = "abundance") %>%
  # Filtrar solo presencias (abundancia > 0)
  filter(!is.na(abundance) & abundance > 0) %>%
  # Crear registros estándar
  mutate(
    species = clean_species,
    lon = NA,  # No tenemos coordenadas específicas para cada sitio
    lat = NA,
    year = 2021,  # Basado en el nombre del archivo
    month = NA,
    day = NA,
    date_recorded = "2021",
    taxonRank = case_when(
      !is.na(Species) & Species != "" ~ "SPECIES",
      !is.na(Genre) & Genre != "" ~ "GENUS",
      !is.na(Family) & Family != "" ~ "FAMILY",
      TRUE ~ "OTU"
    ),
    source = paste0("Valdivia_2021_", site)
  ) %>%
  select(species, lon, lat, year, month, day, date_recorded, taxonRank, source) %>%
  distinct()  # Remover duplicados

cat(sprintf("   - Registros Valdivia procesados: %d\n", nrow(valdivia_records)))

# =============================================================================
# INTEGRACIÓN DE DATOS
# =============================================================================

cat("Integrando todos los datasets...\n")

# Estandarizar el formato de todos los datasets
main_data_clean <- main_data %>%
  mutate(
    species = clean_species_name(species),
    integration_source = "Original_GBIF_iDigBio"
  ) %>%
  filter(!is.na(species))

forhem_records_clean <- forhem_records %>%
  mutate(
    species = clean_species_name(species),
    integration_source = "ForHem_Marine_Samples"
  ) %>%
  filter(!is.na(species))

valdivia_records_clean <- valdivia_records %>%
  mutate(
    species = clean_species_name(species),
    integration_source = "Valdivia_OTU_Analysis"
  ) %>%
  filter(!is.na(species))

# Combinar todos los datasets
integrated_data <- bind_rows(
  main_data_clean %>% mutate(original_source = source, source = integration_source),
  forhem_records_clean %>% mutate(original_source = source, source = integration_source),
  valdivia_records_clean %>% mutate(original_source = source, source = integration_source)
) %>%
  # Agregar ID único
  mutate(record_id = row_number()) %>%
  # Reordenar columnas
  select(record_id, species, lon, lat, year, month, day, date_recorded, 
         taxonRank, source, original_source, integration_source)

# =============================================================================
# VALIDACIÓN Y ESTADÍSTICAS
# =============================================================================

cat("Generando estadísticas de integración...\n")

# Estadísticas generales
total_records <- nrow(integrated_data)
unique_species <- length(unique(integrated_data$species[!is.na(integrated_data$species)]))
records_with_coords <- sum(validate_coordinates(integrated_data$lon, integrated_data$lat))

cat("\n=== RESUMEN DE INTEGRACIÓN ===\n")
cat(sprintf("Total de registros integrados: %d\n", total_records))
cat(sprintf("Especies/taxa únicos: %d\n", unique_species))
cat(sprintf("Registros con coordenadas válidas: %d (%.1f%%)\n", 
            records_with_coords, (records_with_coords/total_records)*100))

# Estadísticas por fuente
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

# Validación de duplicados
potential_duplicates <- integrated_data %>%
  filter(!is.na(species) & !is.na(lon) & !is.na(lat)) %>%
  group_by(species, round(lon, 4), round(lat, 4), year) %>%
  summarise(count = n(), .groups = "drop") %>%
  filter(count > 1)

cat(sprintf("\nPosibles registros duplicados: %d grupos\n", nrow(potential_duplicates)))

# =============================================================================
# GUARDAR RESULTADOS
# =============================================================================

cat("Guardando archivo integrado...\n")

# Crear nombre del archivo de salida
output_filename <- paste0("biodiversity_integrated_", Sys.Date(), ".csv")

# Guardar datos integrados
write_csv(integrated_data, output_filename)

cat(sprintf("Archivo guardado como: %s\n", output_filename))

# Guardar reporte de integración
report_filename <- paste0("integration_report_", Sys.Date(), ".txt")
sink(report_filename)
cat("REPORTE DE INTEGRACIÓN DE DATOS DE BIODIVERSIDAD\n")
cat("===============================================\n")
cat(sprintf("Fecha de integración: %s\n", Sys.Date()))
cat(sprintf("Hora de integración: %s\n", Sys.time()))
cat("\nARCHIVOS FUENTE:\n")
cat("1. biodiversity_results_2025-09-19.csv\n")
cat("2. ForHem-31July2025-18S-GOC-CarabantesETAL.xlsx\n")
cat("3. Valdivia-2021-542OTUs-Location.xlsx\n")
cat(sprintf("\nTOTAL REGISTROS INTEGRADOS: %d\n", total_records))
cat(sprintf("ESPECIES/TAXA ÚNICOS: %d\n", unique_species))
cat(sprintf("REGISTROS CON COORDENADAS: %d\n", records_with_coords))
cat("\nDETALLE POR FUENTE:\n")
for(i in 1:length(source_stats)) {
  cat(sprintf("%s: %d registros\n", names(source_stats)[i], source_stats[i]))
}
sink()

cat(sprintf("Reporte guardado como: %s\n", report_filename))
cat("\n=== INTEGRACIÓN COMPLETADA EXITOSAMENTE ===\n")