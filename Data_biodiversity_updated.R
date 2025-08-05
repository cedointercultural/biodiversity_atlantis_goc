#' Data_biodiversity.R - UPDATED VERSION
#' Migrated from deprecated packages (gdata, maptools, PBSmapping, rgdal)
#' 
#' Obtains and organizes biodiversity data from various sources

# Clean workspace
rm(list=ls())

# Configure CRAN mirror first
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Updated package list - modern alternatives
required_packages <- c(
  "readxl", "fields", "data.table", "rgbif", "raster", "rasterVis",
  "sf", "sperich", "dplyr", "ecoengine", "rvertnet", "httr"
)

# Install and load packages with error handling
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
analysispath <- getwd()  # Current working directory
datapath <- file.path(analysispath, "data")
shapepath <- file.path(analysispath, "shapefiles")
savepath <- file.path(analysispath, "output", "Ocurrencia_especies")
datafiles <- file.path(datapath, "Ocurrencia_especies")
vertnetfiles <- file.path(datapath, "Vertnet")

# Create directories if they don't exist
dir.create(datapath, recursive = TRUE, showWarnings = FALSE)
dir.create(shapepath, recursive = TRUE, showWarnings = FALSE)
dir.create(savepath, recursive = TRUE, showWarnings = FALSE)
dir.create(datafiles, recursive = TRUE, showWarnings = FALSE)
dir.create(vertnetfiles, recursive = TRUE, showWarnings = FALSE)

# Coordinate reference systems using modern format
crs_geo_lcc <- "+proj=lcc +lat_1=17.5 +lat_2=29.5 +lat_0=0 +lon_0=-102 +x_0=2000000 +y_0=0 +datum=NAD27 +units=m +no_defs"
crs_geo_wgs <- "EPSG:4326"

# Create Gulf of California boundary programmatically
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

#' Define bounding polygons for GBIF queries
polygons <- c(
  "POLYGON((-115.142516 32.139900, -108.984272 32.139900, -108.984272 27.174972, -115.142516 27.174972, -115.142516 32.139900))",
  "POLYGON((-108.984272 32.139900, -104.953420 32.139900, -104.953420 27.174972, -108.984272 27.174972, -108.984272 32.139900))",
  "POLYGON((-115.142516 27.174972, -108.984272 27.174972, -108.984272 20.164036, -115.142516 20.164036, -115.142516 27.174972))",
  "POLYGON((-108.984272 27.174972, -104.953420 27.174972, -104.953420 20.164036, -108.984272 20.164036, -108.984272 27.174972))"
)

#' Query GBIF database
print("Querying GBIF database...")
biodiversity_gbif <- data.frame()

for (i in seq_along(polygons)) {
  tryCatch({
    cat("Processing GBIF polygon", i, "of", length(polygons), "\n")
    
    gbif_data <- occ_search(
      geometry = polygons[i],
      return = 'data',
      fields = c('name', 'decimalLatitude', 'decimalLongitude', 'year', 'month', 'day'),
      limit = 200000
    )
    
    if (!is.null(gbif_data) && nrow(gbif_data) > 0) {
      # Create date_recorded field from available date components
      date_recorded <- rep(NA_character_, nrow(gbif_data))
      
      # Construct date from year, month, day if available
      for (j in seq_len(nrow(gbif_data))) {
        date_parts <- c()
        if (!is.na(gbif_data$year[j])) date_parts <- c(date_parts, gbif_data$year[j])
        if (!is.na(gbif_data$month[j])) date_parts <- c(date_parts, sprintf("%02d", gbif_data$month[j]))
        if (!is.na(gbif_data$day[j])) date_parts <- c(date_parts, sprintf("%02d", gbif_data$day[j]))
        
        if (length(date_parts) >= 1) {
          date_recorded[j] <- paste(date_parts, collapse = "-")
        }
      }
      
      # Standardize column names
      temp_data <- data.frame(
        species = gbif_data$name,
        lat = gbif_data$decimalLatitude,
        lon = gbif_data$decimalLongitude,
        year = gbif_data$year,
        month = gbif_data$month,
        day = gbif_data$day,
        date_recorded = date_recorded,
        source = "GBIF",
        stringsAsFactors = FALSE
      )
      
      # Remove rows with missing coordinates
      temp_data <- temp_data[complete.cases(temp_data[, c("lat", "lon")]), ]
      
      biodiversity_gbif <- rbind(biodiversity_gbif, temp_data)
      cat("Retrieved", nrow(temp_data), "records from polygon", i, "\n")
    }
    
  }, error = function(e) {
    cat("Error with GBIF polygon", i, ":", e$message, "\n")
  })
}

