# Guía Rápida - Sistema de Consultas de Biodiversidad

## 🚀 Inicio Rápido

### 1. Ejecutar Consultas Básicas
```r
# Cargar script principal
source("scripts/database_queries.R")

# Ejecutar consultas
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json",
  polygon_file = "shapefiles/study_zone.gpkg",
  output_dir = "data/query_results"
)

# Ver resultados
head(results$results)
summary(results$summary)
```

### 2. Ver Ayuda
```r
source("scripts/database_queries.R")
show_help()
```

---

## 📚 Funciones Principales

### 🎯 Script Principal

#### `execute_biodiversity_queries()`
Función principal que ejecuta todo el proceso de consulta.

**Parámetros:**
- `config_file`: Ruta al JSON de configuración
- `polygon_file`: Ruta al shapefile/GeoPackage (opcional)
- `output_dir`: Directorio de salida (opcional)

**Retorna:**
- `results`: Data frame con registros
- `grid`: Grid de búsqueda usado
- `polygon`: Polígono cargado
- `config`: Configuración usada
- `execution_time`: Tiempo de ejecución
- `summary`: Resumen estadístico

**Ejemplo:**
```r
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json"
)
```

---

### 📊 data_utils.R - Utilidades de Datos

#### `clean_species_name(species_name)`
Limpia nombres científicos eliminando autores, años, etc.

```r
clean_species_name("Homo sapiens Linnaeus, 1758")
# "homo sapiens"
```

#### `format_biodiversity_data(data, source)`
Formatea datos a estructura estándar y valida.

```r
formatted <- format_biodiversity_data(raw_data, "GBIF")
```

#### `log_message(message, log_file, level)`
Registra mensajes con timestamp.

```r
log_message("Proceso iniciado", "output/log.txt", "INFO")
```

#### `remove_duplicates(data)`
Elimina registros duplicados.

```r
unique_data <- remove_duplicates(all_data)
```

#### `summarize_biodiversity_data(data)`
Genera resumen estadístico.

```r
summary <- summarize_biodiversity_data(results$results)
print(summary$unique_species)
print(summary$sources)
```

#### `export_biodiversity_data(data, output_dir, base_name, formats)`
Exporta en múltiples formatos.

```r
export_biodiversity_data(
  data = results$results,
  output_dir = "output",
  base_name = "biodiversity_2024",
  formats = c("csv", "json", "xlsx")
)
```

---

### 🗺️ spatial_utils.R - Utilidades Espaciales

#### `load_polygon_from_shapefile(shp_path)`
Carga y valida polígono.

```r
polygon <- load_polygon_from_shapefile("shapefiles/study_zone.gpkg")
```

#### `generate_grid_bboxes(polygon, grid_size)`
Genera grid de búsqueda.

```r
grid <- generate_grid_bboxes(polygon, grid_size = 0.5)
```

#### `generate_simple_bbox(polygon)`
Genera un único bbox del polígono.

```r
bbox <- generate_simple_bbox(polygon)
```

#### `validate_coordinates(lon, lat)`
Valida coordenadas geográficas.

```r
valid <- validate_coordinates(data$lon, data$lat)
clean_data <- data[valid, ]
```

#### `create_spatial_points(data)`
Convierte data frame a objeto sf.

```r
spatial_points <- create_spatial_points(data)
```

#### `filter_points_in_polygon(points_data, polygon)`
Filtra puntos dentro de polígono.

```r
filtered <- filter_points_in_polygon(points_data, polygon)
```

#### `calculate_spatial_statistics(data)`
Calcula estadísticas espaciales.

```r
stats <- calculate_spatial_statistics(data)
print(stats$centroid)
print(stats$lon_range)
```

---

### 🔍 query_functions.R - Funciones de Consulta

#### `query_gbif(wkt, config, box_id)`
Consulta GBIF.

```r
gbif_data <- query_gbif(
  wkt = grid$wkt[1],
  config = config$databases$gbif,
  box_id = 1
)
```

#### `query_obis(bbox, config, box_id)`
Consulta OBIS.

```r
obis_data <- query_obis(
  bbox = grid$bbox[1],
  config = config$databases$obis,
  box_id = 1
)
```

#### `query_inat(bbox, config, box_id)`
Consulta iNaturalist.

```r
inat_data <- query_inat(
  bbox = grid$bbox[1],
  config = config$databases$inat,
  box_id = 1
)
```

#### `query_ebird(bbox, config, box_id)`
Consulta eBird (requiere API key).

```r
ebird_data <- query_ebird(
  bbox = grid$bbox[1],
  config = config$databases$ebird,
  box_id = 1
)
```

#### `query_idigbio(bbox, config, box_id)`
Consulta iDigBio.

```r
idigbio_data <- query_idigbio(
  bbox = grid$bbox[1],
  config = config$databases$idigbio,
  box_id = 1
)
```

#### `execute_all_queries(grid, config, log_function)`
Ejecuta todas las consultas habilitadas.

```r
all_data <- execute_all_queries(
  grid = grid,
  config = config,
  log_function = log_message
)
```

---

## ⚙️ Configuración JSON

