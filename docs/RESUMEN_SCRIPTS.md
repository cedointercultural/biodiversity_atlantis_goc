# Resumen de Scripts de Extracción de Taxonomía

## 📁 Archivos disponibles

### Scripts principales
1. **`extract_taxonomy_with_claude.R`** - Script principal con todas las funciones
2. **`run_taxonomy_extraction.R`** - Script de ejemplo para ejecutar el proceso  
3. **`test_claude_connection.R`** - Script para verificar la conexión con la API
4. **`setup_dependencies.R`** - Verificación e instalación de dependencias

### Documentación
5. **`README_taxonomy_extraction.md`** - Documentación completa
6. **`RESUMEN_SCRIPTS.md`** - Este archivo

## 🔧 Configuración automática de API Key

El sistema ahora lee automáticamente tu API key desde:
```
C:/Users/ricar/OneDrive/Documentos/Proyectos/miscredenciales/anthropic-apikey
```

**Importante**: Asegúrate de que este archivo contenga solo tu API key de Claude, sin espacios adicionales.

## 🚀 Flujo de trabajo recomendado

### Paso 1: Verificar dependencias
```r
source("setup_dependencies.R")
```

### Paso 2: Probar conexión con API
```r
source("test_claude_connection.R")
```

### Paso 3: Ejecutar con muestra pequeña
```r
source("extract_taxonomy_with_claude.R")
result_test <- run_taxonomy_extraction(sample_size = 50)
```

### Paso 4: Ejecutar con dataset completo (opcional)
```r
result_full <- run_taxonomy_extraction()
```

## 📊 Qué hace el script

1. **Lee** `Tabla2_SP_Adrian.csv`
2. **Extrae** taxonomías únicas de la columna "NCBI Taxonomy"
3. **Procesa** cada taxonomía con Claude para identificar niveles taxonómicos:
   - Kingdom (Reino)
   - Phylum (Filo)
   - Class (Clase)
   - Order (Orden)
   - Family (Familia)
   - Genus (Género)
   - Species (Especie)
4. **Crea** archivo `Tabla2_SP_Adrian_with_taxonomy.csv` con las nuevas columnas
5. **Genera** reporte de completitud

## ⚠️ Consideraciones importantes

- **Costos**: Cada llamada a Claude cuesta dinero
- **Tiempo**: Para ~15,851 filas puede tomar varias horas
- **Pruebas**: Siempre probar primero con `sample_size` pequeño
- **Límites**: El script respeta automáticamente los límites de tasa de la API

## 🆘 Solución de problemas rápida

### Error de API Key
1. Verificar que el archivo existe: `C:/Users/ricar/OneDrive/Documentos/Proyectos/miscredenciales/anthropic-apikey`
2. Verificar que contiene tu API key válida
3. Ejecutar `test_claude_connection.R` para verificar

### Error de archivo no encontrado
- Verificar que `Tabla2_SP_Adrian.csv` existe en la ruta correcta

### Errores de conexión
- Verificar conexión a internet
- Verificar que tienes créditos en tu cuenta de Anthropic

## 📈 Próximos pasos

Después de ejecutar el script:

1. **Revisar** el archivo de salida generado
2. **Analizar** las estadísticas de completitud en el reporte
3. **Evaluar** si necesitas ajustar el prompt para Claude
4. **Usar** los datos taxonomizados para tu análisis

¡El sistema está listo para usar! 🎉
