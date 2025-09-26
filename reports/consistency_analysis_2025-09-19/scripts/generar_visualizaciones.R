# =============================================================================
# SCRIPT DE VISUALIZACIONES PARA ANÁLISIS DE CONSISTENCIA
# =============================================================================
# Objetivo: Generar gráficos y visualizaciones del análisis de consistencia
# Complementa al análisis principal con visualizaciones informativas
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
  library(ggplot2)
  library(scales)
  library(RColorBrewer)
  library(gridExtra)
})

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

# Definir rutas
data_dir <- "/home/atlantis/biodiversity_atlantis_goc/data/occurrence"
input_file <- file.path(data_dir, "biodiversity_integrated_conabio_2025-09-19.csv")
output_dir <- file.path(dirname(getwd()), "visualizations")  # Carpeta visualizations del reporte

# Configuración de tema para gráficos
theme_analysis <- theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 12),
    axis.title = element_text(size = 11),
    axis.text = element_text(size = 10),
    legend.title = element_text(size = 11),
    legend.text = element_text(size = 10),
    strip.text = element_text(size = 11, face = "bold")
  )

# =============================================================================
# CARGAR DATOS
# =============================================================================

cat("Cargando datos para visualizaciones...\n")
data <- read_csv(input_file, show_col_types = FALSE)

cat(sprintf("Datos cargados: %d registros\n", nrow(data)))

# =============================================================================
# GRÁFICO 1: DISTRIBUCIÓN POR FUENTE DE DATOS
# =============================================================================

cat("Generando gráfico de distribución por fuente...\n")

source_plot <- data %>%
  count(integration_source, sort = TRUE) %>%
  mutate(
    integration_source = factor(integration_source, levels = integration_source),
    percentage = round((n/sum(n))*100, 1)
  ) %>%
  ggplot(aes(x = integration_source, y = n, fill = integration_source)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(comma(n), "\n(", percentage, "%)")), 
            vjust = -0.5, size = 3.5) +
  scale_y_continuous(labels = comma_format()) +
  scale_fill_brewer(type = "qualitative", palette = "Set2") +
  labs(
    title = "Distribución de Registros por Fuente de Datos",
    subtitle = paste("Total:", comma(nrow(data)), "registros"),
    x = "Fuente de Integración",
    y = "Número de Registros"
  ) +
  theme_analysis +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(output_dir, "distribution_by_source.png"), 
       source_plot, width = 10, height = 6, dpi = 300)

# =============================================================================
# GRÁFICO 2: DISTRIBUCIÓN TEMPORAL
# =============================================================================

cat("Generando gráfico de distribución temporal...\n")

temporal_plot <- data %>%
  filter(!is.na(year) & year >= 1950 & year <= 2025) %>%
  mutate(decade = floor(year/10)*10) %>%
  count(decade, integration_source) %>%
  ggplot(aes(x = decade, y = n, fill = integration_source)) +
  geom_col(position = "stack") +
  scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  scale_y_continuous(labels = comma_format()) +
  scale_fill_brewer(type = "qualitative", palette = "Set2", name = "Fuente") +
  labs(
    title = "Distribución Temporal de Registros por Década",
    subtitle = "Período 1950-2025",
    x = "Década",
    y = "Número de Registros"
  ) +
  theme_analysis

ggsave(file.path(output_dir, "temporal_distribution.png"), 
       temporal_plot, width = 12, height = 6, dpi = 300)

# =============================================================================
# GRÁFICO 3: DISTRIBUCIÓN POR RANGO TAXONÓMICO
# =============================================================================

cat("Generando gráfico de distribución taxonómica...\n")

taxon_plot <- data %>%
  mutate(taxonRank = ifelse(is.na(taxonRank), "No especificado", taxonRank)) %>%
  count(taxonRank, sort = TRUE) %>%
  head(10) %>%
  mutate(
    taxonRank = factor(taxonRank, levels = rev(taxonRank)),
    percentage = round((n/nrow(data))*100, 1)
  ) %>%
  ggplot(aes(x = taxonRank, y = n, fill = taxonRank)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(comma(n), " (", percentage, "%)")), 
            hjust = -0.1, size = 3.5) +
  scale_y_continuous(labels = comma_format()) +
  scale_fill_brewer(type = "qualitative", palette = "Spectral") +
  coord_flip() +
  labs(
    title = "Distribución por Rango Taxonómico",
    subtitle = "Top 10 rangos más frecuentes",
    x = "Rango Taxonómico",
    y = "Número de Registros"
  ) +
  theme_analysis

