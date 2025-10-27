# 🔍 ANÁLISIS DEL FLUJO DE PROCESAMIENTO ESPACIAL
# Sistema de Consultas de Biodiversidad - Golfo de California
# Fecha: 2025-10-22

## 📊 FLUJO COMPLETO: POLÍGONO → GRID → CONSULTAS

### 🗺️ **PASO 1: CARGA DEL POLÍGONO**

**Archivo fuente**: `shapefiles/study_zone.gpkg` (GeoPackage SQLite)

**Función**: `load_polygon_from_shapefile()` en `scripts/utils/spatial_utils.R`

**Proceso**:
1. Lee archivo con `sf::st_read()`
2. Valida/transforma a WGS84 (EPSG:4326)
3. Corrige geometrías inválidas con `st_make_valid()`
4. **SIMPLIFICACIÓN AUTOMÁTICA**: Si >50,000 coordenadas → simplifica
   - Polígono original: **176,634 coordenadas**
   - Polígono simplificado: **126,901 coordenadas** (28.2% reducción)
   - Tolerancia: 0.01 grados (≈1 km)

**Resultado**:
- Geometría: MULTIPOLYGON (629 features unidas)
- Bounding Box: [-114.892, 20.361] a [-105.188, 31.823]
- Área: 270,423 km²

---

### 📐 **PASO 2: GENERACIÓN DEL GRID**

**Función**: `generate_grid_bboxes()` en `scripts/utils/spatial_utils.R`

**Configuraciones actuales**:
```json
// query_config_final.json
"grid_size_degrees": 2.0,
"max_boxes": 5

// query_config_maxima.json  
"grid_size_degrees": 2.0,
"max_boxes": 30
```

**Proceso**:
1. Extrae bounding box del polígono simplificado
2. Calcula número de celdas: `ceiling((max-min) / grid_size)`
   - Columnas: `ceil((105.188 - 114.892) / 2.0) = ceil(4.85) = 5`
   - Filas: `ceil((31.823 - 20.361) / 2.0) = ceil(5.73) = 6`
   - **Total: 5 × 6 = 30 celdas**

3. Genera cada celda como:
   - `bbox`: "min_lng,min_lat,max_lng,max_lat"
   - `wkt`: POLYGON WKT para APIs que lo requieren

**Salida**: Data frame con columnas `box_id`, `bbox`, `wkt`

---

### 🔍 **PASO 3: EJECUCIÓN DE CONSULTAS**

**Función principal**: `execute_all_queries()` en `scripts/utils/query_functions.R`

**Loop por cada base de datos habilitada**:

#### **3a. GBIF** (usa `wkt`)
```r
for (i in 1:nrow(grid)) {
  query_gbif(wkt = grid$wkt[i], config, box_id = i)
}
```
- **API**: `rgbif::occ_search(geometry = wkt)`
- **Formato spatial**: WKT POLYGON
- **Parámetros**: hasCoordinate, year, limite por box

#### **3b. OBIS** (usa `bbox` → convierte a `wkt`)
```r
for (i in 1:nrow(grid)) {
  query_obis(bbox = grid$bbox[i], config, box_id = i)
}
```
- **Conversión interna**: bbox "min_lng,min_lat,max_lng,max_lat" → WKT POLYGON
- **API**: `robis::occurrence(geometry = wkt_polygon)`
- **Formato spatial**: WKT POLYGON construido desde bbox

#### **3c. iNaturalist** (usa `bbox`)
```r
for (i in 1:nrow(grid)) {
  query_inat(bbox = grid$bbox[i], config, box_id = i)
}
```
- **API**: Directa a `https://api.inaturalist.org/v1/observations`
- **Formato spatial**: nelat, nelng, swlat, swlng (bounding box nativo)

#### **3d. iDigBio** (usa `bbox`)
```r
for (i in 1:nrow(grid)) {
  query_idigbio(bbox = grid$bbox[i], config, box_id = i)
}
```
- **API**: `ridigbio::idig_search_records()`
- **Formato spatial**: geopoint con top_left/bottom_right

---

## ⚠️ **INCONSISTENCIAS IDENTIFICADAS**

### 🔴 **INCONSISTENCIA 1: Configuración vs Realidad del Grid**

**Problema**: `query_config_final.json` tiene `max_boxes: 5` pero el grid genera **30 celdas**

**Efecto**: 
- Se están limitando artificialmente las consultas a solo 5 de 30 celdas
- Se pierde **83%** del área de estudio
- Cobertura espacial incompleta

