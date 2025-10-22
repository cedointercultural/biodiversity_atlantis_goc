# Arquitectura del Sistema de Consultas de Biodiversidad

## Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                    database_queries.R                           │
│                  (Script Principal)                             │
│                                                                 │
│  • execute_biodiversity_queries()                               │
│  • show_help()                                                  │
└────────────────┬────────────────────────────────┬───────────────┘
                 │                                │
                 │                                │
         ┌───────▼──────────┐            ┌────────▼─────────┐
         │  data_utils.R    │            │  spatial_utils.R │
         │                  │            │                  │
         │ • log_message()  │            │ • load_polygon() │
         │ • clean_species()│            │ • generate_grid()│
         │ • format_data()  │            │ • validate_coords│
         │ • export_data()  │            │ • filter_points()│
         │ • summarize()    │            │ • spatial_stats()│
         └──────────────────┘            └──────────────────┘
                 │
                 │
         ┌───────▼──────────────────────────────────────┐
         │          query_functions.R                   │
         │                                              │
         │  • query_gbif()                              │
         │  • query_obis()                              │
         │  • query_inat()                              │
         │  • query_ebird()                             │
         │  • query_idigbio()                           │
         │  • execute_all_queries()                     │
         └──────────────────────────────────────────────┘
                 │
                 │
         ┌───────▼──────────────────────────────────────┐
         │         APIs de Biodiversidad                │
         │                                              │
         │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐    │
         │  │ GBIF │  │ OBIS │  │ iNat │  │eBird│    │
         │  └──────┘  └──────┘  └──────┘  └──────┘    │
         │                                              │
         │  ┌────────┐                                 │
         │  │iDigBio │                                 │
         │  └────────┘                                 │
         └──────────────────────────────────────────────┘
```

## Flujo de Ejecución

```
1. INICIALIZACIÓN
   ├─ Cargar módulos (data_utils, spatial_utils, query_functions)
   ├─ Cargar configuración JSON
   └─ Crear directorio de salida

2. PREPARACIÓN ESPACIAL
   ├─ Cargar polígono del área de estudio
   ├─ Validar y transformar CRS a WGS84
   ├─ Generar grid de búsqueda
   └─ Aplicar límite de boxes (si configurado)

3. CONSULTAS A BASES DE DATOS
   ├─ Para cada box en el grid:
   │  ├─ GBIF (si habilitado)
   │  ├─ OBIS (si habilitado)
   │  ├─ iNaturalist (si habilitado)
   │  ├─ eBird (si habilitado)
   │  └─ iDigBio (si habilitado)
   └─ Consolidar todos los resultados

4. PROCESAMIENTO DE DATOS
   ├─ Formatear a estructura estándar
   ├─ Validar coordenadas y fechas
   ├─ Eliminar duplicados
   └─ Generar resumen estadístico

5. EXPORTACIÓN
   ├─ Exportar en formatos configurados (CSV, JSON, XLSX)
   ├─ Generar metadatos
   └─ Guardar logs

6. FINALIZACIÓN
   └─ Retornar resultados consolidados
