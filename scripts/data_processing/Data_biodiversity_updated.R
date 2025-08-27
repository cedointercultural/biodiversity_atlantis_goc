#' Data_biodiversity_optimized.R - VERSION OPTIMIZADA
#' Solucionando problemas de límites de API y compatibilidad de paquetes
#' Author: Ricardo Cavieses-Nuñez
#' Date: August 2025

# Clean workspace
rm(list=ls())

# Configure CRAN mirror first
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# PAQUETES OPTIMIZADOS PARA R 4.3+ (removiendo los problemáticos)
required_packages <- c(
  "readxl",      # Para leer Excel
  "data.table",  # Manipulación eficiente de datos
  "rgbif",       # GBIF API (funciona)
  "raster",      # Análisis espacial
  "sf",          # Geometrías espaciales modernas
  "dplyr",       # Manipulación de datos
  "httr",        # HTTP requests
  "jsonlite",    # JSON parsing
  "curl"         # Para descargas web
)

# Install and load packages with better error handling
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    tryCatch({
      cat("Installing package:", pkg, "\n")
      install.packages(pkg, dependencies = TRUE)
      library(pkg, character.only = TRUE)
      cat("Successfully loaded:", pkg, "\n")
    }, error = function(e) {
      cat("Warning: Could not install package", pkg, ". Error:", e$message, "\n")
      cat("Continuing without", pkg, "\n")
    })
  } else {
    cat("Package already loaded:", pkg, "\n")
  }
}

# Directory paths - updated to current project structure
analysispath <- getwd()
datapath <- file.path(analysispath, "data")
shapepath <- file.path(analysispath, "shapefiles")
savepath <- file.path(analysispath, "output", "Ocurrencia_especies")
datafiles <- file.path(datapath, "Ocurrencia_especies")

# Create directories if they don't exist
dir.create(datapath, recursive = TRUE, showWarnings = FALSE)
dir.create(shapepath, recursive = TRUE, showWarnings = FALSE)
dir.create(savepath, recursive = TRUE, showWarnings = FALSE)
dir.create(datafiles, recursive = TRUE, showWarnings = FALSE)

# Coordinate reference systems
crs_geo_wgs <- "EPSG:4326"

# Create Gulf of California boundary
cat("Creating Gulf of California boundary...\n")
goc_coords <- matrix(c(
  -115.142516, 32.139900,
  -108.984272, 32.139900,
  -104.953420, 32.139900,
  -104.953420, 20.164036,
  -115.142516, 20.164036,
  -115.142516, 32.139900
), ncol = 2, byrow = TRUE)

goc.shape <- st_sfc(st_polygon(list(goc_coords)), crs = crs_geo_wgs)
goc.shape <- st_sf(id = 1, geometry = goc.shape)

#' FUNCIÓN PARA CREAR BARRA DE PROGRESO
create_progress_bar <- function(current, total, width = 50, char = "█") {
  percent <- round((current / total) * 100)
  filled <- round((current / total) * width)
  empty <- width - filled
  
  bar <- paste0(
    "\r[", 
    paste(rep(char, filled), collapse = ""),
    paste(rep(".", empty), collapse = ""),
    "] ", 
    sprintf("%3d", percent), 
    "% (", current, "/", total, ")"
  )
  
  return(bar)
}

