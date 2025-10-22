# Database Queries Script - Consultas a Bases de Datos de Biodiversidad

## Descripción

Script R para ejecutar consultas a múltiples bases de datos de biodiversidad utilizando:
- **Parámetros configurables** en archivo JSON
- **Importación de polígonos** desde shapefiles
- **Grid de búsqueda** para optimizar consultas espaciales
- **Consolidación de resultados** de múltiples fuentes

## Archivos

### 1. `database_queries.R`
Script principal que contiene todas las funciones necesarias para:
- Cargar configuración desde JSON
- Importar shapefiles con sf
- Generar grid de búsqueda
- Ejecutar consultas a las siguientes bases de datos:
  - **GBIF** (Global Biodiversity Information Facility)
  - **OBIS** (Ocean Biodiversity Information System)
  - **iNaturalist** (mediante spocc)
  - **eBird** (mediante rebird)
  - **iDigBio** (mediante ridigbio)
- Consolidar y exportar resultados

### 2. `query_config.json`
Archivo de configuración JSON con todos los parámetros de las consultas:

```json
{
  "general": {
    "polygon_path": "shapefiles/study_area.shp",
    "output_dir": "data/query_results"
  },
  "databases": {
    "gbif": {
      "enabled": true,
      "params": {
        "records_per_box": 500,
        "year_start": 2000,
        "year_end": 2025
      }
    },
    // ... más bases de datos
  },
  "spatial": {
    "grid_enabled": true,
    "grid_size_degrees": 0.5,
    "max_boxes": 100
  },
  "output": {
    "formats": ["csv", "json", "xlsx"],
    "include_metadata": true
  }
}
```

## Estructura de Directorios

```
biodiversity_atlantis_goc/
├── scripts/
│   ├── database_queries.R          # Script principal
│   ├── query_config.json           # Configuración de parámetros
│   └── README_database_queries.md  # Este archivo
├── shapefiles/
│   └── study_area.shp              # Polígono de estudio (+ archivos .dbf, .shx, etc.)
└── data/
    └── query_results/              # Resultados de consultas
        ├── biodiversity_*.csv      # Resultados en CSV
        ├── biodiversity_*.json     # Resultados en JSON
        ├── biodiversity_*.xlsx     # Resultados en Excel
        ├── metadata_*.json         # Metadatos
        └── logs/
            └── query_execution.log # Log de ejecución
```

## Requisitos

### Librerías R necesarias:

```r
# Instalar si no están disponibles
packages <- c(
  "jsonlite",    # Leer/escribir JSON
  "sf",          # Procesamiento de shapefiles
  "sp",          # Spatial features
  "dplyr",       # Manipulación de datos
  "rgbif",       # Consultas GBIF
  "robis",       # Consultas OBIS
  "spocc",       # Consultas múltiples (iNat)
  "rebird",      # Consultas eBird
  "ridigbio",    # Consultas iDigBio
  "raster",      # Funciones espaciales
  "openxlsx",    # Exportar Excel
  "lubridate"    # Fechas
)

# Instalar paquetes faltantes
new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages)
```

## Uso

### Uso Básico

```r
# Cargar el script
source("scripts/database_queries.R")

# Ejecutar con configuración por defecto
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json"
)
```

### Uso Avanzado

```r
# Con parámetros personalizados
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json",
  polygon_file = "shapefiles/my_study_area.shp",
  output_dir = "data/custom_results"
)

# Acceder a los resultados
head(results$results)
summary(results$results)
table(results$results$source)
```

### Funciones Individuales

```r
# Cargar solo la configuración
config <- load_query_config("scripts/query_config.json")

# Cargar polígono
polygon <- load_polygon_from_shapefile("shapefiles/study_area.shp")

# Generar grid
grid <- generate_grid_bboxes(polygon, grid_size = 0.5)

# Consultar una base de datos específica
gbif_data <- query_gbif(
  bbox = "min_lng,min_lat,max_lng,max_lat",
  config = config$databases$gbif,
  box_id = 1
)
```

## Configuración de `query_config.json`

### Sección `general`

```json
"general": {
  "description": "Configuración general",
  "polygon_path": "shapefiles/study_area.shp",    // Ruta al shapefile
  "output_dir": "data/query_results",               // Directorio de salida
  "date_format": "%Y-%m-%d"                         // Formato de fechas
}
```

### Sección `databases`

