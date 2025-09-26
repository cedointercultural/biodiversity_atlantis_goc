# =============================================================================
# SCRIPT DE ANÁLISIS DE CONSISTENCIA DE BASE DE DATOS INTEGRADA
# =============================================================================
# Objetivo: Analizar la consistencia y calidad de la base de datos de biodiversidad integrada
# Fuente: biodiversity_integrated_conabio_2025-09-19.csv
# Salida: Reporte detallado de consistencia y calidad de datos
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
  library(ggplot2)
  library(sf)
  library(maps)
})

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

# Definir rutas
data_dir <- "/home/atlantis/biodiversity_atlantis_goc/data/occurrence"
input_file <- file.path(data_dir, "biodiversity_integrated_conabio_2025-09-19.csv")
output_dir <- data_dir

# Función para crear gráficos si es posible
safe_plot <- function(plot_expr, filename, width = 10, height = 8) {
  tryCatch({
    ggsave(filename, plot_expr, width = width, height = height, dpi = 150)
    cat(sprintf("Gráfico guardado: %s\n", filename))
  }, error = function(e) {
    cat(sprintf("Error creando gráfico %s: %s\n", filename, e$message))
  })
}

# =============================================================================
# CARGAR Y EXAMINAR DATOS
# =============================================================================

cat("=== ANÁLISIS DE CONSISTENCIA DE BASE DE DATOS INTEGRADA ===\n")
cat(sprintf("Fecha de análisis: %s\n", Sys.Date()))
cat(sprintf("Hora de análisis: %s\n\n", Sys.time()))

cat("Cargando datos integrados...\n")
integrated_data <- read_csv(input_file, show_col_types = FALSE)

cat(sprintf("Datos cargados exitosamente: %d registros\n\n", nrow(integrated_data)))

# =============================================================================
# ANÁLISIS BÁSICO DE ESTRUCTURA
# =============================================================================

cat("1. ANÁLISIS DE ESTRUCTURA DE DATOS\n")
cat("==================================\n")

# Dimensiones
cat(sprintf("Número de registros: %d\n", nrow(integrated_data)))
cat(sprintf("Número de columnas: %d\n", ncol(integrated_data)))

# Estructura de columnas
cat("\nEstructura de columnas:\n")
col_info <- integrated_data %>%
  summarise_all(~class(.)[1]) %>%
  pivot_longer(everything(), names_to = "columna", values_to = "tipo")

for(i in 1:nrow(col_info)) {
  cat(sprintf("  %s: %s\n", col_info$columna[i], col_info$tipo[i]))
}

# Valores faltantes por columna
cat("\nValores faltantes por columna:\n")
missing_values <- integrated_data %>%
  summarise_all(~sum(is.na(.))) %>%
  pivot_longer(everything(), names_to = "columna", values_to = "valores_faltantes") %>%
  mutate(porcentaje = round((valores_faltantes / nrow(integrated_data)) * 100, 2)) %>%
  arrange(desc(valores_faltantes))

for(i in 1:nrow(missing_values)) {
  cat(sprintf("  %s: %d (%.2f%%)\n", 
              missing_values$columna[i], 
              missing_values$valores_faltantes[i],
              missing_values$porcentaje[i]))
}

# =============================================================================
# ANÁLISIS DE CALIDAD DE COORDENADAS
# =============================================================================

cat("\n2. ANÁLISIS DE CALIDAD DE COORDENADAS\n")
cat("====================================\n")

# Estadísticas de coordenadas
coords_stats <- integrated_data %>%
  summarise(
    total_registros = n(),
    con_longitud = sum(!is.na(lon)),
    con_latitud = sum(!is.na(lat)),
    con_ambas_coords = sum(!is.na(lon) & !is.na(lat)),
    coords_validas = sum(!is.na(lon) & !is.na(lat) & 
                        lon >= -180 & lon <= 180 & 
                        lat >= -90 & lat <= 90),
    coords_no_zero = sum(!is.na(lon) & !is.na(lat) & 
                        lon != 0 & lat != 0 &
                        lon >= -180 & lon <= 180 & 
                        lat >= -90 & lat <= 90)
  )

cat(sprintf("Registros con longitud: %d (%.2f%%)\n", 
            coords_stats$con_longitud, 
            (coords_stats$con_longitud/coords_stats$total_registros)*100))
cat(sprintf("Registros con latitud: %d (%.2f%%)\n", 
            coords_stats$con_latitud, 
            (coords_stats$con_latitud/coords_stats$total_registros)*100))
