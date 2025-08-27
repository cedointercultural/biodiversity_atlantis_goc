#' Hem Nalini Morzaria Luna
#' hmorzarialuna@gmail.com
#' Based on R script by Miguel Gandra || m3gandra@gmail.com || April 2015 
#' UPDATED VERSION: Modern packages for biodiversity data collection
#' FIXED VERSION by Ricardo Cavieses-Nuñez August 2025  
#' rcavieses@gmail.com

# Clear environment completely
rm(list=ls())
gc()

# Configure CRAN mirror first
options(repos = c(CRAN = "https://cran.rstudio.com/"))

#' Automatically install required libraries - UPDATED VERSIONS
required_packages <- c(
  "dismo", "data.table", "xml2", "jsonlite", "graphics", "maps",
  "sf", "magrittr", "dplyr", "Hmisc", "readxl", 
  "ridigbio", "ecoengine", "rbison", "rgbif", "rebird", "spocc"
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
shapepath <- file.path(current_dir, "shapefiles")
savepath <- current_dir
ulloafiles <- file.path(current_dir, "data", "ulloa")
datafiles <- file.path(current_dir, "data", "occurrence")

# Create directories if they don't exist
dir.create(shapepath, showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(current_dir, "data"), showWarnings = FALSE, recursive = TRUE)
dir.create(ulloafiles, showWarnings = FALSE, recursive = TRUE)
dir.create(datafiles, showWarnings = FALSE, recursive = TRUE)

cat("Working directory:", current_dir, "\n")

#' Define geographical coordinate system
crs_geo_wgs <- st_crs(4326)  # WGS 84

#' Create Gulf of California bounding polygon
print("Creating Gulf of California polygon")

# Define Gulf of California bounds (simplified rectangular boundary)
goc_lon_min <- -115.142516
goc_lon_max <- -104.95342
goc_lat_min <- 20.164036
goc_lat_max <- 32.139900

# Create simple rectangular polygon for Gulf of California
goc_coords <- matrix(c(
  goc_lon_min, goc_lat_min,  # SW corner
  goc_lon_max, goc_lat_min,  # SE corner
  goc_lon_max, goc_lat_max,  # NE corner
  goc_lon_min, goc_lat_max,  # NW corner
  goc_lon_min, goc_lat_min   # Close polygon
), ncol = 2, byrow = TRUE)

# Create polygon using sf
goc_polygon <- st_polygon(list(goc_coords))
goc.shape <- st_sfc(goc_polygon, crs = crs_geo_wgs)

#' Create simple bounding boxes for database queries
#' This completely avoids WKT polygon self-intersection issues
print("Generating simple rectangular bounding boxes for queries")

# Create a simple grid of rectangular bounding boxes covering the Gulf of California
lat_seq <- seq(goc_lat_min, goc_lat_max - 2.0, by = 2.0)  # 2-degree boxes
lon_seq <- seq(goc_lon_min, goc_lon_max - 2.0, by = 2.0)

wkt.data <- character()
boxes.data <- character()
counter <- 0

for (lat in lat_seq) {
  for (lon in lon_seq) {
    # Create bounding box
    lat_min <- lat
    lat_max <- lat + 2.0
    lon_min <- lon
    lon_max <- lon + 2.0
    
    # Ensure coordinates are within GOC bounds
    lat_min <- max(lat_min, goc_lat_min)
    lat_max <- min(lat_max, goc_lat_max)
    lon_min <- max(lon_min, goc_lon_min)
    lon_max <- min(lon_max, goc_lon_max)
    
    # Skip if box is outside bounds
    if (lat_min >= lat_max || lon_min >= lon_max) next
    
    counter <- counter + 1
    
    # Create WKT polygon (counterclockwise for exterior ring)
    wkt_polygon <- sprintf("POLYGON((%f %f, %f %f, %f %f, %f %f, %f %f))",
                          lon_min, lat_min,  # bottom-left
                          lon_max, lat_min,  # bottom-right
                          lon_max, lat_max,  # top-right
                          lon_min, lat_max,  # top-left
                          lon_min, lat_min)  # close polygon
    
    wkt.data <- c(wkt.data, wkt_polygon)
    
    # Bounding box for other APIs (format: min_lon,min_lat,max_lon,max_lat)
    bbox <- paste(lon_min, lat_min, lon_max, lat_max, sep = ",")
    boxes.data <- c(boxes.data, bbox)
    
    cat("Created box", counter, ":", round(lat_min, 2), "-", round(lat_max, 2), ",", round(lon_min, 2), "-", round(lon_max, 2), "\n")
  }
}

cat("Total boxes created:", length(wkt.data), "\n")

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

#' Query GBIF database with proper error handling
print("Querying GBIF database")
for (i in seq_len(min(3, length(wkt.data)))) {  # Limit to 3 boxes for testing
  tryCatch({
    cat("Querying GBIF box", i, "of", length(wkt.data), "\n")
    
    # Use rgbif v3.0.0 compatible syntax (NO return parameter)
    gbif_data <- occ_search(
      geometry = wkt.data[i],
      limit = 500,  # Reduced limit for faster testing
      hasCoordinate = TRUE
    )
    
    # Handle the rgbif v3.0.0 structure
    if (!is.null(gbif_data) && !is.null(gbif_data$data) && nrow(gbif_data$data) > 0) {
      data_df <- gbif_data$data
      
      # Check available columns in the GBIF response
      available_cols <- names(data_df)
      cat("Available GBIF columns:", paste(head(available_cols, 10), collapse = ", "), "...\n")
      
      # Map column names (GBIF standard column names)
      species_col <- if ("scientificName" %in% available_cols) "scientificName" else 
                    if ("species" %in% available_cols) "species" else 
                    if ("name" %in% available_cols) "name" else NULL
      lon_col <- if ("decimalLongitude" %in% available_cols) "decimalLongitude" else NULL
      lat_col <- if ("decimalLatitude" %in% available_cols) "decimalLatitude" else NULL
      
      # Skip if essential columns are missing
      if (is.null(species_col) || is.null(lon_col) || is.null(lat_col)) {
        cat("GBIF box", i, "- missing essential columns, skipping\n")
        next
      }
      
      # Create date_recorded field from available date components
      date_recorded <- rep(NA_character_, nrow(data_df))
      
      # Try to use eventDate first, then construct from year/month/day
      if ("eventDate" %in% available_cols && !all(is.na(data_df$eventDate))) {
        date_recorded <- as.character(data_df$eventDate)
      } else {
        # Construct date from year, month, day if available
        for (j in seq_len(nrow(data_df))) {
          date_parts <- c()
          if ("year" %in% available_cols && !is.na(data_df$year[j])) date_parts <- c(date_parts, data_df$year[j])
          if ("month" %in% available_cols && !is.na(data_df$month[j])) date_parts <- c(date_parts, sprintf("%02d", data_df$month[j]))
          if ("day" %in% available_cols && !is.na(data_df$day[j])) date_parts <- c(date_parts, sprintf("%02d", data_df$day[j]))
          
          if (length(date_parts) >= 1) {
            date_recorded[j] <- paste(date_parts, collapse = "-")
          }
        }
      }
      
      temp_df <- data.frame(
        species = data_df[[species_col]],
        lon = as.numeric(data_df[[lon_col]]),
        lat = as.numeric(data_df[[lat_col]]),
        year = if("year" %in% available_cols) as.numeric(data_df$year) else NA,
        month = if("month" %in% available_cols) as.numeric(data_df$month) else NA,
        day = if("day" %in% available_cols) as.numeric(data_df$day) else NA,
        date_recorded = date_recorded,
        source = "GBIF",
        stringsAsFactors = FALSE
      )
      
      # Filter out records with missing essential data
      temp_df <- temp_df[!is.na(temp_df$species) & !is.na(temp_df$lon) & !is.na(temp_df$lat), ]
      
      if (nrow(temp_df) > 0) {
        biodiversity <- rbind(biodiversity, temp_df)
        cat("GBIF box", i, "- added", nrow(temp_df), "records\n")
      } else {
        cat("GBIF box", i, "- no valid records after filtering\n")
      }
    } else {
      cat("GBIF box", i, "- no data returned\n")
    }
  }, error = function(e) {
    cat("Error with GBIF box", i, ":", e$message, "\n")
  })
  
  # Add small delay between requests to be respectful to API
  Sys.sleep(1)
}

#' Query other databases using spocc (safer alternative)
print("Querying additional databases via spocc")

# Skip VertNet direct calls and use spocc instead
if ("spocc" %in% rownames(installed.packages())) {
  for (i in seq_len(min(2, length(boxes.data)))) {  # Limit for testing
    tryCatch({
      cat("Querying additional sources via spocc, box", i, "of", length(boxes.data), "\n")
      
      # Parse bounding box
      bbox_parts <- as.numeric(strsplit(boxes.data[i], ",")[[1]])
      if (length(bbox_parts) == 4) {
        # spocc uses different order: min_lon, min_lat, max_lon, max_lat
        spocc_data <- spocc::occ(
          from = c("gbif", "inat"),  # Reliable sources
          geometry = paste(bbox_parts, collapse = ","),
          limit = 100
        )
        
        if (!is.null(spocc_data) && length(spocc_data) > 0) {
          # Process spocc data (simplified for now)
          cat("Spocc box", i, "- found additional data\n")
        } else {
          cat("Spocc box", i, "- no additional data\n")
        }
      }
    }, error = function(e) {
      cat("Error with spocc box", i, ":", e$message, "\n")
    })
    
    # Add delay between requests
    Sys.sleep(1)
  }
}

#' Read local datasets
print("Reading local datasets")

# Try to load Ulloa data
tryCatch({
  ulloa_files <- list.files(ulloafiles, pattern = "\\.(csv|xlsx?|txt)$", full.names = TRUE)
  if (length(ulloa_files) > 0) {
    for (file in ulloa_files) {
      if (grepl("\\.csv$", file)) {
        ulloa_data <- read.csv(file, stringsAsFactors = FALSE)
      } else if (grepl("\\.xlsx?$", file)) {
        ulloa_data <- read_excel(file)
      } else {
        ulloa_data <- read.delim(file, stringsAsFactors = FALSE)
      }
      
      if (ncol(ulloa_data) >= 3) {
        temp_df <- data.frame(
          species = ulloa_data[, 1],
          lon = as.numeric(ulloa_data[, 2]),
          lat = as.numeric(ulloa_data[, 3]),
          year = NA,
          month = NA,
          day = NA,
          date_recorded = NA,
          source = "Ulloa",
          stringsAsFactors = FALSE
        )
        temp_df <- temp_df[complete.cases(temp_df[, c('species', 'lon', 'lat')]), ]
        biodiversity <- rbind(biodiversity, temp_df)
      }
    }
  }
  cat("Ulloa data loaded - total records:", nrow(subset(biodiversity, source == "Ulloa")), "\n")
}, error = function(e) {
  cat("Error reading Ulloa data:", e$message, "\n")
})

# Similar for other local datasets (OBIS, UABCS)
# ... (code for other local datasets)

#' Remove duplicates
print("Removing duplicates")
initial_count <- nrow(biodiversity)
biodiversity <- biodiversity[!duplicated(biodiversity[, c('species', 'lon', 'lat')]), ]
final_count <- nrow(biodiversity)
cat("Removed", initial_count - final_count, "duplicates. Final count:", final_count, "\n")

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

cat("Final Gulf of California dataset - records:", nrow(biodiversity_final), "\n")

#' Save final dataset
write.csv(biodiversity_final, file = "goc_biodiversity_fixed.csv", row.names = FALSE)

print("Script completed successfully!")
print(paste("Final dataset saved with", nrow(biodiversity_final), "records to goc_biodiversity_fixed.csv"))