# Remove duplicates from GBIF data
if (nrow(biodiversity_gbif) > 0) {
  biodiversity_gbif <- biodiversity_gbif[!duplicated(
    biodiversity_gbif[, c('species', 'lat', 'lon')]
  ), ]
  
  # Spatial subset to Gulf of California using sf
  biodiversity_gbif_sf <- st_as_sf(
    biodiversity_gbif, 
    coords = c("lon", "lat"), 
    crs = crs_geo_wgs
  )
  
  goc_gbif <- st_intersection(biodiversity_gbif_sf, goc.shape)
  
  if (nrow(goc_gbif) > 0) {
    coords <- st_coordinates(goc_gbif)
    biodiversity_gbif_final <- data.frame(
      st_drop_geometry(goc_gbif),
      lon = coords[, "X"],
      lat = coords[, "Y"]
    )
  } else {
    biodiversity_gbif_final <- data.frame()
  }
  
  # Save GBIF data
  write.csv(biodiversity_gbif_final, 
           file.path(savepath, "GBIF_biodiver_species_goc.csv"), 
           row.names = FALSE)
  cat("GBIF final dataset:", nrow(biodiversity_gbif_final), "records\n")
}

#' Query Ecoengine database
print("Querying Ecoengine database...")
biodiversity_ecoengine <- data.frame()

# Define bounding boxes for Ecoengine
bbox_list <- list(
  c(-115.142516, 27.174972, -108.984272, 32.139900),
  c(-108.984272, 27.174972, -104.953420, 32.139900),
  c(-115.142516, 20.164036, -108.984272, 27.174972),
  c(-108.984272, 20.164036, -104.953420, 27.174972)
)

for (i in seq_along(bbox_list)) {
  tryCatch({
    cat("Processing Ecoengine bbox", i, "of", length(bbox_list), "\n")
    
    bbox <- bbox_list[[i]]
    eco_data <- ee_observations(
      bbox = bbox,
      page_size = 1000,
      page = "all"
    )
    
    if (!is.null(eco_data) && nrow(eco_data) > 0) {
      # Create date_recorded field from available date components
      date_recorded <- rep(NA_character_, nrow(eco_data))
      
      # Construct date from year, month, day if available
      for (j in seq_len(nrow(eco_data))) {
        date_parts <- c()
        if (!is.na(eco_data$year[j])) date_parts <- c(date_parts, eco_data$year[j])
        if (!is.na(eco_data$month[j])) date_parts <- c(date_parts, sprintf("%02d", eco_data$month[j]))
        if (!is.na(eco_data$day[j])) date_parts <- c(date_parts, sprintf("%02d", eco_data$day[j]))
        
        if (length(date_parts) >= 1) {
          date_recorded[j] <- paste(date_parts, collapse = "-")
        }
      }
      
      temp_data <- data.frame(
        species = eco_data$scientific_name,
        lat = as.numeric(eco_data$latitude),
        lon = as.numeric(eco_data$longitude),
        year = as.numeric(eco_data$year),
        month = as.numeric(eco_data$month),
        day = as.numeric(eco_data$day),
        date_recorded = date_recorded,
        source = "Ecoengine",
        stringsAsFactors = FALSE
      )
      
      temp_data <- temp_data[complete.cases(temp_data[, c("lat", "lon")]), ]
      biodiversity_ecoengine <- rbind(biodiversity_ecoengine, temp_data)
      cat("Retrieved", nrow(temp_data), "records from bbox", i, "\n")
    }
    
  }, error = function(e) {
    cat("Error with Ecoengine bbox", i, ":", e$message, "\n")
  })
}