Cada base de datos tiene configuración específica:

#### GBIF
```json
"gbif": {
  "enabled": true,
  "params": {
    "records_per_box": 500,       // Registros por caja de búsqueda
    "year_start": 2000,           // Año inicio
    "year_end": 2025,             // Año fin
    "rank": null,                 // Rango taxonómico (null = sin filtro)
    "has_coordinate": true        // Solo con coordenadas
  }
}
```

#### OBIS
```json
"obis": {
  "enabled": true,
  "params": {
    "records_per_box": 500,
    "year_start": 2000,
    "year_end": 2025
  }
}
```

#### iNaturalist
```json
"inat": {
  "enabled": true,
  "params": {
    "records_per_box": 500,
    "year_start": 2000,
    "year_end": 2025,
    "page_size": 200              // Tamaño de página
  }
}
```

#### eBird
```json
"ebird": {
  "enabled": false,
  "params": {
    "api_key": null,              // Configurar tu API key
    "region_code": null           // Código de región
  }
}
```

#### iDigBio
```json
"idigbio": {
  "enabled": false,
  "params": {
    "records_per_box": 500,
    "year_start": 2000,
    "year_end": 2025
  }
}
```

### Sección `spatial`

```json
"spatial": {
  "grid_enabled": true,           // Activar grid de búsqueda
  "grid_size_degrees": 0.5,       // Tamaño de celdas en grados
  "max_boxes": 100,               // Máximo de cajas a consultar
  "spatial_filter": true,         // Filtrar por polígono
  "buffer_distance_m": 0          // Buffer alrededor del polígono
}
```

### Sección `output`

```json
"output": {
  "formats": ["csv", "json", "xlsx"],  // Formatos de salida
  "include_metadata": true,             // Incluir archivo de metadatos
  "compress": false                     // Comprimir archivos
}
```

## Formato de Datos de Salida

Los resultados contienen las siguientes columnas:

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `species` | character | Nombre científico (limpio, minúsculas) |
| `lon` | numeric | Longitud |
| `lat` | numeric | Latitud |
| `year` | numeric | Año de registro |
| `month` | numeric | Mes de registro |
| `day` | numeric | Día de registro |
| `date_recorded` | character | Fecha completa |
| `taxonRank` | character | Rango taxonómico |
| `source` | character | Base de datos de origen (GBIF, OBIS, etc.) |

## Preparación de Shapefile

El shapefile debe cumplir con estos requisitos:

1. **Sistema de Coordenadas**: WGS84 (EPSG:4326)
   - Si no está especificado, se asignará automáticamente
   - Si está en otro sistema, se transformará automáticamente

2. **Componentes necesarios**:
   - `study_area.shp` - Geometría
   - `study_area.shx` - Índice
   - `study_area.dbf` - Atributos
   - `study_area.prj` - Proyección (opcional pero recomendado)

3. **Validación**:
```r
library(sf)
polygon <- st_read("shapefiles/study_area.shp")
st_crs(polygon)              # Verificar CRS
st_geometry_type(polygon)    # Debe ser POLYGON
st_is_valid(polygon)         # Debe ser válido
```

## Funciones Disponibles

### `load_query_config(config_file)`
Carga configuración desde JSON.

**Parámetros:**
- `config_file`: Ruta al archivo JSON

**Retorna:** Lista con la configuración

### `load_polygon_from_shapefile(shp_path)`
Carga polígono desde shapefile y lo transforma a WGS84 si es necesario.

**Parámetros:**
- `shp_path`: Ruta al archivo shapefile

**Retorna:** Objeto sf

### `generate_grid_bboxes(polygon, grid_size)`
Genera grid de bounding boxes desde un polígono.

**Parámetros:**
- `polygon`: Objeto sf
- `grid_size`: Tamaño de celda en grados

**Retorna:** Data frame con box_id, bbox, wkt

### `query_gbif(bbox, config, box_id)`
Consulta GBIF.

### `query_obis(bbox, config, box_id)`
Consulta OBIS.

### `query_inat(bbox, config, box_id)`
Consulta iNaturalist.

### `query_ebird(bbox, config, box_id)`
Consulta eBird.

### `query_idigbio(bbox, config, box_id)`
Consulta iDigBio.

### `execute_biodiversity_queries(config_file, polygon_file, output_dir)`
Función principal - ejecuta todas las consultas.

