#' Hem Nalini Morzaria Luna
#' hmorzarialuna@gmail.com
#' Based on R script by Miguel Gandra || m3gandra@gmail.com || April 2015 
#' UPDATED VERSION: Modern packages for biodiversity data collection
#'UPPDATED VERSION by Ricardo Cavieses-Nuñez August 2025  
#' rcavieses@gmail.com
rm(list=ls())

# Configure CRAN mirror first
options(repos = c(CRAN = "https://cran.rstudio.com/"))

#' Automatically install required libraries - UPDATED VERSIONS
required_packages <- c(
  "dismo", "data.table", "xml2", "jsonlite", "graphics", "maps",
  "sf", "magrittr", "dplyr", "Hmisc", "readxl", 
  "ridigbio", "rvertnet", "ecoengine", "rbison", "rgbif", "rebird"
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

# Directory paths - Updated to current project directory
current_dir <- getwd()
workpath <- current_dir
shapepath <- file.path(current_dir, "shapefiles")  # Crear carpeta si no existe
savepath <- current_dir
ulloafiles <- file.path(current_dir, "data", "ulloa")
datafiles <- file.path(current_dir, "data", "occurrence")

# Create directories if they don't exist
dir.create(shapepath, showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(current_dir, "data"), showWarnings = FALSE, recursive = TRUE)
dir.create(ulloafiles, showWarnings = FALSE, recursive = TRUE)
dir.create(datafiles, showWarnings = FALSE, recursive = TRUE)

cat("Working directory:", current_dir, "\n")
cat("Shapefile directory:", shapepath, "\n")
cat("Save directory:", savepath, "\n")

# Projections - Updated to use sf CRS format
crs_geo_wgs <- "EPSG:4326"  # WGS84 geographic
crs_lcc <- "+proj=lcc +lat_1=17.5 +lat_2=29.5 +lat_0=0 +lon_0=-102 +x_0=2000000 +y_0=0 +datum=NAD27 +units=m +no_defs"

# Create Gulf of California boundary programmatically since shapefile doesn't exist
cat("Creating Gulf of California boundary...\n")

# Gulf of California approximate boundary coordinates
goc_coords <- matrix(c(
  -115.0, 32.0,   # North-west
  -109.5, 32.0,   # North-east  
  -109.5, 23.0,   # South-east
  -115.0, 23.0,   # South-west
  -115.0, 32.0    # Close polygon
), ncol = 2, byrow = TRUE)

# Create polygon using sf
goc_polygon <- st_polygon(list(goc_coords))
goc.shape <- st_sfc(goc_polygon, crs = crs_geo_wgs)
goc.shape <- st_sf(id = 1, geometry = goc.shape)

cat("Gulf of California boundary created successfully.\n")

setwd(workpath)

#' Create bounding polygon for the Gulf of California using sf
lat = c(32.139900, 20.164036, 20.164036, 32.139900, 32.139900)  # Close polygon
lon = c(-115.142516, -115.142516, -104.95342, -104.95342, -115.142516)

# Create polygon using sf
goc_coords <- cbind(lon, lat)
goc_pol <- st_polygon(list(goc_coords))
goc_pol <- st_sfc(goc_pol, crs = crs_geo_wgs)

#' Create point grid for the Gulf of California
#' Using sf to create regular grid
goc_bbox <- st_bbox(goc_pol)
goc_grid <- st_make_grid(goc_pol, n = c(70, 59))  # Approximate 4000 points
goc_points <- st_centroid(goc_grid)

# Convert to coordinates for WKT creation
goc_coords_matrix <- st_coordinates(goc_points)

#' Create WKT polygons for database queries
boxes = length(goc_points) - 70  # Adjust for grid structure
wkt.data = character(boxes)
boxes.data = character(boxes)

print("Generating point grids")

counter = 0
for (i in 1:boxes) {
  if (counter + 61 <= nrow(goc_coords_matrix)) {
    corner1 = paste(goc_coords_matrix[counter + 1, ], collapse = " ")
    corner2 = paste(goc_coords_matrix[counter + 2, ], collapse = " ")
    corner3 = paste(goc_coords_matrix[counter + 62, ], collapse = " ")
    corner4 = paste(goc_coords_matrix[counter + 61, ], collapse = " ")
    
    coords = paste(corner1, corner2, corner3, corner4, corner1, sep = " ,")
    wkt.data[i] = paste("POLYGON((", coords, "))", sep = "")
    
    # Bounding boxes for ecoengine
    boxes.data[i] = paste(
      goc_coords_matrix[counter + 1, 1], goc_coords_matrix[counter + 1, 2],
      goc_coords_matrix[counter + 62, 1], goc_coords_matrix[counter + 62, 2],
      sep = ","
    )
    
    counter = counter + 1
    print(counter)
  }
}

# Remove empty entries
wkt.data <- wkt.data[wkt.data != ""]
boxes.data <- boxes.data[boxes.data != ""]

#' Initialize biodiversity data frame with date fields
biodiversity <- data.frame(
  species = character(0),
  lon = numeric(0),
  lat = numeric(0),
  year = numeric(0),
  month = numeric(0),
  day = numeric(0),
  date_recorded = character(0),
  source = character(0),
  stringsAsFactors = FALSE
)

#' Query databases (updated API calls)
print("Querying GBIF database")
for (i in seq_len(min(5, length(wkt.data)))) {  # Limit for testing
  tryCatch({
    gbif_data <- occ_search(
      geometry = wkt.data[i],
      return = 'data',
      fields = c("name", "decimalLatitude", "decimalLongitude", "year", "month", "day", "eventDate"),
      limit = 10000
    )
    
    if (!is.null(gbif_data) && nrow(gbif_data) > 0) {
      # Create date_recorded field from available date components
      date_recorded <- rep(NA_character_, nrow(gbif_data))
      
      # Try to use eventDate first, then construct from year/month/day
      if ("eventDate" %in% names(gbif_data) && !all(is.na(gbif_data$eventDate))) {
        date_recorded <- as.character(gbif_data$eventDate)
      } else {
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
      }
      
      temp_df <- data.frame(
        species = gbif_data$name,
        lon = gbif_data$decimalLongitude,
        lat = gbif_data$decimalLatitude,
        year = ifelse("year" %in% names(gbif_data) && !is.na(gbif_data$year), gbif_data$year, NA),
        month = ifelse("month" %in% names(gbif_data) && !is.na(gbif_data$month), gbif_data$month, NA),
        day = ifelse("day" %in% names(gbif_data) && !is.na(gbif_data$day), gbif_data$day, NA),
        date_recorded = date_recorded,
        source = "GBIF",
        stringsAsFactors = FALSE
      )
      temp_df <- temp_df[complete.cases(temp_df[, c('species', 'lon', 'lat')]), ]
      biodiversity <- rbind(biodiversity, temp_df)
      print(paste("GBIF polygon", i, "- records:", nrow(temp_df)))
    }
  }, error = function(e) {
    print(paste("Error with GBIF polygon", i, ":", e$message))
  })
}

#' Query other databases with similar updated approach
print("Querying VertNet database")
for (i in seq_len(min(3, length(wkt.data)))) {  # Limit for testing
  tryCatch({
    vertnet_data <- vertnet_search(
      q = paste("*"),
      spatial = list(geometry = wkt.data[i]),
      limit = 5000
    )
    
    if (!is.null(vertnet_data$data) && nrow(vertnet_data$data) > 0) {
      # Extract date information if available
      year_col <- ifelse("year" %in% names(vertnet_data$data), vertnet_data$data$year, NA)
      month_col <- ifelse("month" %in% names(vertnet_data$data), vertnet_data$data$month, NA)
      day_col <- ifelse("day" %in% names(vertnet_data$data), vertnet_data$data$day, NA)
      eventdate_col <- ifelse("eventdate" %in% names(vertnet_data$data), vertnet_data$data$eventdate, NA)
      
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
      
      temp_df <- data.frame(
        species = vertnet_data$data$scientificname,
        lon = as.numeric(vertnet_data$data$decimalLongitude),
        lat = as.numeric(vertnet_data$data$decimalLatitude),
        year = ifelse(length(year_col) > 0 && !is.na(year_col), year_col, NA),
        month = ifelse(length(month_col) > 0 && !is.na(month_col), month_col, NA),
        day = ifelse(length(day_col) > 0 && !is.na(day_col), day_col, NA),
        date_recorded = date_recorded,
        source = "VertNet",
        stringsAsFactors = FALSE
      )
      temp_df <- temp_df[complete.cases(temp_df[, c('species', 'lon', 'lat')]), ]
      biodiversity <- rbind(biodiversity, temp_df)
      print(paste("VertNet polygon", i, "- records:", nrow(temp_df)))
    }
  }, error = function(e) {
    print(paste("Error with VertNet polygon", i, ":", e$message))
  })
}

#' Read local datasets using updated functions
print("Reading local datasets")

# Read Ulloa data
tryCatch({
  setwd(ulloafiles)
  ulloa_files <- list.files(pattern = "\\.csv$", full.names = TRUE)
  for (file in ulloa_files) {
    ulloa_data <- read.csv(file, stringsAsFactors = FALSE)
    if (ncol(ulloa_data) >= 3) {
      # Assume columns are species, lon, lat (adjust as needed)
      # Try to extract date information if available in additional columns
      date_recorded <- rep(NA_character_, nrow(ulloa_data))
      year_val <- rep(NA, nrow(ulloa_data))
      month_val <- rep(NA, nrow(ulloa_data))
      day_val <- rep(NA, nrow(ulloa_data))
      
      # Check if there are date columns (common names: date, year, month, day, eventDate)
      if (ncol(ulloa_data) > 3) {
        date_cols <- names(ulloa_data)[4:ncol(ulloa_data)]
        date_col_matches <- grep("date|year|month|day|tiempo|fecha", date_cols, ignore.case = TRUE)
        
        if (length(date_col_matches) > 0) {
          # Try to extract year from first date-related column
          date_col_idx <- 3 + date_col_matches[1]
          date_data <- ulloa_data[, date_col_idx]
          
          # Try to parse dates
          if (is.character(date_data) || is.factor(date_data)) {
            date_recorded <- as.character(date_data)
            # Try to extract year from date strings
            year_matches <- regmatches(date_data, regexpr("\\b(19|20)\\d{2}\\b", date_data))
            year_val[year_matches != ""] <- as.numeric(year_matches[year_matches != ""])
          }
        }
      }
      
      temp_df <- data.frame(
        species = ulloa_data[, 1],
        lon = as.numeric(ulloa_data[, 2]),
        lat = as.numeric(ulloa_data[, 3]),
        year = year_val,
        month = month_val,
        day = day_val,
        date_recorded = date_recorded,
        source = "Ulloa",
        stringsAsFactors = FALSE
      )
      temp_df <- temp_df[complete.cases(temp_df[, c('species', 'lon', 'lat')]), ]
      biodiversity <- rbind(biodiversity, temp_df)
    }
  }
  print(paste("Ulloa data loaded - total records:", nrow(biodiversity)))
}, error = function(e) {
  print(paste("Error reading Ulloa data:", e$message))
})

# Read OBIS data
tryCatch({
  setwd(datafiles)
  obis_files <- list.files(pattern = "OBIS.*\\.csv$", full.names = TRUE)
  for (file in obis_files) {
    obis_data <- read.csv(file, stringsAsFactors = FALSE)
    if (ncol(obis_data) >= 3) {
      # Adjust column names as needed
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
      
      temp_df <- data.frame(
        species = obis_data[, 1],
        lon = as.numeric(obis_data[, 2]),
        lat = as.numeric(obis_data[, 3]),
        year = year_val,
        month = month_val,
        day = day_val,
        date_recorded = date_recorded,
        source = "OBIS",
        stringsAsFactors = FALSE
      )
      temp_df <- temp_df[complete.cases(temp_df[, c('species', 'lon', 'lat')]), ]
      biodiversity <- rbind(biodiversity, temp_df)
    }
  }
  print(paste("OBIS data loaded - total records:", nrow(biodiversity)))
}, error = function(e) {
  print(paste("Error reading OBIS data:", e$message))
})

# Read UABCS Excel data using readxl
tryCatch({
  uabcs_files <- list.files(pattern = "UABCS.*\\.(xlsx|xls)$", full.names = TRUE)
  for (file in uabcs_files) {
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
      
      temp_df <- data.frame(
        species = uabcs_data[[1]],
        lon = as.numeric(uabcs_data[[2]]),
        lat = as.numeric(uabcs_data[[3]]),
        year = year_val,
        month = month_val,
        day = day_val,
        date_recorded = date_recorded,
        source = "UABCS",
        stringsAsFactors = FALSE
      )
      temp_df <- temp_df[complete.cases(temp_df[, c('species', 'lon', 'lat')]), ]
      biodiversity <- rbind(biodiversity, temp_df)
    }
  }
  print(paste("UABCS data loaded - total records:", nrow(biodiversity)))
}, error = function(e) {
  print(paste("Error reading UABCS data:", e$message))
})