# Process Ecoengine data similar to GBIF
if (nrow(biodiversity_ecoengine) > 0) {
  biodiversity_ecoengine <- biodiversity_ecoengine[!duplicated(
    biodiversity_ecoengine[, c('species', 'lat', 'lon')]
  ), ]
  
  biodiversity_ecoengine_sf <- st_as_sf(
    biodiversity_ecoengine, 
    coords = c("lon", "lat"), 
    crs = crs_geo_wgs
  )
  
  goc_ecoengine <- st_intersection(biodiversity_ecoengine_sf, goc.shape)
  
  if (nrow(goc_ecoengine) > 0) {
    coords <- st_coordinates(goc_ecoengine)
    biodiversity_ecoengine_final <- data.frame(
      st_drop_geometry(goc_ecoengine),
      lon = coords[, "X"],
      lat = coords[, "Y"]
    )
  } else {
    biodiversity_ecoengine_final <- data.frame()
  }
  
  write.csv(biodiversity_ecoengine_final, 
           file.path(savepath, "Ecoengine_biodiver_species_goc.csv"), 
           row.names = FALSE)
  cat("Ecoengine final dataset:", nrow(biodiversity_ecoengine_final), "records\n")
}

#' Read and process OBIS CSV files using modern functions
print("Processing OBIS data...")
obis_files <- list.files(datafiles, pattern = "OBIS.*\\.csv$", full.names = TRUE)
biodiversity_obis <- data.frame()

for (file in obis_files) {
  tryCatch({
    obis_data <- read.csv(file, stringsAsFactors = FALSE)
    
    # Standardize column names (adjust based on actual OBIS data structure)
    if (ncol(obis_data) >= 3) {
      # Try to extract date information if available
      date_recorded <- rep(NA_character_, nrow(obis_data))
      year_val <- rep(NA, nrow(obis_data))
      month_val <- rep(NA, nrow(obis_data))
      day_val <- rep(NA, nrow(obis_data))
      
      # Check for date columns in OBIS data
      if (ncol(obis_data) > 3) {
        date_cols <- names(obis_data)
        # Look for common OBIS date column names
        year_col <- grep("year|año", date_cols, ignore.case = TRUE, value = TRUE)
        month_col <- grep("month|mes", date_cols, ignore.case = TRUE, value = TRUE)
        day_col <- grep("day|dia", date_cols, ignore.case = TRUE, value = TRUE)
        date_col <- grep("date|fecha|eventdate", date_cols, ignore.case = TRUE, value = TRUE)
        
        if (length(year_col) > 0) {
          year_val <- as.numeric(obis_data[[year_col[1]]])
        }
        if (length(month_col) > 0) {
          month_val <- as.numeric(obis_data[[month_col[1]]])
        }
        if (length(day_col) > 0) {
          day_val <- as.numeric(obis_data[[day_col[1]]])
        }
        if (length(date_col) > 0) {
          date_recorded <- as.character(obis_data[[date_col[1]]])
        } else {
          # Construct date from year, month, day if available
          for (j in seq_len(nrow(obis_data))) {
            date_parts <- c()
            if (!is.na(year_val[j])) date_parts <- c(date_parts, year_val[j])
            if (!is.na(month_val[j])) date_parts <- c(date_parts, sprintf("%02d", month_val[j]))
            if (!is.na(day_val[j])) date_parts <- c(date_parts, sprintf("%02d", day_val[j]))
            
            if (length(date_parts) >= 1) {
              date_recorded[j] <- paste(date_parts, collapse = "-")
            }
          }
        }
      }
      
      temp_data <- data.frame(
        species = obis_data[, 1],  # Adjust column indices as needed
        lat = as.numeric(obis_data[, 2]),
        lon = as.numeric(obis_data[, 3]),
        year = year_val,
        month = month_val,
        day = day_val,
        date_recorded = date_recorded,
        source = "OBIS",
        stringsAsFactors = FALSE
      )
      
      temp_data <- temp_data[complete.cases(temp_data[, c("lat", "lon")]), ]
      biodiversity_obis <- rbind(biodiversity_obis, temp_data)
    }
    
  }, error = function(e) {
    cat("Error reading OBIS file", basename(file), ":", e$message, "\n")
  })
}

# Process OBIS data
if (nrow(biodiversity_obis) > 0) {
  biodiversity_obis <- biodiversity_obis[!duplicated(
    biodiversity_obis[, c('species', 'lat', 'lon')]
  ), ]
  
  biodiversity_obis_sf <- st_as_sf(
    biodiversity_obis, 
    coords = c("lon", "lat"), 
    crs = crs_geo_wgs
  )
  
  goc_obis <- st_intersection(biodiversity_obis_sf, goc.shape)
  
  if (nrow(goc_obis) > 0) {
    coords <- st_coordinates(goc_obis)
    biodiversity_obis_final <- data.frame(
      st_drop_geometry(goc_obis),
      lon = coords[, "X"],
      lat = coords[, "Y"]
    )
  } else {
    biodiversity_obis_final <- data.frame()
  }
  
  write.csv(biodiversity_obis_final, 
           file.path(savepath, "OBIS_biodiver_species_goc.csv"), 
           row.names = FALSE)
  cat("OBIS final dataset:", nrow(biodiversity_obis_final), "records\n")
}

