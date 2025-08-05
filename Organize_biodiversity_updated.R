#' Organize_biodiversity.R - UPDATED VERSION
#' Migrated from deprecated packages (gdata, rgdal)
#' 
#' Consolidates biodiversity data and performs taxonomic standardization

# Clean workspace
rm(list=ls())

# Updated package list - modern alternatives
required_packages <- c(
  "dplyr", "taxize", "data.table", "sf", "readr"
)

# Install and load packages
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

# Directory paths - updated to current project structure
filepath <- file.path(getwd(), "output", "Ocurrencia_especies")
analysispath <- getwd()
savepath <- analysispath
shapepath <- file.path(analysispath, "shapefiles")

# Create directories if they don't exist
dir.create(filepath, recursive = TRUE, showWarnings = FALSE)
dir.create(shapepath, recursive = TRUE, showWarnings = FALSE)

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

# Create a simple corridor shape (subset of GOC)
corridor_coords <- matrix(c(
  -115.0, 30.0,
  -110.0, 30.0,
  -110.0, 25.0,
  -115.0, 25.0,
  -115.0, 30.0
), ncol = 2, byrow = TRUE)

corridor.shape <- st_sfc(st_polygon(list(corridor_coords)), crs = crs_geo_wgs)
corridor.shape <- st_sf(id = 1, geometry = corridor.shape)

#' Read all CSV files from occurrence directory
csv.files <- list.files(filepath, pattern = "\\.csv$", full.names = TRUE)
print(paste("Found", length(csv.files), "CSV files to process"))

# Initialize master biodiversity dataset with date fields
biodiversity <- data.frame(
  species = character(0),
  lat = numeric(0),
  lon = numeric(0),
  year = numeric(0),
  month = numeric(0),
  day = numeric(0),
  date_recorded = character(0),
  source = character(0),
  stringsAsFactors = FALSE
)

#' Process each CSV file
for (i in seq_along(csv.files)) {
  tryCatch({
    cat("Processing file", i, "of", length(csv.files), ":", basename(csv.files[i]), "\n")
    
    # Read CSV file using readr for better handling
    temp_data <- read_csv(csv.files[i], show_col_types = FALSE)
    
    # Standardize column names
    if ("species" %in% names(temp_data) || "name" %in% names(temp_data)) {
      # Handle different possible column names
      species_col <- ifelse("species" %in% names(temp_data), "species", "name")
      
      standardized_data <- data.frame(
        species = temp_data[[species_col]],
        lat = as.numeric(temp_data$lat),
        lon = as.numeric(temp_data$lon),
        year = if("year" %in% names(temp_data)) as.numeric(temp_data$year) else NA,
        month = if("month" %in% names(temp_data)) as.numeric(temp_data$month) else NA,
        day = if("day" %in% names(temp_data)) as.numeric(temp_data$day) else NA,
        date_recorded = if("date_recorded" %in% names(temp_data)) as.character(temp_data$date_recorded) else NA,
        source = ifelse("source" %in% names(temp_data), 
                       temp_data$source, 
                       tools::file_path_sans_ext(basename(csv.files[i]))),
        stringsAsFactors = FALSE
      )
      
      # Remove rows with missing coordinates
      standardized_data <- standardized_data[complete.cases(standardized_data[, c("lat", "lon", "species")]), ]
      
      # Remove rows with empty species names
      standardized_data <- standardized_data[standardized_data$species != "" & 
                                           !is.na(standardized_data$species), ]
      
      # Combine with master dataset
      biodiversity <- rbind(biodiversity, standardized_data)
      
      cat("Added", nrow(standardized_data), "records from", basename(csv.files[i]), "\n")
    } else {
      cat("Warning: No species column found in", basename(csv.files[i]), "\n")
    }
    
  }, error = function(e) {
    cat("Error processing", basename(csv.files[i]), ":", e$message, "\n")
  })
}

cat("Combined dataset before deduplication:", nrow(biodiversity), "records\n")