#' Remove duplicates
print("Removing duplicates")
biodiversity <- biodiversity[!duplicated(biodiversity[, c('species', 'lon', 'lat')]), ]
print(paste("After deduplication - total records:", nrow(biodiversity)))

#' Spatial subset to Gulf of California using sf
print("Performing spatial subset to Gulf of California")
if (nrow(biodiversity) > 0) {
  # Convert biodiversity data to sf object
  biodiversity_sf <- st_as_sf(
    biodiversity, 
    coords = c("lon", "lat"), 
    crs = crs_geo_wgs
  )
  
  # Spatial intersection with GOC shapefile
  goc_subset <- st_intersection(biodiversity_sf, goc.shape)
  
  # Convert back to data frame with coordinates
  if (nrow(goc_subset) > 0) {
    coords <- st_coordinates(goc_subset)
    biodiversity_final <- data.frame(
      species = goc_subset$species,
      lon = coords[, "X"],
      lat = coords[, "Y"],
      year = if("year" %in% names(goc_subset)) goc_subset$year else NA,
      month = if("month" %in% names(goc_subset)) goc_subset$month else NA,
      day = if("day" %in% names(goc_subset)) goc_subset$day else NA,
      date_recorded = if("date_recorded" %in% names(goc_subset)) goc_subset$date_recorded else NA,
      source = goc_subset$source,
      stringsAsFactors = FALSE
    )
  } else {
    biodiversity_final <- data.frame(
      species = character(0),
      lon = numeric(0),
      lat = numeric(0),
      year = numeric(0),
      month = numeric(0),
      day = numeric(0),
      date_recorded = character(0),
      source = character(0),
      stringsAsFactors = FALSE
    )
  }
} else {
  biodiversity_final <- biodiversity
}

print(paste("Final Gulf of California dataset - records:", nrow(biodiversity_final)))

#' Save final dataset
setwd(savepath)
write.csv(biodiversity_final, file = "goc_biodiversity.csv", row.names = FALSE)

print("Script completed successfully!")
print(paste("Final dataset saved with", nrow(biodiversity_final), "records"))
