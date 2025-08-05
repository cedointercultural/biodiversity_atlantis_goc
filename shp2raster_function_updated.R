#' shp2raster_function.R - UPDATED VERSION
#' Migrated from deprecated packages (rgdal, rgeos, maptools)
#' 
#' Function to convert shapefile to raster format using modern sf package

# Clean workspace
rm(list=ls())

# Updated package list - modern alternatives
required_packages <- c(
  "sf", "raster", "fasterize", "terra", "ggplot2"
)

# Install and load packages
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

#' Modern shp2raster function using sf and fasterize
#' 
#' @param shp sf object or path to shapefile
#' @param mask_raster RasterLayer to use as template/mask
#' @param label character string for output filename
#' @param value numeric value to assign to rasterized cells
#' @param output_dir directory to save output files
#' @param transform_crs logical, whether to transform CRS to match mask
#' @param plot_result logical, whether to plot the result
#' @param merge_with_mask logical, whether to merge with background mask
#' 
#' @return RasterLayer object
shp2raster <- function(shp, 
                      mask_raster, 
                      label = "output", 
                      value = 1,
                      output_dir = ".",
                      transform_crs = TRUE,
                      plot_result = FALSE,
                      merge_with_mask = TRUE) {
  
  # Load shapefile if path is provided
  if (is.character(shp)) {
    cat("Loading shapefile:", shp, "\n")
    tryCatch({
      shp <- st_read(shp)
    }, error = function(e) {
      stop("Error loading shapefile: ", e$message)
    })
  }
  
  # Ensure shp is an sf object
  if (!inherits(shp, "sf")) {
    stop("Input must be an sf object or path to shapefile")
  }
  
  # Check mask raster
  if (!inherits(mask_raster, "RasterLayer")) {
    stop("mask_raster must be a RasterLayer object")
  }
  
  cat("Input shapefile features:", nrow(shp), "\n")
  cat("Mask raster dimensions:", dim(mask_raster), "\n")
  
  # Transform coordinate system if needed
  if (transform_crs) {
    mask_crs <- crs(mask_raster)
    shp_crs <- st_crs(shp)
    
    if (!st_crs(shp) == st_crs(mask_crs)) {
      cat("Transforming shapefile CRS...\n")
      cat("From:", shp_crs$input, "\n")
      cat("To:", mask_crs, "\n")
      
      shp <- st_transform(shp, crs = mask_crs)
    }
  }
  
  # Rasterize shapefile using fasterize (much faster than raster::rasterize)
  cat("Rasterizing shapefile...\n")
  tryCatch({
    # Use fasterize for better performance
    if (requireNamespace("fasterize", quietly = TRUE)) {
      rasterized <- fasterize(shp, mask_raster, field = NULL, fun = "sum")
    } else {
      # Fallback to raster package
      rasterized <- rasterize(shp, mask_raster, field = 1, fun = "sum")
    }
    
    # Set values
    rasterized[!is.na(rasterized)] <- value
    
    cat("Rasterization completed\n")
    
  }, error = function(e) {
    stop("Error during rasterization: ", e$message)
  })
  
  # Merge with mask raster if requested
  if (merge_with_mask) {
    cat("Merging with mask raster...\n")
    
    # Create merged raster (background from mask, foreground from rasterized)
    merged_raster <- mask_raster
    merged_raster[!is.na(rasterized)] <- rasterized[!is.na(rasterized)]
    
    final_raster <- merged_raster
  } else {
    final_raster <- rasterized
  }
  
  # Export as GeoTIFF
  output_filename <- file.path(output_dir, paste0(label, ".tif"))
  cat("Exporting as GeoTIFF:", output_filename, "\n")
  
  tryCatch({
    writeRaster(final_raster, output_filename, format = "GTiff", overwrite = TRUE)
    cat("GeoTIFF exported successfully\n")
  }, error = function(e) {
    cat("Warning: Could not export GeoTIFF:", e$message, "\n")
  })
  
  # Optional plotting
  if (plot_result) {
    cat("Creating plot...\n")
    
    tryCatch({
      # Create plot using base R
      plot(final_raster, main = paste("Rasterized:", label),
           col = terrain.colors(100), axes = TRUE)
      
      # Add shapefile boundaries
      plot(st_geometry(shp), add = TRUE, border = "red", lwd = 1)
      
      # Save plot as PNG
      png_filename <- file.path(output_dir, paste0(label, "_plot.png"))
      dev.copy(png, png_filename, width = 800, height = 600)
      dev.off()
      
      cat("Plot saved as:", png_filename, "\n")
      
    }, error = function(e) {
      cat("Warning: Could not create plot:", e$message, "\n")
    })
  }
  
  # Summary statistics
  cat("\n=== RASTERIZATION SUMMARY ===\n")
  cat("Output label:", label, "\n")
  cat("Assigned value:", value, "\n")
  cat("Non-NA cells:", sum(!is.na(final_raster[])), "\n")
  cat("Raster extent:", extent(final_raster), "\n")
  cat("Raster resolution:", res(final_raster), "\n")
  
  if (!is.na(minValue(final_raster)) && !is.na(maxValue(final_raster))) {
    cat("Value range:", minValue(final_raster), "to", maxValue(final_raster), "\n")
  }
  
  return(final_raster)
}