#' FUNCIÓN OPTIMIZADA PARA GBIF CON LÍMITES RESPETADOS Y BARRA DE PROGRESO
query_gbif_safely <- function(polygon_wkt, max_records = 50000, delay = 2, polygon_id = 1, total_polygons = 1) {
  # Mostrar barra de progreso
  progress_bar <- create_progress_bar(polygon_id - 1, total_polygons)
  cat(progress_bar)
  
  cat("\n🔍 Querying GBIF polygon", polygon_id, "of", total_polygons, "...\n")
  
  # Mostrar mini progreso para la consulta actual
  cat("   ⏳ Sending request to GBIF API...")
  
  tryCatch({
    # Usar límite menor para evitar el error de offset
    gbif_data <- occ_search(
      geometry = polygon_wkt,
      limit = max_records,  # Límite seguro
      fields = c('scientificName', 'decimalLatitude', 'decimalLongitude', 
                'year', 'month', 'day', 'eventDate', 'basisOfRecord'),
      hasCoordinate = TRUE,  # Solo registros con coordenadas
      hasGeospatialIssue = FALSE  # Sin problemas geoespaciales
    )
    
    cat(" ✓\n")
    cat("   📊 Processing response...")
    
    if (!is.null(gbif_data) && nrow(gbif_data) > 0) {
      cat(" ✓\n")
      cat("   ✅ Retrieved", nrow(gbif_data), "records from GBIF\n")
      
      # Pausa entre requests con countdown visual
      if (delay > 0) {
        cat("   ⏱️  Waiting", delay, "seconds before next request...")
        for (i in seq(delay, 1, -1)) {
          cat("\r   ⏱️  Waiting", i, "seconds before next request...")
          Sys.sleep(1)
        }
        cat(" ✓\n")
      }
      
      return(gbif_data)
    } else {
      cat(" ⚠️\n")
      cat("   ⚠️  No data returned from GBIF\n")
      return(NULL)
    }
    
  }, error = function(e) {
    cat(" ✗\n")
    cat("   ✗ GBIF error:", e$message, "\n")
    
    # Pausa incluso en caso de error
    if (delay > 0) {
      cat("   ⏱️  Waiting", delay, "seconds before continuing...")
      Sys.sleep(delay)
      cat(" ✓\n")
    }
    
    return(NULL)
  })
}

#' FUNCIÓN PARA PROCESAR DATOS LOCALES DE MANERA ROBUSTA
process_local_data <- function(file_path, source_name) {
  cat("Processing", source_name, "data from:", file_path, "\n")
  
  if (!file.exists(file_path)) {
    cat("⚠ File not found:", file_path, "\n")
    return(data.frame())
  }
  
  tryCatch({
    # Detectar tipo de archivo y leer apropiadamente
    if (grepl("\\.xlsx?$", file_path, ignore.case = TRUE)) {
      data <- read_excel(file_path)
    } else {
      data <- read.csv(file_path, stringsAsFactors = FALSE)
    }
    
    if (nrow(data) == 0 || ncol(data) < 3) {
      cat("⚠ Insufficient data in file\n")
      return(data.frame())
    }
    
    # Detectar columnas de coordenadas automáticamente
    coord_cols <- find_coordinate_columns(data)
    date_cols <- find_date_columns(data)
    species_col <- find_species_column(data)
    
    if (is.null(coord_cols) || is.null(species_col)) {
      cat("⚠ Could not identify required columns\n")
      return(data.frame())
    }
    
    # Crear dataset estandarizado
    standardized_data <- data.frame(
      species = data[[species_col]],
      lat = as.numeric(data[[coord_cols$lat]]),
      lon = as.numeric(data[[coord_cols$lon]]),
      year = if(!is.null(date_cols$year)) as.numeric(data[[date_cols$year]]) else NA,
      month = if(!is.null(date_cols$month)) as.numeric(data[[date_cols$month]]) else NA,
      day = if(!is.null(date_cols$day)) as.numeric(data[[date_cols$day]]) else NA,
      date_recorded = if(!is.null(date_cols$date)) as.character(data[[date_cols$date]]) else NA,
      source = source_name,
      stringsAsFactors = FALSE
    )
    
    # Remover filas con coordenadas faltantes
    standardized_data <- standardized_data[complete.cases(standardized_data[, c("lat", "lon", "species")]), ]
    
    cat("✓ Processed", nrow(standardized_data), "valid records\n")
    return(standardized_data)
    
  }, error = function(e) {
    cat("✗ Error processing file:", e$message, "\n")
    return(data.frame())
  })
}

#' FUNCIONES AUXILIARES PARA DETECTAR COLUMNAS
find_coordinate_columns <- function(data) {
  cols <- tolower(names(data))
  
  # Buscar columnas de latitud
  lat_patterns <- c("lat", "latitud", "latitude", "y")
  lat_col <- NULL
  for (pattern in lat_patterns) {
    matches <- grep(pattern, cols)
    if (length(matches) > 0) {
      lat_col <- names(data)[matches[1]]
      break
    }
  }
  
  # Buscar columnas de longitud
  lon_patterns <- c("lon", "longitud", "longitude", "x")
  lon_col <- NULL
  for (pattern in lon_patterns) {
    matches <- grep(pattern, cols)
    if (length(matches) > 0) {
      lon_col <- names(data)[matches[1]]
      break
    }
  }
  
  if (!is.null(lat_col) && !is.null(lon_col)) {
    return(list(lat = lat_col, lon = lon_col))
  } else {
    return(NULL)
  }
}