**Código afectado**:
```r
# database_queries.R línea 183
if (nrow(grid) > config$spatial$max_boxes) {
  grid <- grid[1:config$spatial$max_boxes, ]  # ¡TRUNCA 25 CELDAS!
}
```

### 🔴 **INCONSISTENCIA 2: Formatos Espaciales Mixtos**

**Problema**: Diferentes APIs usan diferentes formatos espaciales desde el mismo grid

**APIs y formatos**:
- **GBIF**: Usa `grid$wkt` (correcto)
- **OBIS**: Usa `grid$bbox` → convierte a WKT (doble conversión innecesaria)
- **iNaturalist**: Usa `grid$bbox` (correcto)
- **iDigBio**: Usa `grid$bbox` (correcto)

**Efecto**: Inconsistencia en precisión espacial y posibles errores de conversión

### 🔴 **INCONSISTENCIA 3: Orden de Coordenadas en WKT**

**Problema**: El WKT generado puede no seguir el estándar correcto

**Código actual** (spatial_utils.R línea 135):
```r
grid_wkts[[box_count]] <- sprintf(
  "POLYGON((%f %f,%f %f,%f %f,%f %f,%f %f))",
  cell_min_lon, cell_min_lat,    # ❌ Primer punto
  cell_max_lon, cell_min_lat,    # ❌ Sentido horario
  cell_max_lon, cell_max_lat,
  cell_min_lon, cell_max_lat,
  cell_min_lon, cell_min_lat     # Cierre correcto
)
```

**Problema**: Algunos sistemas esperan coordenadas en sentido antihorario o formato diferente

### 🔴 **INCONSISTENCIA 4: Validación de Grid vs Polígono Original**

**Problema**: No se valida que las celdas del grid intersecten realmente con el polígono original

**Efecto**: 
- Se consultan celdas que pueden estar completamente fuera del área de estudio
- Datos irrelevantes en zonas oceánicas sin biodiversidad terrestre
- Desperdicio de recursos de API

### 🔴 **INCONSISTENCIA 5: Diferentes Tolerancias de Simplificación**

**Problema**: Simplificación automática con tolerancia fija puede ser inapropiada

**Código actual**:
```r
# Tolerancia fija de 0.01 grados ≈ 1 km
polygon_simplified <- sf::st_simplify(polygon_union, dTolerance = 0.01)
```

**Problemas**:
- Para polígonos grandes: tolerancia muy pequeña (no simplifica lo suficiente)
- Para polígonos pequeños: tolerancia muy grande (pierde detalle importante)

---

## ✅ **RECOMENDACIONES DE CORRECCIÓN**

### 🔧 **1. Corregir Configuración de max_boxes**

```json
// query_config_final.json
"max_boxes": 30,  // En lugar de 5

// O mejor: calcular dinámicamente
"max_boxes": null,  // Sin límite artificial
```

### 🔧 **2. Estandarizar Formato Espacial**

**Opción A**: Todo a WKT
```r
# Que todas las APIs usen grid$wkt directamente
query_obis(wkt = grid$wkt[i], ...)  # En lugar de bbox
```

**Opción B**: Todo a bbox con conversión local
```r
# Generar solo bbox, convertir a WKT cuando sea necesario
```

### 🔧 **3. Validar Intersección Grid-Polígono**

```r
# Filtrar celdas que intersectan con polígono original
valid_cells <- sapply(1:nrow(grid), function(i) {
  cell_geom <- sf::st_as_sfc(grid$wkt[i])
  sf::st_intersects(cell_geom, original_polygon, sparse = FALSE)[1]
})
grid <- grid[valid_cells, ]
```

### 🔧 **4. Tolerancia Adaptativa de Simplificación**

```r
# Calcular tolerancia basada en el tamaño del polígono
bbox_diagonal <- sqrt((bbox_width^2) + (bbox_height^2))
tolerance <- max(0.001, bbox_diagonal / 1000)  # 0.1% del diagonal
```

### 🔧 **5. Configuración Grid Inteligente**

```r
# Auto-calcular grid_size basado en área y número objetivo de celdas
target_cells <- 20
area_per_cell <- total_area / target_cells
grid_size <- sqrt(area_per_cell)
```

---

## 📊 **IMPACTO ACTUAL DE LAS INCONSISTENCIAS**

1. **Cobertura espacial**: Solo 17% del área se consulta (5 de 30 celdas)
2. **Eficiencia**: Conversiones redundantes bbox↔wkt
3. **Precisión**: Posibles errores en formatos WKT
4. **Recursos**: Consultas en áreas irrelevantes
5. **Datos**: Resultados incompletos y sesgados espacialmente

**Prioridad de corrección**: ALTA - Afecta directamente la calidad de los datos obtenidos