#' Read and process UABCS Excel files using readxl
print("Processing UABCS data...")
uabcs_files <- list.files(datafiles, pattern = "UABCS.*\\.(xlsx|xls)$", full.names = TRUE)
biodiversity_uabcs <- data.frame()

for (file in uabcs_files) {
  tryCatch({
    uabcs_data <- read_excel(file)
    
    if (ncol(uabcs_data) >= 3) {
      # Try to extract date information if available
      date_recorded <- rep(NA_character_, nrow(uabcs_data))
      year_val <- rep(NA, nrow(uabcs_data))
      month_val <- rep(NA, nrow(uabcs_data))
      day_val <- rep(NA, nrow(uabcs_data))
      
      # Check for date columns in UABCS data
      if (ncol(uabcs_data) > 3) {
        date_cols <- names(uabcs_data)
        # Look for common date column names
        year_col <- grep("year|año", date_cols, ignore.case = TRUE, value = TRUE)
        month_col <- grep("month|mes", date_cols, ignore.case = TRUE, value = TRUE)
        day_col <- grep("day|dia", date_cols, ignore.case = TRUE, value = TRUE)
        date_col <- grep("date|fecha|eventdate", date_cols, ignore.case = TRUE, value = TRUE)
        
        if (length(year_col) > 0) {
          year_val <- as.numeric(uabcs_data[[year_col[1]]])
        }
        if (length(month_col) > 0) {
          month_val <- as.numeric(uabcs_data[[month_col[1]]])
        }
        if (length(day_col) > 0) {
          day_val <- as.numeric(uabcs_data[[day_col[1]]])
        }
        if (length(date_col) > 0) {
          date_recorded <- as.character(uabcs_data[[date_col[1]]])
        } else {
          # Construct date from year, month, day if available
          for (j in seq_len(nrow(uabcs_data))) {
            date_parts <- c()
            if (!is.na(year_val[j])) date_parts <- c(date_parts, year_val[j])
            if (!is.na(month_val[j])) date_parts <- c(date_parts, sprintf("%02d", month_val[j]))
            if (!is.na(day_val[j])) date_parts <- c(date_parts, sprintf("%02d", day_val[j]))
            
            if (length(date_parts) >= 1) {
              date_recorded[j] <- paste(date_parts, collapse = "-")
            }
          }
        }
      }
      
      temp_data <- data.frame(
        species = uabcs_data[[1]],  # First column
        lat = as.numeric(uabcs_data[[2]]),  # Second column
        lon = as.numeric(uabcs_data[[3]]),  # Third column
        year = year_val,
        month = month_val,
        day = day_val,
        date_recorded = date_recorded,
        source = "UABCS",
        stringsAsFactors = FALSE
      )
      
      temp_data <- temp_data[complete.cases(temp_data[, c("lat", "lon")]), ]
      biodiversity_uabcs <- rbind(biodiversity_uabcs, temp_data)
    }
    
  }, error = function(e) {
    cat("Error reading UABCS file", basename(file), ":", e$message, "\n")
  })
}

# Process UABCS data
if (nrow(biodiversity_uabcs) > 0) {
  biodiversity_uabcs <- biodiversity_uabcs[!duplicated(
    biodiversity_uabcs[, c('species', 'lat', 'lon')]
  ), ]
  
  biodiversity_uabcs_sf <- st_as_sf(
    biodiversity_uabcs, 
    coords = c("lon", "lat"), 
    crs = crs_geo_wgs
  )
  
  goc_uabcs <- st_intersection(biodiversity_uabcs_sf, goc.shape)
  
  if (nrow(goc_uabcs) > 0) {
    coords <- st_coordinates(goc_uabcs)
    biodiversity_uabcs_final <- data.frame(
      st_drop_geometry(goc_uabcs),
      lon = coords[, "X"],
      lat = coords[, "Y"]
    )
  } else {
    biodiversity_uabcs_final <- data.frame()
  }
  
  write.csv(biodiversity_uabcs_final, 
           file.path(savepath, "UABCS_biodiver_species_goc.csv"), 
           row.names = FALSE)
  cat("UABCS final dataset:", nrow(biodiversity_uabcs_final), "records\n")
}

