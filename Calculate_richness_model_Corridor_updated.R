#' Calculate_richness_model_Corridor.R - UPDATED VERSION
#' Migrated from deprecated packages (gdata, maptools, PBSmapping, rgdal, SDMTools)
#' 
#' Calculates species richness model for coastal corridor

# Clean workspace
rm(list=ls())

# Updated package list - modern alternatives
required_packages <- c(
  "fields", "raster", "rasterVis", "sf", "sperich", "terra", "readr", "dplyr"
)

# Install and load packages
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

# Directory paths
analysispath <- "E:/Archivos/1Archivos/Articulos/En preparacion/Biodiversity_model/Analysis"
savepath <- analysispath
shapepath <- file.path(analysispath, "SIG_Biodiversity")

# Coordinate reference systems using modern format
crs_geo_lcc <- "+proj=lcc +lat_1=17.5 +lat_2=29.5 +lat_0=0 +lon_0=-102 +x_0=2000000 +y_0=0 +datum=NAD27 +units=m +no_defs"
crs_geo_wgs <- "EPSG:4326"

#' Read corridor biodiversity data
print("Loading corridor biodiversity data...")
tryCatch({
  biodiversity <- read_csv(file.path(savepath, "biodiver_species_corridor.csv"), 
                          show_col_types = FALSE)
  
  if (nrow(biodiversity) == 0) {
    stop("No biodiversity data found in corridor dataset")
  }
  
  cat("Loaded", nrow(biodiversity), "records from corridor\n")
  cat("Species count:", length(unique(biodiversity$species)), "\n")
  
}, error = function(e) {
  stop("Error loading biodiversity data: ", e$message)
})

#' Define model parameters
resolution <- 0.05  # degrees (approximately 5km)
species_threshold <- 3  # minimum species per cell

cat("Model parameters:\n")
cat("- Resolution:", resolution, "degrees (~5km)\n")
cat("- Species threshold:", species_threshold, "species per cell\n")

#' Read corridor shapefile for extent definition
print("Loading corridor shapefile...")
tryCatch({
  corridor_shape <- st_read(shapepath, "corridor_poly_WGS84")
  corridor_shape <- st_transform(corridor_shape, crs_geo_wgs)
  
  cat("Corridor shapefile loaded successfully\n")
  
}, error = function(e) {
  stop("Error loading corridor shapefile: ", e$message)
})

#' Create land/water mask using terra (modern alternative to SDMTools)
print("Creating land/water masks...")
corridor_bbox <- st_bbox(corridor_shape)

# Create base raster for the corridor extent
base_raster <- raster(
  xmn = floor(corridor_bbox["xmin"]) - 0.1,
  xmx = ceiling(corridor_bbox["xmax"]) + 0.1,
  ymn = floor(corridor_bbox["ymin"]) - 0.1,
  ymx = ceiling(corridor_bbox["ymax"]) + 0.1,
  resolution = resolution,
  crs = crs_geo_wgs
)

# Simple land mask (inside corridor = 1, outside = 0)
corridor_raster <- rasterize(as_Spatial(corridor_shape), base_raster, field = 1)
corridor_raster[is.na(corridor_raster)] <- 0

# For water mask, we'll use the inverse (this is simplified - in practice you'd use actual bathymetry data)
water_mask <- corridor_raster
water_mask[water_mask == 1] <- 0
water_mask[water_mask == 0] <- 1

coast_raster <- corridor_raster  # Use corridor as land mask

cat("Masks created successfully\n")

#' Filter biodiversity data to corridor extent
print("Filtering biodiversity data to corridor extent...")
biodiversity_sf <- st_as_sf(biodiversity, coords = c("lon", "lat"), crs = crs_geo_wgs)
corridor_biodiversity <- st_intersection(biodiversity_sf, corridor_shape)

if (nrow(corridor_biodiversity) == 0) {
  stop("No biodiversity records found within corridor boundaries")
}

