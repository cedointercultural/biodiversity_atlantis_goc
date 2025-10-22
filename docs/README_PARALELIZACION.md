# Guía de Paralelización de Consultas

## 📚 Descripción General

El sistema de consultas de biodiversidad ahora soporta **ejecución paralela** para acelerar significativamente las consultas cuando se trabaja con grids de múltiples celdas. La paralelización distribuye las consultas a diferentes bases de datos entre múltiples núcleos de CPU, reduciendo el tiempo total de ejecución.

## 🚀 Ventajas de la Paralelización

### ✅ Beneficios

1. **Velocidad**: Reducción del tiempo de ejecución de **3x a 8x** dependiendo del número de núcleos
2. **Eficiencia**: Mejor uso de recursos de hardware modernos (multi-core)
3. **Escalabilidad**: Maneja grids grandes (50+ celdas) de manera eficiente
4. **Automática**: Detección automática del número óptimo de núcleos

### ⚠️ Consideraciones

1. **Memoria RAM**: Cada núcleo requiere memoria adicional (~500MB-1GB por núcleo)
2. **Conexiones API**: Mayor carga en las APIs (respetar límites de rate)
3. **Complejidad**: Debugging más difícil en caso de errores
4. **No siempre mejor**: Para grids pequeños (<5 celdas), el overhead puede ser contraproducente

## 📦 Dependencias Adicionales

La paralelización requiere dos paquetes adicionales de R:

```r
install.packages("future")   # Framework de paralelización
install.packages("furrr")    # future + purrr (functional programming)
```

**Nota**: El sistema los instalará automáticamente si no están disponibles.

## 🎯 Cuándo Usar Paralelización

### ✅ Usar Paralelización Cuando:

- Grid con **≥ 5 celdas**
- Máquina con **≥ 4 núcleos CPU**
- Consultas a **múltiples bases de datos** (GBIF + OBIS + iNat + iDigBio)
- Áreas geográficas **grandes** (> 1000 km²)
- Necesitas **resultados rápidos** y tienes recursos disponibles

### ❌ Evitar Paralelización Cuando:

- Grid con **< 5 celdas** (overhead no justifica beneficio)
- Máquina con **≤ 2 núcleos** (poco beneficio)
- **Memoria RAM limitada** (< 4GB disponibles)
- Problemas de **conectividad inestable** (más difícil manejar errores)
- **Debugging activo** (logs más difíciles de seguir)

## 📖 Modos de Ejecución

### 1. Modo Automático (Recomendado)

El sistema decide automáticamente si usar paralelización:

```r
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json",
  polygon_file = "shapefiles/study_zone.gpkg",
  parallel = "auto"  # ← Decide automáticamente
)
```

**Lógica de decisión**:
- Si `grid >= 5 celdas` → Paralelo
- Si `grid < 5 celdas` → Secuencial

### 2. Modo Paralelo Explícito

Forzar paralelización independientemente del número de celdas:

```r
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json",
  polygon_file = "shapefiles/study_zone.gpkg",
  parallel = TRUE,      # ← Forzar paralelo
  n_cores = 4           # ← Usar 4 núcleos
)
```

### 3. Modo Secuencial Explícito

Deshabilitar paralelización:

```r
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json",
  polygon_file = "shapefiles/study_zone.gpkg",
  parallel = FALSE      # ← Forzar secuencial
)
```

### 4. Script Optimizado para Paralelización

Usar el script dedicado `maxima_query_parallel.R`:

```bash
cd /home/atlantis/biodiversity_atlantis_goc
Rscript scripts/maxima_query_parallel.R
```

Este script:
- ✅ Auto-detecta núcleos disponibles
- ✅ Reserva 1 núcleo para el sistema
- ✅ Muestra estadísticas de rendimiento
- ✅ Incluye análisis completo de resultados

## 🔧 Configuración de Núcleos

### Detección Automática (Recomendado)

```r
# Detecta automáticamente y deja 1 núcleo libre
results <- execute_biodiversity_queries(
  config_file = "config.json",
  parallel = TRUE,
  n_cores = NULL  # ← Auto-detectar
)
```

### Especificación Manual

```r
# Usar exactamente 4 núcleos
results <- execute_biodiversity_queries(
  config_file = "config.json",
  parallel = TRUE,
  n_cores = 4  # ← Número específico
)
```

### Fórmula Recomendada

```r
n_cores_total <- parallel::detectCores()
n_cores_use <- max(1, n_cores_total - 1)  # Dejar 1 libre
```

**Ejemplos**:
- 8 núcleos disponibles → Usar 7 núcleos
- 4 núcleos disponibles → Usar 3 núcleos
- 2 núcleos disponibles → Usar 1 núcleo (mejor secuencial)

## 📊 Estrategias de Paralelización

El sistema incluye **3 estrategias** diferentes:

### 1. Paralelización Completa (`execute_all_queries_parallel`)

- **Mejor para**: Grids grandes (20+ celdas)
- **Características**: Ejecuta todas las celdas en paralelo simultáneamente
- **Ventajas**: Máxima velocidad
- **Desventajas**: Mayor consumo de memoria

