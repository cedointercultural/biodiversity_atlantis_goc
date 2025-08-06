#' Script para ejecutar todo el flujo de biodiversidad en orden
#' Excluyendo scripts de CONABIO
#' Autor: Ricardo Cavieses-Nuñez
#' Fecha: Agosto 2025

# Limpiar workspace
rm(list=ls())

# Configurar CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Función para ejecutar script con manejo de errores
execute_script <- function(script_path, description) {
  cat("\n", rep("=", 60), "\n")
  cat("EJECUTANDO:", description, "\n")
  cat("Archivo:", script_path, "\n")
  cat(rep("=", 60), "\n")
  
  if (!file.exists(script_path)) {
    cat("❌ ERROR: Archivo no encontrado:", script_path, "\n")
    return(FALSE)
  }
  
  tryCatch({
    # Guardar directorio actual
    original_dir <- getwd()
    
    # Cambiar al directorio del proyecto si es necesario
    project_dir <- dirname(script_path)
    if (project_dir != "." && project_dir != getwd()) {
      setwd(project_dir)
      cat("📁 Cambiando a directorio:", project_dir, "\n")
    }
    
    # Ejecutar script
    source(script_path, echo = FALSE, print.eval = TRUE)
    
    # Restaurar directorio original
    setwd(original_dir)
    
    cat("✅ COMPLETADO:", description, "\n")
    return(TRUE)
  }, error = function(e) {
    cat("❌ ERROR en", description, ":", e$message, "\n")
    # Restaurar directorio original en caso de error
    setwd(original_dir)
    return(FALSE)
  })
}

# =============================================================================
# FLUJO PRINCIPAL DE EJECUCIÓN
# =============================================================================

cat("🌟 INICIANDO FLUJO COMPLETO DE ANÁLISIS DE BIODIVERSIDAD\n")
cat("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Directorio:", getwd(), "\n\n")

# Obtener directorio base del proyecto
base_dir <- getwd()

# Lista de scripts a ejecutar en orden (excluyendo CONABIO)
scripts_to_run <- list(
  list(
    file = file.path(base_dir, "setup_cran.R"),
    desc = "Configuración de CRAN y paquetes básicos"
  ),
  list(
    file = file.path(base_dir, "check_syntax.R"),
    desc = "Validación de sintaxis de scripts (opcional)"
  ),
  list(
    file = file.path(base_dir, "ocurrence_records_updated.R"),
    desc = "Descarga de registros de ocurrencia de especies"
  ),
  list(
    file = file.path(base_dir, "Data_biodiversity_updated.R"),
    desc = "Procesamiento y análisis de datos de biodiversidad"
  ),
  list(
    file = file.path(base_dir, "Organize_biodiversity_updated.R"),
    desc = "Organización final de datos de biodiversidad"
  ),
  list(
    file = file.path(base_dir, "Buffer_polygon_updated.R"),
    desc = "Análisis de polígonos y buffers"
  ),
  list(
    file = file.path(base_dir, "shp2raster_function_updated.R"),
    desc = "Funciones de conversión shapefile a raster"
  ),
  list(
    file = file.path(base_dir, "Calculate_richness_model_Corridor_updated.R"),
    desc = "Cálculo de modelos de riqueza de especies"
  )
)

# Crear directorios necesarios
dirs_to_create <- c("data", "data/occurrence", "data/ulloa", "shapefiles", "output", "results")
for (dir in dirs_to_create) {
  dir_path <- file.path(base_dir, dir)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    cat("📁 Directorio creado:", dir_path, "\n")
  }
}

# Ejecutar scripts en orden
results <- list()
for (i in seq_along(scripts_to_run)) {
  script_info <- scripts_to_run[[i]]
  script_name <- basename(script_info$file)
  
  cat("\n🔄 PASO", i, "de", length(scripts_to_run), "\n")
  
  # Verificar si el script existe antes de ejecutar
  if (file.exists(script_info$file)) {
    results[[script_name]] <- execute_script(script_info$file, script_info$desc)
  } else {
    cat("⚠️  SALTANDO:", script_info$desc, "(archivo no encontrado)\n")
    results[[script_name]] <- NA
  }
  
  # Pausa pequeña entre scripts
  Sys.sleep(1)
}