### Estructura Básica
```json
{
  "general": {
    "polygon_path": "shapefiles/study_zone.gpkg",
    "output_dir": "data/query_results"
  },
  "spatial": {
    "grid_enabled": true,
    "grid_size_degrees": 0.5,
    "max_boxes": 10
  },
  "databases": {
    "gbif": {
      "enabled": true,
      "params": {
        "records_per_box": 1000,
        "has_coordinate": true,
        "year_start": 2000,
        "year_end": 2024
      }
    },
    "obis": {
      "enabled": true,
      "params": {
        "records_per_box": 1000
      }
    },
    "inat": {
      "enabled": false,
      "params": {
        "records_per_box": 500
      }
    }
  },
  "output": {
    "formats": ["csv", "json"],
    "include_metadata": true
  },
  "logging": {
    "log_file": "logs/biodiversity_query.log"
  }
}
```

---

## 📝 Ejemplos de Uso

### Ejemplo 1: Consulta Simple
```r
# Cargar script
source("scripts/database_queries.R")

# Ejecutar con valores predeterminados del JSON
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json"
)

# Ver especies únicas
unique_species <- unique(results$results$species)
cat("Especies encontradas:", length(unique_species), "\n")
```

### Ejemplo 2: Consulta Personalizada
```r
# Ejecutar con parámetros específicos
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json",
  polygon_file = "mi_area.gpkg",
  output_dir = "mis_resultados"
)

# Ver resumen
print(results$summary)
```

### Ejemplo 3: Uso Modular - Solo GBIF
```r
# Cargar módulos necesarios
source("scripts/utils/data_utils.R")
source("scripts/utils/spatial_utils.R")
source("scripts/utils/query_functions.R")

# Cargar configuración
config <- load_query_config("scripts/query_config.json")

# Cargar polígono
polygon <- load_polygon_from_shapefile("shapefiles/study_zone.gpkg")

# Generar grid
grid <- generate_grid_bboxes(polygon, grid_size = 0.5)

# Consultar solo GBIF
gbif_data <- data.frame()
for (i in 1:nrow(grid)) {
  box_data <- query_gbif(grid$wkt[i], config$databases$gbif, box_id = i)
  gbif_data <- rbind(gbif_data, box_data)
}

# Procesar y exportar
gbif_unique <- remove_duplicates(gbif_data)
export_biodiversity_data(gbif_unique, "output", "gbif_only", c("csv"))
```

### Ejemplo 4: Análisis Espacial
```r
source("scripts/utils/spatial_utils.R")

# Cargar polígono
polygon <- load_polygon_from_shapefile("shapefiles/study_zone.gpkg")

# Cargar datos
data <- read.csv("data/biodiversity.csv")

# Filtrar puntos dentro del polígono
filtered_data <- filter_points_in_polygon(data, polygon)

# Calcular estadísticas espaciales
stats <- calculate_spatial_statistics(filtered_data)

print(paste("Centroide:", stats$centroid["lon"], stats$centroid["lat"]))
print(paste("Rango lon:", stats$lon_range[1], "-", stats$lon_range[2]))
print(paste("Rango lat:", stats$lat_range[1], "-", stats$lat_range[2]))
```

### Ejemplo 5: Procesamiento por Lotes
```r
source("scripts/database_queries.R")

# Lista de áreas de estudio
areas <- c(
  "area1.gpkg",
  "area2.gpkg",
  "area3.gpkg"
)

# Procesar cada área
for (area in areas) {
  area_name <- tools::file_path_sans_ext(basename(area))
  
  results <- execute_biodiversity_queries(
    config_file = "scripts/query_config.json",
    polygon_file = file.path("shapefiles", area),
    output_dir = file.path("output", area_name)
  )
  
  cat("Completado:", area_name, "\n")
}
```

---

## 🔧 Solución de Problemas

### Error: "Módulos no encontrados"
```r
# Verificar directorio de trabajo
getwd()

# Establecer directorio correcto
setwd("/ruta/a/biodiversity_atlantis_goc")

# Cargar nuevamente
source("scripts/database_queries.R")
```

### Error: "Shapefile no encontrado"
```r
# Verificar que el archivo existe
file.exists("shapefiles/study_zone.gpkg")

# Usar ruta absoluta si es necesario
polygon_file <- "/ruta/completa/a/study_zone.gpkg"
```

### Sin resultados de una base de datos
- Verificar que esté habilitada en la configuración JSON
- Revisar los logs para mensajes de error
- Verificar conectividad a Internet
- Para eBird, verificar que la API key esté configurada

### Coordenadas inválidas
```r
# Las funciones ya incluyen validación automática
# Los puntos con coordenadas inválidas se eliminan automáticamente
# Revisar logs para ver cuántos fueron eliminados
```

---

## 📊 Estructura de Salida

### Archivos Generados
```
data/query_results/
├── biodiversity_20241017_153045.csv      # Datos en CSV
├── biodiversity_20241017_153045.json     # Datos en JSON
├── metadata_20241017_153045.json         # Metadatos
└── biodiversity_query.log                # Logs
```

### Estructura del CSV
```csv
species,lon,lat,year,month,day,date_recorded,taxonRank,source
homo sapiens,-95.2,18.5,2023,3,15,2023-03-15,SPECIES,GBIF
canis lupus,-94.8,19.1,2022,7,20,2022-07-20,SPECIES,OBIS
```

---

## 📞 Referencias Adicionales

- **Documentación Completa:** `docs/REFACTORIZACION_SUMMARY.md`
- **Arquitectura:** `docs/ARQUITECTURA_SISTEMA.md`
- **README Principal:** `README.md`
- **Configuración de Bases de Datos:** `scripts/README_database_queries.md`

---

**Última actualización:** 2025-10-17