cat(sprintf("Registros con ambas coordenadas: %d (%.2f%%)\n", 
            coords_stats$con_ambas_coords, 
            (coords_stats$con_ambas_coords/coords_stats$total_registros)*100))
cat(sprintf("Coordenadas válidas (rango correcto): %d (%.2f%%)\n", 
            coords_stats$coords_validas, 
            (coords_stats$coords_validas/coords_stats$total_registros)*100))
cat(sprintf("Coordenadas válidas (no cero): %d (%.2f%%)\n", 
            coords_stats$coords_no_zero, 
            (coords_stats$coords_no_zero/coords_stats$total_registros)*100))

# Rangos de coordenadas
coords_ranges <- integrated_data %>%
  filter(!is.na(lon) & !is.na(lat)) %>%
  summarise(
    lon_min = min(lon, na.rm = TRUE),
    lon_max = max(lon, na.rm = TRUE),
    lat_min = min(lat, na.rm = TRUE),
    lat_max = max(lat, na.rm = TRUE)
  )

cat(sprintf("\nRangos de coordenadas:\n"))
cat(sprintf("  Longitud: %.6f a %.6f\n", coords_ranges$lon_min, coords_ranges$lon_max))
cat(sprintf("  Latitud: %.6f a %.6f\n", coords_ranges$lat_min, coords_ranges$lat_max))

# Coordenadas problemáticas
problematic_coords <- integrated_data %>%
  filter(!is.na(lon) & !is.na(lat)) %>%
  filter(lon < -180 | lon > 180 | lat < -90 | lat > 90 | (lon == 0 & lat == 0))

cat(sprintf("Coordenadas problemáticas: %d registros\n", nrow(problematic_coords)))

# =============================================================================
# ANÁLISIS TEMPORAL
# =============================================================================

cat("\n3. ANÁLISIS TEMPORAL\n")
cat("===================\n")

# Estadísticas de fechas
temporal_stats <- integrated_data %>%
  summarise(
    con_year = sum(!is.na(year)),
    con_month = sum(!is.na(month)),
    con_day = sum(!is.na(day)),
    con_date_recorded = sum(!is.na(date_recorded) & date_recorded != "")
  )

cat(sprintf("Registros con año: %d (%.2f%%)\n", 
            temporal_stats$con_year, 
            (temporal_stats$con_year/nrow(integrated_data))*100))
cat(sprintf("Registros con mes: %d (%.2f%%)\n", 
            temporal_stats$con_month, 
            (temporal_stats$con_month/nrow(integrated_data))*100))
cat(sprintf("Registros con día: %d (%.2f%%)\n", 
            temporal_stats$con_day, 
            (temporal_stats$con_day/nrow(integrated_data))*100))
cat(sprintf("Registros con fecha completa: %d (%.2f%%)\n", 
            temporal_stats$con_date_recorded, 
            (temporal_stats$con_date_recorded/nrow(integrated_data))*100))

# Rangos temporales
year_ranges <- integrated_data %>%
  filter(!is.na(year)) %>%
  summarise(
    year_min = min(year, na.rm = TRUE),
    year_max = max(year, na.rm = TRUE),
    years_unique = n_distinct(year, na.rm = TRUE)
  )

cat(sprintf("\nRango temporal:\n"))
cat(sprintf("  Años: %d a %d (%d años únicos)\n", 
            year_ranges$year_min, year_ranges$year_max, year_ranges$years_unique))

# Años problemáticos
problematic_years <- integrated_data %>%
  filter(!is.na(year) & (year < 1700 | year > 2030))

cat(sprintf("Años problemáticos (< 1700 o > 2030): %d registros\n", nrow(problematic_years)))

# Distribución por décadas
decade_dist <- integrated_data %>%
  filter(!is.na(year) & year >= 1700 & year <= 2030) %>%
  mutate(decade = floor(year/10)*10) %>%
  count(decade, sort = TRUE) %>%
  head(10)

cat("\nTop 10 décadas con más registros:\n")
for(i in 1:nrow(decade_dist)) {
  cat(sprintf("  %ds: %d registros\n", decade_dist$decade[i], decade_dist$n[i]))
}

# =============================================================================
# ANÁLISIS TAXONÓMICO
# =============================================================================

cat("\n4. ANÁLISIS TAXONÓMICO\n")
cat("======================\n")

# Estadísticas de especies
species_stats <- integrated_data %>%
  summarise(
    con_species = sum(!is.na(species) & species != ""),
    species_unique = n_distinct(species, na.rm = TRUE),
    con_taxon_rank = sum(!is.na(taxonRank) & taxonRank != "")
  )