find_date_columns <- function(data) {
  cols <- tolower(names(data))
  
  year_col <- NULL
  month_col <- NULL
  day_col <- NULL
  date_col <- NULL
  
  # Buscar columnas de fecha
  year_patterns <- c("year", "año", "yr")
  month_patterns <- c("month", "mes", "mon")
  day_patterns <- c("day", "dia", "dd")
  date_patterns <- c("date", "fecha", "eventdate", "datetime")
  
  for (pattern in year_patterns) {
    matches <- grep(pattern, cols)
    if (length(matches) > 0) {
      year_col <- names(data)[matches[1]]
      break
    }
  }
  
  for (pattern in month_patterns) {
    matches <- grep(pattern, cols)
    if (length(matches) > 0) {
      month_col <- names(data)[matches[1]]
      break
    }
  }
  
  for (pattern in day_patterns) {
    matches <- grep(pattern, cols)
    if (length(matches) > 0) {
      day_col <- names(data)[matches[1]]
      break
    }
  }
  
  for (pattern in date_patterns) {
    matches <- grep(pattern, cols)
    if (length(matches) > 0) {
      date_col <- names(data)[matches[1]]
      break
    }
  }
  
  return(list(year = year_col, month = month_col, day = day_col, date = date_col))
}

find_species_column <- function(data) {
  cols <- tolower(names(data))
  
  species_patterns <- c("species", "especie", "scientific", "nombre", "name", "taxon")
  
  for (pattern in species_patterns) {
    matches <- grep(pattern, cols)
    if (length(matches) > 0) {
      return(names(data)[matches[1]])
    }
  }
  
  # Si no encuentra, usar la primera columna
  return(names(data)[1])
}

#' FUNCIÓN PARA APLICAR FILTRO ESPACIAL
apply_spatial_filter <- function(data, boundary_shape) {
  if (nrow(data) == 0) {
    return(data.frame())
  }
  
  tryCatch({
    # Convertir a sf
    data_sf <- st_as_sf(
      data, 
      coords = c("lon", "lat"), 
      crs = crs_geo_wgs
    )
    
    # Intersección espacial
    filtered_sf <- st_intersection(data_sf, boundary_shape)
    
    if (nrow(filtered_sf) > 0) {
      # Recuperar coordenadas
      coords <- st_coordinates(filtered_sf)
      
      # Crear dataframe final
      result <- data.frame(
        st_drop_geometry(filtered_sf),
        lon = coords[, "X"],
        lat = coords[, "Y"]
      )
      
      cat("✓ Spatial filter applied:", nrow(result), "records within boundary\n")
      return(result)
    } else {
      cat("⚠ No records within spatial boundary\n")
      return(data.frame())
    }
    
  }, error = function(e) {
    cat("✗ Error applying spatial filter:", e$message, "\n")
    return(data.frame())
  })
}

#' =============================================================================
#' PROCESO PRINCIPAL - VERSIÓN OPTIMIZADA
#' =============================================================================

cat("🌟 STARTING OPTIMIZED BIODIVERSITY DATA PROCESSING\n")
cat("===================================================\n\n")

# Inicializar contenedor para todos los datos
all_biodiversity_data <- data.frame()

# 1. GBIF DATA - Con límites seguros y barra de progreso
cat("📡 STEP 1: Querying GBIF (with safe limits and progress tracking)...\n")

# Definir polígonos más pequeños para GBIF
smaller_polygons <- c(
  "POLYGON((-115.142516 30.0, -110.0 30.0, -110.0 25.0, -115.142516 25.0, -115.142516 30.0))",
  "POLYGON((-110.0 30.0, -104.953420 30.0, -104.953420 25.0, -110.0 25.0, -110.0 30.0))",
  "POLYGON((-115.142516 25.0, -110.0 25.0, -110.0 20.164036, -115.142516 20.164036, -115.142516 25.0))",
  "POLYGON((-110.0 25.0, -104.953420 25.0, -104.953420 20.164036, -110.0 20.164036, -110.0 25.0))"
)

