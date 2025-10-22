# Scripts Deprecados - Consultas de Biodiversidad

**Fecha de deprecación:** 2025-10-17  
**Razón:** Refactorización completa del sistema

---

## 📁 Contenido de esta Carpeta

Esta carpeta contiene scripts que han sido **reemplazados** o **consolidados** en el nuevo sistema refactorizado. Se mantienen aquí por referencia histórica y compatibilidad temporal.

---

## 🗂️ Scripts Deprecados

### 1. `database_queries_refactored.R`
- **Estado:** ❌ DEPRECADO
- **Reemplazado por:** `../database_queries.R` (versión final)
- **Descripción:** Versión intermedia durante la refactorización
- **Razón de deprecación:** Era una copia temporal durante el proceso de refactorización

### 2. `test_query.R`
- **Estado:** ❌ DEPRECADO
- **Reemplazado por:** `../final_query.R`
- **Descripción:** Script de prueba inicial para validar la refactorización
- **Razón de deprecación:** Ya no es necesario, la funcionalidad está en `final_query.R`

### 3. `run_query.R`
- **Estado:** ❌ DEPRECADO
- **Reemplazado por:** `../final_query.R`
- **Descripción:** Script original para ejecutar consultas
- **Razón de deprecación:** Funcionalidad integrada en el nuevo sistema

### 4. `example_usage.R`
- **Estado:** ❌ DEPRECADO
- **Reemplazado por:** Documentación en `../docs/GUIA_RAPIDA.md`
- **Descripción:** Ejemplos de uso del sistema antiguo
- **Razón de deprecación:** Ejemplos actualizados en la documentación nueva

### 5. `query_config_test.json`
- **Estado:** ❌ DEPRECADO
- **Reemplazado por:** `../query_config_final.json`
- **Descripción:** Configuración de prueba temporal
- **Razón de deprecación:** Configuración de prueba ya no necesaria

---

## ✅ Scripts Actuales (A Usar)

### Script Principal
```r
# Usar este script para consultas de producción
source("scripts/final_query.R")
```

### Configuración Principal
```json
// Usar este archivo de configuración
scripts/query_config.json          # Configuración general
scripts/query_config_final.json    # Configuración optimizada
```

### Módulos del Sistema
```r
# Los módulos están en scripts/utils/
source("scripts/utils/query_functions.R")
source("scripts/utils/data_utils.R")
source("scripts/utils/spatial_utils.R")

# O cargar todo con:
source("scripts/database_queries.R")
```

---

## 🔄 Migración desde Scripts Antiguos

Si estabas usando alguno de estos scripts deprecados, aquí está cómo migrar:

### Migrar desde `run_query.R`
**Antes:**
```r
source("scripts/run_query.R")
# código antiguo
```

**Ahora:**
```r
source("scripts/final_query.R")
# o mejor aún:
source("scripts/database_queries.R")
results <- execute_biodiversity_queries(
  config_file = "scripts/query_config.json"
)
```

### Migrar desde `example_usage.R`
**Antes:**
```r
source("scripts/example_usage.R")
```

**Ahora:**
```r
# Ver ejemplos en la documentación:
# docs/GUIA_RAPIDA.md
# docs/ARQUITECTURA_SISTEMA.md

# Ejemplo básico:
source("scripts/database_queries.R")
show_help()  # Ver ayuda integrada
```

---

## 📚 Documentación Nueva

La documentación completa del nuevo sistema está en:

- **`docs/REFACTORIZACION_SUMMARY.md`** - Resumen de cambios
- **`docs/ARQUITECTURA_SISTEMA.md`** - Arquitectura modular
- **`docs/GUIA_RAPIDA.md`** - Guía de referencia rápida
- **`docs/EJECUCION_EXITOSA.md`** - Reporte de ejecución

---

## ⚠️ Importante

**NO USAR** estos scripts para nuevos desarrollos. Están aquí solo por:

1. **Referencia histórica**
2. **Compatibilidad temporal** (si alguien todavía los está usando)
3. **Auditoría de código**

Se recomienda migrar completamente al nuevo sistema antes de **2025-12-01**.

---

## 🗑️ Programado para Eliminación

Estos scripts serán **eliminados permanentemente** en:

- **Fecha:** 2026-01-01
- **Advertencia:** Después de esta fecha, no habrá forma de recuperarlos del repositorio

Si necesitas mantener alguno de estos scripts, haz una copia de respaldo antes de esa fecha.

---

## 📞 Soporte

Si tienes problemas migrando desde alguno de estos scripts:

1. Consulta la **Guía Rápida**: `docs/GUIA_RAPIDA.md`
2. Revisa los **Ejemplos**: En la documentación
3. Ejecuta la **Ayuda integrada**: `show_help()` en R

---

**Última actualización:** 2025-10-17  
**Responsable:** Sistema de Consultas de Biodiversidad - Versión Refactorizada