```r
results <- execute_all_queries_parallel(
  grid = grid,
  config = config,
  n_cores = 4
)
```

### 2. Paralelización Adaptativa (`execute_all_queries_adaptive`)

- **Mejor para**: Uso general (RECOMENDADO)
- **Características**: Decide automáticamente secuencial vs paralelo
- **Ventajas**: Óptimo en todos los casos
- **Desventajas**: Ninguna

```r
results <- execute_all_queries_adaptive(
  grid = grid,
  config = config,
  parallel_threshold = 5  # Umbral de celdas
)
```

### 3. Paralelización por Chunks (`execute_all_queries_chunked`)

- **Mejor para**: Grids muy grandes (50+ celdas), memoria limitada
- **Características**: Procesa el grid en lotes (chunks) secuenciales
- **Ventajas**: Control de memoria, mejor manejo de errores
- **Desventajas**: Más lento que paralelización completa

```r
results <- execute_all_queries_chunked(
  grid = grid,
  config = config,
  chunk_size = 10,  # Procesar 10 celdas por chunk
  n_cores = 4
)
```

## 💡 Ejemplos Prácticos

### Ejemplo 1: Consulta Rápida (Grid Pequeño)

```r
# Grid de 3 celdas → Modo secuencial automático
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config_test.json",
  parallel = "auto"  # Se ejecutará en modo secuencial
)
```

### Ejemplo 2: Consulta Máxima (Grid Grande)

```r
# Grid de 50 celdas → Modo paralelo automático
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config_maxima.json",
  parallel = "auto"  # Se ejecutará en modo paralelo
)
```

### Ejemplo 3: Servidor con Muchos Núcleos

```r
# Servidor con 32 núcleos → Usar 24 núcleos
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config_maxima.json",
  parallel = TRUE,
  n_cores = 24  # Dejar 8 para otros procesos
)
```

### Ejemplo 4: Laptop con Recursos Limitados

```r
# Laptop con 4 núcleos y 8GB RAM → Usar 2 núcleos
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config_test.json",
  parallel = TRUE,
  n_cores = 2  # Conservador para no saturar
)
```

## 📈 Benchmarks y Rendimiento

### Resultados Esperados (Grid de 20 celdas, 4 bases de datos)

| Configuración | Tiempo | Velocidad Relativa | Uso RAM |
|--------------|--------|-------------------|----------|
| Secuencial (1 núcleo) | 15 min | 1.0x (baseline) | ~2 GB |
| Paralelo (2 núcleos) | 8 min | 1.9x | ~3 GB |
| Paralelo (4 núcleos) | 4.5 min | 3.3x | ~5 GB |
| Paralelo (8 núcleos) | 3 min | 5.0x | ~8 GB |

**Notas**:
- Velocidad no es lineal por overhead y límites de API
- Eficiencia disminuye con más de 8 núcleos (límites de red)
- RAM por núcleo varía según datos descargados

## 🐛 Troubleshooting

### Problema: "Error: Package 'future' not found"

**Solución**: El sistema debería instalarlo automáticamente. Si no:

```r
install.packages("future")
install.packages("furrr")
```

### Problema: "System hangs / se congela"

**Solución**: Demasiados núcleos o poca RAM. Reducir núcleos:

```r
results <- execute_biodiversity_queries(
  config_file = "config.json",
  parallel = TRUE,
  n_cores = 2  # Reducir número de núcleos
)
```

### Problema: "Resultados inconsistentes o incompletos"

**Solución**: Problemas de sincronización. Usar modo secuencial:

```r
results <- execute_biodiversity_queries(
  config_file = "config.json",
  parallel = FALSE  # Volver a secuencial
)
```

### Problema: "API rate limit errors"

**Solución**: Demasiadas solicitudes simultáneas. Usar chunks:

```r
results <- execute_all_queries_chunked(
  grid = grid,
  config = config,
  chunk_size = 5,   # Chunks pequeños
  n_cores = 2       # Pocos núcleos
)
```

## 📁 Archivos Relacionados

- `scripts/utils/parallel_query_functions.R` - Implementación de paralelización
- `scripts/database_queries.R` - Integración con sistema principal
- `scripts/maxima_query_parallel.R` - Script optimizado para consultas paralelas
- `docs/README_PARALELIZACION.md` - Este documento

## 🔮 Desarrollo Futuro

### Mejoras Planificadas

1. **Rate limiting inteligente**: Control automático de velocidad por API
2. **Priorización de celdas**: Consultar primero celdas con más probabilidad de datos
3. **Caché distribuido**: Evitar re-consultar datos ya descargados
4. **Monitoreo en tiempo real**: Dashboard de progreso con estadísticas
5. **Paralelización jerárquica**: Paralelo por base de datos + por celda

## 📞 Soporte

Para problemas o preguntas sobre paralelización:

1. Revisar logs en `data/query_results/query_execution_*.log`
2. Verificar versiones de paquetes: `packageVersion("future")`
3. Probar primero en modo secuencial para aislar problemas
4. Consultar documentación de `future`: `?future::plan`

---

**Última actualización**: 2025-10-18  
**Versión del sistema**: 2.0 (con soporte de paralelización)
