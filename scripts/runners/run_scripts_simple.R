#' Script simple para ejecutar scripts en orden - Versión directa
#' Excluyendo scripts de CONABIO
#' Ricardo Cavieses-Nuñez - Agosto 2025

# Limpiar workspace
rm(list=ls())

# Configurar directorio y CRAN
setwd("c:/Users/ricar/OneDrive/Documentos/Proyectos/Atlantis")
options(repos = c(CRAN = "https://cran.rstudio.com/"))

cat("🌟 EJECUTANDO SCRIPTS DE BIODIVERSIDAD EN ORDEN\n")
cat("Directorio:", getwd(), "\n")
cat("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Función simple para ejecutar scripts
run_script <- function(script_name, description) {
  cat("\n", rep("=", 50), "\n")
  cat("EJECUTANDO:", description, "\n")
  cat("Script:", script_name, "\n")
  cat(rep("=", 50), "\n")
  
  if (file.exists(script_name)) {
    tryCatch({
      source(script_name, echo = FALSE)
      cat("✅ COMPLETADO:", script_name, "\n")
      return(TRUE)
    }, error = function(e) {
      cat("❌ ERROR en", script_name, ":", e$message, "\n")
      return(FALSE)
    })
  } else {
    cat("⚠️ SALTADO:", script_name, "(no encontrado)\n")
    return(FALSE)
  }
}

# PASO 1: Configuración de CRAN
cat("🔄 PASO 1: Configuración inicial\n")
step1 <- run_script("setup_cran.R", "Configuración de CRAN y paquetes")

# PASO 2: Validación de sintaxis (opcional)
cat("\n🔄 PASO 2: Validación de sintaxis\n")
step2 <- run_script("check_syntax.R", "Validación de sintaxis")

# PASO 3: Registros de ocurrencia
cat("\n🔄 PASO 3: Registros de ocurrencia\n")
step3 <- run_script("ocurrence_records_updated.R", "Descarga de registros de ocurrencia")

# PASO 4: Análisis de datos de biodiversidad
cat("\n🔄 PASO 4: Análisis de biodiversidad\n")
step4 <- run_script("Data_biodiversity_updated.R", "Análisis de datos de biodiversidad")

# PASO 5: Organización de datos
cat("\n🔄 PASO 5: Organización de datos\n")
step5 <- run_script("Organize_biodiversity_updated.R", "Organización de datos de biodiversidad")

# PASO 6: Análisis de polígonos y buffers
cat("\n🔄 PASO 6: Análisis espacial\n")
step6 <- run_script("Buffer_polygon_updated.R", "Análisis de polígonos y buffers")

# PASO 7: Funciones de conversión shapefile a raster
cat("\n🔄 PASO 7: Funciones espaciales\n")
step7 <- run_script("shp2raster_function_updated.R", "Funciones de conversión espacial")

# PASO 8: Cálculo de modelos de riqueza
cat("\n🔄 PASO 8: Modelos de riqueza\n")
step8 <- run_script("Calculate_richness_model_Corridor_updated.R", "Modelos de riqueza de especies")

# RESUMEN FINAL
cat("\n", rep("=", 60), "\n")
cat("🎯 RESUMEN FINAL DE EJECUCIÓN\n")
cat(rep("=", 60), "\n")

results <- c(step1, step2, step3, step4, step5, step6, step7, step8)
script_names <- c(
  "setup_cran.R",
  "check_syntax.R", 
  "ocurrence_records_updated.R",
  "Data_biodiversity_updated.R",
  "Organize_biodiversity_updated.R",
  "Buffer_polygon_updated.R",
  "shp2raster_function_updated.R",
  "Calculate_richness_model_Corridor_updated.R"
)

for (i in seq_along(results)) {
  status <- if (results[i]) "✅ EXITOSO" else "❌ FALLÓ/SALTADO"
  cat(sprintf("%-40s: %s\n", script_names[i], status))
}

successful <- sum(results)
total <- length(results)
cat("\n📊 ESTADÍSTICAS:\n")
cat("- Scripts exitosos:", successful, "de", total, "\n")
cat("- Porcentaje de éxito:", round(successful/total*100, 1), "%\n")

# Verificar archivos generados
cat("\n📁 ARCHIVOS PRINCIPALES GENERADOS:\n")
main_files <- c("goc_biodiversity.csv", "extracted_biodiversity_data.csv")
for (file in main_files) {
  if (file.exists(file)) {
    size_mb <- round(file.size(file) / 1024 / 1024, 2)
    cat("  📄", file, "(", size_mb, "MB)\n")
  }
}

cat("\n⏰ Finalizado:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("✨ Scripts de biodiversidad completados (excluyendo CONABIO)\n")