cat(sprintf("Registros con especies: %d (%.2f%%)\n", 
            species_stats$con_species, 
            (species_stats$con_species/nrow(integrated_data))*100))
cat(sprintf("Especies únicas: %d\n", species_stats$species_unique))
cat(sprintf("Registros con rango taxonómico: %d (%.2f%%)\n", 
            species_stats$con_taxon_rank, 
            (species_stats$con_taxon_rank/nrow(integrated_data))*100))

# Distribución por rango taxonómico
taxon_rank_dist <- integrated_data %>%
  count(taxonRank, sort = TRUE) %>%
  mutate(porcentaje = round((n/nrow(integrated_data))*100, 2))

cat("\nDistribución por rango taxonómico:\n")
for(i in 1:nrow(taxon_rank_dist)) {
  rank_name <- ifelse(is.na(taxon_rank_dist$taxonRank[i]), "NA", taxon_rank_dist$taxonRank[i])
  cat(sprintf("  %s: %d (%.2f%%)\n", 
              rank_name, 
              taxon_rank_dist$n[i], 
              taxon_rank_dist$porcentaje[i]))
}

# Top especies más frecuentes
top_species <- integrated_data %>%
  filter(!is.na(species) & species != "") %>%
  count(species, sort = TRUE) %>%
  head(15)

cat("\nTop 15 especies más frecuentes:\n")
for(i in 1:nrow(top_species)) {
  cat(sprintf("  %s: %d registros\n", top_species$species[i], top_species$n[i]))
}

# =============================================================================
# ANÁLISIS POR FUENTE DE DATOS
# =============================================================================

cat("\n5. ANÁLISIS POR FUENTE DE DATOS\n")
cat("===============================\n")

# Distribución por fuente de integración
integration_source_dist <- integrated_data %>%
  count(integration_source, sort = TRUE) %>%
  mutate(porcentaje = round((n/nrow(integrated_data))*100, 2))

cat("Distribución por fuente de integración:\n")
for(i in 1:nrow(integration_source_dist)) {
  source_name <- ifelse(is.na(integration_source_dist$integration_source[i]), 
                       "NA", integration_source_dist$integration_source[i])
  cat(sprintf("  %s: %d (%.2f%%)\n", 
              source_name, 
              integration_source_dist$n[i], 
              integration_source_dist$porcentaje[i]))
}

# Distribución por fuente original
source_dist <- integrated_data %>%
  count(source, sort = TRUE) %>%
  head(10)

cat("\nTop 10 fuentes originales:\n")
for(i in 1:nrow(source_dist)) {
  source_name <- ifelse(is.na(source_dist$source[i]), "NA", source_dist$source[i])
  cat(sprintf("  %s: %d registros\n", source_name, source_dist$n[i]))
}

# Calidad de datos por fuente
data_quality_by_source <- integrated_data %>%
  group_by(integration_source) %>%
  summarise(
    total_registros = n(),
    con_coords = sum(!is.na(lon) & !is.na(lat)),
    con_species = sum(!is.na(species) & species != ""),
    con_year = sum(!is.na(year)),
    coords_validas = sum(!is.na(lon) & !is.na(lat) & 
                        lon >= -180 & lon <= 180 & 
                        lat >= -90 & lat <= 90 &
                        lon != 0 & lat != 0),
    .groups = "drop"
  ) %>%
  mutate(
    pct_coords = round((con_coords/total_registros)*100, 1),
    pct_species = round((con_species/total_registros)*100, 1),
    pct_year = round((con_year/total_registros)*100, 1),
    pct_coords_validas = round((coords_validas/total_registros)*100, 1)
  )

cat("\nCalidad de datos por fuente de integración:\n")
cat("Fuente | Total | Coords(%) | Species(%) | Year(%) | CoordsVal(%)\n")
cat("-------|-------|-----------|------------|---------|-------------\n")
for(i in 1:nrow(data_quality_by_source)) {
  cat(sprintf("%-15s | %6d | %8.1f | %9.1f | %6.1f | %10.1f\n",
              substr(data_quality_by_source$integration_source[i], 1, 15),
              data_quality_by_source$total_registros[i],
              data_quality_by_source$pct_coords[i],
              data_quality_by_source$pct_species[i],
              data_quality_by_source$pct_year[i],
              data_quality_by_source$pct_coords_validas[i]))
}

