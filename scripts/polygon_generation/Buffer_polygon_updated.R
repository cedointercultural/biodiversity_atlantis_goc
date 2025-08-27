#' Buffer_polygon.R - UPDATED VERSION
#' Migrated from deprecated packages (rgdal, rgeos, maptools, gdata, reshape, plyr)
#' 
#' Creates a buffer around a polygon shapefile

# Clean workspace
rm(list=ls())

# Updated package list - modern alternatives
required_packages <- c(
  "sf", "ggplot2", "RColorBrewer", "classInt", "raster", "rasterVis", "dplyr"
)

# Install and load packages
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

# Define working directories and projections
pathToSaveShapes <- "E:/Archivos/1Archivos/Articulos/En preparacion/Biodiversity_model/Analysis/SIG_Biodiversity"

# Lambert Conformal Conic projection for accurate area calculations
crs_geo <- "+proj=lcc +lat_1=17.5 +lat_2=29.5 +lat_0=0 +lon_0=-102 +x_0=2000000 +y_0=0 +datum=NAD27 +units=m +no_defs"

# Base file name (without extension)
base_file_name <- "nacional_lam"

#' Read input shapefile using sf
print("Reading input shapefile...")
tryCatch({
  # Read shapefile using sf
  all_rg <- st_read(pathToSaveShapes, base_file_name)
  
  # Ensure the CRS is set correctly
  all_rg <- st_transform(all_rg, crs_geo)
  
  cat("Successfully loaded shapefile:", base_file_name, "\n")
  cat("Number of features:", nrow(all_rg), "\n")
  cat("CRS:", st_crs(all_rg)$input, "\n")
  
}, error = function(e) {
  stop("Error reading shapefile: ", e$message)
})

#' Calculate polygon area using sf
print("Calculating polygon area...")
poly_area <- st_area(all_rg)
total_area <- sum(as.numeric(poly_area))

cat("Total polygon area:", format(total_area, scientific = TRUE), "square meters\n")
cat("Total polygon area:", round(total_area / 1e6, 2), "square kilometers\n")

#' Create 10km buffer around polygon using sf
print("Creating 10km buffer...")
buffer_distance <- 10000  # 10km in meters

tryCatch({
  # Create buffer using sf (much simpler than rgeos)
  naamp_10km <- st_buffer(all_rg, dist = buffer_distance)
  
  cat("Buffer created successfully\n")
  cat("Buffer distance:", buffer_distance / 1000, "km\n")
  
  # Calculate buffered area
  buffered_area <- st_area(naamp_10km)
  total_buffered_area <- sum(as.numeric(buffered_area))
  
  cat("Buffered polygon area:", format(total_buffered_area, scientific = TRUE), "square meters\n")
  cat("Buffered polygon area:", round(total_buffered_area / 1e6, 2), "square kilometers\n")
  cat("Area increase:", round((total_buffered_area - total_area) / 1e6, 2), "square kilometers\n")
  
}, error = function(e) {
  stop("Error creating buffer: ", e$message)
})

#' Save buffered polygon as shapefile using sf
output_filename <- "Mexico_lm_buffer_10km"
print(paste("Saving buffered polygon as:", output_filename))

tryCatch({
  # Save as shapefile using sf
  st_write(naamp_10km, 
          file.path(pathToSaveShapes, paste0(output_filename, ".shp")), 
          delete_dsn = TRUE)  # Overwrite if exists
  
  cat("Buffered shapefile saved successfully\n")
  
}, error = function(e) {
  stop("Error saving shapefile: ", e$message)
})

#' Optional: Create visualization
print("Creating visualization...")
tryCatch({
  # Create a simple plot to visualize the result
  ggplot() +
    geom_sf(data = all_rg, fill = "lightblue", color = "blue", alpha = 0.7) +
    geom_sf(data = naamp_10km, fill = NA, color = "red", size = 1) +
    labs(title = paste("Original Polygon vs 10km Buffer"),
         subtitle = paste("Original area:", round(total_area / 1e6, 2), "km²",
                         "| Buffered area:", round(total_buffered_area / 1e6, 2), "km²")) +
    theme_minimal() +
    theme(axis.text = element_text(size = 8))
  
  # Save plot
  ggsave(file.path(pathToSaveShapes, paste0(output_filename, "_visualization.png")), 
         width = 10, height = 8, dpi = 300)
  
  cat("Visualization saved\n")
  
}, error = function(e) {
  cat("Warning: Could not create visualization:", e$message, "\n")
})

#' Summary information
print("=== BUFFER OPERATION SUMMARY ===")
cat("Input shapefile:", base_file_name, "\n")
cat("Output shapefile:", output_filename, "\n")
cat("Buffer distance:", buffer_distance / 1000, "km\n")
cat("Original area:", round(total_area / 1e6, 2), "km²\n")
cat("Buffered area:", round(total_buffered_area / 1e6, 2), "km²\n")
cat("Area increase:", round((total_buffered_area - total_area) / 1e6, 2), "km²\n")
cat("Percentage increase:", round(((total_buffered_area - total_area) / total_area) * 100, 1), "%\n")

print("Buffer_polygon.R completed successfully!")

#' Additional functions for different buffer distances
create_multiple_buffers <- function(input_shapefile, distances_km, output_dir) {
  #' Function to create multiple buffers with different distances
  #' 
  #' @param input_shapefile sf object with the input polygon
  #' @param distances_km vector of buffer distances in kilometers
  #' @param output_dir output directory for shapefiles
  
  for (dist_km in distances_km) {
    dist_m <- dist_km * 1000
    
    cat("Creating", dist_km, "km buffer...\n")
    
    tryCatch({
      buffered <- st_buffer(input_shapefile, dist = dist_m)
      
      output_name <- paste0("Mexico_lm_buffer_", dist_km, "km")
      st_write(buffered, 
               file.path(output_dir, paste0(output_name, ".shp")), 
               delete_dsn = TRUE)
      
      cat("Saved:", output_name, "\n")
      
    }, error = function(e) {
      cat("Error creating", dist_km, "km buffer:", e$message, "\n")
    })
  }
}

# Example usage (commented out):
# create_multiple_buffers(all_rg, c(5, 10, 20, 50), pathToSaveShapes)
