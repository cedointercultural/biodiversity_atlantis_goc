#' =============================================================================
#' SCRIPT MANAGER - EJECUTOR DE SCRIPTS DE BIODIVERSIDAD
#' =============================================================================
#' Consolidación de run_all_scripts.R y run_scripts_simple.R
#' Permite ejecutar scripts individuales o flujos completos
#' Autor: Ricardo Cavieses-Nuñez
#' Fecha: Octubre 2025
#' =============================================================================

# Limpiar workspace
rm(list=ls())

# Configurar CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

#' =============================================================================
#' FUNCIONES AUXILIARES
#' =============================================================================

#' Ejecutar script con manejo de errores avanzado
execute_script <- function(script_path, description, verbose = TRUE) {
  if (verbose) {
    cat("\n", rep("=", 60), "\n")
    cat("EJECUTANDO:", description, "\n")
    cat("Archivo:", script_path, "\n")
    cat(rep("=", 60), "\n")
  }
  
  if (!file.exists(script_path)) {
    cat("❌ ERROR: Archivo no encontrado:", script_path, "\n")
    return(FALSE)
  }
  
  tryCatch({
    # Guardar directorio actual
    original_dir <- getwd()
    
    # Ejecutar script
    source(script_path, echo = FALSE)
    
    # Restaurar directorio
    setwd(original_dir)
    
    if (verbose) cat("✅ COMPLETADO:", basename(script_path), "\n")
    return(TRUE)
    
  }, error = function(e) {
    cat("❌ ERROR en", basename(script_path), ":", e$message, "\n")
    return(FALSE)
  })
}

#' Ejecutar script simple (versión rápida)
run_script_simple <- function(script_name, description) {
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
    cat("❌ ARCHIVO NO ENCONTRADO:", script_name, "\n")
    return(FALSE)
  }
}

#' =============================================================================
#' DEFINICIÓN DE SCRIPTS DISPONIBLES
#' =============================================================================

# Scripts principales de biodiversidad
main_scripts <- list(
  list(
    path = "scripts/database_queries.R",
    name = "Consultas Base de Datos",
    description = "Script núcleo para consultas de biodiversidad"
  ),
  list(
    path = "scripts/biodiversity_query.R", 
    name = "Consulta Unificada",
    description = "Script unificado con todos los modos (básico, máximo, paralelo)"
  )
)

# Herramientas auxiliares
tool_scripts <- list(
  list(
    path = "scripts/tools/test_polygon_simplification.R",
    name = "Test Simplificación Polígonos",
    description = "Análisis y optimización de polígonos complejos"
  ),
  list(
    path = "scripts/tools/setup_dependencies.R",
    name = "Configuración Dependencias", 
    description = "Instalación y configuración de paquetes"
  )
)

#' =============================================================================
#' FUNCIONES DE EJECUCIÓN
#' =============================================================================

