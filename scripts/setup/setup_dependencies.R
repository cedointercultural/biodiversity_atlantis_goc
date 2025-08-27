# Script para verificar e instalar dependencias
# Ejecutar este script antes de usar extract_taxonomy_with_claude.R

cat("=== VERIFICACIÓN DE DEPENDENCIAS ===\n")
cat("Verificando librerías necesarias para el script de taxonomía...\n\n")

# Lista de librerías requeridas
required_packages <- c("dplyr", "readr", "stringr", "httr", "jsonlite", "tidyr")

# Función para verificar e instalar paquetes
check_and_install <- function(packages) {
  new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
  
  if(length(new_packages) > 0) {
    cat("Instalando paquetes faltantes:", paste(new_packages, collapse = ", "), "\n")
    install.packages(new_packages, dependencies = TRUE)
  } else {
    cat("✓ Todas las librerías requeridas están instaladas\n")
  }
}

# Verificar instalación
check_and_install(required_packages)

# Verificar que se pueden cargar
cat("\nVerificando que las librerías se pueden cargar...\n")
success <- TRUE

for(pkg in required_packages) {
  result <- tryCatch({
    library(pkg, character.only = TRUE)
    cat("✓", pkg, "cargado exitosamente\n")
    TRUE
  }, error = function(e) {
    cat("✗", pkg, "falló al cargar:", e$message, "\n")
    FALSE
  })
  
  if(!result) success <- FALSE
}

if(success) {
  cat("\n🎉 ¡Todas las dependencias están listas!\n")
  cat("Puedes proceder a ejecutar extract_taxonomy_with_claude.R\n")
} else {
  cat("\n⚠️  Hay problemas con algunas dependencias.\n")
  cat("Por favor, revisa los errores arriba e instala manualmente las librerías faltantes.\n")
}

# Información adicional
cat("\n=== INFORMACIÓN ADICIONAL ===\n")
cat("Versión de R:", R.version.string, "\n")
cat("Plataforma:", R.version$platform, "\n")
cat("Directorio de trabajo actual:", getwd(), "\n")

# Verificar archivo de entrada
input_file <- "tablas_taxon/Tablas taxon 050825/Tablas/Tabla2_SP_Adrian.csv"
if(file.exists(input_file)) {
  cat("✓ Archivo de entrada encontrado:", input_file, "\n")
} else {
  cat("⚠️  Archivo de entrada no encontrado en:", input_file, "\n")
  cat("   Verifica la ruta del archivo en el script principal\n")
}
