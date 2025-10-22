# ============================================================================
# Script: parallel_query_functions.R
# Descripción: Versión paralelizada de las consultas a bases de datos
# Autor: Sistema de consultas de biodiversidad
# Fecha: 2025-10-18
# ============================================================================

#' Ejecutar consultas en paralelo para todas las bases de datos habilitadas
#'
#' Versión optimizada que usa paralelización para acelerar las consultas
#' cuando hay múltiples celdas de grid
#'
#' @param grid Data frame con columnas: box_id, bbox, wkt
#' @param config Lista de configuración con parámetros de consulta
#' @param log_function Función para logging (opcional)
#' @param n_cores Número de núcleos a usar (por defecto: detecta automáticamente)
#' @return Data frame consolidado con todos los resultados
#' @export
execute_all_queries_parallel <- function(grid, config, log_function = cat, n_cores = NULL) {
  
  # Verificar e instalar paquetes de paralelización si es necesario
  if (!require("future", quietly = TRUE)) {
    log_function("📦 Instalando paquete 'future' para paralelización...")
    install.packages("future", quiet = TRUE)
    library(future)
  }
  
  if (!require("furrr", quietly = TRUE)) {
    log_function("📦 Instalando paquete 'furrr' para paralelización...")
    install.packages("furrr", quiet = TRUE)
    library(furrr)
  }
  
  library(future)
  library(furrr)
  
  # Detectar número de núcleos disponibles
  if (is.null(n_cores)) {
    n_cores <- max(1, parallel::detectCores() - 1)  # Dejar 1 núcleo libre
  }
  
  log_function(paste0("🚀 Configuración de paralelización:"))
  log_function(paste0("   • Núcleos disponibles: ", parallel::detectCores()))
  log_function(paste0("   • Núcleos a usar: ", n_cores))
  log_function(paste0("   • Celdas del grid: ", nrow(grid)))
  log_function(paste0("   • Estimación: ~", round(nrow(grid) / n_cores, 1), " celdas por núcleo\n"))
  
  # Configurar plan de paralelización
  plan(multisession, workers = n_cores)
  
  all_results <- data.frame()
  
  # ============================================================================
  # GBIF - Paralelizado
  # ============================================================================
  if (config$databases$gbif$enabled) {
    log_function("Iniciando consultas paralelas a GBIF...")
    start_time <- Sys.time()
    
    tryCatch({
      # Ejecutar consultas en paralelo
      gbif_results_list <- future_map(
        1:nrow(grid),
        function(i) {
          tryCatch({
            query_gbif(
              bbox = grid$bbox[i],
              wkt = grid$wkt[i],
              config = config$databases$gbif,
              box_id = i,
              log_function = function(msg) {} # Silenciar logs individuales
            )
          }, error = function(e) {
            data.frame() # Retornar data frame vacío en caso de error
          })
        },
        .options = furrr_options(seed = TRUE)
      )
      
      # Combinar resultados
      gbif_results <- do.call(rbind, gbif_results_list)
      
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      
      if (!is.null(gbif_results) && nrow(gbif_results) > 0) {
        all_results <- rbind(all_results, gbif_results)
        log_function(sprintf("✓ GBIF - Total: %d registros en %.1f segundos (%.1f celdas/seg)",
                           nrow(gbif_results), elapsed, nrow(grid)/elapsed))
      } else {
        log_function(sprintf("⚠ GBIF - Sin resultados (%.1f segundos)", elapsed))
      }
    }, error = function(e) {
      log_function(paste("✗ Error en consultas GBIF:", e$message))
    })
  }
  
  # ============================================================================
  # OBIS - Paralelizado
  # ============================================================================
  if (config$databases$obis$enabled) {
    log_function("Iniciando consultas paralelas a OBIS...")
    start_time <- Sys.time()
    
    tryCatch({
      obis_results_list <- future_map(
        1:nrow(grid),
        function(i) {
          tryCatch({
            query_obis(
              bbox = grid$bbox[i],
              config = config$databases$obis,
              box_id = i,
              log_function = function(msg) {}
            )
          }, error = function(e) {
            data.frame()
          })
        },
        .options = furrr_options(seed = TRUE)
      )
      
      obis_results <- do.call(rbind, obis_results_list)
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      
      if (!is.null(obis_results) && nrow(obis_results) > 0) {
        all_results <- rbind(all_results, obis_results)
        log_function(sprintf("✓ OBIS - Total: %d registros en %.1f segundos (%.1f celdas/seg)",
                           nrow(obis_results), elapsed, nrow(grid)/elapsed))
      } else {
        log_function(sprintf("⚠ OBIS - Sin resultados (%.1f segundos)", elapsed))
      }
    }, error = function(e) {
      log_function(paste("✗ Error en consultas OBIS:", e$message))
    })
  }
  
  # ============================================================================
  # iNaturalist - Paralelizado
  # ============================================================================
  if (config$databases$inat$enabled) {
    log_function("Iniciando consultas paralelas a iNaturalist...")
    start_time <- Sys.time()
    
    tryCatch({
      inat_results_list <- future_map(
        1:nrow(grid),
        function(i) {
          tryCatch({
            query_inat(
              bbox = grid$bbox[i],
              config = config$databases$inat,
              box_id = i,
              log_function = function(msg) {}
            )
          }, error = function(e) {
            data.frame()
          })
        },
        .options = furrr_options(seed = TRUE)
      )
      
      inat_results <- do.call(rbind, inat_results_list)
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      
      if (!is.null(inat_results) && nrow(inat_results) > 0) {
        all_results <- rbind(all_results, inat_results)
        log_function(sprintf("✓ iNaturalist - Total: %d registros en %.1f segundos (%.1f celdas/seg)",
                           nrow(inat_results), elapsed, nrow(grid)/elapsed))
      } else {
        log_function(sprintf("⚠ iNaturalist - Sin resultados (%.1f segundos)", elapsed))
      }
    }, error = function(e) {
      log_function(paste("✗ Error en consultas iNaturalist:", e$message))
    })
  }
  
  # ============================================================================
  # iDigBio - Paralelizado
  # ============================================================================
  if (config$databases$idigbio$enabled) {
    log_function("Iniciando consultas paralelas a iDigBio...")
    start_time <- Sys.time()
    
    tryCatch({
      idigbio_results_list <- future_map(
        1:nrow(grid),
        function(i) {
          tryCatch({
            query_idigbio(
              bbox = grid$bbox[i],
              config = config$databases$idigbio,
              box_id = i,
              log_function = function(msg) {}
            )
          }, error = function(e) {
            data.frame()
          })
        },
        .options = furrr_options(seed = TRUE)
      )
      
      idigbio_results <- do.call(rbind, idigbio_results_list)
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      
      if (!is.null(idigbio_results) && nrow(idigbio_results) > 0) {
        all_results <- rbind(all_results, idigbio_results)
        log_function(sprintf("✓ iDigBio - Total: %d registros en %.1f segundos (%.1f celdas/seg)",
                           nrow(idigbio_results), elapsed, nrow(grid)/elapsed))
      } else {
        log_function(sprintf("⚠ iDigBio - Sin resultados (%.1f segundos)", elapsed))
      }
    }, error = function(e) {
      log_function(paste("✗ Error en consultas iDigBio:", e$message))
    })
  }
  
  # Restaurar plan secuencial
  plan(sequential)
  
  return(all_results)
}


