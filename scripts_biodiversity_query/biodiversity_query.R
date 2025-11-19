# ============================================================================
# Script: biodiversity_query.R
# Descripción: Script unificado para consultas de biodiversidad
# Combina funcionalidades de final_query.R, maxima_query.R y maxima_query_parallel.R
# Fecha: 2025-10-22
# ============================================================================

# Establecer directorio de trabajo
setwd("/home/atlantis/biodiversity_atlantis_goc")

#' =============================================================================
#' CONFIGURACIÓN INICIAL
#' =============================================================================

# Función para mostrar ayuda
show_help <- function() {
  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════════╗\n")
  cat("║                                                                   ║\n")
  cat("║              SISTEMA UNIFICADO DE CONSULTAS DE BIODIVERSIDAD     ║\n")
  cat("║                                                                   ║\n")
  cat("╚═══════════════════════════════════════════════════════════════════╝\n\n")
  
  cat("📋 MODOS DE OPERACIÓN DISPONIBLES:\n\n")
  
  cat("🔸 MODO BÁSICO (basic):\n")
  cat("   • Configuración: query_config_final.json\n")
  cat("   • Período: 2015-2025 (10 años)\n")
  cat("   • Registros por celda: 500\n")
  cat("   • Bases de datos: GBIF, OBIS\n")
  cat("   • Tiempo estimado: 5-10 minutos\n")
  cat("   • Uso recomendado: Pruebas iniciales, datasets pequeños\n\n")
  
  cat("🔹 MODO MÁXIMO SECUENCIAL (maxima):\n")
  cat("   • Configuración: query_config_maxima.json\n") 
  cat("   • Período: 2000-2025 (25 años)\n")
  cat("   • Registros por celda: 5,000\n")
  cat("   • Bases de datos: GBIF, OBIS, iDigBio\n")
  cat("   • Procesamiento: Secuencial (un núcleo)\n")
  cat("   • Tiempo estimado: 30-45 minutos\n")
  cat("   • Uso recomendado: Datasets medianos, recursos limitados\n\n")
  
  cat("🚀 MODO MÁXIMO PARALELO (parallel) [RECOMENDADO]:\n")
  cat("   • Configuración: query_config_maxima.json\n")
  cat("   • Período: 2000-2025 (25 años)\n")
  cat("   • Registros por celda: 5,000\n")
  cat("   • Bases de datos: GBIF, OBIS, iDigBio\n")
  cat("   • Procesamiento: Paralelo (múltiples núcleos)\n")
  cat("   • Tiempo estimado: 15-20 minutos\n")
  cat("   • Uso recomendado: Datasets grandes, máximo rendimiento\n\n")
  
  cat("💡 EJEMPLOS DE USO:\n")
  cat("   source('scripts/biodiversity_query.R')\n")
  cat("   run_biodiversity_query('basic')      # Consulta básica\n")
  cat("   run_biodiversity_query('maxima')     # Consulta exhaustiva secuencial\n")
  cat("   run_biodiversity_query('parallel')   # Consulta exhaustiva paralela\n")
  cat("   run_biodiversity_query()             # Modo interactivo\n\n")
}

