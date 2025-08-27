# Script de ejemplo para ejecutar la extracción de taxonomía
# Este es un ejemplo simple de cómo usar el script principal

# Cargar el script principal
source("extract_taxonomy_with_claude.R")

# Configuración
cat("=== CONFIGURACIÓN INICIAL ===\n")

# El script ahora lee automáticamente la API key desde:
# C:/Users/ricar/OneDrive/Documentos/Proyectos/miscredenciales/anthropic-apikey

# Ejecutar con una muestra pequeña para probar (recomendado primero)
cat("Para ejecutar con muestra de 50 registros para prueba:\n")
cat("result_test <- run_taxonomy_extraction(sample_size = 50)\n\n")

# Ejecutar con todos los datos (puede tomar mucho tiempo y costar dinero)
cat("Para ejecutar con todos los datos:\n")
cat("result_full <- run_taxonomy_extraction()\n\n")

# Si necesitas usar una API key diferente:
cat("Para usar una API key específica:\n")
cat("result <- run_taxonomy_extraction(api_key = 'tu_clave_aqui')\n\n")

cat("Para ejecutar este script:\n")
cat("1. Asegúrate de que tu API key esté en el archivo de credenciales\n")
cat("2. Descomenta y ejecuta las líneas apropiadas abajo\n")
cat("3. Revisa el archivo de salida generado\n\n")

# Descomenta las siguientes líneas para ejecutar:

# Ejecutar con muestra pequeña para pruebas
# result_test <- run_taxonomy_extraction(sample_size = 50)

# Ejecutar con todos los datos
# result_full <- run_taxonomy_extraction()