# =============================================================================
# DETECCIÓN DE DUPLICADOS
# =============================================================================

cat("\n6. ANÁLISIS DE DUPLICADOS\n")
cat("=========================\n")

# Duplicados exactos (todas las columnas)
exact_duplicates <- integrated_data %>%
  select(-record_id) %>%  # Excluir ID para detectar duplicados
  duplicated() %>%
  sum()

cat(sprintf("Duplicados exactos: %d registros\n", exact_duplicates))

# Duplicados potenciales (misma especie, coordenadas similares, mismo año)
potential_duplicates <- integrated_data %>%
  filter(!is.na(species) & !is.na(lon) & !is.na(lat) & !is.na(year)) %>%
  mutate(
    lon_rounded = round(lon, 4),
    lat_rounded = round(lat, 4)
  ) %>%
  group_by(species, lon_rounded, lat_rounded, year) %>%
  summarise(count = n(), .groups = "drop") %>%
  filter(count > 1) %>%
  arrange(desc(count))

cat(sprintf("Grupos de posibles duplicados: %d\n", nrow(potential_duplicates)))
cat(sprintf("Total registros en grupos duplicados: %d\n", sum(potential_duplicates$count)))

if(nrow(potential_duplicates) > 0) {
  cat("\nTop 10 grupos con más duplicados potenciales:\n")
  top_dups <- head(potential_duplicates, 10)
  for(i in 1:nrow(top_dups)) {
    cat(sprintf("  %s [%.4f, %.4f] %d: %d registros\n",
                substr(top_dups$species[i], 1, 30),
                top_dups$lon_rounded[i],
                top_dups$lat_rounded[i],
                top_dups$year[i],
                top_dups$count[i]))
  }
}

# =============================================================================
# ANÁLISIS GEOGRÁFICO
# =============================================================================

cat("\n7. ANÁLISIS GEOGRÁFICO\n")
cat("======================\n")

# Distribución geográfica general
geo_stats <- integrated_data %>%
  filter(!is.na(lon) & !is.na(lat) & 
         lon >= -180 & lon <= 180 & 
         lat >= -90 & lat <= 90) %>%
  summarise(
    registros_con_coords = n(),
    lon_mean = mean(lon, na.rm = TRUE),
    lat_mean = mean(lat, na.rm = TRUE),
    lon_sd = sd(lon, na.rm = TRUE),
    lat_sd = sd(lat, na.rm = TRUE),
    area_aprox = (max(lon, na.rm = TRUE) - min(lon, na.rm = TRUE)) * 
                 (max(lat, na.rm = TRUE) - min(lat, na.rm = TRUE))
  )

cat(sprintf("Registros con coordenadas válidas: %d\n", geo_stats$registros_con_coords))
cat(sprintf("Centroide geográfico: %.4f°, %.4f°\n", geo_stats$lon_mean, geo_stats$lat_mean))
cat(sprintf("Desviación estándar: %.4f° (lon), %.4f° (lat)\n", geo_stats$lon_sd, geo_stats$lat_sd))
cat(sprintf("Área aproximada cubierta: %.2f grados cuadrados\n", geo_stats$area_aprox))

# Distribución por cuadrantes geográficos
quadrants <- integrated_data %>%
  filter(!is.na(lon) & !is.na(lat)) %>%
  mutate(
    hemisphere_ns = ifelse(lat >= 0, "Norte", "Sur"),
    hemisphere_ew = ifelse(lon >= 0, "Este", "Oeste"),
    quadrant = paste(hemisphere_ns, hemisphere_ew)
  ) %>%
  count(quadrant, sort = TRUE)

cat("\nDistribución por cuadrantes:\n")
for(i in 1:nrow(quadrants)) {
  cat(sprintf("  %s: %d registros\n", quadrants$quadrant[i], quadrants$n[i]))
}

# =============================================================================
# ANÁLISIS DE CONSISTENCIA INTERNA
# =============================================================================

cat("\n8. ANÁLISIS DE CONSISTENCIA INTERNA\n")
cat("===================================\n")

# Verificar consistencia de fechas
date_consistency <- integrated_data %>%
  filter(!is.na(year) & !is.na(month) & !is.na(day)) %>%
  mutate(
    date_constructed = as.Date(paste(year, month, day, sep = "-"), "%Y-%m-%d"),
    date_recorded_parsed = as.Date(date_recorded)
  ) %>%
  filter(!is.na(date_constructed) & !is.na(date_recorded_parsed)) %>%
  mutate(date_match = date_constructed == date_recorded_parsed) %>%
  summarise(
    total_with_complete_dates = n(),
    matching_dates = sum(date_match, na.rm = TRUE),
    non_matching_dates = sum(!date_match, na.rm = TRUE)
  )

