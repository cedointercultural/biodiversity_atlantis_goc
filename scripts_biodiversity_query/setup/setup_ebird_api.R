#!/usr/bin/env Rscript
#' setup_ebird_api.R
#' Script para configurar la API key de eBird
#' Author: Asistente AI
#' Date: August 2025

cat("🔑 CONFIGURACIÓN DE API KEY DE EBIRD\n")
cat("====================================\n\n")

# Verificar si ya existe una clave
current_key <- Sys.getenv("EBIRD_KEY")
if (current_key != "" && current_key != "tu_clave_api_aqui") {
  cat("✅ Ya tienes una API key configurada:\n")
  cat("   Key:", substr(current_key, 1, 8), "...", substr(current_key, nchar(current_key)-3, nchar(current_key)), "\n")
  cat("\n¿Quieres cambiarla? (y/N): ")
  response <- readLines(con = "stdin", n = 1)
  if (tolower(substr(response, 1, 1)) != "y") {
    cat("✅ Conservando la API key actual\n")
    quit(save = "no")
  }
}

cat("📋 PASOS PARA OBTENER TU API KEY DE EBIRD:\n")
cat("1. Ve a: https://ebird.org/api/keygen\n")
cat("2. Inicia sesión con tu cuenta de eBird (o crea una cuenta)\n")
cat("3. Solicita una API key (es gratis)\n")
cat("4. Copia la clave que te proporcionen\n\n")

cat("🔑 Ingresa tu API key de eBird: ")
api_key <- readLines(con = "stdin", n = 1)

# Validar que no esté vacía
if (is.null(api_key) || nchar(trimws(api_key)) == 0) {
  cat("❌ Error: No ingresaste ninguna API key\n")
  quit(save = "no", status = 1)
}

# Validar formato básico (eBird keys suelen tener cierta longitud)
api_key <- trimws(api_key)
if (nchar(api_key) < 10) {
  cat("⚠️  Advertencia: La API key parece muy corta. ¿Estás seguro de que es correcta?\n")
  cat("   API key ingresada:", api_key, "\n")
  cat("   ¿Continuar? (y/N): ")
  response <- readLines(con = "stdin", n = 1)
  if (tolower(substr(response, 1, 1)) != "y") {
    cat("❌ Configuración cancelada\n")
    quit(save = "no")
  }
}

# Crear o actualizar .Renviron
renviron_path <- file.path(Sys.getenv("HOME"), ".Renviron")

# Leer contenido existente si existe
existing_content <- character(0)
if (file.exists(renviron_path)) {
  existing_content <- readLines(renviron_path)
  # Remover líneas existentes de EBIRD_KEY
  existing_content <- existing_content[!grepl("^EBIRD_KEY=", existing_content)]
}

# Agregar la nueva API key
new_content <- c(
  existing_content,
  "",
  "# eBird API Key - Configurado automáticamente",
  paste0("EBIRD_KEY=", api_key)
)

# Escribir al archivo
tryCatch({
  writeLines(new_content, renviron_path)
  cat("✅ API key de eBird configurada exitosamente!\n")
  cat("📁 Archivo:", renviron_path, "\n")
  cat("\n📋 PRÓXIMOS PASOS:\n")
  cat("1. Reinicia R o RStudio para que tome efecto\n")
  cat("2. O ejecuta: readRenviron('~/.Renviron')\n")
  cat("3. Verifica con: Sys.getenv('EBIRD_KEY')\n")
  cat("\n🎉 ¡Ya puedes usar eBird en tu generador de polígonos!\n")
}, error = function(e) {
  cat("❌ Error escribiendo al archivo .Renviron:\n")
  cat("   ", e$message, "\n")
  cat("\n🛠️  CONFIGURACIÓN MANUAL:\n")
  cat("1. Abre el archivo:", renviron_path, "\n")
  cat("2. Agrega esta línea:\n")
  cat("   EBIRD_KEY=", api_key, "\n")
  cat("3. Guarda el archivo\n")
  quit(save = "no", status = 1)
})

# Opcional: recargar el entorno
tryCatch({
  readRenviron(renviron_path)
  test_key <- Sys.getenv("EBIRD_KEY")
  if (test_key == api_key) {
    cat("🔄 Entorno recargado exitosamente\n")
  }
}, error = function(e) {
  cat("⚠️  No se pudo recargar automáticamente. Reinicia R para que tome efecto.\n")
})