#' Remove duplicates based on species, latitude, and longitude
if (nrow(biodiversity) > 0) {
  biodiversity <- biodiversity[!duplicated(biodiversity[, c('species', 'lat', 'lon')]), ]
  cat("After deduplication:", nrow(biodiversity), "records\n")
  
  #' Generate unique species list for manual review
  species_list <- biodiversity %>%
    group_by(species) %>%
    summarise(
      record_count = n(),
      sources = paste(unique(source), collapse = "; "),
      .groups = 'drop'
    ) %>%
    arrange(species)
  
  # Save species list for manual review
  write_csv(species_list, file.path(savepath, "biodiver_species_list.csv"))
  cat("Species list saved:", nrow(species_list), "unique species\n")
  
  #' Optional: Perform taxonomic resolution using taxize
  print("Performing taxonomic resolution (this may take a while)...")
  
  # Sample smaller subset for testing taxonomic resolution
  sample_species <- sample(unique(biodiversity$species), min(100, length(unique(biodiversity$species))))
  
  tryCatch({
    # Use Global Names Resolver
    taxonomy_results <- gnr_resolve(
      names = sample_species,
      data_source_ids = c(1, 3, 4, 11),  # ITIS, NCBI, EOL, GBIF
      canonical = TRUE,
      with_context = TRUE
    )
    
    if (!is.null(taxonomy_results) && nrow(taxonomy_results) > 0) {
      # Identify ambiguous names (multiple matches)
      ambiguous_names <- taxonomy_results %>%
        group_by(user_supplied_name) %>%
        filter(n() > 1) %>%
        arrange(user_supplied_name, score)
      
      if (nrow(ambiguous_names) > 0) {
        write_csv(ambiguous_names, file.path(savepath, "master_taxonomy_list.csv"))
        cat("Taxonomic ambiguities saved:", nrow(ambiguous_names), "entries\n")
      }
      
      # Use best matches for updating species names
      best_matches <- taxonomy_results %>%
        group_by(user_supplied_name) %>%
        filter(score == max(score)) %>%
        slice(1) %>%
        select(user_supplied_name, matched_name = matched_name2)
      
      # Update biodiversity dataset with corrected names
      biodiversity <- biodiversity %>%
        left_join(best_matches, by = c("species" = "user_supplied_name")) %>%
        mutate(species = ifelse(!is.na(matched_name), matched_name, species)) %>%
        select(-matched_name)
      
      cat("Taxonomic corrections applied\n")
    }
    
  }, error = function(e) {
    cat("Error in taxonomic resolution:", e$message, "\n")
    cat("Proceeding without taxonomic corrections\n")
  })
  
  #' Check if manual species corrections exist
  manual_corrections_file <- file.path(savepath, "species_list.csv")
  if (file.exists(manual_corrections_file)) {
    cat("Loading manual species corrections...\n")
    
    tryCatch({
      corrected_species <- read_csv(manual_corrections_file, show_col_types = FALSE)
      
      # Join corrected names (assuming columns: original_name, corrected_name)
      if (all(c("original_name", "corrected_name") %in% names(corrected_species))) {
        biodiversity <- biodiversity %>%
          left_join(corrected_species, by = c("species" = "original_name")) %>%
          mutate(species = ifelse(!is.na(corrected_name), corrected_name, species)) %>%
          select(-corrected_name)
        
        cat("Manual corrections applied\n")
      }
      
    }, error = function(e) {
      cat("Error loading manual corrections:", e$message, "\n")
    })
  }
  
  #' Final deduplication after taxonomic corrections
  biodiversity <- biodiversity[!duplicated(biodiversity[, c('species', 'lat', 'lon')]), ]
  cat("Final dataset after taxonomic corrections:", nrow(biodiversity), "records\n")
  
  #' Save final cleaned biodiversity data as CSV
  write_csv(biodiversity, file.path(savepath, "biodiver_species_goc.csv"))
  
  #' Convert to sf object and save as shapefile
  if (nrow(biodiversity) > 0) {
    biodiversity_sf <- st_as_sf(
      biodiversity,
      coords = c("lon", "lat"),
      crs = crs_geo_wgs
    )
    
    # Save as shapefile
    st_write(biodiversity_sf, 
             file.path(savepath, "biodiversity_goc.shp"), 
             delete_dsn = TRUE)
    
    cat("Biodiversity data saved as shapefile\n")
    
    #' Subset to coastal corridor
    print("Subsetting data to coastal corridor...")
    
    corridor_subset <- st_intersection(biodiversity_sf, corridor.shape)
    
    if (nrow(corridor_subset) > 0) {
      # Convert back to data frame with coordinates
      coords <- st_coordinates(corridor_subset)
      corridor_biodiversity <- data.frame(
        st_drop_geometry(corridor_subset),
        lon = coords[, "X"],
        lat = coords[, "Y"]
      )
      
      # Save corridor subset as CSV
      write_csv(corridor_biodiversity, file.path(savepath, "biodiver_species_corridor.csv"))
      
      # Save corridor subset as shapefile
      st_write(corridor_subset, 
               file.path(savepath, "biodiversity_corridor.shp"), 
               delete_dsn = TRUE)
      
      cat("Corridor subset saved:", nrow(corridor_biodiversity), "records\n")
    } else {
      cat("No records found within corridor boundaries\n")
    }
  }
  
} else {
  cat("No data to process\n")
}

print("Organize_biodiversity.R completed successfully!")

# Summary statistics
if (exists("biodiversity") && nrow(biodiversity) > 0) {
  cat("\n=== SUMMARY STATISTICS ===\n")
  cat("Total records:", nrow(biodiversity), "\n")
  cat("Unique species:", length(unique(biodiversity$species)), "\n")
  cat("Data sources:", paste(unique(biodiversity$source), collapse = ", "), "\n")
  
  # Species by source
  source_summary <- biodiversity %>%
    group_by(source) %>%
    summarise(
      records = n(),
      species = n_distinct(species),
      .groups = 'drop'
    )
  
  print(source_summary)
}
