#' Script para extraer y procesar archivos ZIP de CONABIO
#' Author: Ricardo Cavieses-Nuñez
#' Date: August 2025
#' Email: rcavieses@gmail.com

# Clear workspace
rm(list=ls())

# Configure CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Required packages
required_packages <- c("readr", "dplyr", "stringr", "purrr", "readxl")

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
library(purrr)
library(readxl)

# Define paths
scraped_dir <- file.path(getwd(), "data", "scraped_conabio")
extracted_dir <- file.path(getwd(), "data", "extracted_csv")

# Create extraction directory
if (!dir.exists(extracted_dir)) {
  dir.create(extracted_dir, recursive = TRUE)
  cat("Created extraction directory:", extracted_dir, "\n")
}

# Function to extract ZIP content from scraped data
extract_zip_data <- function(scraped_file) {
  
  cat("Processing file:", scraped_file, "\n")
  
  # Load scraped data
  data <- readRDS(scraped_file)
  
  if (data$status != "success" || data$content_type != "html") {
    cat("Skipping - not a successful HTML scrape\n")
    return(NULL)
  }
  
  # Get the text content (which contains the ZIP data)
  zip_content <- data$text_sample
  
  if (is.null(zip_content) || is.na(zip_content) || zip_content == "") {
    cat("No content found\n")
    return(NULL)
  }
  
  # Check if it starts with PK (ZIP file signature)
  if (!grepl("^PK", zip_content)) {
    cat("Content doesn't appear to be a ZIP file\n")
    return(NULL)
  }
  
  # Extract filename from URL
  url <- data$url
  filename <- basename(url)
  filename <- gsub("\\.zip$", ".csv", filename)
  
  cat("Expected CSV filename:", filename, "\n")
  
  # Save information about this file
  file_info <- list(
    original_url = url,
    expected_filename = filename,
    scraped_at = data$scraped_at,
    has_zip_content = TRUE,
    content_sample = substr(zip_content, 1, 200)
  )
  
  return(file_info)
}

# Function to download ZIP files directly
download_zip_files <- function() {
  
  # Read the original Excel file to get URLs
  excel_file <- file.path(getwd(), "Links CONABIO_2025.xlsx")
  
  if (!file.exists(excel_file)) {
    stop("Excel file not found: ", excel_file)
  }
  
  # Read Excel file
  library(readxl)
  links_data <- read_excel(excel_file, sheet = 1)
  
  # Find URL columns
  url_columns <- names(links_data)[sapply(links_data, function(col) {
    any(grepl("http", col, ignore.case = TRUE), na.rm = TRUE)
  })]
  
  # Extract all URLs
  all_urls <- c()
  for (col in url_columns) {
    urls_in_col <- links_data[[col]][!is.na(links_data[[col]])]
    urls_in_col <- urls_in_col[urls_in_col != ""]
    all_urls <- c(all_urls, urls_in_col)
  }
  
  # Remove duplicates
  all_urls <- unique(all_urls)
  
  cat("Found", length(all_urls), "unique URLs to download\n")
  
  # Download each ZIP file
  downloaded_files <- c()
  
  for (i in seq_along(all_urls)) {
    url <- all_urls[i]
    filename <- basename(url)
    local_path <- file.path(extracted_dir, filename)
    
    cat("\nDownloading", i, "of", length(all_urls), ":", url, "\n")
    
    tryCatch({
      # Download file
      download.file(url, local_path, mode = "wb", quiet = TRUE)
      
      if (file.exists(local_path) && file.size(local_path) > 0) {
        cat("Successfully downloaded:", filename, "(", file.size(local_path), "bytes )\n")
        downloaded_files <- c(downloaded_files, local_path)
      } else {
        cat("Download failed or file is empty\n")
      }
      
    }, error = function(e) {
      cat("Error downloading:", e$message, "\n")
    })
    
    # Pause between downloads
    Sys.sleep(1)
  }
  
  return(downloaded_files)
}

# Function to extract and read CSV files from ZIP archives
extract_and_read_csvs <- function(zip_files) {
  
  csv_data_list <- list()
  
  for (zip_file in zip_files) {
    cat("\nExtracting ZIP file:", basename(zip_file), "\n")
    
    tryCatch({
      # Create temporary directory for extraction
      temp_dir <- file.path(extracted_dir, "temp")
      if (!dir.exists(temp_dir)) {
        dir.create(temp_dir)
      }
      
      # Extract ZIP file
      unzip(zip_file, exdir = temp_dir)
      
      # Find CSV files in extracted content
      csv_files <- list.files(temp_dir, pattern = "\\.csv$", full.names = TRUE, recursive = TRUE)
      
      if (length(csv_files) > 0) {
        cat("Found", length(csv_files), "CSV file(s)\n")
        
        for (csv_file in csv_files) {
          csv_name <- basename(csv_file)
          cat("Reading CSV:", csv_name, "\n")
          
          # Read CSV with error handling
          csv_data <- tryCatch({
            read_csv(csv_file, locale = locale(encoding = "UTF-8"), show_col_types = FALSE)
          }, error = function(e) {
            cat("Error reading CSV with UTF-8, trying Latin1...\n")
            tryCatch({
              read_csv(csv_file, locale = locale(encoding = "Latin1"), show_col_types = FALSE)
            }, error = function(e2) {
              cat("Error reading CSV:", e2$message, "\n")
              return(NULL)
            })
          })
          
          if (!is.null(csv_data) && nrow(csv_data) > 0) {
            # Add metadata
            csv_data$source_file <- csv_name
            csv_data$source_zip <- basename(zip_file)
            csv_data$extracted_at <- Sys.time()
            
            csv_data_list[[csv_name]] <- csv_data
            
            cat("Successfully read", nrow(csv_data), "rows with", ncol(csv_data), "columns\n")
            
            # Show first few column names
            cat("Columns:", paste(names(csv_data)[1:min(10, ncol(csv_data))], collapse = ", "), "\n")
          }
        }
      } else {
        cat("No CSV files found in ZIP archive\n")
      }
      
      # Clean up temporary directory
      unlink(temp_dir, recursive = TRUE)
      
    }, error = function(e) {
      cat("Error processing ZIP file:", e$message, "\n")
    })
  }
  
  return(csv_data_list)
}