#' Función principal unificada
run_biodiversity_query <- function(mode = NULL) {
  
  # Si no se especifica modo, mostrar opciones
  if (is.null(mode)) {
    show_help()
    cat("🎮 SELECCIONA UN MODO:\n")
    cat("1. basic    - Consulta básica (rápida)\n")
    cat("2. maxima   - Consulta exhaustiva secuencial\n")
    cat("3. parallel - Consulta exhaustiva paralela (recomendado)\n")
    cat("4. help     - Mostrar ayuda detallada\n\n")
    
    if (interactive()) {
      mode <- readline("Ingresa el modo (basic/maxima/parallel) o 'help': ")
      if (mode == "help" || mode == "4") {
        show_help()
        return(invisible(NULL))
      }
    } else {
      cat("ℹ️  Ejecutando en modo no interactivo. Usa: run_biodiversity_query('modo')\n")
      return(invisible(NULL))
    }
  }
  
  # Validar modo
  valid_modes <- c("basic", "maxima", "parallel")
  if (!mode %in% valid_modes) {
    cat("❌ Error: Modo inválido '", mode, "'\n")
    cat("   Modos válidos: ", paste(valid_modes, collapse = ", "), "\n")
    return(invisible(NULL))
  }
  
  # Configurar según el modo
  if (mode == "basic") {
    config_file <- "scripts/config/query_config_final.json"
    use_parallel <- FALSE
    cat("\n🔸 INICIANDO CONSULTA BÁSICA\n")
    cat("═══════════════════════════════════════════════════════════════\n")
    cat("• Configuración: Básica (10 años, 500 registros/celda)\n")
    cat("• Bases de datos: GBIF, OBIS\n")
    cat("• Procesamiento: Secuencial\n")
    cat("• Tiempo estimado: 5-10 minutos\n")
    
  } else if (mode == "maxima") {
    config_file <- "scripts/config/query_config_maxima.json"
    use_parallel <- FALSE
    cat("\n🔹 INICIANDO CONSULTA MÁXIMA SECUENCIAL\n")
    cat("═══════════════════════════════════════════════════════════════\n")
    cat("• Configuración: Máxima (25 años, 5000 registros/celda)\n")
    cat("• Bases de datos: GBIF, OBIS, iDigBio\n")
    cat("• Procesamiento: Secuencial (1 núcleo)\n")
    cat("• Tiempo estimado: 30-45 minutos\n")
    
  } else if (mode == "parallel") {
    config_file <- "scripts/config/query_config_maxima.json"
    use_parallel <- TRUE
    
    # Detectar núcleos disponibles
    n_cores_available <- parallel::detectCores()
    n_cores_to_use <- max(1, min(n_cores_available - 1, 4))
    
    cat("\n🚀 INICIANDO CONSULTA MÁXIMA PARALELA\n")
    cat("═══════════════════════════════════════════════════════════════\n")
    cat("• Configuración: Máxima (25 años, 5000 registros/celda)\n")
    cat("• Bases de datos: GBIF, OBIS, iDigBio\n")
    cat("• Procesamiento: PARALELO (", n_cores_to_use, "/", n_cores_available, " núcleos)\n")
    cat("• Tiempo estimado: 15-20 minutos\n")
  }
  
  cat("═══════════════════════════════════════════════════════════════\n\n")
  
  # Cargar el script principal
  cat("📦 Cargando sistema de consultas...\n")
  source("scripts/database_queries.R")
  
  # Configurar paralelización si es necesario
  if (use_parallel) {
    if (!requireNamespace("future", quietly = TRUE) || !requireNamespace("furrr", quietly = TRUE)) {
      cat("⚠️  Paquetes de paralelización no disponibles. Ejecutando en modo secuencial.\n")
      use_parallel <- FALSE
    } else {
      cat("⚙️  Configurando paralelización (", n_cores_to_use, " núcleos)...\n")
      future::plan(future::multisession, workers = n_cores_to_use)
      
      # Verificar configuración
      cat("✅ Paralelización configurada correctamente\n")
    }
  }
  
  cat("\n🚀 Iniciando consultas de biodiversidad...\n")
  cat("   • Archivo de configuración:", basename(config_file), "\n")
  cat("   • Procesamiento:", if(use_parallel) "PARALELO" else "SECUENCIAL", "\n")
  cat("   • Hora de inicio:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  # Ejecutar consultas
  start_time <- Sys.time()
  
  tryCatch({
    results <- execute_biodiversity_queries(
      config_file = config_file,
      polygon_file = "shapefiles/study_zone.gpkg",
      output_dir = "data/query_results",
      parallel = use_parallel
    )
    
    end_time <- Sys.time()
    duration <- as.numeric(difftime(end_time, start_time, units = "mins"))
    
    # Mostrar resultados
    if (!is.null(results) && nrow(results$results) > 0) {
      cat("\n")
      cat("╔═══════════════════════════════════════════════════════════════════╗\n")
      cat("║                    CONSULTA COMPLETADA CON ÉXITO                  ║\n")
      cat("╚═══════════════════════════════════════════════════════════════════╝\n\n")
      
      cat("📊 RESUMEN DE RESULTADOS:\n")
      cat("   • Registros totales:", nrow(results$results), "\n")
      cat("   • Tiempo transcurrido:", sprintf("%.1f minutos", duration), "\n")
      cat("   • Modo utilizado:", toupper(mode), "\n")
      cat("   • Procesamiento:", if(use_parallel) "PARALELO" else "SECUENCIAL", "\n\n")
      
      # Análisis por base de datos
      if ("database" %in% colnames(results$results)) {
        db_summary <- table(results$results$database)
        cat("📈 REGISTROS POR BASE DE DATOS:\n")
        for (db in names(db_summary)) {
          cat(sprintf("   • %-15s: %s registros\n", db, format(db_summary[db], big.mark = ",")))
        }
        cat("\n")
      }
      
      # Información de archivos generados
      cat("📁 ARCHIVOS GENERADOS:\n")
      output_files <- list.files("data/query_results", 
                                pattern = paste0("biodiversity.*", format(Sys.Date(), "%Y%m%d")), 
                                full.names = FALSE)
      if (length(output_files) > 0) {
        for (file in output_files) {
          cat("   • data/query_results/", file, "\n")
        }
      }
      
      cat("\n✅ Consulta completada exitosamente!\n")
      
    } else {
      cat("\n❌ No se obtuvieron resultados. Revisa la configuración y conexión.\n")
    }
    
  }, error = function(e) {
    cat("\n❌ ERROR durante la ejecución:\n")
    cat("   ", e$message, "\n\n")
    cat("💡 SUGERENCIAS:\n")
    cat("   • Verifica tu conexión a internet\n")
    cat("   • Revisa los archivos de configuración en scripts/config/\n")
    cat("   • Prueba con el modo 'basic' si hay problemas de recursos\n")
  })
  
  # Limpiar paralelización
  if (use_parallel) {
    future::plan(future::sequential)
    cat("\n🔧 Paralelización finalizada\n")
  }
  
  return(results)
}

#' =============================================================================
#' FUNCIONES DE COMPATIBILIDAD (LEGACY)
#' =============================================================================

# Compatibilidad con final_query.R
run_final_query <- function() {
  cat("⚠️  FUNCIÓN LEGACY: Usando run_biodiversity_query('basic')\n")
  return(run_biodiversity_query('basic'))
}

# Compatibilidad con maxima_query.R
run_maxima_query <- function() {
  cat("⚠️  FUNCIÓN LEGACY: Usando run_biodiversity_query('maxima')\n")
  return(run_biodiversity_query('maxima'))
}

# Compatibilidad con maxima_query_parallel.R
run_maxima_query_parallel <- function() {
  cat("⚠️  FUNCIÓN LEGACY: Usando run_biodiversity_query('parallel')\n")
  return(run_biodiversity_query('parallel'))
}

#' =============================================================================
#' EJECUCIÓN AUTOMÁTICA SI SE EJECUTA DIRECTAMENTE
#' =============================================================================

if (!interactive() && !exists(".__biodiversity_query_loaded__.")) {
  # Si se ejecuta directamente sin argumentos, mostrar ayuda
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) == 0) {
    show_help()
    cat("💡 Para ejecutar directamente desde terminal:\n")
    cat("   Rscript scripts/biodiversity_query.R basic\n")
    cat("   Rscript scripts/biodiversity_query.R maxima\n")
    cat("   Rscript scripts/biodiversity_query.R parallel\n\n")
  } else {
    mode <- args[1]
    cat("🚀 Ejecutando modo:", mode, "\n")
    results <- run_biodiversity_query(mode)
  }
} else if (interactive()) {
  # Modo interactivo
  show_help()
  cat("🎮 Script cargado. Usa: run_biodiversity_query() para empezar\n\n")
}

# Marcar como cargado
.__biodiversity_query_loaded__. <- TRUE