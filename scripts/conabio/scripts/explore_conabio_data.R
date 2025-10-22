#' Script para Extraer y Explorar Datos CSV de CONABIO
#' Author: Ricardo Cavieses-Nuñez
#' Date: August 2025
#' Email: rcavieses@gmail.com

# Clear workspace
rm(list=ls())

# Configure CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Required packages
required_packages <- c("readr", "dplyr", "stringr", "utils")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# Load libraries explicitly
library(readr)
library(dplyr)
library(stringr)

# Define directories
downloads_dir <- file.path(getwd(), "data", "downloads")
extracted_dir <- file.path(getwd(), "data", "extracted")

# Create extraction directory
if (!dir.exists(extracted_dir)) {
  dir.create(extracted_dir, recursive = TRUE)
  cat("Created extraction directory:", extracted_dir, "\n")
}

# Function to extract and explore a single ZIP file
extract_and_explore_zip <- function(zip_file) {
  
  cat("\n======================================\n")
  cat("Processing:", basename(zip_file), "\n")
  cat("======================================\n")
  
  # Check if ZIP file exists and is not empty
  if (!file.exists(zip_file)) {
    cat("Error: ZIP file not found\n")
    return(NULL)
  }
  
  file_size <- file.size(zip_file)
  if (file_size == 0) {
    cat("Error: ZIP file is empty\n")
    return(NULL)
  }
  
  cat("ZIP file size:", file_size, "bytes\n")
  
  # Create subdirectory for this ZIP file
  zip_name <- tools::file_path_sans_ext(basename(zip_file))
  extract_subdir <- file.path(extracted_dir, zip_name)
  
  if (!dir.exists(extract_subdir)) {
    dir.create(extract_subdir, recursive = TRUE)
  }
  
  tryCatch({
    # List contents first
    contents <- unzip(zip_file, list = TRUE)
    cat("ZIP contains", nrow(contents), "files:\n")
    
    # Show all files in the ZIP
    for (i in 1:nrow(contents)) {
      cat(sprintf("  %2d. %-30s %10s bytes\n", 
                  i, contents$Name[i], formatC(contents$Length[i], big.mark = ",")))
    }
    
    # Extract all files
    cat("\nExtracting files...\n")
    unzip(zip_file, exdir = extract_subdir, overwrite = TRUE)
    
    # Find and analyze CSV files
    csv_files <- list.files(extract_subdir, pattern = "\\.csv$", full.names = TRUE)
    
    if (length(csv_files) == 0) {
      cat("No CSV files found after extraction\n")
      return(NULL)
    }
    
    cat("Found", length(csv_files), "CSV files\n")
    
    # Analyze each CSV file
    csv_info <- list()
    
    for (csv_file in csv_files) {
      csv_name <- basename(csv_file)
      cat("\n--- Analyzing:", csv_name, "---\n")
      
      tryCatch({
        # Try to read first few rows to understand structure
        sample_data <- read_csv(csv_file, n_max = 100, show_col_types = FALSE)
        
        info <- list(
          filename = csv_name,
          filepath = csv_file,
          file_size = file.size(csv_file),
          nrows_sample = nrow(sample_data),
          ncols = ncol(sample_data),
          column_names = names(sample_data),
          data_sample = sample_data
        )
        
        cat("  File size:", formatC(info$file_size, big.mark = ","), "bytes\n")
        cat("  Columns (", info$ncols, "):", paste(info$column_names[1:min(10, length(info$column_names))], collapse = ", "))
        if (info$ncols > 10) cat(", ...")
        cat("\n")
        
        # Look for key biodiversity columns
        col_names_lower <- tolower(info$column_names)
        
        # Species/taxonomy columns
        species_cols <- grep("especie|species|nombre.*cientifico|scientific.*name|taxon|familia|genero|genus|family", col_names_lower)
        if (length(species_cols) > 0) {
          cat("  Species/taxonomy columns:", paste(info$column_names[species_cols], collapse = ", "), "\n")
        }
        
        # Geographic columns
        geo_cols <- grep("lat|lon|coord|decimal_lat|decimal_lon|x|y|estado|municipio|localidad|country|pais", col_names_lower)
        if (length(geo_cols) > 0) {
          cat("  Geographic columns:", paste(info$column_names[geo_cols], collapse = ", "), "\n")
        }
        
        # Date columns
        date_cols <- grep("fecha|date|year|mes|month|dia|day|ano", col_names_lower)
        if (length(date_cols) > 0) {
          cat("  Date columns:", paste(info$column_names[date_cols], collapse = ", "), "\n")
        }
        
        # Show sample data
        cat("  Sample data (first 3 rows):\n")
        print(head(sample_data, 3))
        
        csv_info[[csv_name]] <- info
        
      }, error = function(e) {
        cat("  Error reading CSV:", e$message, "\n")
      })
    }
    
    return(list(
      zip_file = zip_file,
      extract_dir = extract_subdir,
      csv_info = csv_info
    ))
    
  }, error = function(e) {
    cat("Error processing ZIP file:", e$message, "\n")
    return(NULL)
  })
}