# =============================================================================
# RESUMEN FINAL
# =============================================================================

cat("\n", rep("=", 80), "\n")
cat("🎯 RESUMEN DE EJECUCIÓN COMPLETA\n")
cat(rep("=", 80), "\n")

total_success <- sum(results == TRUE, na.rm = TRUE)
total_attempted <- sum(!is.na(results))
total_skipped <- sum(is.na(results))

for (script_name in names(results)) {
  if (is.na(results[[script_name]])) {
    status <- "⏭️  SALTADO"
  } else if (results[[script_name]]) {
    status <- "✅ EXITOSO"
  } else {
    status <- "❌ FALLÓ"
  }
  cat(sprintf("%-45s: %s\n", script_name, status))
}

cat("\n")
cat("📊 ESTADÍSTICAS FINALES:\n")
cat("- Scripts ejecutados exitosamente:", total_success, "de", total_attempted, "intentados\n")
cat("- Scripts saltados (no encontrados):", total_skipped, "\n")
if (total_attempted > 0) {
  cat("- Porcentaje de éxito:", round(total_success/total_attempted*100, 1), "%\n")
}

if (total_success == total_attempted && total_attempted > 0) {
  cat("\n🎉 ¡FLUJO COMPLETO EJECUTADO EXITOSAMENTE!\n")
  cat("Todos los scripts disponibles han sido procesados correctamente.\n")
} else if (total_success > 0) {
  cat("\n⚠️  FLUJO COMPLETADO PARCIALMENTE\n")
  cat("Algunos scripts se ejecutaron exitosamente, revisa los errores arriba.\n")
} else {
  cat("\n❌ FLUJO FALLÓ\n")
  cat("Ningún script se ejecutó exitosamente.\n")
}

# Mostrar archivos generados
cat("\n📁 ARCHIVOS GENERADOS EN EL DIRECTORIO PRINCIPAL:\n")
output_patterns <- c(
  "goc_biodiversity.csv",
  "extracted_biodiversity_data*.csv",
  "biodiversity_analysis*.csv",
  "species_richness*.csv",
  "*.rds",
  "*_results.csv"
)

files_found <- FALSE
for (pattern in output_patterns) {
  files <- list.files(path = base_dir, pattern = glob2rx(pattern), full.names = FALSE)
  if (length(files) > 0) {
    for (file in files) {
      file_path <- file.path(base_dir, file)
      if (file.exists(file_path)) {
        size_mb <- round(file.size(file_path) / 1024 / 1024, 2)
        cat("  📄", file, "(", size_mb, "MB )\n")
        files_found <- TRUE
      }
    }
  }
}

if (!files_found) {
  cat("  (No se encontraron archivos de salida en el directorio principal)\n")
}

# Mostrar archivos en subdirectorios
subdirs_to_check <- c("data", "output", "results")
for (subdir in subdirs_to_check) {
  subdir_path <- file.path(base_dir, subdir)
  if (dir.exists(subdir_path)) {
    files <- list.files(subdir_path, pattern = "\\.(csv|rds|xlsx?)$", recursive = TRUE)
    if (length(files) > 0) {
      cat("\n📁 ARCHIVOS EN", toupper(subdir), ":\n")
      for (file in files[1:min(10, length(files))]) {  # Mostrar máximo 10 archivos
        file_path <- file.path(subdir_path, file)
        if (file.exists(file_path)) {
          size_mb <- round(file.size(file_path) / 1024 / 1024, 2)
          cat("  📄", file, "(", size_mb, "MB )\n")
        }
      }
      if (length(files) > 10) {
        cat("  ... y", length(files) - 10, "archivos más\n")
      }
    }
  }
}

cat("\n⏰ Tiempo de finalización:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat(rep("=", 80), "\n")

# Limpiar variables temporales
rm(list = setdiff(ls(), c("results", "base_dir")))

cat("\n💡 SIGUIENTE PASO: Revisa los archivos generados y cualquier mensaje de error.\n")
cat("💡 Los datos principales se encuentran en 'goc_biodiversity.csv'\n")