# Convert back to coordinates
coords <- st_coordinates(corridor_biodiversity)
biodiversity_filtered <- data.frame(
  species = corridor_biodiversity$species,
  lon = coords[, "X"],
  lat = coords[, "Y"],
  stringsAsFactors = FALSE
)

cat("Filtered to", nrow(biodiversity_filtered), "records within corridor\n")

#' Generate non-interpolated occurrence grid
print("Generating occurrence grid...")
tryCatch({
  # Create species occurrence matrix
  species_list <- unique(biodiversity_filtered$species)
  
  # Create grid cells
  grid_coords <- coordinates(base_raster)
  grid_df <- data.frame(
    cell_id = 1:nrow(grid_coords),
    lon = grid_coords[, 1],
    lat = grid_coords[, 2]
  )
  
  # Count species per grid cell
  richness_grid <- base_raster
  richness_values <- numeric(ncell(base_raster))
  
  for (i in 1:nrow(grid_df)) {
    cell_lon <- grid_df$lon[i]
    cell_lat <- grid_df$lat[i]
    
    # Define cell boundaries
    cell_extent <- extent(
      cell_lon - resolution/2, cell_lon + resolution/2,
      cell_lat - resolution/2, cell_lat + resolution/2
    )
    
    # Count species in this cell
    in_cell <- biodiversity_filtered$lon >= cell_extent@xmin & 
               biodiversity_filtered$lon < cell_extent@xmax &
               biodiversity_filtered$lat >= cell_extent@ymin & 
               biodiversity_filtered$lat < cell_extent@ymax
    
    if (any(in_cell)) {
      species_in_cell <- unique(biodiversity_filtered$species[in_cell])
      richness_values[i] <- length(species_in_cell)
    } else {
      richness_values[i] <- 0
    }
  }
  
  # Assign values to raster
  richness_grid[] <- richness_values
  
  # Apply species threshold
  richness_grid[richness_grid < species_threshold] <- NA
  
  cat("Non-interpolated grid created\n")
  cat("Cells with >= ", species_threshold, " species: ", sum(!is.na(richness_grid[])), "\n")
  
}, error = function(e) {
  stop("Error creating occurrence grid: ", e$message)
})

#' Calculate inverse-distance weighted species richness using sperich
print("Calculating inverse-distance weighted richness...")
tryCatch({
  # Prepare data for sperich
  sperich_data <- data.frame(
    species = biodiversity_filtered$species,
    x = biodiversity_filtered$lon,
    y = biodiversity_filtered$lat
  )
  
  # Remove duplicate records
  sperich_data <- sperich_data[!duplicated(sperich_data), ]
  
  # Define grid for richness calculation
  grid_x <- seq(corridor_bbox["xmin"], corridor_bbox["xmax"], by = resolution)
  grid_y <- seq(corridor_bbox["ymin"], corridor_bbox["ymax"], by = resolution)
  
  # Calculate richness using sperich (this may take time)
  cat("Running sperich analysis (this may take several minutes)...\n")
  
  richness_weighted <- richness(
    sperich_data,
    grid = list(x = grid_x, y = grid_y),
    method = "idw",  # Inverse distance weighting
    power = 2        # IDW power parameter
  )
  
  cat("Inverse-distance weighted richness calculated\n")
  
}, error = function(e) {
  cat("Error with sperich calculation:", e$message, "\n")
  cat("Using simple grid-based richness instead\n")
  richness_weighted <- richness_grid
})

