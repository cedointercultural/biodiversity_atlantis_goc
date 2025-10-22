#' MIGRATION_GUIDE.R
#' Comprehensive migration guide for Atlantis GOC Biodiversity Project
#' 
#' This script provides step-by-step migration instructions and code examples
#' for updating all scripts from deprecated packages to modern alternatives

# ============================================================================
# PACKAGE MIGRATION SUMMARY
# ============================================================================

#' Critical Package Migrations Required:
#' 
#' RETIRED PACKAGES (October 2023):
#' - rgdal    → sf (for vector data) + terra (for raster data)
#' - rgeos    → sf (geometry operations built-in)
#' - maptools → sf (modern spatial operations)
#' 
#' DEPRECATED/PROBLEMATIC PACKAGES:
#' - gdata    → readr, readxl (data import)
#' - SDMTools → terra, raster (spatial analysis)
#' - PBSmapping → sf (mapping and spatial operations)
#' - reshape  → tidyr (data reshaping)
#' - plyr     → dplyr (data manipulation)
#' - XML      → xml2 (XML parsing)
#' - spocc    → Direct API calls to GBIF, VertNet, etc.

# ============================================================================
# INSTALLATION OF MODERN PACKAGES
# ============================================================================

install_modern_packages <- function() {
  #' Install all modern replacement packages
  
  modern_packages <- c(
    # Spatial data packages
    "sf",           # Replaces rgdal, rgeos, maptools
    "terra",        # Modern raster operations
    "fasterize",    # Fast rasterization
    
    # Data manipulation
    "dplyr",        # Replaces plyr
    "tidyr",        # Replaces reshape
    "readr",        # Replaces gdata for CSV
    "readxl",       # Replaces gdata for Excel
    "data.table",   # Fast data operations
    
    # Web APIs and data sources
    "rgbif",        # GBIF data
    "rvertnet",     # VertNet data
    "ecoengine",    # Berkeley Ecoengine
    "rbison",       # USGS BISON
    "rebird",       # eBird data
    
    # Visualization and analysis
    "ggplot2",      # Advanced plotting
    "raster",       # Raster operations (compatibility)
    "rasterVis",    # Raster visualization
    "sperich",      # Species richness modeling
    "taxize",       # Taxonomic name resolution
    "xml2",         # XML parsing (replaces XML)
    
    # Utility packages
    "magrittr",     # Pipe operators
    "httr",         # HTTP requests
    "jsonlite",     # JSON handling
    "fields"        # Spatial statistics
  )
  
  cat("Installing modern packages...\n")
  
  for (pkg in modern_packages) {
    if (!require(pkg, character.only = TRUE)) {
      cat("Installing:", pkg, "\n")
      install.packages(pkg)
    } else {
      cat("Already installed:", pkg, "\n")
    }
  }
  
  cat("Modern packages installation completed!\n")
}

# ============================================================================
# MIGRATION EXAMPLES BY OPERATION TYPE
# ============================================================================

#' 1. READING SPATIAL DATA
migration_examples_read_spatial <- function() {
  cat("=== READING SPATIAL DATA ===\n")
  
  cat("OLD (rgdal):\n")
  cat('library(rgdal)\n')
  cat('shapefile <- readOGR(".", "filename")\n\n')
  
  cat("NEW (sf):\n")
  cat('library(sf)\n')
  cat('shapefile <- st_read(".", "filename")\n')
  cat('# or\n')
  cat('shapefile <- st_read("filename.shp")\n\n')
}

#' 2. COORDINATE REFERENCE SYSTEMS
migration_examples_crs <- function() {
  cat("=== COORDINATE REFERENCE SYSTEMS ===\n")
  
  cat("OLD (sp/rgdal):\n")
  cat('crs_wgs84 <- CRS("+proj=longlat +datum=WGS84")\n')
  cat('shapefile <- spTransform(shapefile, crs_wgs84)\n\n')
  
  cat("NEW (sf):\n")
  cat('crs_wgs84 <- "EPSG:4326"\n')
  cat('shapefile <- st_transform(shapefile, crs_wgs84)\n\n')
}

