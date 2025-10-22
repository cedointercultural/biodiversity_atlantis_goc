# Refactorización de database_queries.R

**Fecha:** 2025-10-17  
**Autor:** Sistema de Consultas de Biodiversidad

## Resumen de Cambios

Se ha realizado una refactorización completa del script `database_queries.R`, separando las funcionalidades en módulos especializados para mejorar la mantenibilidad, legibilidad y reutilización del código.

---

## Estructura Nueva

### Archivos Creados

1. **`scripts/utils/query_functions.R`**
   - Funciones de consulta a bases de datos de biodiversidad
   - Funciones incluidas:
     - `query_gbif()` - Consultar GBIF
     - `query_obis()` - Consultar OBIS
     - `query_inat()` - Consultar iNaturalist
     - `query_ebird()` - Consultar eBird
     - `query_idigbio()` - Consultar iDigBio
     - `execute_all_queries()` - Ejecutar todas las consultas

2. **`scripts/utils/data_utils.R`**
   - Utilidades para procesamiento de datos
   - Funciones incluidas:
     - `clean_species_name()` - Limpiar nombres científicos
     - `format_biodiversity_data()` - Formatear datos a estructura estándar
     - `log_message()` - Sistema de logging con timestamps
     - `load_query_config()` - Cargar configuración JSON
     - `remove_duplicates()` - Eliminar registros duplicados
     - `summarize_biodiversity_data()` - Generar resumen estadístico
     - `export_biodiversity_data()` - Exportar en múltiples formatos
     - `generate_metadata()` - Generar metadatos de consulta

3. **`scripts/utils/spatial_utils.R`**
   - Utilidades para procesamiento espacial
   - Funciones incluidas:
     - `load_polygon_from_shapefile()` - Cargar y validar polígonos
     - `generate_grid_bboxes()` - Generar grid de búsqueda
     - `generate_simple_bbox()` - Generar bbox simple
     - `validate_coordinates()` - Validar coordenadas geográficas
     - `create_spatial_points()` - Crear objetos sf desde coordenadas
     - `filter_points_in_polygon()` - Filtrar puntos dentro de polígono
     - `calculate_spatial_statistics()` - Calcular estadísticas espaciales
     - `generate_adaptive_grid()` - Grid adaptativo (funcionalidad futura)
     - `simplify_polygon()` - Simplificar geometrías

4. **`scripts/database_queries.R`** (Refactorizado)
   - Script principal simplificado
   - Importa módulos especializados
   - Función principal: `execute_biodiversity_queries()`
   - Función de ayuda: `show_help()`

---

## Mejoras Implementadas

### 1. Modularización
- **Antes:** Todas las funciones en un solo archivo de 726 líneas
- **Después:** Código organizado en módulos especializados
  - `query_functions.R`: ~470 líneas
  - `data_utils.R`: ~350 líneas
  - `spatial_utils.R`: ~350 líneas
  - `database_queries.R`: ~220 líneas

### 2. Manejo de Errores Mejorado

#### Validaciones de Entrada
```r
# Ejemplo en query_gbif()
if (is.null(wkt) || nchar(trimws(wkt)) == 0) {
  log_function(paste("✗ Error GBIF - Box", box_id, ": geometría WKT vacía"))
  return(data.frame())
}
```

#### Validación de Coordenadas
```r
# En format_biodiversity_data()
formatted_data <- formatted_data[
  !is.na(formatted_data$lon) & 
  !is.na(formatted_data$lat) &
  formatted_data$lon >= -180 & 
  formatted_data$lon <= 180 &
  formatted_data$lat >= -90 & 
  formatted_data$lat <= 90,
]
```

#### Validación de Años
```r
# Filtrar años razonables (1600 a año actual)
formatted_data <- formatted_data[
  is.na(formatted_data$year) | 
  (formatted_data$year >= 1600 & 
   formatted_data$year <= as.numeric(format(Sys.Date(), "%Y"))),
]
```

### 3. Funciones de Logging Mejoradas

```r
log_message <- function(message, log_file = NULL, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", level, "] ", message)
  
  cat(log_entry, "\n")
  
  if (!is.null(log_file)) {
    tryCatch({
      cat(log_entry, "\n", file = log_file, append = TRUE)
    }, error = function(e) {
      warning(paste("No se pudo escribir en el archivo de log:", e$message))
    })
  }
}
```

### 4. Documentación Mejorada

Todas las funciones ahora incluyen documentación Roxygen completa:
```r
#' Consultar GBIF (Global Biodiversity Information Facility)
#'
#' @param wkt WKT (Well-Known Text) string para la geometría de búsqueda
#' @param config Lista de configuración GBIF con parámetros de consulta
#' @param box_id ID de la caja de búsqueda (para logging)
#' @param log_function Función para registrar mensajes (opcional)
#' @return Data frame con registros de GBIF formateados
#' @export
query_gbif <- function(wkt, config, box_id = 1, log_function = NULL) {
  # ...
}
```

### 5. Funciones de Utilidad Nuevas