# Function to combine and analyze biodiversity data
analyze_biodiversity_data <- function(csv_data_list) {
  
  cat("\nAnalyzing extracted biodiversity data...\n")
  cat("========================================\n")
  
  if (length(csv_data_list) == 0) {
    cat("No CSV data to analyze\n")
    return(NULL)
  }
  
  # Summary of datasets
  cat("Total datasets extracted:", length(csv_data_list), "\n\n")
  
  for (dataset_name in names(csv_data_list)) {
    data <- csv_data_list[[dataset_name]]
    cat("Dataset:", dataset_name, "\n")
    cat("- Rows:", nrow(data), "\n")
    cat("- Columns:", ncol(data), "\n")
    cat("- Source ZIP:", unique(data$source_zip), "\n")
    
    # Look for key biodiversity columns
    col_names <- tolower(names(data))
    
    # Species columns
    species_cols <- grep("especie|species|nombre.*cientifico|scientific.*name|taxon", col_names, value = TRUE)
    if (length(species_cols) > 0) {
      cat("- Species columns:", paste(species_cols, collapse = ", "), "\n")
    }
    
    # Coordinate columns
    coord_cols <- grep("lat|lon|coord|decimal_lat|decimal_lon|x|y", col_names, value = TRUE)
    if (length(coord_cols) > 0) {
      cat("- Coordinate columns:", paste(coord_cols, collapse = ", "), "\n")
    }
    
    # Date columns
    date_cols <- grep("fecha|date|year|mes|month|dia|day", col_names, value = TRUE)
    if (length(date_cols) > 0) {
      cat("- Date columns:", paste(date_cols, collapse = ", "), "\n")
    }
    
    cat("\n")
  }
  
  # Try to combine datasets with similar structure
  cat("Attempting to combine datasets...\n")
  
  # Save individual datasets
  for (dataset_name in names(csv_data_list)) {
    output_file <- file.path(extracted_dir, paste0("processed_", dataset_name))
    write_csv(csv_data_list[[dataset_name]], output_file)
    cat("Saved processed dataset:", output_file, "\n")
  }
  
  # Try to combine all datasets
  tryCatch({
    combined_data <- bind_rows(csv_data_list, .id = "dataset_id")
    
    if (nrow(combined_data) > 0) {
      combined_file <- file.path(extracted_dir, "combined_biodiversity_data.csv")
      write_csv(combined_data, combined_file)
      cat("Combined data saved to:", combined_file, "\n")
      cat("Total combined records:", nrow(combined_data), "\n")
      
      return(list(
        individual_datasets = csv_data_list,
        combined_data = combined_data,
        summary = list(
          total_datasets = length(csv_data_list),
          total_records = nrow(combined_data),
          total_columns = ncol(combined_data)
        )
      ))
    }
  }, error = function(e) {
    cat("Could not combine datasets:", e$message, "\n")
    cat("Datasets may have different structures\n")
  })
  
  return(csv_data_list)
}

# Main execution function
main_extraction <- function() {
  
  cat("CONABIO Data Extraction Process\n")
  cat("===============================\n\n")
  
  # Step 1: Analyze scraped data
  cat("Step 1: Analyzing scraped data...\n")
  scraped_files <- list.files(scraped_dir, pattern = "scraped_.*\\.rds$", full.names = TRUE)
  
  if (length(scraped_files) == 0) {
    cat("No scraped files found. Running download process instead...\n\n")
  } else {
    cat("Found", length(scraped_files), "scraped files\n")
    
    for (file in scraped_files) {
      extract_zip_data(file)
    }
  }
  
  # Step 2: Download ZIP files directly
  cat("\nStep 2: Downloading ZIP files directly...\n")
  downloaded_files <- download_zip_files()
  
  if (length(downloaded_files) == 0) {
    cat("No files downloaded successfully\n")
    return(NULL)
  }
  
  # Step 3: Extract and read CSV files
  cat("\nStep 3: Extracting and reading CSV files...\n")
  csv_data <- extract_and_read_csvs(downloaded_files)
  
  if (length(csv_data) == 0) {
    cat("No CSV data extracted\n")
    return(NULL)
  }
  
  # Step 4: Analyze biodiversity data
  cat("\nStep 4: Analyzing biodiversity data...\n")
  analysis_results <- analyze_biodiversity_data(csv_data)
  
  cat("\nExtraction and analysis completed!\n")
  return(analysis_results)
}

# Execute main function
if (interactive()) {
  cat("Ready to extract CONABIO data. Run main_extraction() to start.\n")
} else {
  results <- main_extraction()
}