# Function to create summary report
create_summary_report <- function(extraction_results) {
  
  cat("\n\n")
  cat("########################################\n")
  cat("#          SUMMARY REPORT              #\n")
  cat("########################################\n\n")
  
  total_zips <- length(extraction_results)
  successful_extractions <- sum(!sapply(extraction_results, is.null))
  
  cat("Total ZIP files processed:", total_zips, "\n")
  cat("Successful extractions:", successful_extractions, "\n\n")
  
  # Summary table
  summary_data <- data.frame(
    Group = character(),
    ZIP_File = character(),
    CSV_Files = integer(),
    Total_Size_MB = numeric(),
    Main_Columns = character(),
    stringsAsFactors = FALSE
  )
  
  for (result in extraction_results) {
    if (!is.null(result)) {
      zip_name <- tools::file_path_sans_ext(basename(result$zip_file))
      csv_count <- length(result$csv_info)
      
      if (csv_count > 0) {
        total_size <- sum(sapply(result$csv_info, function(x) x$file_size))
        main_csv <- result$csv_info[[1]]  # First CSV file
        main_cols <- paste(main_csv$column_names[1:min(5, length(main_csv$column_names))], collapse = ", ")
        
        summary_data <- rbind(summary_data, data.frame(
          Group = zip_name,
          ZIP_File = basename(result$zip_file),
          CSV_Files = csv_count,
          Total_Size_MB = round(total_size / 1024 / 1024, 2),
          Main_Columns = main_cols,
          stringsAsFactors = FALSE
        ))
      }
    }
  }
  
  cat("BIODIVERSITY GROUPS SUMMARY:\n")
  cat("============================\n")
  print(summary_data)
  
  # Save summary
  summary_file <- file.path(extracted_dir, paste0("conabio_extraction_summary_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"))
  write.csv(summary_data, summary_file, row.names = FALSE)
  cat("\nSummary saved to:", summary_file, "\n")
  
  return(summary_data)
}

# Main function
main_extraction <- function() {
  
  cat("CONABIO Data Extraction and Exploration\n")
  cat("=======================================\n")
  
  # Find all ZIP files
  zip_files <- list.files(downloads_dir, pattern = "\\.zip$", full.names = TRUE)
  
  if (length(zip_files) == 0) {
    cat("No ZIP files found in:", downloads_dir, "\n")
    cat("Please run the download script first.\n")
    return(NULL)
  }
  
  cat("Found", length(zip_files), "ZIP files to process\n")
  cat("Extraction directory:", extracted_dir, "\n\n")
  
  # Process each ZIP file
  extraction_results <- list()
  
  for (i in seq_along(zip_files)) {
    cat(sprintf("\n[%d/%d] Processing: %s\n", i, length(zip_files), basename(zip_files[i])))
    
    result <- extract_and_explore_zip(zip_files[i])
    extraction_results[[i]] <- result
  }
  
  # Create summary report
  summary_data <- create_summary_report(extraction_results)
  
  cat("\n\nExtraction completed!\n")
  cat("Extracted data location:", extracted_dir, "\n")
  
  return(list(
    extraction_results = extraction_results,
    summary = summary_data
  ))
}

# Execute if run directly
cat("Starting CONABIO data extraction...\n")
results <- main_extraction()

if (!is.null(results)) {
  cat("\n✓ All biodiversity data has been successfully extracted and analyzed!\n")
  cat("✓ Check the 'data/conabio_extracted' directory for the CSV files.\n")
  cat("✓ Each taxonomic group has its own subdirectory with the extracted data.\n")
} else {
  cat("\n✗ Extraction failed. Please check that ZIP files are available.\n")
}