#' 3. GEOMETRIC OPERATIONS
migration_examples_geometry <- function() {
  cat("=== GEOMETRIC OPERATIONS ===\n")
  
  cat("OLD (rgeos):\n")
  cat('buffered <- gBuffer(shapefile, width = 1000)\n')
  cat('area_value <- gArea(shapefile)\n')
  cat('intersected <- gIntersection(shp1, shp2)\n\n')
  
  cat("NEW (sf):\n")
  cat('buffered <- st_buffer(shapefile, dist = 1000)\n')
  cat('area_value <- st_area(shapefile)\n')
  cat('intersected <- st_intersection(shp1, shp2)\n\n')
}

#' 4. DATA IMPORT
migration_examples_data_import <- function() {
  cat("=== DATA IMPORT ===\n")
  
  cat("OLD (gdata):\n")
  cat('library(gdata)\n')
  cat('data <- read.xls("file.xlsx")\n\n')
  
  cat("NEW (readxl):\n")
  cat('library(readxl)\n')
  cat('data <- read_excel("file.xlsx")\n\n')
  
  cat("CSV files - OLD:\n")
  cat('data <- read.csv("file.csv", stringsAsFactors = FALSE)\n\n')
  
  cat("CSV files - NEW (readr):\n")
  cat('library(readr)\n')
  cat('data <- read_csv("file.csv")\n\n')
}

#' 5. DATA MANIPULATION
migration_examples_data_manipulation <- function() {
  cat("=== DATA MANIPULATION ===\n")
  
  cat("OLD (plyr):\n")
  cat('library(plyr)\n')
  cat('result <- ddply(data, .(species), summarise, count = length(species))\n\n')
  
  cat("NEW (dplyr):\n")
  cat('library(dplyr)\n')
  cat('result <- data %>%\n')
  cat('  group_by(species) %>%\n')
  cat('  summarise(count = n())\n\n')
}

#' 6. SPATIAL SUBSETTING
migration_examples_spatial_subset <- function() {
  cat("=== SPATIAL SUBSETTING ===\n")
  
  cat("OLD (sp/rgeos):\n")
  cat('# Convert to SpatialPointsDataFrame\n')
  cat('coordinates(data) <- ~lon+lat\n')
  cat('proj4string(data) <- CRS("+proj=longlat +datum=WGS84")\n')
  cat('subset <- data[shapefile, ]\n\n')
  
  cat("NEW (sf):\n")
  cat('# Convert to sf object\n')
  cat('data_sf <- st_as_sf(data, coords = c("lon", "lat"), crs = "EPSG:4326")\n')
  cat('subset <- st_intersection(data_sf, shapefile)\n\n')
}

# ============================================================================
# SCRIPT-SPECIFIC MIGRATION FUNCTIONS
# ============================================================================

migrate_occurrence_records <- function() {
  cat("=== MIGRATING ocurrence_records.R ===\n")
  cat("Key changes:\n")
  cat("1. Replace rgdal/rgeos/maptools with sf\n")
  cat("2. Replace XML with xml2\n")
  cat("3. Update spocc usage or use direct API calls\n")
  cat("4. Use sf for spatial operations\n\n")
  
  cat("Updated script available as: ocurrence_records_updated.R\n\n")
}

migrate_data_biodiversity <- function() {
  cat("=== MIGRATING Data_biodiversity.R ===\n")
  cat("Key changes:\n")
  cat("1. Replace gdata with readxl\n")
  cat("2. Replace maptools/PBSmapping with sf\n")
  cat("3. Replace rgdal with sf\n")
  cat("4. Update spatial operations\n\n")
  
  cat("Updated script available as: Data_biodiversity_updated.R\n\n")
}

migrate_organize_biodiversity <- function() {
  cat("=== MIGRATING Organize_biodiversity.R ===\n")
  cat("Key changes:\n")
  cat("1. Replace gdata with readr\n")
  cat("2. Replace rgdal with sf\n")
  cat("3. Update spatial operations and file I/O\n\n")
  
  cat("Updated script available as: Organize_biodiversity_updated.R\n\n")
}

migrate_buffer_polygon <- function() {
  cat("=== MIGRATING Buffer_polygon.R ===\n")
  cat("Key changes:\n")
  cat("1. Replace rgdal/rgeos/maptools with sf\n")
  cat("2. Replace gdata/reshape/plyr with modern alternatives\n")
  cat("3. Simplify buffer operations using sf\n\n")
  
  cat("Updated script available as: Buffer_polygon_updated.R\n\n")
}