ggsave(file.path(output_dir, "taxonomic_distribution.png"), 
       taxon_plot, width = 10, height = 6, dpi = 300)

# =============================================================================
# GRÁFICO 4: MAPA DE DISTRIBUCIÓN GEOGRÁFICA
# =============================================================================

cat("Generando mapa de distribución geográfica...\n")

# Crear mapa de puntos (muestra)
if(nrow(data %>% filter(!is.na(lon) & !is.na(lat))) > 0) {
  
  # Tomar una muestra para visualización (para evitar sobrecarga)
  map_data <- data %>%
    filter(!is.na(lon) & !is.na(lat)) %>%
    sample_n(min(10000, nrow(.))) %>%
    mutate(integration_source = factor(integration_source))
  
  geo_plot <- ggplot(map_data, aes(x = lon, y = lat, color = integration_source)) +
    geom_point(alpha = 0.6, size = 0.8) +
    scale_color_brewer(type = "qualitative", palette = "Set2", name = "Fuente") +
    labs(
      title = "Distribución Geográfica de Registros",
      subtitle = paste("Muestra de", comma(nrow(map_data)), "registros"),
      x = "Longitud",
      y = "Latitud"
    ) +
    theme_analysis +
    theme(legend.position = "bottom")
  
  ggsave(file.path(output_dir, "geographic_distribution.png"), 
         geo_plot, width = 12, height = 8, dpi = 300)
}

# =============================================================================
# GRÁFICO 5: CALIDAD DE DATOS POR FUENTE
# =============================================================================

cat("Generando gráfico de calidad de datos...\n")

quality_data <- data %>%
  group_by(integration_source) %>%
  summarise(
    total = n(),
    con_coords = sum(!is.na(lon) & !is.na(lat)),
    con_year = sum(!is.na(year)),
    con_date = sum(!is.na(date_recorded) & date_recorded != ""),
    .groups = "drop"
  ) %>%
  mutate(
    pct_coords = (con_coords/total)*100,
    pct_year = (con_year/total)*100,
    pct_date = (con_date/total)*100
  ) %>%
  pivot_longer(cols = c(pct_coords, pct_year, pct_date),
               names_to = "metric", values_to = "percentage") %>%
  mutate(
    metric = case_when(
      metric == "pct_coords" ~ "Coordenadas",
      metric == "pct_year" ~ "Año",
      metric == "pct_date" ~ "Fecha completa"
    )
  )

quality_plot <- ggplot(quality_data, aes(x = integration_source, y = percentage, fill = metric)) +
  geom_col(position = "dodge") +
  geom_text(aes(label = paste0(round(percentage, 1), "%")), 
            position = position_dodge(width = 0.9), vjust = -0.5, size = 3) +
  scale_y_continuous(limits = c(0, 105)) +
  scale_fill_brewer(type = "qualitative", palette = "Set1", name = "Métrica") +
  labs(
    title = "Calidad de Datos por Fuente",
    subtitle = "Porcentaje de registros con datos completos",
    x = "Fuente de Integración",
    y = "Porcentaje (%)"
  ) +
  theme_analysis +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(output_dir, "data_quality_by_source.png"), 
       quality_plot, width = 12, height = 6, dpi = 300)

# =============================================================================
# GRÁFICO 6: TOP ESPECIES MÁS FRECUENTES
# =============================================================================

cat("Generando gráfico de especies más frecuentes...\n")

species_plot <- data %>%
  filter(!is.na(species) & species != "") %>%
  count(species, sort = TRUE) %>%
  head(20) %>%
  mutate(
    species = as.character(species),
    species = factor(species, levels = rev(species)),
    species_short = ifelse(nchar(as.character(species)) > 30, 
                          paste0(substr(as.character(species), 1, 27), "..."), 
                          as.character(species))
  ) %>%
  ggplot(aes(x = species_short, y = n)) +
  geom_col(fill = "steelblue", alpha = 0.8) +
  geom_text(aes(label = comma(n)), hjust = -0.1, size = 3) +
  scale_y_continuous(labels = comma_format()) +
  coord_flip() +
  labs(
    title = "Top 20 Especies Más Frecuentes",
    subtitle = "Número de registros por especie",
    x = "Especies",
    y = "Número de Registros"
  ) +
  theme_analysis