cat(sprintf("Fechas completas analizadas: %d\n", date_consistency$total_with_complete_dates))
cat(sprintf("Fechas consistentes: %d\n", date_consistency$matching_dates))
cat(sprintf("Fechas inconsistentes: %d\n", date_consistency$non_matching_dates))

# Verificar rangos válidos de meses y días
invalid_dates <- integrated_data %>%
  filter(
    (!is.na(month) & (month < 1 | month > 12)) |
    (!is.na(day) & (day < 1 | day > 31))
  )

cat(sprintf("Registros con meses/días inválidos: %d\n", nrow(invalid_dates)))

# Verificar consistencia de nombres de especies
species_consistency <- integrated_data %>%
  filter(!is.na(species) & species != "") %>%
  mutate(
    has_space = str_detect(species, " "),
    word_count = str_count(species, "\\S+"),
    has_numbers = str_detect(species, "\\d"),
    has_special_chars = str_detect(species, "[^a-z0-9 _-]"),
    all_lowercase = species == tolower(species)
  ) %>%
  summarise(
    total_species = n(),
    binomial_like = sum(word_count >= 2, na.rm = TRUE),
    with_numbers = sum(has_numbers, na.rm = TRUE),
    with_special_chars = sum(has_special_chars, na.rm = TRUE),
    not_lowercase = sum(!all_lowercase, na.rm = TRUE)
  )

cat(sprintf("\nConsistencia de nombres de especies:\n"))
cat(sprintf("Total especies analizadas: %d\n", species_consistency$total_species))
cat(sprintf("Nombres binomiales: %d (%.1f%%)\n", 
            species_consistency$binomial_like,
            (species_consistency$binomial_like/species_consistency$total_species)*100))
cat(sprintf("Con números: %d (%.1f%%)\n", 
            species_consistency$with_numbers,
            (species_consistency$with_numbers/species_consistency$total_species)*100))
cat(sprintf("Con caracteres especiales: %d (%.1f%%)\n", 
            species_consistency$with_special_chars,
            (species_consistency$with_special_chars/species_consistency$total_species)*100))
cat(sprintf("No en minúsculas: %d (%.1f%%)\n", 
            species_consistency$not_lowercase,
            (species_consistency$not_lowercase/species_consistency$total_species)*100))

# =============================================================================
# RECOMENDACIONES DE LIMPIEZA
# =============================================================================

cat("\n9. RECOMENDACIONES DE LIMPIEZA\n")
cat("==============================\n")

recommendations <- c()

# Coordenadas
if(nrow(problematic_coords) > 0) {
  recommendations <- c(recommendations, 
    sprintf("• Revisar %d registros con coordenadas problemáticas", nrow(problematic_coords)))
}

if(coords_stats$coords_validas < coords_stats$con_ambas_coords) {
  recommendations <- c(recommendations,
    sprintf("• Validar %d registros con coordenadas fuera de rango válido", 
            coords_stats$con_ambas_coords - coords_stats$coords_validas))
}

# Fechas
if(nrow(problematic_years) > 0) {
  recommendations <- c(recommendations,
    sprintf("• Revisar %d registros con años problemáticos", nrow(problematic_years)))
}

if(nrow(invalid_dates) > 0) {
  recommendations <- c(recommendations,
    sprintf("• Corregir %d registros con meses/días inválidos", nrow(invalid_dates)))
}

# Especies
if(species_consistency$with_special_chars > 0) {
  recommendations <- c(recommendations,
    sprintf("• Limpiar %d nombres de especies con caracteres especiales", 
            species_consistency$with_special_chars))
}

# Duplicados
if(exact_duplicates > 0) {
  recommendations <- c(recommendations,
    sprintf("• Eliminar %d registros duplicados exactos", exact_duplicates))
}

if(nrow(potential_duplicates) > 0) {
  recommendations <- c(recommendations,
    sprintf("• Revisar %d grupos de posibles duplicados espaciotemporales", 
            nrow(potential_duplicates)))
}

# Valores faltantes críticos
critical_missing <- missing_values %>%
  filter(columna %in% c("species", "lon", "lat") & valores_faltantes > 0)

if(nrow(critical_missing) > 0) {
  for(i in 1:nrow(critical_missing)) {
    recommendations <- c(recommendations,
      sprintf("• Completar %d valores faltantes en campo crítico '%s'", 
              critical_missing$valores_faltantes[i], 
              critical_missing$columna[i]))
  }
}