#' Ejecutar script individual por nombre
run_single_script <- function(script_name, mode = "advanced") {
  cat("🚀 EJECUTANDO SCRIPT INDIVIDUAL\n")
  cat("Script:", script_name, "\n")
  cat("Modo:", mode, "\n")
  cat("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  # Buscar en scripts principales
  for (script in main_scripts) {
    if (basename(script$path) == script_name || script$path == script_name) {
      if (mode == "simple") {
        return(run_script_simple(script$path, script$description))
      } else {
        return(execute_script(script$path, script$description))
      }
    }
  }
  
  # Buscar en herramientas
  for (script in tool_scripts) {
    if (basename(script$path) == script_name || script$path == script_name) {
      if (mode == "simple") {
        return(run_script_simple(script$path, script$description))
      } else {
        return(execute_script(script$path, script$description))
      }
    }
  }
  
  cat("❌ Script no encontrado:", script_name, "\n")
  return(FALSE)
}

#' Ejecutar flujo completo de biodiversidad
run_biodiversity_flow <- function(mode = "advanced", skip_parallel = FALSE) {
  cat("🌟 EJECUTANDO FLUJO COMPLETO DE BIODIVERSIDAD\n")
  cat("Modo:", mode, "\n")
  cat("Directorio:", getwd(), "\n")
  cat("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  results <- list()
  
  # Ejecutar scripts en orden
  scripts_to_run <- main_scripts
  if (skip_parallel) {
    # Filtrar solo el script principal, no hay más scripts paralelos específicos
    scripts_to_run <- scripts_to_run[!grepl("parallel", sapply(scripts_to_run, function(x) x$name), ignore.case = TRUE)]
  }
  
  for (i in seq_along(scripts_to_run)) {
    script <- scripts_to_run[[i]]
    
    if (mode == "simple") {
      results[[script$name]] <- run_script_simple(script$path, script$description)
    } else {
      results[[script$name]] <- execute_script(script$path, script$description)
    }
    
    # Pausa entre scripts
    if (i < length(scripts_to_run)) {
      Sys.sleep(2)
    }
  }
  
  # Resumen final
  cat("\n", rep("=", 70), "\n")
  cat("📊 RESUMEN DE EJECUCIÓN\n")
  cat(rep("=", 70), "\n")
  
  success_count <- sum(unlist(results))
  total_count <- length(results)
  
  for (name in names(results)) {
    status <- if (results[[name]]) "✅ ÉXITO" else "❌ FALLO"
    cat(sprintf("%-30s: %s\n", name, status))
  }
  
  cat(rep("-", 70), "\n")
  cat(sprintf("Total ejecutados: %d/%d (%.1f%% éxito)\n", 
              success_count, total_count, 
              (success_count/total_count)*100))
  cat(rep("=", 70), "\n")
  
  return(results)
}

#' Mostrar scripts disponibles
show_available_scripts <- function() {
  cat("📋 SCRIPTS DISPONIBLES\n")
  cat(rep("=", 50), "\n")
  
  cat("\n🎯 SCRIPTS PRINCIPALES:\n")
  for (i in seq_along(main_scripts)) {
    script <- main_scripts[[i]]
    cat(sprintf("%d. %s\n", i, script$name))
    cat(sprintf("   Archivo: %s\n", script$path))
    cat(sprintf("   Descripción: %s\n\n", script$description))
  }
  
  cat("🔧 HERRAMIENTAS:\n")
  for (i in seq_along(tool_scripts)) {
    script <- tool_scripts[[i]]
    cat(sprintf("%d. %s\n", i, script$name))
    cat(sprintf("   Archivo: %s\n", script$path))
    cat(sprintf("   Descripción: %s\n\n", script$description))
  }
}

#' =============================================================================
#' EJECUCIÓN INTERACTIVA (SI SE EJECUTA DIRECTAMENTE)
#' =============================================================================

if (interactive() || !exists(".__run_manager_loaded__.")) {
  cat("🎮 SCRIPT MANAGER - SISTEMA DE BIODIVERSIDAD\n")
  cat("===============================================\n")
  
  # Mostrar opciones
  cat("\nOpciones disponibles:\n")
  cat("1. run_single_script('nombre_script.R') - Ejecutar script individual\n")
  cat("2. run_biodiversity_flow() - Ejecutar flujo completo\n")  
  cat("3. show_available_scripts() - Mostrar scripts disponibles\n")
  cat("\nEjemplos:\n")
  cat("• run_single_script('biodiversity_query.R')\n")
  cat("• run_biodiversity_flow(mode = 'simple')\n")
  cat("• run_biodiversity_flow(skip_parallel = TRUE)\n\n")
  
  # Mostrar scripts disponibles
  show_available_scripts()
  
  # Marcar como cargado
  .__run_manager_loaded__. <- TRUE
}

#' =============================================================================
#' FUNCIONES DE COMPATIBILIDAD (LEGACY)
#' =============================================================================

# Compatibilidad con run_all_scripts.R
run_all_scripts <- function() {
  cat("⚠️  FUNCIÓN LEGACY: Usando run_biodiversity_flow()\n")
  return(run_biodiversity_flow(mode = "advanced"))
}

# Compatibilidad con run_scripts_simple.R  
run_scripts_simple <- function() {
  cat("⚠️  FUNCIÓN LEGACY: Usando run_biodiversity_flow(mode = 'simple')\n")
  return(run_biodiversity_flow(mode = "simple"))
}