#' Ejecutar consultas con estrategia adaptativa (automática o paralela)
#'
#' Decide automáticamente si usar paralelización basándose en el número de celdas
#'
#' @param grid Data frame con columnas: box_id, bbox, wkt
#' @param config Lista de configuración con parámetros de consulta
#' @param log_function Función para logging (opcional)
#' @param parallel_threshold Número mínimo de celdas para usar paralelización (default: 5)
#' @param n_cores Número de núcleos a usar (por defecto: detecta automáticamente)
#' @return Data frame consolidado con todos los resultados
#' @export
execute_all_queries_adaptive <- function(grid, config, log_function = cat, 
                                        parallel_threshold = 5, n_cores = NULL) {
  
  n_boxes <- nrow(grid)
  
  # Decidir estrategia
  if (n_boxes >= parallel_threshold) {
    log_function(paste0("📊 Estrategia: PARALELA (", n_boxes, " celdas)\n"))
    return(execute_all_queries_parallel(grid, config, log_function, n_cores))
  } else {
    log_function(paste0("📊 Estrategia: SECUENCIAL (", n_boxes, " celdas)\n"))
    # Usar la función original del archivo query_functions.R
    return(execute_all_queries(grid, config, log_function))
  }
}


#' Ejecutar consultas con balanceo de carga por chunks
#'
#' Divide el grid en chunks y los procesa en paralelo para mejor control
#' y recuperación ante errores
#'
#' @param grid Data frame con columnas: box_id, bbox, wkt
#' @param config Lista de configuración con parámetros de consulta
#' @param log_function Función para logging (opcional)
#' @param chunk_size Tamaño de cada chunk (default: 10 celdas)
#' @param n_cores Número de núcleos a usar (por defecto: detecta automáticamente)
#' @return Data frame consolidado con todos los resultados
#' @export
execute_all_queries_chunked <- function(grid, config, log_function = cat, 
                                       chunk_size = 10, n_cores = NULL) {
  
  if (!require("future", quietly = TRUE)) install.packages("future", quiet = TRUE)
  if (!require("furrr", quietly = TRUE)) install.packages("furrr", quiet = TRUE)
  
  library(future)
  library(furrr)
  
  # Detectar núcleos
  if (is.null(n_cores)) {
    n_cores <- max(1, parallel::detectCores() - 1)
  }
  
  # Dividir grid en chunks
  n_boxes <- nrow(grid)
  n_chunks <- ceiling(n_boxes / chunk_size)
  
  log_function(paste0("🔄 Estrategia por chunks:"))
  log_function(paste0("   • Total de celdas: ", n_boxes))
  log_function(paste0("   • Tamaño de chunk: ", chunk_size))
  log_function(paste0("   • Total de chunks: ", n_chunks))
  log_function(paste0("   • Núcleos: ", n_cores, "\n"))
  
  plan(multisession, workers = n_cores)
  
  all_results <- data.frame()
  
  # Procesar por base de datos
  for (db_name in names(config$databases)) {
    db_config <- config$databases[[db_name]]
    
    if (!db_config$enabled) next
    
    log_function(paste0("Procesando ", toupper(db_name), " en ", n_chunks, " chunks..."))
    start_time <- Sys.time()
    
    # Función de consulta según base de datos
    query_func <- switch(db_name,
      "gbif" = query_gbif,
      "obis" = query_obis,
      "inat" = query_inat,
      "ebird" = query_ebird,
      "idigbio" = query_idigbio,
      NULL
    )
    
    if (is.null(query_func)) {
      log_function(paste("⚠ Base de datos no reconocida:", db_name))
      next
    }
    
    # Procesar chunks en paralelo
    chunk_results <- list()
    
    for (chunk_idx in 1:n_chunks) {
      start_idx <- (chunk_idx - 1) * chunk_size + 1
      end_idx <- min(chunk_idx * chunk_size, n_boxes)
      chunk_indices <- start_idx:end_idx
      
      log_function(sprintf("  Chunk %d/%d (celdas %d-%d)...", 
                          chunk_idx, n_chunks, start_idx, end_idx))
      
      tryCatch({
        chunk_result_list <- future_map(
          chunk_indices,
          function(i) {
            tryCatch({
              args <- list(
                config = db_config,
                box_id = i,
                log_function = function(msg) {}
              )
              
              # Agregar bbox o wkt según la función
              if (db_name %in% c("gbif")) {
                args$bbox <- grid$bbox[i]
                args$wkt <- grid$wkt[i]
              } else {
                args$bbox <- grid$bbox[i]
              }
              
              do.call(query_func, args)
            }, error = function(e) {
              data.frame()
            })
          },
          .options = furrr_options(seed = TRUE)
        )
        
        chunk_result <- do.call(rbind, chunk_result_list)
        if (!is.null(chunk_result) && nrow(chunk_result) > 0) {
          chunk_results[[chunk_idx]] <- chunk_result
          log_function(sprintf("    ✓ %d registros", nrow(chunk_result)))
        } else {
          log_function("    ⚠ Sin resultados")
        }
        
      }, error = function(e) {
        log_function(sprintf("    ✗ Error: %s", e$message))
      })
    }
    
    # Consolidar resultados del database
    if (length(chunk_results) > 0) {
      db_results <- do.call(rbind, chunk_results)
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      
      if (nrow(db_results) > 0) {
        all_results <- rbind(all_results, db_results)
        log_function(sprintf("✓ %s completado: %d registros en %.1f segundos\n",
                           toupper(db_name), nrow(db_results), elapsed))
      }
    }
  }
  
  plan(sequential)
  return(all_results)
}