if(length(recommendations) > 0) {
  cat("Se identificaron las siguientes oportunidades de mejora:\n\n")
  for(rec in recommendations) {
    cat(paste0(rec, "\n"))
  }
} else {
  cat("¡Excelente! No se detectaron problemas críticos de consistencia.\n")
}

# =============================================================================
# GUARDAR REPORTE
# =============================================================================

cat("\n=== GENERANDO REPORTE FINAL ===\n")

# Crear reporte en archivo de texto
report_filename <- file.path(output_dir, paste0("consistency_analysis_report_", Sys.Date(), ".txt"))

sink(report_filename)
cat("REPORTE DE ANÁLISIS DE CONSISTENCIA\n")
cat("===================================\n")
cat(sprintf("Base de datos: %s\n", basename(input_file)))
cat(sprintf("Fecha de análisis: %s\n", Sys.Date()))
cat(sprintf("Hora de análisis: %s\n\n", Sys.time()))

cat("RESUMEN EJECUTIVO\n")
cat("-----------------\n")
cat(sprintf("Total de registros: %d\n", nrow(integrated_data)))
cat(sprintf("Especies únicas: %d\n", species_stats$species_unique))
cat(sprintf("Registros con coordenadas válidas: %d (%.1f%%)\n", 
            coords_stats$coords_no_zero, 
            (coords_stats$coords_no_zero/nrow(integrated_data))*100))
cat(sprintf("Registros con especies válidas: %d (%.1f%%)\n", 
            species_stats$con_species, 
            (species_stats$con_species/nrow(integrated_data))*100))
cat(sprintf("Rango temporal: %d - %d\n", year_ranges$year_min, year_ranges$year_max))
cat(sprintf("Área geográfica: %.2f grados cuadrados\n", geo_stats$area_aprox))

cat("\nPROBLEMAS DETECTADOS\n")
cat("-------------------\n")
cat(sprintf("Duplicados exactos: %d\n", exact_duplicates))
cat(sprintf("Grupos de posibles duplicados: %d\n", nrow(potential_duplicates)))
cat(sprintf("Coordenadas problemáticas: %d\n", nrow(problematic_coords)))
cat(sprintf("Años problemáticos: %d\n", nrow(problematic_years)))
cat(sprintf("Fechas inválidas: %d\n", nrow(invalid_dates)))

cat("\nCALIDAD POR FUENTE\n")
cat("-----------------\n")
for(i in 1:nrow(data_quality_by_source)) {
  cat(sprintf("%s:\n", data_quality_by_source$integration_source[i]))
  cat(sprintf("  Registros: %d\n", data_quality_by_source$total_registros[i]))
  cat(sprintf("  Coordenadas válidas: %.1f%%\n", data_quality_by_source$pct_coords_validas[i]))
  cat(sprintf("  Especies válidas: %.1f%%\n", data_quality_by_source$pct_species[i]))
  cat(sprintf("  Años válidos: %.1f%%\n\n", data_quality_by_source$pct_year[i]))
}

cat("RECOMENDACIONES\n")
cat("--------------\n")
if(length(recommendations) > 0) {
  for(rec in recommendations) {
    cat(paste0(rec, "\n"))
  }
} else {
  cat("No se detectaron problemas críticos de consistencia.\n")
}

sink()

cat(sprintf("Reporte guardado como: %s\n", report_filename))

# Crear resumen CSV con estadísticas principales
summary_filename <- file.path(output_dir, paste0("consistency_summary_", Sys.Date(), ".csv"))

summary_stats <- data.frame(
  metric = c("total_records", "unique_species", "valid_coordinates_pct", 
             "valid_species_pct", "exact_duplicates", "potential_duplicate_groups",
             "problematic_coordinates", "problematic_years", "invalid_dates"),
  value = c(nrow(integrated_data), species_stats$species_unique,
            round((coords_stats$coords_no_zero/nrow(integrated_data))*100, 2),
            round((species_stats$con_species/nrow(integrated_data))*100, 2),
            exact_duplicates, nrow(potential_duplicates),
            nrow(problematic_coords), nrow(problematic_years), nrow(invalid_dates))
)

write_csv(summary_stats, summary_filename)
cat(sprintf("Resumen estadístico guardado como: %s\n", summary_filename))

cat("\n=== ANÁLISIS DE CONSISTENCIA COMPLETADO ===\n")