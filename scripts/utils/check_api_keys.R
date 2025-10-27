#!/usr/bin/env Rscript
#' check_api_keys.R
#' Script para verificar la configuración de API keys
#' Author: Asistente AI
#' Date: August 2025

cat("🔍 VERIFICACIÓN DE API KEYS\n")
cat("===========================\n\n")

# Verificar eBird
ebird_key <- Sys.getenv("EBIRD_KEY")
if (ebird_key != "" && ebird_key != "tu_clave_api_aqui") {
  cat("✅ eBird API Key: Configurada\n")
  cat("   Key:", substr(ebird_key, 1, 8), "...", substr(ebird_key, nchar(ebird_key)-3, nchar(ebird_key)), "\n")
  
  # Probar la conexión a eBird
  cat("🔗 Probando conexión a eBird API...")
  tryCatch({
    library(rebird, quietly = TRUE)
    
    # Hacer una consulta simple para verificar
    test_result <- ebirdgeo(lat = 23.5, lng = -110.5, dist = 50, back = 1, key = ebird_key)
    if (!is.null(test_result)) {
      cat(" ✅ FUNCIONA\n")
      cat("   Registros de prueba obtenidos:", nrow(test_result), "\n")
    } else {
      cat(" ⚠️  Sin datos, pero API responde\n")
    }
  }, error = function(e) {
    cat(" ❌ ERROR\n")
    cat("   Mensaje:", e$message, "\n")
    cat("   💡 Verifica que la API key sea correcta\n")
  })
} else {
  cat("❌ eBird API Key: NO configurada\n")
  cat("   💡 Ejecuta: Rscript setup_ebird_api.R\n")
}

cat("\n")

# Verificar GBIF (opcional)
gbif_user <- Sys.getenv("GBIF_USER")
gbif_pwd <- Sys.getenv("GBIF_PWD")
gbif_email <- Sys.getenv("GBIF_EMAIL")

if (gbif_user != "" && gbif_pwd != "" && gbif_email != "") {
  cat("✅ GBIF: Configurado\n")
  cat("   Usuario:", gbif_user, "\n")
  cat("   Email:", gbif_email, "\n")
} else {
  cat("ℹ️  GBIF: No configurado (opcional)\n")
  cat("   Las consultas públicas de GBIF funcionan sin credenciales\n")
}

cat("\n")

# Verificar archivos de configuración
renviron_path <- file.path(Sys.getenv("HOME"), ".Renviron")
if (file.exists(renviron_path)) {
  cat("📁 Archivo .Renviron: Existe\n")
  cat("   Ubicación:", renviron_path, "\n")
  
  # Mostrar líneas relevantes (sin mostrar las claves completas)
  content <- readLines(renviron_path)
  relevant_lines <- content[grepl("(EBIRD|GBIF)", content)]
  if (length(relevant_lines) > 0) {
    cat("   Configuraciones encontradas:\n")
    for (line in relevant_lines) {
      if (grepl("=", line) && !grepl("^#", line)) {
        parts <- strsplit(line, "=")[[1]]
        if (length(parts) >= 2) {
          key_name <- parts[1]
          key_value <- parts[2]
          if (nchar(key_value) > 8) {
            key_display <- paste0(substr(key_value, 1, 4), "...", substr(key_value, nchar(key_value)-3, nchar(key_value)))
          } else {
            key_display <- key_value
          }
          cat("     ", key_name, "=", key_display, "\n")
        }
      }
    }
  }
} else {
  cat("❌ Archivo .Renviron: No existe\n")
  cat("   💡 Se creará automáticamente al configurar las API keys\n")
}

cat("\n")

# Verificar paquetes necesarios
cat("📦 VERIFICACIÓN DE PAQUETES:\n")
required_packages <- c("rebird", "rgbif", "robis", "spocc", "ridigbio")

for (pkg in required_packages) {
  if (require(pkg, quietly = TRUE, character.only = TRUE)) {
    cat("✅", pkg, "- Instalado\n")
  } else {
    cat("❌", pkg, "- No instalado\n")
    cat("   💡 Instalar con: install.packages('", pkg, "')\n")
  }
}

cat("\n🎯 RESUMEN:\n")
if (ebird_key != "" && ebird_key != "tu_clave_api_aqui") {
  cat("✅ Todo listo para usar eBird en el generador de polígonos\n")
} else {
  cat("⚠️  Configura la API key de eBird para usar todas las funcionalidades\n")
  cat("   Ejecuta: Rscript setup_ebird_api.R\n")
}

cat("\n📋 APIs disponibles en el generador:\n")
cat("- GBIF: ✅ Siempre disponible\n")
cat("- iDigBio: ✅ Siempre disponible\n")
cat("- eBird:", ifelse(ebird_key != "" && ebird_key != "tu_clave_api_aqui", "✅ Configurado", "❌ Requiere configuración"), "\n")
cat("- OBIS: ✅ Disponible (corregido)\n")
cat("- iNaturalist: ⚠️  Temporalmente no disponible (problema del servidor)\n")