cat("🌐 Total polygons to process:", length(smaller_polygons), "\n\n")

gbif_data_combined <- data.frame()
total_polygons <- length(smaller_polygons)

for (i in seq_along(smaller_polygons)) {
  cat("\n" , rep("─", 60), "\n")
  
  gbif_result <- query_gbif_safely(
    smaller_polygons[i], 
    max_records = 40000, 
    delay = 3,
    polygon_id = i,
    total_polygons = total_polygons
  )
  
  if (!is.null(gbif_result) && nrow(gbif_result) > 0) {
    # Estandarizar datos de GBIF
    gbif_standardized <- data.frame(
      species = gbif_result$scientificName,
      lat = gbif_result$decimalLatitude,
      lon = gbif_result$decimalLongitude,
      year = gbif_result$year,
      month = gbif_result$month,
      day = gbif_result$day,
      date_recorded = gbif_result$eventDate,
      source = "GBIF",
      stringsAsFactors = FALSE
    )
    
    # Remover duplicados y filas incompletas
    gbif_standardized <- gbif_standardized[complete.cases(gbif_standardized[, c("lat", "lon", "species")]), ]
    gbif_standardized <- gbif_standardized[!duplicated(gbif_standardized[, c('species', 'lat', 'lon')]), ]
    
    gbif_data_combined <- rbind(gbif_data_combined, gbif_standardized)
    cat("   📈 Running total:", nrow(gbif_data_combined), "unique records\n")
  }
}

# Mostrar barra de progreso final completa
final_progress <- create_progress_bar(total_polygons, total_polygons)
cat("\n", final_progress, "\n")
cat("🎯 GBIF queries completed!\n")

if (nrow(gbif_data_combined) > 0) {
  # Aplicar filtro espacial
  gbif_filtered <- apply_spatial_filter(gbif_data_combined, goc.shape)
  
  if (nrow(gbif_filtered) > 0) {
    # Guardar datos de GBIF
    write.csv(gbif_filtered, 
             file.path(savepath, "GBIF_biodiver_species_goc_optimized.csv"), 
             row.names = FALSE)
    
    all_biodiversity_data <- rbind(all_biodiversity_data, gbif_filtered)
    cat("✅ GBIF data saved:", nrow(gbif_filtered), "records\n")
  }
}

# 2. DATOS LOCALES - OBIS con barra de progreso
cat("\n📁 STEP 2: Processing local OBIS data...\n")
obis_files <- list.files(datafiles, pattern = "OBIS.*\\.(csv|xlsx?)$", full.names = TRUE)

if (length(obis_files) > 0) {
  cat("📊 Found", length(obis_files), "OBIS files to process\n")
  
  for (file_idx in seq_along(obis_files)) {
    file <- obis_files[file_idx]
    
    # Mostrar progreso
    progress_bar <- create_progress_bar(file_idx - 1, length(obis_files))
    cat(progress_bar, "\n")
    cat("📄 Processing:", basename(file), "\n")
    
    obis_data <- process_local_data(file, "OBIS")
    if (nrow(obis_data) > 0) {
      obis_filtered <- apply_spatial_filter(obis_data, goc.shape)
      if (nrow(obis_filtered) > 0) {
        write.csv(obis_filtered, 
                 file.path(savepath, paste0("OBIS_", basename(file), "_processed.csv")), 
                 row.names = FALSE)
        all_biodiversity_data <- rbind(all_biodiversity_data, obis_filtered)
      }
    }
  }
  
  # Progreso final para OBIS
  final_progress <- create_progress_bar(length(obis_files), length(obis_files))
  cat(final_progress, "\n")
  cat("✅ OBIS processing completed!\n")
} else {
  cat("⚠️  No OBIS files found\n")
}

# 3. DATOS LOCALES - UABCS con barra de progreso
cat("\n📁 STEP 3: Processing local UABCS data...\n")
uabcs_files <- list.files(datafiles, pattern = "UABCS.*\\.(csv|xlsx?)$", full.names = TRUE)