ggsave(file.path(output_dir, "top_species.png"), 
       species_plot, width = 10, height = 8, dpi = 300)

# =============================================================================
# GRÁFICO 7: RESUMEN DE MÉTRICAS DE CALIDAD
# =============================================================================

cat("Generando gráfico de resumen de métricas...\n")

# Leer datos del resumen estadístico
summary_data <- read_csv(file.path(output_dir, "consistency_summary_2025-09-19.csv"),
                        show_col_types = FALSE)

# Preparar datos para visualización
metrics_viz <- summary_data %>%
  filter(metric %in% c("valid_coordinates_pct", "valid_species_pct")) %>%
  mutate(
    metric_name = case_when(
      metric == "valid_coordinates_pct" ~ "Coordenadas Válidas",
      metric == "valid_species_pct" ~ "Especies Válidas"
    ),
    status = ifelse(value >= 95, "Excelente", 
                   ifelse(value >= 80, "Bueno", "Necesita Mejora"))
  )

quality_summary_plot <- ggplot(metrics_viz, aes(x = metric_name, y = value, fill = status)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(value, "%")), vjust = -0.5, size = 5, fontface = "bold") +
  scale_y_continuous(limits = c(0, 105)) +
  scale_fill_manual(values = c("Excelente" = "#2E8B57", "Bueno" = "#FFA500", "Necesita Mejora" = "#DC143C"),
                    name = "Estado") +
  labs(
    title = "Resumen de Calidad de Datos",
    subtitle = paste("Base de datos con", comma(summary_data$value[summary_data$metric == "total_records"]), "registros"),
    x = "Métrica",
    y = "Porcentaje (%)"
  ) +
  theme_analysis

ggsave(file.path(output_dir, "quality_summary.png"), 
       quality_summary_plot, width = 8, height = 6, dpi = 300)

# =============================================================================
# CREAR DASHBOARD RESUMEN
# =============================================================================

cat("Creando dashboard resumen...\n")

# Preparar datos para el dashboard
total_records <- nrow(data)
unique_species <- length(unique(data$species[!is.na(data$species)]))
coord_coverage <- round((sum(!is.na(data$lon) & !is.na(data$lat))/total_records)*100, 1)
temporal_coverage <- round((sum(!is.na(data$year))/total_records)*100, 1)

# Crear elementos del dashboard
info_text <- paste0(
  "RESUMEN EJECUTIVO\n",
  "Registros totales: ", comma(total_records), "\n",
  "Especies únicas: ", comma(unique_species), "\n",
  "Cobertura de coordenadas: ", coord_coverage, "%\n",
  "Cobertura temporal: ", temporal_coverage, "%"
)

# Crear gráfico de texto informativo
info_plot <- ggplot() + 
  annotate("text", x = 0.5, y = 0.5, label = info_text, 
           hjust = 0.5, vjust = 0.5, size = 6, fontface = "bold") +
  theme_void() +
  labs(title = "Dashboard de Análisis de Consistencia",
       subtitle = paste("Base de Datos de Biodiversidad -", Sys.Date()))

ggsave(file.path(output_dir, "dashboard_summary.png"), 
       info_plot, width = 8, height = 6, dpi = 300)

# =============================================================================
# REPORTE FINAL
# =============================================================================

cat("\n=== VISUALIZACIONES GENERADAS ===\n")
visualizations <- c(
  "distribution_by_source.png - Distribución por fuente de datos",
  "temporal_distribution.png - Distribución temporal por década", 
  "taxonomic_distribution.png - Distribución por rango taxonómico",
  "geographic_distribution.png - Mapa de distribución geográfica",
  "data_quality_by_source.png - Calidad de datos por fuente",
  "top_species.png - Top 20 especies más frecuentes",
  "quality_summary.png - Resumen de métricas de calidad",
  "dashboard_summary.png - Dashboard resumen"
)

for(viz in visualizations) {
  cat(sprintf("✓ %s\n", viz))
}

cat(sprintf("\nTodas las visualizaciones se guardaron en: %s\n", output_dir))
cat("=== GENERACIÓN DE VISUALIZACIONES COMPLETADA ===\n")