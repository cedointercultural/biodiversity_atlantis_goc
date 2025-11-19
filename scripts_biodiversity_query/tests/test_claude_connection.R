# Script para probar la conexión con la API de Claude
# Ejecutar este script antes de procesar el dataset completo

# Cargar el script principal
source("extract_taxonomy_with_claude.R")

# Función para probar la API con una taxonomía de ejemplo
test_claude_api <- function() {
  cat("=== PRUEBA DE CONEXIÓN CON API DE CLAUDE ===\n")
  
  # Intentar cargar la API key
  api_key <- read_api_key()
  
  if (is.null(api_key)) {
    cat("❌ No se pudo cargar la API key. Verifica el archivo:\n")
    cat("   C:/Users/ricar/OneDrive/Documentos/Proyectos/miscredenciales/anthropic-apikey\n")
    return(FALSE)
  }
  
  # Taxonomía de ejemplo para probar
  test_taxonomy <- "NCBI;cellular organisms;Eukaryota;Opisthokonta;Metazoa;Eumetazoa;Bilateria;Protostomia;Spiralia;Lophotrochozoa;Mollusca;Bivalvia;Autobranchia;Heteroconchia;Euheterodonta;Imparidentia;Neoheterodontei;Venerida;Veneroidea;"
  
  cat("Probando con taxonomía de ejemplo...\n")
  cat("Taxonomía:", substr(test_taxonomy, 1, 80), "...\n\n")
  
  # Llamar a la API
  result <- call_claude_api(test_taxonomy, api_key)
  
  if (!is.null(result)) {
    cat("✅ ¡Conexión exitosa con la API de Claude!\n\n")
    cat("Resultado de ejemplo:\n")
    cat("Kingdom:", ifelse(is.null(result$kingdom), "NA", result$kingdom), "\n")
    cat("Phylum:", ifelse(is.null(result$phylum), "NA", result$phylum), "\n")
    cat("Class:", ifelse(is.null(result$class), "NA", result$class), "\n")
    cat("Order:", ifelse(is.null(result$order), "NA", result$order), "\n")
    cat("Family:", ifelse(is.null(result$family), "NA", result$family), "\n")
    cat("Genus:", ifelse(is.null(result$genus), "NA", result$genus), "\n")
    cat("Species:", ifelse(is.null(result$species), "NA", result$species), "\n\n")
    
    cat("🎉 La API está funcionando correctamente.\n")
    cat("Puedes proceder a ejecutar el script principal.\n")
    return(TRUE)
  } else {
    cat("❌ Error al conectar con la API de Claude.\n")
    cat("Verifica:\n")
    cat("1. Que tu API key sea válida\n")
    cat("2. Que tengas créditos disponibles en tu cuenta de Anthropic\n")
    cat("3. Tu conexión a internet\n")
    return(FALSE)
  }
}

# Función para verificar el archivo de API key
check_api_key_file <- function() {
  api_key_file <- "C:/Users/ricar/OneDrive/Documentos/Proyectos/miscredenciales/anthropic-apikey"
  
  cat("=== VERIFICACIÓN DEL ARCHIVO DE API KEY ===\n")
  cat("Ruta esperada:", api_key_file, "\n")
  
  if (file.exists(api_key_file)) {
    cat("✅ El archivo existe\n")
    
    # Leer y verificar contenido
    content <- readLines(api_key_file, n = 1, warn = FALSE)
    content <- str_trim(content)
    
    if (str_length(content) > 0) {
      cat("✅ El archivo contiene datos\n")
      cat("Longitud de la clave:", str_length(content), "caracteres\n")
      
      # Verificar formato básico de API key de Anthropic
      if (str_detect(content, "^sk-ant-")) {
        cat("✅ El formato de la API key parece correcto\n")
        return(TRUE)
      } else {
        cat("⚠️  La API key no tiene el formato esperado (debería empezar con 'sk-ant-')\n")
        return(FALSE)
      }
    } else {
      cat("❌ El archivo está vacío\n")
      return(FALSE)
    }
  } else {
    cat("❌ El archivo no existe\n")
    cat("Crea el archivo y guarda tu API key de Claude en él\n")
    return(FALSE)
  }
}

# Ejecutar verificaciones
cat("Iniciando verificaciones...\n\n")

# Verificar archivo de API key
key_ok <- check_api_key_file()

if (key_ok) {
  cat("\n")
  # Probar conexión con API
  api_ok <- test_claude_api()
  
  if (api_ok) {
    cat("\n=== SIGUIENTE PASO ===\n")
    cat("Todo está listo. Para procesar tus datos:\n")
    cat("1. Para una prueba pequeña: run_taxonomy_extraction(sample_size = 50)\n")
    cat("2. Para el dataset completo: run_taxonomy_extraction()\n")
  }
} else {
  cat("\n=== ACCIÓN REQUERIDA ===\n")
  cat("Primero debes crear/corregir el archivo de API key.\n")
}