if (length(uabcs_files) > 0) {
  cat("📊 Found", length(uabcs_files), "UABCS files to process\n")
  
  for (file_idx in seq_along(uabcs_files)) {
    file <- uabcs_files[file_idx]
    
    # Mostrar progreso
    progress_bar <- create_progress_bar(file_idx - 1, length(uabcs_files))
    cat(progress_bar, "\n")
    cat("📄 Processing:", basename(file), "\n")
    
    uabcs_data <- process_local_data(file, "UABCS")
    if (nrow(uabcs_data) > 0) {
      uabcs_filtered <- apply_spatial_filter(uabcs_data, goc.shape)
      if (nrow(uabcs_filtered) > 0) {
        write.csv(uabcs_filtered, 
                 file.path(savepath, paste0("UABCS_", basename(file), "_processed.csv")), 
                 row.names = FALSE)
        all_biodiversity_data <- rbind(all_biodiversity_data, uabcs_filtered)
      }
    }
  }
  
  # Progreso final para UABCS
  final_progress <- create_progress_bar(length(uabcs_files), length(uabcs_files))
  cat(final_progress, "\n")
  cat("✅ UABCS processing completed!\n")
} else {
  cat("⚠️  No UABCS files found\n")
}

# 4. OTROS ARCHIVOS LOCALES con barra de progreso
cat("\n📁 STEP 4: Processing other local data files...\n")
other_files <- list.files(datafiles, pattern = "\\.(csv|xlsx?)$", full.names = TRUE)
other_files <- other_files[!grepl("(OBIS|UABCS)", other_files, ignore.case = TRUE)]

if (length(other_files) > 0) {
  cat("📊 Found", length(other_files), "additional files to process\n")
  
  for (file_idx in seq_along(other_files)) {
    file <- other_files[file_idx]
    
    # Mostrar progreso
    progress_bar <- create_progress_bar(file_idx - 1, length(other_files))
    cat(progress_bar, "\n")
    cat("📄 Processing:", basename(file), "\n")
    
    other_data <- process_local_data(file, paste0("Local_", tools::file_path_sans_ext(basename(file))))
    if (nrow(other_data) > 0) {
      other_filtered <- apply_spatial_filter(other_data, goc.shape)
      if (nrow(other_filtered) > 0) {
        write.csv(other_filtered, 
                 file.path(savepath, paste0("Local_", basename(file), "_processed.csv")), 
                 row.names = FALSE)
        all_biodiversity_data <- rbind(all_biodiversity_data, other_filtered)
      }
    }
  }
  
  # Progreso final para otros archivos
  final_progress <- create_progress_bar(length(other_files), length(other_files))
  cat(final_progress, "\n")
  cat("✅ Additional files processing completed!\n")
} else {
  cat("⚠️  No additional files found\n")
}

# 5. COMBINAR Y GUARDAR DATASET FINAL
cat("\n🔄 STEP 5: Combining and finalizing dataset...\n")

if (nrow(all_biodiversity_data) > 0) {
  # Remover duplicados finales
  all_biodiversity_data <- all_biodiversity_data[!duplicated(
    all_biodiversity_data[, c('species', 'lat', 'lon')]
  ), ]
  
  # Guardar dataset combinado
  final_filename <- paste0("biodiversity_goc_combined_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
  write.csv(all_biodiversity_data, 
           file.path(savepath, final_filename), 
           row.names = FALSE)
  
  # Estadísticas finales
  cat("\n")
  cat("🎉 PROCESSING COMPLETED SUCCESSFULLY!\n")
  cat("=====================================\n")
  cat("Total unique records:", nrow(all_biodiversity_data), "\n")
  cat("Unique species:", length(unique(all_biodiversity_data$species)), "\n")
  cat("Data sources:", paste(unique(all_biodiversity_data$source), collapse = ", "), "\n")
  cat("Date range:", min(all_biodiversity_data$year, na.rm = TRUE), "-", max(all_biodiversity_data$year, na.rm = TRUE), "\n")
  cat("Output directory:", savepath, "\n")
  cat("Final combined file:", final_filename, "\n")
  
  # Resumen por fuente
  cat("\nRecords by source:\n")
  source_summary <- table(all_biodiversity_data$source)
  for (src in names(source_summary)) {
    cat("-", src, ":", source_summary[src], "records\n")
  }
  
} else {
  cat("⚠ WARNING: No biodiversity data was processed successfully\n")
}

cat("\n✨ Script completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