```

## Estructura de Datos

### Entrada: Configuración JSON
```json
{
  "general": {
    "polygon_path": "ruta/al/shapefile.gpkg",
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
    }
  },
  "output": {
    "formats": ["csv", "json"],
    "include_metadata": true
  }
}
```

### Salida: Datos de Biodiversidad
```
Data Frame con estructura estándar:
┌──────────────┬──────┬──────┬──────┬───────┬─────┬─────────────┬───────────┬────────┐
│ species      │ lon  │ lat  │ year │ month │ day │date_recorded│ taxonRank │ source │
├──────────────┼──────┼──────┼──────┼───────┼─────┼─────────────┼───────────┼────────┤
│ homo sapiens │-95.2 │ 18.5 │ 2023 │   3   │ 15  │ 2023-03-15  │  SPECIES  │  GBIF  │
│ canis lupus  │-94.8 │ 19.1 │ 2022 │   7   │ 20  │ 2022-07-20  │  SPECIES  │  OBIS  │
└──────────────┴──────┴──────┴──────┴───────┴─────┴─────────────┴───────────┴────────┘
```

## Responsabilidades de Módulos

### 📊 data_utils.R - Procesamiento de Datos
- Limpieza de nombres científicos
- Formateo a estructura estándar
- Validación de datos
- Eliminación de duplicados
- Resúmenes estadísticos
- Exportación multi-formato
- Sistema de logging

### 🗺️ spatial_utils.R - Procesamiento Espacial
- Carga de archivos espaciales
- Transformación de CRS
- Generación de grids
- Validación de coordenadas
- Operaciones espaciales (intersección, filtrado)
- Cálculo de estadísticas espaciales
- Simplificación de geometrías

### 🔍 query_functions.R - Consultas a APIs
- Funciones específicas por base de datos
- Validación de parámetros
- Manejo de errores por consulta
- Formateo de resultados
- Ejecución consolidada de todas las consultas
- Logging específico por fuente

### 🎯 database_queries.R - Orquestación
- Coordinación del flujo completo
- Carga de módulos
- Gestión de configuración
- Control de ejecución
- Interfaz de usuario
- Documentación y ayuda

## Beneficios de la Arquitectura Modular

### ✅ Separación de Responsabilidades
Cada módulo tiene un propósito claro y definido

### ✅ Reutilización de Código
Las funciones pueden usarse independientemente

### ✅ Mantenibilidad
Cambios localizados, sin afectar otros módulos

### ✅ Escalabilidad
Fácil agregar nuevas funcionalidades o fuentes

### ✅ Testabilidad
Módulos independientes facilitan pruebas unitarias

### ✅ Legibilidad
Código organizado y bien documentado

## Ejemplo de Uso Modular

### Uso Completo (Recomendado)
```r
source("scripts/database_queries.R")

results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json",
  polygon_file = "shapefiles/study_zone.gpkg",
  output_dir = "data/query_results"
)
```

### Uso de Módulo Específico
```r
# Solo procesamiento espacial
source("scripts/utils/spatial_utils.R")

polygon <- load_polygon_from_shapefile("shapefiles/study_zone.gpkg")
grid <- generate_grid_bboxes(polygon, grid_size = 0.5)
```

### Uso de Funciones Individuales
```r
# Solo consulta a GBIF
source("scripts/utils/data_utils.R")
source("scripts/utils/query_functions.R")

config <- load_query_config("scripts/query_config.json")
gbif_data <- query_gbif(
  wkt = "POLYGON((-95 18, -95 19, -94 19, -94 18, -95 18))",
  config = config$databases$gbif,
  box_id = 1
)
```

## Extensibilidad

### Agregar Nueva Base de Datos

1. **Crear función en query_functions.R:**
```r
query_nueva_bd <- function(bbox, config, box_id = 1, log_function = NULL) {
  # Implementación
}
```

2. **Agregar al executor:**
```r
# En execute_all_queries()
if (config$databases$nueva_bd$enabled) {
  nueva_bd_results <- query_nueva_bd(...)
  all_results <- rbind(all_results, nueva_bd_results)
}
```

3. **Actualizar configuración JSON:**
```json
"databases": {
  "nueva_bd": {
    "enabled": true,
    "params": { ... }
  }
}
```

### Agregar Nueva Funcionalidad Espacial

1. **Agregar función a spatial_utils.R:**
```r
nueva_funcion_espacial <- function(...) {
  # Implementación
}
```

2. **Exportar y documentar:**
```r
#' @export
```

3. **Usar en script principal o individualmente**

## Conclusión

Esta arquitectura modular proporciona una base sólida y escalable para el sistema de consultas de biodiversidad, facilitando el mantenimiento, la extensión y la reutilización del código.