#' Query VertNet using point grid
print("Querying VertNet database...")
# Create point grid for VertNet queries (simplified approach)
goc_bbox <- st_bbox(goc.shape)
grid_points <- expand.grid(
  lon = seq(goc_bbox["xmin"], goc_bbox["xmax"], length.out = 10),
  lat = seq(goc_bbox["ymin"], goc_bbox["ymax"], length.out = 10)
)

biodiversity_vertnet <- data.frame()

for (i in seq_len(min(20, nrow(grid_points)))) {  # Limit queries for testing
  tryCatch({
    point <- grid_points[i, ]
    
    vertnet_data <- vertnet_search(
      q = "*",
      limit = 1000,
      lat = point$lat,
      lon = point$lon,
      radius = 50  # 50km radius
    )
    
    if (!is.null(vertnet_data$data) && nrow(vertnet_data$data) > 0) {
      # Extract date information if available
      year_col <- if("year" %in% names(vertnet_data$data)) vertnet_data$data$year else rep(NA, nrow(vertnet_data$data))
      month_col <- if("month" %in% names(vertnet_data$data)) vertnet_data$data$month else rep(NA, nrow(vertnet_data$data))
      day_col <- if("day" %in% names(vertnet_data$data)) vertnet_data$data$day else rep(NA, nrow(vertnet_data$data))
      eventdate_col <- if("eventdate" %in% names(vertnet_data$data)) vertnet_data$data$eventdate else rep(NA, nrow(vertnet_data$data))
      
      # Create date_recorded field
      date_recorded <- rep(NA_character_, nrow(vertnet_data$data))
      if (!all(is.na(eventdate_col))) {
        date_recorded <- as.character(eventdate_col)
      } else {
        for (j in seq_len(nrow(vertnet_data$data))) {
          date_parts <- c()
          if (!is.na(year_col[j])) date_parts <- c(date_parts, year_col[j])
          if (!is.na(month_col[j])) date_parts <- c(date_parts, sprintf("%02d", month_col[j]))
          if (!is.na(day_col[j])) date_parts <- c(date_parts, sprintf("%02d", day_col[j]))
          
          if (length(date_parts) >= 1) {
            date_recorded[j] <- paste(date_parts, collapse = "-")
          }
        }
      }
      
      temp_data <- data.frame(
        species = vertnet_data$data$scientificname,
        lat = as.numeric(vertnet_data$data$decimalLatitude),
        lon = as.numeric(vertnet_data$data$decimalLongitude),
        year = year_col,
        month = month_col,
        day = day_col,
        date_recorded = date_recorded,
        source = "VertNet",
        stringsAsFactors = FALSE
      )
      
      temp_data <- temp_data[complete.cases(temp_data[, c("lat", "lon")]), ]
      biodiversity_vertnet <- rbind(biodiversity_vertnet, temp_data)
      cat("Retrieved", nrow(temp_data), "records from point", i, "\n")
    }
    
  }, error = function(e) {
    cat("Error with VertNet point", i, ":", e$message, "\n")
  })
}

# Process VertNet data
if (nrow(biodiversity_vertnet) > 0) {
  biodiversity_vertnet <- biodiversity_vertnet[!duplicated(
    biodiversity_vertnet[, c('species', 'lat', 'lon')]
  ), ]
  
  biodiversity_vertnet_sf <- st_as_sf(
    biodiversity_vertnet, 
    coords = c("lon", "lat"), 
    crs = crs_geo_wgs
  )
  
  goc_vertnet <- st_intersection(biodiversity_vertnet_sf, goc.shape)
  
  if (nrow(goc_vertnet) > 0) {
    coords <- st_coordinates(goc_vertnet)
    biodiversity_vertnet_final <- data.frame(
      st_drop_geometry(goc_vertnet),
      lon = coords[, "X"],
      lat = coords[, "Y"]
    )
  } else {
    biodiversity_vertnet_final <- data.frame()
  }
  
  write.csv(biodiversity_vertnet_final, 
           file.path(savepath, "VertNet_biodiver_species_goc.csv"), 
           row.names = FALSE)
  cat("VertNet final dataset:", nrow(biodiversity_vertnet_final), "records\n")
}

print("Data_biodiversity.R completed successfully!")
cat("All processed datasets saved to:", savepath, "\n")