#' Enhanced shp2raster function with multiple field support
#' 
#' @param shp sf object or path to shapefile
#' @param mask_raster RasterLayer to use as template/mask
#' @param field character, name of field to use for raster values
#' @param fun character, function to use when multiple features overlap ("sum", "mean", "max", "min", "first", "last")
#' @param label character string for output filename
#' @param output_dir directory to save output files
#' @param background_value numeric, value for background cells
#' 
#' @return RasterLayer object
shp2raster_field <- function(shp,
                            mask_raster,
                            field = NULL,
                            fun = "sum",
                            label = "output_field",
                            output_dir = ".",
                            background_value = NA) {
  
  # Load shapefile if path is provided
  if (is.character(shp)) {
    shp <- st_read(shp)
  }
  
  cat("Rasterizing with field:", ifelse(is.null(field), "geometry only", field), "\n")
  cat("Overlay function:", fun, "\n")
  
  # Rasterize with field values
  if (is.null(field)) {
    # Use presence/absence (1/NA)
    if (requireNamespace("fasterize", quietly = TRUE)) {
      rasterized <- fasterize(shp, mask_raster)
    } else {
      rasterized <- rasterize(shp, mask_raster)
    }
  } else {
    # Use field values
    if (requireNamespace("fasterize", quietly = TRUE)) {
      rasterized <- fasterize(shp, mask_raster, field = field, fun = fun)
    } else {
      rasterized <- rasterize(shp, mask_raster, field = field, fun = fun)
    }
  }
  
  # Set background value
  if (!is.na(background_value)) {
    rasterized[is.na(rasterized)] <- background_value
  }
  
  # Export
  output_filename <- file.path(output_dir, paste0(label, ".tif"))
  writeRaster(rasterized, output_filename, format = "GTiff", overwrite = TRUE)
  
  cat("Field-based rasterization completed\n")
  return(rasterized)
}

#' Batch processing function for multiple shapefiles
#' 
#' @param shapefile_list vector of shapefile paths
#' @param mask_raster RasterLayer template
#' @param output_dir output directory
#' @param value_list vector of values to assign (optional)
#' 
#' @return list of RasterLayer objects
batch_shp2raster <- function(shapefile_list, 
                            mask_raster, 
                            output_dir = ".",
                            value_list = NULL) {
  
  cat("Processing", length(shapefile_list), "shapefiles...\n")
  
  results <- list()
  
  for (i in 1:length(shapefile_list)) {
    shp_path <- shapefile_list[i]
    label <- tools::file_path_sans_ext(basename(shp_path))
    value <- ifelse(is.null(value_list), i, value_list[i])
    
    cat("\nProcessing", i, "of", length(shapefile_list), ":", label, "\n")
    
    tryCatch({
      result <- shp2raster(
        shp = shp_path,
        mask_raster = mask_raster,
        label = label,
        value = value,
        output_dir = output_dir,
        plot_result = FALSE
      )
      
      results[[label]] <- result
      
    }, error = function(e) {
      cat("Error processing", label, ":", e$message, "\n")
      results[[label]] <- NULL
    })
  }
  
  cat("\nBatch processing completed\n")
  cat("Successfully processed:", sum(!sapply(results, is.null)), "files\n")
  
  return(results)
}

# Example usage (commented out):
# 
# # Create example mask raster
# mask_raster <- raster(extent(-120, -100, 20, 35), resolution = 0.1)
# mask_raster[] <- 0  # Background value
# 
# # Single shapefile conversion
# result <- shp2raster(
#   shp = "path/to/shapefile.shp",
#   mask_raster = mask_raster,
#   label = "my_raster",
#   value = 1,
#   output_dir = "output/",
#   plot_result = TRUE
# )
# 
# # Field-based conversion
# result_field <- shp2raster_field(
#   shp = "path/to/shapefile.shp",
#   mask_raster = mask_raster,
#   field = "population",
#   fun = "sum",
#   label = "population_raster"
# )
# 
# # Batch processing
# shp_list <- c("shp1.shp", "shp2.shp", "shp3.shp")
# batch_results <- batch_shp2raster(shp_list, mask_raster, "output/")

print("shp2raster_function.R loaded successfully!")
print("Available functions:")
print("- shp2raster(): Basic shapefile to raster conversion")
print("- shp2raster_field(): Field-based conversion with overlay functions")
print("- batch_shp2raster(): Batch processing multiple shapefiles")
