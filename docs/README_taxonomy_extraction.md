# Extracción de Taxonomía con API de Claude

Este script lee la tabla `Tabla2_SP_Adrian.csv` y utiliza la API de Claude (Anthropic) para extraer y organizar los niveles taxonómicos de la columna "NCBI Taxonomy".

## Archivos incluidos

- `extract_taxonomy_with_claude.R`: Script principal con todas las funciones
- `run_taxonomy_extraction.R`: Script de ejemplo para ejecutar el proceso
- `README_taxonomy_extraction.md`: Este archivo con instrucciones

## Requisitos previos

### 1. Librerías de R necesarias
```r
install.packages(c("dplyr", "readr", "stringr", "httr", "jsonlite", "tidyr"))
```

### 2. Clave API de Claude

- Crear cuenta en [Anthropic Console](https://console.anthropic.com/)
- Generar una clave API
- **Guardar la API key en**: `C:/Users/ricar/OneDrive/Documentos/Proyectos/miscredenciales/anthropic-apikey`
- **Importante**: La API de Claude tiene costos asociados

## Funcionamiento del script

El script realiza las siguientes operaciones:

1. **Lectura de datos**: Carga el archivo `Tabla2_SP_Adrian.csv`
2. **Extracción de taxonomías únicas**: Identifica todas las cadenas taxonómicas únicas para optimizar las llamadas a la API
3. **Procesamiento con Claude**: Para cada taxonomía única, envía una petición a Claude para extraer:
   - Kingdom (Reino)
   - Phylum (Filo) 
   - Class (Clase)
   - Order (Orden)
   - Family (Familia)
   - Genus (Género)
   - Species (Especie)
4. **Generación de resultado**: Crea un nuevo archivo CSV con las columnas taxonómicas añadidas

## Estructura del archivo de salida

El archivo resultante tendrá la siguiente estructura:
```
NCBI Taxonomy | kingdom | phylum | class | order | family | genus | species | [columnas originales...]
```

## Cómo usar

### Opción 1: Verificar conexión primero (recomendado)

```r
# Verificar que todo esté configurado correctamente
source("test_claude_connection.R")
```

### Opción 2: Usar el script de ejemplo

```r
# 1. Cargar el script
source("run_taxonomy_extraction.R")

# 2. Descomentar y ejecutar las líneas apropiadas en el archivo
```

### Opción 3: Usar directamente las funciones

```r
# Cargar el script principal
source("extract_taxonomy_with_claude.R")

# Ejecutar con muestra pequeña (recomendado para pruebas)
result_test <- run_taxonomy_extraction(sample_size = 100)

# Ejecutar con todos los datos
result_full <- run_taxonomy_extraction()

# Usar una API key específica si es necesario
result <- run_taxonomy_extraction(api_key = "tu_clave_api_aqui")
```

## Consideraciones importantes

### Costos
- Cada llamada a la API de Claude tiene un costo
- Con ~15,851 filas y taxonomías únicas, el costo puede ser significativo
- **Recomendación**: Probar primero con `sample_size = 50` o `sample_size = 100`

### Tiempo de ejecución
- El script incluye pausas entre llamadas para respetar límites de tasa
- Para ~1000 taxonomías únicas puede tomar 30-60 minutos
- Para el dataset completo puede tomar varias horas

### Manejo de errores
- El script maneja errores de API automáticamente
- Si una taxonomía falla, se marca como NA en lugar de detener el proceso
- Se genera un reporte de completitud al final

## Archivos de salida

- `Tabla2_SP_Adrian_with_taxonomy.csv`: Archivo principal con taxonomía extraída
- Reporte en consola con estadísticas de completitud

## Ejemplo de taxonomía procesada

**Entrada:**
```
NCBI;cellular organisms;Eukaryota;Opisthokonta;Metazoa;Eumetazoa;Bilateria;Protostomia;Spiralia;Lophotrochozoa;Mollusca;Bivalvia;Autobranchia;Heteroconchia;Euheterodonta;Imparidentia;Neoheterodontei;Venerida;Veneroidea;
```

**Salida esperada:**
- kingdom: Metazoa
- phylum: Mollusca  
- class: Bivalvia
- order: Venerida
- family: Veneroidea (si se puede determinar)
- genus: (vacío si no está presente)
- species: (vacío si no está presente)

## Solución de problemas

### Error de API Key
```
Error: Debes proporcionar una clave API válida de Claude
```
**Solución**: Verificar que la clave API es correcta y está activa

### Error de archivo no encontrado
```
Error: No se encontró el archivo de entrada
```
**Solución**: Verificar que `Tabla2_SP_Adrian.csv` existe en la ruta especificada

### Errores de conexión
**Solución**: Verificar conexión a internet y que la API de Claude esté funcionando

## Personalización

Para modificar los niveles taxonómicos extraídos, editar la función `call_claude_api()` y ajustar:
- El prompt enviado a Claude
- La estructura JSON esperada
- Las columnas creadas en el resultado final

## Contacto

Para dudas sobre este script, consultar la documentación de R o la API de Claude de Anthropic.
