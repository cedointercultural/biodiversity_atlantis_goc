# Web Scraping CONABIO - Guía de Uso

## Descripción
Este conjunto de scripts permite realizar web scraping de las bases de datos de biodiversidad cuyos enlaces están proporcionados en el archivo Excel `Links CONABIO_2025.xlsx`. Los datos extraídos se integrarán posteriormente con otros conjuntos de datos de biodiversidad.

## Archivos Principales

### 1. `web_scrapping_conabio.R`
Script principal que realiza el web scraping de los enlaces de CONABIO.

**Funcionalidades:**
- Lee automáticamente el archivo Excel con los enlaces
- Detecta diferentes tipos de contenido (JSON, CSV, HTML)
- Maneja errores y reintentos automáticos
- Extrae datos estructurados cuando es posible
- Identifica enlaces de descarga en páginas HTML
- Guarda resultados individuales y resumen general

### 2. `analyze_scraped_data.R`
Script de análisis que procesa los datos obtenidos del web scraping.

**Funcionalidades:**
- Carga y analiza todos los resultados del scraping
- Identifica columnas de especies, coordenadas y fechas
- Combina datos estructurados cuando es posible
- Genera estadísticas resumen
- Crea reportes de análisis en formato Markdown

### 3. `setup_conabio_scraping.R`
Script de configuración que facilita la ejecución del flujo completo.

**Funcionalidades:**
- Menú interactivo para ejecutar diferentes opciones
- Verificación de requisitos del sistema
- Gestión de directorios y archivos
- Ejecución del flujo completo de trabajo

## Instrucciones de Uso

### Paso 1: Preparación
1. Asegúrate de que el archivo `Links CONABIO_2025.xlsx` esté en el directorio de trabajo
2. Instala R y RStudio (recomendado)
3. Asegúrate de tener conexión a internet

### Paso 2: Ejecución Simple
```r
# Ejecutar el script de configuración
source("setup_conabio_scraping.R")
```

### Paso 3: Ejecución Manual
```r
# Opción 1: Solo web scraping
source("web_scrapping_conabio.R")

# Opción 2: Solo análisis (requiere datos previamente extraídos)
source("analyze_scraped_data.R")
analysis_results <- analyze_scraped_data()

# Opción 3: Flujo completo
source("web_scrapping_conabio.R")
source("analyze_scraped_data.R")
analysis_results <- analyze_scraped_data()
```

## Requisitos del Sistema

### Paquetes de R Requeridos
- **Para web scraping:** `readxl`, `rvest`, `httr`, `xml2`, `jsonlite`, `curl`, `RCurl`, `progress`, `lubridate`
- **Para análisis:** `dplyr`, `purrr`, `stringr`, `tibble`, `readr`, `ggplot2`
- **Para reportes:** `knitr`, `rmarkdown`, `DT`

### Otros Requisitos
- R versión 4.0 o superior
- Conexión a internet estable
- Permisos de escritura en el directorio de trabajo

## Estructura de Salida

### Directorio `data/scraped_conabio/`
- `scraped_X_TIMESTAMP.rds`: Resultados individuales de cada URL
- `scraping_summary_TIMESTAMP.csv`: Resumen del proceso de scraping
- `conabio_scraping_report_TIMESTAMP.md`: Reporte de análisis completo
- `extracted_biodiversity_data_TIMESTAMP.csv`: Datos de biodiversidad extraídos (si disponible)

## Tipos de Datos Soportados

### 1. JSON
- Datos estructurados en formato JSON
- Se convierten automáticamente a data frames
- Incluye metadatos de origen

### 2. CSV
- Archivos CSV descargables directamente
- Se procesan automáticamente
- Mantienen estructura original

### 3. HTML
- Páginas web con contenido
- Extrae enlaces de descarga
- Identifica tablas de datos
- Captura texto de muestra

## Manejo de Errores

### Errores Comunes y Soluciones

1. **"Excel file not found"**
   - Verificar que `Links CONABIO_2025.xlsx` esté en el directorio
   - Verificar permisos de lectura del archivo

2. **"No URL columns detected"**
   - Revisar la estructura del archivo Excel
   - Asegurar que las URLs estén en el formato correcto

3. **"HTTP error 403/404"**
   - Algunos sitios pueden bloquear el acceso automatizado
   - URLs pueden estar desactualizadas o inaccesibles

4. **"Package installation failed"**
   - Verificar conexión a internet
   - Instalar paquetes manualmente: `install.packages("nombre_paquete")`

## Personalización

### Modificar Configuración
```r
# Cambiar directorio de salida
output_dir <- "mi_directorio_personalizado"

# Modificar tiempo de espera
timeout_seconds <- 60

# Cambiar número de reintentos
max_retries <- 5
```

### Agregar Nuevos Tipos de Contenido
Modifica la función `scrape_single_url()` en `web_scrapping_conabio.R` para agregar soporte para nuevos formatos de datos.

## Consideraciones Éticas

- El script respeta los sitios web con pausas entre solicitudes
- Incluye User-Agent apropiado para identificación
- Maneja errores sin sobrecargar los servidores
- No descarga contenido protegido por derechos de autor

## Troubleshooting

### Si el scraping es muy lento:
- Reducir el tiempo de pausa entre solicitudes (modificar `Sys.sleep(1)`)
- Procesar menos URLs para pruebas

### Si hay muchos errores 403/404:
- Verificar la validez de las URLs en el archivo Excel
- Algunos sitios pueden requerir autenticación

### Si no se extraen datos:
- Muchos sitios requieren descarga manual
- Los resultados pueden incluir enlaces para descarga posterior

## Soporte

Para problemas técnicos o preguntas:
- Revisar los mensajes de error en la consola
- Verificar la estructura del reporte de análisis generado
- Contactar al desarrollador: rcavieses@gmail.com

---

**Versión:** 1.0  
**Fecha:** Agosto 2025  
**Autor:** Ricardo Cavieses-Nuñez