migrate_richness_models <- function() {
  cat("=== MIGRATING Calculate_richness_model*.R ===\n")
  cat("Key changes:\n")
  cat("1. Replace SDMTools with terra/raster\n")
  cat("2. Replace rgdal/maptools with sf\n")
  cat("3. Replace gdata/PBSmapping with modern alternatives\n")
  cat("4. Update spatial analysis workflows\n\n")
  
  cat("Updated script available as: Calculate_richness_model_Corridor_updated.R\n\n")
}

migrate_shp2raster <- function() {
  cat("=== MIGRATING shp2raster_function.R ===\n")
  cat("Key changes:\n")
  cat("1. Replace rgdal/rgeos/maptools with sf\n")
  cat("2. Use fasterize for improved performance\n")
  cat("3. Add enhanced functionality and error handling\n\n")
  
  cat("Updated script available as: shp2raster_function_updated.R\n\n")
}

# ============================================================================
# TESTING AND VALIDATION FUNCTIONS
# ============================================================================

test_modern_packages <- function() {
  cat("=== TESTING MODERN PACKAGES ===\n")
  
  required_packages <- c("sf", "terra", "readr", "readxl", "dplyr", "tidyr")
  
  for (pkg in required_packages) {
    if (require(pkg, character.only = TRUE)) {
      cat("✓", pkg, "loaded successfully\n")
    } else {
      cat("✗", pkg, "failed to load\n")
    }
  }
}

validate_spatial_operations <- function() {
  cat("=== VALIDATING SPATIAL OPERATIONS ===\n")
  
  tryCatch({
    # Test basic sf operations
    library(sf)
    
    # Create test data
    coords <- cbind(c(-110, -109, -109, -110, -110), c(25, 25, 26, 26, 25))
    test_poly <- st_polygon(list(coords))
    test_sf <- st_sfc(test_poly, crs = "EPSG:4326")
    
    # Test operations
    buffered <- st_buffer(test_sf, dist = 0.1)
    area <- st_area(test_sf)
    
    cat("✓ sf spatial operations working correctly\n")
    cat("Test polygon area:", area, "\n")
    
  }, error = function(e) {
    cat("✗ Error in spatial operations:", e$message, "\n")
  })
}

# ============================================================================
# MAIN MIGRATION WORKFLOW
# ============================================================================

run_migration_guide <- function() {
  cat("=======================================================\n")
  cat("ATLANTIS GOC BIODIVERSITY PROJECT - MIGRATION GUIDE\n")
  cat("=======================================================\n\n")
  
  # Show migration examples
  migration_examples_read_spatial()
  migration_examples_crs()
  migration_examples_geometry()
  migration_examples_data_import()
  migration_examples_data_manipulation()
  migration_examples_spatial_subset()
  
  # Script-specific migrations
  migrate_occurrence_records()
  migrate_data_biodiversity()
  migrate_organize_biodiversity()
  migrate_buffer_polygon()
  migrate_richness_models()
  migrate_shp2raster()
  
  # Testing
  cat("=== VALIDATION ===\n")
  test_modern_packages()
  validate_spatial_operations()
  
  cat("\n=======================================================\n")
  cat("MIGRATION GUIDE COMPLETED\n")
  cat("=======================================================\n")
  cat("Next steps:\n")
  cat("1. Install modern packages using install_modern_packages()\n")
  cat("2. Replace old scripts with updated versions\n")
  cat("3. Test all workflows with sample data\n")
  cat("4. Update file paths and parameters as needed\n")
  cat("5. Validate outputs against original results\n")
}

# ============================================================================
# EXECUTION
# ============================================================================

# Uncomment to run the migration guide
# run_migration_guide()

# Uncomment to install modern packages
# install_modern_packages()

print("MIGRATION_GUIDE.R loaded successfully!")
print("Available functions:")
print("- run_migration_guide(): Complete migration overview")
print("- install_modern_packages(): Install all required modern packages")
print("- test_modern_packages(): Test package installations")
print("- validate_spatial_operations(): Test spatial functionality")
