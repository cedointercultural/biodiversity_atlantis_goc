# Proyecto CONABIO - Datos de Biodiversidad

Este directorio contiene todos los scripts, datos y reportes relacionados con la extracción y análisis de datos de biodiversidad de CONABIO (Comisión Nacional para el Conocimiento y Uso de la Biodiversidad).

## Estructura del Proyecto

```
conabio/
├── README.md                    # Este archivo
├── README_webscraping.md        # Guía detallada de web scraping
├── main_conabio.R              # Script principal para ejecutar todo el flujo
├── scripts/                    # Scripts de R para diferentes tareas
│   ├── web_scrapping_conabio.R      # Web scraping inicial (obsoleto)
│   ├── download_conabio_zips.R      # Descarga directa de archivos ZIP
│   ├── explore_conabio_data.R       # Extracción y exploración de datos
│   ├── extract_conabio_data.R       # Procesamiento adicional de datos
│   └── analyze_scraped_data.R       # Análisis de datos extraídos
├── data/                       # Datos descargados y procesados
│   ├── downloads/                   # Archivos ZIP descargados de CONABIO
│   └── extracted/                   # Datos CSV extraídos y organizados
└── reports/                    # Reportes y archivos de resumen
    ├── *.rds                       # Resultados individuales del scraping
    ├── *_summary_*.csv             # Resúmenes de descarga y extracción
    └── *_report_*.md               # Reportes de análisis
```

## Flujo de Trabajo

### 1. Descarga de Datos
El script `download_conabio_zips.R` descarga automáticamente los archivos ZIP de biodiversidad desde las URLs proporcionadas en el archivo Excel `Links CONABIO_2025.xlsx`.

**Grupos de biodiversidad descargados:**
- Cromistas (45 MB)
- Hongos (29 MB)  
- Invertebrados (1.5 MB)
- Mamíferos (7 MB)
- Peces (116 MB)
- Plantas (64 MB)
- Protozoarios (3 MB)
- Reptiles (113 MB)

### 2. Extracción y Análisis
El script `explore_conabio_data.R` extrae el contenido de los archivos ZIP y analiza la estructura de los datos CSV.

**Datos exitosamente procesados:**
- **Cromistas**: 11 archivos CSV, 717 MB de datos
- **Peces**: 16 archivos CSV, 98 columnas por registro
- **Protozoarios**: 16 archivos CSV, 44 MB de datos

### 3. Estructura de Datos

Cada grupo taxonómico incluye:
- **Archivo principal**: `[grupo].csv` con todos los registros
- **Archivos por zona UTM**: Datos organizados geográficamente (utm11-utm16)
- **Archivos por país**: Datos de EUA y Canadá
- **Metadatos**: Archivos XML, HTML, README e imágenes
- **Licencias**: Información sobre uso y citación

**Columnas principales de los datos:**
- **Taxonomía**: `grupobio`, `familiavalida`, `generovalido`, `especievalida`
- **Ubicación**: `longitud`, `latitud`, `estadomapa`, `municipiomapa`, `localidad`
- **Conservación**: `nom059`, `cites`, `iucn`, `prioritaria`, `exoticainvasora`
- **Temporales**: `fechacolecta`, `fechadeterminacion`, `ultimafechaactualizacion`
- **Identificación**: `idejemplar`, `urlejemplar`, `fuente`, `proyecto`

## Uso Rápido

### Ejecutar todo el flujo completo:
```r
source("conabio/main_conabio.R")
```

### Ejecutar pasos individuales:
```r
# Solo descarga
source("conabio/scripts/download_conabio_zips.R")

# Solo extracción y análisis
source("conabio/scripts/explore_conabio_data.R")
```

## Estadísticas del Proyecto

- **Total de archivos ZIP descargados**: 8
- **Tamaño total de datos**: ~380 MB comprimidos
- **Grupos taxonómicos procesados**: 3 (Cromistas, Peces, Protozoarios)
- **Total de archivos CSV extraídos**: 43+
- **Registros de biodiversidad**: Miles de registros por grupo

## Archivos de Salida

### En `data/downloads/`:
- Archivos ZIP originales de CONABIO
- Resúmenes de descarga con estado y tamaños

### En `data/extracted/`:
- Archivos CSV organizados por grupo taxonómico
- Subdirectorios para cada grupo (cromistas, peces, protozoarios)

### En `reports/`:
- Reportes de análisis en formato Markdown
- Archivos RDS con resultados del scraping
- Resúmenes CSV con estadísticas

## Requisitos del Sistema

- R versión 4.0+
- Paquetes: `readxl`, `readr`, `dplyr`, `stringr`, `purrr`, `utils`
- Conexión a internet para descargas
- Espacio en disco: ~2 GB recomendados

## Notas Importantes

1. **Licencias**: Todos los datos están sujetos a las licencias especificadas por CONABIO
2. **Citación**: Consultar archivos `*licencia.csv` para información de citación
3. **Actualizaciones**: Los datos corresponden a marzo 2025 (202503)
4. **Formatos**: Todos los datos están en coordenadas decimales (WGS84)

## Contacto

- **Autor**: Ricardo Cavieses-Nuñez
- **Email**: rcavieses@gmail.com
- **Fecha**: Agosto 2025

---

Para más detalles sobre el proceso de web scraping, consultar `README_webscraping.md`.
