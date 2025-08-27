# GUÍA DE COMPATIBILIDAD DE PAQUETES PARA BIODIVERSIDAD
# =====================================================

## VERSIONES DE R RECOMENDADAS:

### R 4.3.x (ACTUAL - RECOMENDADA)
- **Ventajas**: 
  - Más reciente y estable
  - Mejor soporte para `sf` y análisis espacial moderno
  - Compatibilidad total con `rgbif` v3.x
  - Soporte completo para `data.table` y `dplyr`

- **Desventajas**:
  - Algunos paquetes legacy no disponibles (`ecoengine`, `rbison`)

### R 4.2.x (ALTERNATIVA ESTABLE)
- **Ventajas**:
  - Muy estable
  - Buena compatibilidad con la mayoría de paquetes
  - Disponible en la mayoría de sistemas

### R 4.1.x (LEGACY - NO RECOMENDADA)
- Algunos paquetes modernos pueden tener problemas

## PAQUETES RECOMENDADOS POR CATEGORÍA:

### 📊 MANIPULACIÓN DE DATOS:
- `data.table` ✅ (Funciona en todas las versiones)
- `dplyr` ✅ (Funciona en todas las versiones)
- `readxl` ✅ (Para leer Excel)

### 🌍 DATOS DE BIODIVERSIDAD (APIs):
- `rgbif` ✅ (GBIF - Global Biodiversity Information Facility)
  - Versión 3.x: Compatible con R 4.3+
  - Límite recomendado: 50,000 registros por consulta
  - Incluir pausa de 2-3 segundos entre consultas

### 🗺️ ANÁLISIS ESPACIAL:
- `sf` ✅ (Moderno, reemplaza `sp`, `rgdal`, `maptools`)
- `raster` ✅ (Análisis raster)
- `terra` ⭐ (Moderno, más rápido que `raster`)

### 🌐 CONECTIVIDAD WEB:
- `httr` ✅ (HTTP requests)
- `jsonlite` ✅ (JSON parsing)
- `curl` ✅ (Descargas web)

### ❌ PAQUETES PROBLEMÁTICOS (NO USAR):
- `ecoengine` ❌ (No disponible para R 4.3+)
- `rbison` ❌ (No disponible para R 4.3+)
- `rvertnet` ⚠️ (Funciones deprecadas)
- `rgdal` ❌ (Deprecado, usar `sf`)
- `maptools` ❌ (Deprecado, usar `sf`)
- `PBSmapping` ❌ (Obsoleto)

## LÍMITES DE APIS PARA EVITAR ERRORES:

### GBIF (rgbif):
```r
# ✅ CORRECTO:
occ_search(geometry = polygon, limit = 50000, hasCoordinate = TRUE)
Sys.sleep(3)  # Pausa entre consultas

# ❌ INCORRECTO:
occ_search(geometry = polygon, limit = 200000)  # Muy alto
```

### Estrategia de polígonos:
- Dividir área de estudio en polígonos más pequeños
- Máximo 4-6 polígonos por sesión
- Procesar secuencialmente con pausas

## COMANDO PARA INSTALAR PAQUETES OPTIMIZADOS:

```r
# Instalar paquetes recomendados para R 4.3+
install.packages(c(
  "readxl", "data.table", "rgbif", "sf", "terra", 
  "dplyr", "httr", "jsonlite", "curl"
))
```

## VERIFICAR VERSIÓN DE R:
```r
R.version.string
sessionInfo()
```

## CONFIGURACIÓN RECOMENDADA:
```r
# Al inicio de cada script
options(repos = c(CRAN = "https://cran.rstudio.com/"))
options(timeout = 300)  # 5 minutos timeout para descargas
```

## ALTERNATIVAS A PAQUETES PROBLEMÁTICOS:

### En lugar de `ecoengine`:
- Usar datos locales del California Academy of Sciences
- APIs directas con `httr` + `jsonlite`

### En lugar de `rvertnet`:
- Usar portal web de VertNet para descarga manual
- API directa con `httr`

### En lugar de `rbison`:
- Usar GBIF que incluye datos de BISON
- API directa de USGS BISON

## RECOMENDACIÓN FINAL:

**R 4.3.3 con el conjunto de paquetes optimizado es la mejor opción** para este proyecto de biodiversidad del Golfo de California.