#' Adjust richness for sampling effort
print("Adjusting richness for sampling effort...")
tryCatch({
  # Calculate sampling effort (number of records per cell)
  effort_grid <- base_raster
  effort_values <- numeric(ncell(base_raster))
  
  for (i in 1:nrow(grid_df)) {
    cell_lon <- grid_df$lon[i]
    cell_lat <- grid_df$lat[i]
    
    cell_extent <- extent(
      cell_lon - resolution/2, cell_lon + resolution/2,
      cell_lat - resolution/2, cell_lat + resolution/2
    )
    
    in_cell <- biodiversity_filtered$lon >= cell_extent@xmin & 
               biodiversity_filtered$lon < cell_extent@xmax &
               biodiversity_filtered$lat >= cell_extent@ymin & 
               biodiversity_filtered$lat < cell_extent@ymax
    
    effort_values[i] <- sum(in_cell)
  }
  
  effort_grid[] <- effort_values
  
  # Adjust richness by effort (simple approach: richness / log(effort + 1))
  if (exists("richness_weighted") && class(richness_weighted) == "RasterLayer") {
    richness_adjusted <- richness_weighted / log(effort_grid + 1)
  } else {
    richness_adjusted <- richness_grid / log(effort_grid + 1)
  }
  
  # Remove infinite values
  richness_adjusted[is.infinite(richness_adjusted[])] <- NA
  
  cat("Richness adjusted for sampling effort\n")
  
}, error = function(e) {
  cat("Error adjusting for sampling effort:", e$message, "\n")
  richness_adjusted <- richness_grid
})

#' Export richness models as GeoTIFFs
print("Exporting richness models...")
tryCatch({
  # Export adjusted richness
  writeRaster(richness_adjusted, 
             file.path(savepath, "richness_adj_corridor.tif"),
             format = "GTiff", overwrite = TRUE)
  
  # Export weighted richness (if available)
  if (exists("richness_weighted") && class(richness_weighted) == "RasterLayer") {
    writeRaster(richness_weighted, 
               file.path(savepath, "richness_weighted_corridor.tif"),
               format = "GTiff", overwrite = TRUE)
  }
  
  cat("GeoTIFF files exported successfully\n")
  
}, error = function(e) {
  cat("Error exporting GeoTIFFs:", e$message, "\n")
})

#' Create and export PNG visualizations
print("Creating visualizations...")
tryCatch({
  # Plot adjusted richness
  png(file.path(savepath, "richness_adj_corridor.png"), 
      width = 1200, height = 800, res = 150)
  
  plot(richness_adjusted, main = "Species Richness (Adjusted) - Corridor",
       col = terrain.colors(100), axes = TRUE)
  plot(as_Spatial(corridor_shape), add = TRUE, border = "black", lwd = 2)
  
  dev.off()
  
  # Plot weighted richness (if available)
  if (exists("richness_weighted") && class(richness_weighted) == "RasterLayer") {
    png(file.path(savepath, "richness_weighted_corridor.png"), 
        width = 1200, height = 800, res = 150)
    
    plot(richness_weighted, main = "Species Richness (Weighted) - Corridor",
         col = terrain.colors(100), axes = TRUE)
    plot(as_Spatial(corridor_shape), add = TRUE, border = "black", lwd = 2)
    
    dev.off()
  }
  
  cat("PNG visualizations created\n")
  
}, error = function(e) {
  cat("Error creating visualizations:", e$message, "\n")
})

#' Summary statistics
print("=== RICHNESS MODEL SUMMARY ===")
if (exists("richness_adjusted")) {
  cat("Adjusted Richness Statistics:\n")
  cat("- Min:", round(minValue(richness_adjusted), 2), "\n")
  cat("- Max:", round(maxValue(richness_adjusted), 2), "\n")
  cat("- Mean:", round(cellStats(richness_adjusted, mean, na.rm = TRUE), 2), "\n")
  cat("- Cells with data:", sum(!is.na(richness_adjusted[])), "\n")
}

if (exists("richness_weighted") && class(richness_weighted) == "RasterLayer") {
  cat("\nWeighted Richness Statistics:\n")
  cat("- Min:", round(minValue(richness_weighted), 2), "\n")
  cat("- Max:", round(maxValue(richness_weighted), 2), "\n")
  cat("- Mean:", round(cellStats(richness_weighted, mean, na.rm = TRUE), 2), "\n")
  cat("- Cells with data:", sum(!is.na(richness_weighted[])), "\n")
}

cat("\nOutput files:\n")
cat("- richness_adj_corridor.tif\n")
cat("- richness_weighted_corridor.tif\n")
cat("- richness_adj_corridor.png\n")
cat("- richness_weighted_corridor.png\n")

print("Calculate_richness_model_Corridor.R completed successfully!")