**Parámetros:**
- `config_file`: Ruta al JSON de configuración
- `polygon_file`: Ruta al shapefile (opcional)
- `output_dir`: Directorio de salida (opcional)

**Retorna:** Lista con resultados, grid, polígono y configuración

## Logs y Monitoreo

Los logs se guardan en `data/query_results/logs/query_execution.log` con información:

```
[2025-10-17 14:30:45] === INICIANDO CONSULTAS DE BIODIVERSIDAD ===
[2025-10-17 14:30:45] Configuración: scripts/query_config.json
[2025-10-17 14:30:46] ✓ Shapefile cargado: shapefiles/study_area.shp
[2025-10-17 14:30:46] ✓ Grid de búsqueda generado: 25 celdas
[2025-10-17 14:30:47] ✓ GBIF - Box 1: 250 registros
[2025-10-17 14:30:48] ✓ GBIF - Box 2: 300 registros
...
[2025-10-17 14:31:00] Total de registros consolidados: 15000
[2025-10-17 14:31:00] Registros únicos: 12500
[2025-10-17 14:31:01] === CONSULTAS COMPLETADAS ===
```

## Ejemplos

### Ejemplo 1: Consulta Básica

```r
source("scripts/database_queries.R")

# Usar configuración por defecto
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json"
)

# Ver resultados
head(results$results)
```

### Ejemplo 2: Consulta Personalizada

```r
# Modificar configuración
config <- load_query_config("scripts/query_config.json")
config$databases$gbif$params$year_start <- 2020
config$databases$gbif$params$year_end <- 2025

# Guardar configuración modificada
jsonlite::write_json(config, "scripts/query_config_custom.json", pretty = TRUE)

# Ejecutar con configuración personalizada
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config_custom.json"
)
```

### Ejemplo 3: Consulta a Una Sola Base de Datos

```r
source("scripts/database_queries.R")

# Cargar configuración
config <- load_query_config("scripts/query_config.json")

# Cargar polígono
polygon <- load_polygon_from_shapefile("shapefiles/study_area.shp")

# Generar grid
grid <- generate_grid_bboxes(polygon, grid_size = 1.0)

# Consultar solo GBIF
gbif_results <- data.frame()
for (i in 1:nrow(grid)) {
  box_data <- query_gbif(grid$bbox[i], config$databases$gbif, box_id = i)
  gbif_results <- rbind(gbif_results, box_data)
}

# Ver resultados
head(gbif_results)
nrow(gbif_results)
table(gbif_results$source)
```

### Ejemplo 4: Análisis de Resultados

```r
# Ver estadísticas
summary(results$results)

# Registros por fuente
table(results$results$source)

# Especies por fuente
results$results %>%
  group_by(source) %>%
  summarise(n_species = n_distinct(species), n_records = n())

# Rango temporal
results$results %>%
  filter(!is.na(year)) %>%
  summarise(year_min = min(year), year_max = max(year))

# Exportar análisis
write.csv(
  results$results %>%
    group_by(source, species) %>%
    summarise(n = n(), .groups = "drop"),
  "analysis_by_source_species.csv"
)
```

## Troubleshooting

### Error: "Shapefile no encontrado"
- Verificar que la ruta en `query_config.json` es correcta
- Usar rutas absolutas o relativas desde el directorio de trabajo actual

### Error: "geometría inválida"
- Validar shapefile con: `st_is_valid(st_read("ruta.shp"))`
- Intentar reparar con: `st_make_valid()`

### Pocas o ningún resultado
- Verificar que el polígono intersecta con datos reales
- Aumentar `max_boxes` en la configuración
- Aumentar `records_per_box`
- Revisar filtros de año

### Lentitud en consultas
- Reducir `records_per_box`
- Aumentar `grid_size_degrees`
- Reducir `max_boxes`
- Usar rangos de años más pequeños

## Integración con Shiny App

Para usar este script en la aplicación Shiny:

```r
# En server_logic.R

# Cargar script de consultas
source("../scripts/database_queries.R")

# Crear tabla reactiva
observeEvent(input$execute_queries, {
  results <- execute_biodiversity_queries(
    config_file = "../scripts/query_config.json"
  )
  
  values$biodiversity_data <- results$results
  showNotification("Consultas completadas", type = "message")
})
```

## Licencia

Parte del proyecto biodiversity_atlantis_goc

## Contacto

Para preguntas o reportar problemas, consulta el README principal del proyecto.
