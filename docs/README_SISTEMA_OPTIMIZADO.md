# 🌊 SISTEMA DE CONSULTAS DE BIODIVERSIDAD - GOLFO DE CALIFORNIA

[![R](https://img.shields.io/badge/R-4.0+-blue.svg)](https://www.r-project.org/)
[![Biodiversidad](https://img.shields.io/badge/Biodiversidad-GBIF%20|%20OBIS%20|%20iNaturalist%20|%20iDigBio-green.svg)]()
[![Paralelización](https://img.shields.io/badge/Paralelización-future%2Ffurrr-orange.svg)]()

Sistema modular para consultas masivas de biodiversidad en el Golfo de California, integrando múltiples bases de datos científicas con procesamiento espacial avanzado y paralelización.

## 📁 ESTRUCTURA DEL PROYECTO (OPTIMIZADA)

```
scripts/
├── 🎯 APLICACIONES PRINCIPALES
│   ├── database_queries.R           # NÚCLEO: Orchestrador principal
│   └── biodiversity_query.R         # APP UNIFICADA: Todos los modos (básico/máximo/paralelo)
│
├── 📦 MÓDULOS UTILITARIOS (utils/)
│   ├── data_utils.R                 # Procesamiento y limpieza de datos
│   ├── spatial_utils.R              # Operaciones espaciales y grid
│   ├── query_functions.R            # APIs de bases de datos
│   ├── parallel_query_functions.R   # Estrategias de paralelización
│   ├── polygon_simplification.R     # Optimización de polígonos
│   ├── validate_syntax.R            # Validación de código R
│   └── check_api_keys.R             # Verificación de APIs
│
├── 🔧 HERRAMIENTAS (tools/)
│   ├── test_polygon_simplification.R # Análisis de polígonos complejos
│   ├── setup_dependencies.R         # Instalación de dependencias
│   └── run_manager.R                # Ejecutor consolidado de scripts
│
├── ⚙️ CONFIGURACIÓN (config/)
│   ├── query_config_final.json      # Configuración básica
│   ├── query_config_maxima.json     # Configuración exhaustiva
│   └── query_config.json            # Configuración general
│
└── 📋 OTROS DIRECTORIOS
    ├── data_processing/             # Análisis de datos post-consulta
    ├── api_interaction/             # Configuración de APIs
    ├── setup/                       # Scripts de configuración inicial
    └── tests/                       # Herramientas de validación
```

## 🚀 INICIO RÁPIDO

### 1. **Configuración Inicial**
```r
# Instalar dependencias
source("scripts/tools/setup_dependencies.R")

# Verificar APIs (opcional)
source("scripts/utils/check_api_keys.R")
```

### 2. **Ejecutar Consultas**

#### 🔸 **Consulta Unificada** (recomendado)
```r
source("scripts/biodiversity_query.R")

# Modo interactivo (seleccionar opción)
run_biodiversity_query()

# Modo directo
run_biodiversity_query("basic")    # Consulta básica (rápida)
run_biodiversity_query("maxima")   # Consulta exhaustiva secuencial  
run_biodiversity_query("parallel") # Consulta exhaustiva paralela (recomendado)
```

#### 🔸 **Desde Terminal**
```bash
# Consulta básica
Rscript scripts/biodiversity_query.R basic

# Consulta máxima paralela
Rscript scripts/biodiversity_query.R parallel
```

#### 🔸 **Usando el Ejecutor Consolidado**
```r
source("scripts/tools/run_manager.R")

# Mostrar opciones disponibles
show_available_scripts()

# Ejecutar script específico
run_single_script("biodiversity_query.R")

# Ejecutar flujo completo
run_biodiversity_flow()
```

## 🎯 APLICACIONES DISPONIBLES

| Script | Descripción | Uso Recomendado |
|--------|-------------|------------------|
| **biodiversity_query.R** | Script unificado con 3 modos de operación | Todas las consultas (básicas y avanzadas) |
| **database_queries.R** | Núcleo del sistema (no ejecutar directamente) | Base para otras aplicaciones |

### 🎮 **Modos Disponibles en biodiversity_query.R**

| Modo | Configuración | Tiempo | Uso Recomendado |
|------|---------------|--------|------------------|
| **basic** | 10 años, 500 reg/celda, GBIF+OBIS | 5-10 min | Pruebas iniciales |
| **maxima** | 25 años, 5000 reg/celda, todas las DBs | 30-45 min | Datasets medianos |
| **parallel** | 25 años, 5000 reg/celda, paralelizado | 15-20 min | Máximo rendimiento |

## 🌐 BASES DE DATOS INTEGRADAS

- **🔬 GBIF**: Global Biodiversity Information Facility
- **🌊 OBIS**: Ocean Biodiversity Information System  
- **📸 iNaturalist**: Observaciones ciudadanas
- **🦅 eBird**: Registros de aves
- **🏛️ iDigBio**: Especímenes digitalizados

## ⚡ CARACTERÍSTICAS TÉCNICAS

### 🔄 **Sistema de Paralelización**
- **Estrategia**: Grid dividido en celdas de 2° × 2°
- **Cores**: Automático (detecta CPU disponible)
- **Optimización**: Balanceado de carga por celda

### 🗺️ **Procesamiento Espacial**
- **Área de estudio**: Golfo de California (MULTIPOLYGON)
- **Simplificación automática**: Para polígonos >50,000 coordenadas
- **Grid adaptativo**: 30 celdas optimizadas (5×6)

### 📊 **Formato de Datos**
- **Salida**: CSV, JSON, Excel
- **Campos estándar**: species, coordinates, database, date, source
- **Limpieza automática**: Duplicados y coordenadas inválidas

## 🔧 HERRAMIENTAS AUXILIARES

### 📐 **Análisis de Polígonos**
```r
source("scripts/tools/test_polygon_simplification.R")
```
- Analiza complejidad del polígono de estudio
- Recomienda configuraciones óptimas
- Prueba simplificación automática

### 🎮 **Ejecutor Interactivo**
```r
source("scripts/tools/run_manager.R")
```
- Interfaz interactiva para ejecutar scripts
- Monitoreo de progreso y errores
- Funciones de compatibilidad legacy

## 📝 CONFIGURACIÓN

### 🔑 **APIs Requeridas**
```r
# eBird API (opcional)
# Crear archivo: scripts/api_interaction/ebirdapi_key
# Contenido: tu_clave_ebird_aqui
```

### ⚙️ **Archivos de Configuración**
- `config/query_config_final.json`: Configuración básica
- `config/query_config_maxima.json`: Configuración exhaustiva  
- `config/query_config.json`: Configuración general

## 📊 RESULTADOS ESPERADOS

### 🎯 **Consulta Típica**
- **Área**: ~240,000 km² (Golfo de California)
- **Duración**: 15-45 minutos (depende de paralelización)
- **Registros esperados**: 50,000-200,000 observaciones
- **Archivos generados**: CSV principal + metadatos JSON

### 📈 **Rendimiento**
- **Sin paralelización**: ~45 minutos
- **Con paralelización (3 cores)**: ~15-20 minutos
- **Memoria requerida**: 2-4 GB RAM
- **Espacio en disco**: 100-500 MB por consulta

## 🔍 SOLUCIÓN DE PROBLEMAS

### ❌ **Errores Comunes**

#### Polígono muy complejo
```r
# Ejecutar análisis de polígono
source("scripts/tools/test_polygon_simplification.R")
# Seguir recomendaciones de simplificación
```

#### Falla de API
```r
# Verificar conexiones
source("scripts/utils/check_api_keys.R")
# Revisar configuración de red/proxy
```

#### Memoria insuficiente
```r
# Usar consulta básica
source("scripts/final_query.R")
# O ajustar grid en configuración JSON
```

## 📚 DOCUMENTACIÓN ADICIONAL

- **[Análisis de Scripts](docs/ANALISIS_SCRIPTS_RELACIONES.md)**: Arquitectura del sistema
- **[Guía de APIs](docs/README_API_SETUP.md)**: Configuración de bases de datos
- **[Mejoras Implementadas](docs/MEJORAS_IMPLEMENTADAS.md)**: Historial de optimizaciones

## 🤝 CONTRIBUCIÓN

1. **Fork** el repositorio
2. **Crear** branch de feature (`git checkout -b feature/nueva-funcionalidad`)
3. **Commit** cambios (`git commit -am 'Añadir nueva funcionalidad'`)
4. **Push** al branch (`git push origin feature/nueva-funcionalidad`)  
5. **Crear** Pull Request

## 📄 LICENCIA

Este proyecto está bajo la licencia MIT. Ver [LICENSE](LICENSE) para más detalles.

---

**🌊 Proyecto**: Biodiversidad Atlántis - Golfo de California  
**📅 Última actualización**: Octubre 2025  
**🔧 Estado**: Sistema optimizado y funcional  
**👥 Mantenedor**: Ricardo Cavieses-Nuñez