#### Eliminación de Duplicados
```r
remove_duplicates <- function(data, keep_first = TRUE) {
  data_unique <- data %>%
    dplyr::distinct(species, lon, lat, year, source, .keep_all = TRUE)
  # ...
}
```

#### Resumen Estadístico
```r
summarize_biodiversity_data <- function(data) {
  summary <- list(
    total_records = nrow(data),
    unique_species = length(unique(data$species[!is.na(data$species)])),
    sources = table(data$source),
    year_range = range(data$year, na.rm = TRUE),
    # ...
  )
}
```

#### Exportación Multi-formato
```r
export_biodiversity_data <- function(data, output_dir, base_name, 
                                     formats = c("csv", "json"),
                                     log_function = NULL) {
  # Exporta automáticamente en todos los formatos especificados
}
```

### 6. Salida Mejorada

```
═══════════════════════════════════════════════════════════════
  SISTEMA DE CONSULTAS DE BIODIVERSIDAD
═══════════════════════════════════════════════════════════════

✓ Configuración cargada desde: scripts/query_config.json
✓ Directorio de salida creado: data/query_results

Cargando área de estudio...
✓ Archivo espacial cargado: shapefiles/study_zone.gpkg
  - Geometría: MULTIPOLYGON
  - CRS original: EPSG:4326
  - Bounding box:
    Longitud: -95.5 a -94.2
    Latitud: 18.3 a 19.8
  - Área aproximada: 15234.56 km²

───────────────────────────────────────────────────────────────
EJECUTANDO CONSULTAS
───────────────────────────────────────────────────────────────
```

---

## Ventajas de la Refactorización

### 1. **Mantenibilidad**
- Cada módulo tiene una responsabilidad clara
- Más fácil encontrar y corregir errores
- Actualizaciones localizadas

### 2. **Reutilización**
- Las funciones pueden usarse independientemente
- Módulos importables en otros scripts
- Menos código duplicado

### 3. **Testabilidad**
- Funciones individuales más fáciles de probar
- Módulos independientes permiten tests unitarios
- Validaciones más robustas

### 4. **Escalabilidad**
- Fácil agregar nuevas bases de datos
- Nuevas funcionalidades sin modificar código existente
- Estructura preparada para crecimiento

### 5. **Legibilidad**
- Código más limpio y organizado
- Documentación completa
- Flujo lógico más claro

---

## Uso

### Opción 1: Usar el script principal
```r
source("scripts/database_queries.R")

results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json",
  polygon_file = "shapefiles/study_zone.gpkg",
  output_dir = "data/query_results"
)
```

### Opción 2: Usar módulos individuales
```r
source("scripts/utils/data_utils.R")
source("scripts/utils/spatial_utils.R")
source("scripts/utils/query_functions.R")

# Cargar configuración
config <- load_query_config("scripts/query_config.json")

# Cargar polígono
polygon <- load_polygon_from_shapefile("shapefiles/study_zone.gpkg")

# Generar grid
grid <- generate_grid_bboxes(polygon, grid_size = 0.5)

# Ejecutar consultas específicas
gbif_data <- query_gbif(grid$wkt[1], config$databases$gbif, box_id = 1)
```

### Opción 3: Ver ayuda
```r
source("scripts/database_queries.R")
show_help()
```

---

## Compatibilidad

El script refactorizado mantiene **100% de compatibilidad** con el código anterior:
- Misma interfaz de función principal
- Mismos parámetros
- Mismo formato de salida
- Misma estructura de configuración JSON

---

## Próximos Pasos Sugeridos

1. **Tests Unitarios**: Crear tests para cada módulo
2. **Paralelización**: Implementar consultas paralelas para múltiples boxes
3. **Cache**: Sistema de cache para evitar consultas repetidas
4. **Validación de Taxonomía**: Integrar validación de nombres científicos
5. **Visualizaciones**: Agregar generación automática de mapas

---

## Archivos Modificados

- ✅ `scripts/database_queries.R` - Refactorizado
- ➕ `scripts/utils/query_functions.R` - Nuevo
- ➕ `scripts/utils/data_utils.R` - Nuevo
- ➕ `scripts/utils/spatial_utils.R` - Nuevo
- ➕ `docs/REFACTORIZACION_SUMMARY.md` - Este documento

---

## Notas Técnicas

### Dependencias Requeridas
```r
# Paquetes necesarios
library(jsonlite)    # Configuración JSON
library(sf)          # Datos espaciales
library(dplyr)       # Manipulación de datos
library(rgbif)       # GBIF API
library(robis)       # OBIS API
library(spocc)       # iNaturalist
library(rebird)      # eBird API
library(ridigbio)    # iDigBio API
library(openxlsx)    # Exportación Excel (opcional)
```

### Estructura de Directorios
```
scripts/
├── database_queries.R          # Script principal refactorizado
├── example_usage.R             # Ejemplos de uso
├── query_config.json           # Configuración
└── utils/
    ├── query_functions.R       # Funciones de consulta
    ├── data_utils.R            # Utilidades de datos
    └── spatial_utils.R         # Utilidades espaciales
```

---

**Fin del documento**
