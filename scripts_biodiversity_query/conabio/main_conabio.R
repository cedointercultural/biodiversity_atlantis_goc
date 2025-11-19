#' Script Principal CONABIO - Coordinador del Flujo Completo
#' Author: Ricardo Cavieses-Nuñez
#' Date: August 2025
#' Email: rcavieses@gmail.com
#' 
#' Este script coordina todo el flujo de descarga, extracción y análisis
#' de los datos de biodiversidad de CONABIO

# Clear workspace
rm(list=ls())

# Set working directory to the conabio folder
setwd(file.path(dirname(rstudioapi::getSourceEditorContext()$path)))

# Configure CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Function to display header
show_header <- function() {
  cat("\n")
  cat("######################################################\n")
  cat("#                                                    #\n")
  cat("#           CONABIO BIODIVERSITY DATA                #\n")
  cat("#         Complete Processing Pipeline               #\n")
  cat("#                                                    #\n")
  cat("######################################################\n")
  cat("\n")
  cat("Author: Ricardo Cavieses-Nuñez\n")
  cat("Date: ", format(Sys.Date(), "%B %d, %Y"), "\n")
  cat("Working Directory: ", getwd(), "\n")
  cat("\n")
}

# Function to display menu
show_menu <- function() {
  cat("CONABIO Data Processing Menu\n")
  cat("============================\n")
  cat("1. Download ZIP files from CONABIO\n")
  cat("2. Extract and explore data from ZIP files\n")
  cat("3. Run complete workflow (download + extract + analyze)\n")
  cat("4. View project status and statistics\n")
  cat("5. Clean temporary files\n")
  cat("6. View help and documentation\n")
  cat("7. Exit\n")
  cat("\nEnter your choice (1-7): ")
}

# Function to check project status
check_status <- function() {
  cat("\nCONABIO Project Status\n")
  cat("======================\n")
  
  # Check downloads
  downloads_dir <- file.path("data", "downloads")
  if (dir.exists(downloads_dir)) {
    zip_files <- list.files(downloads_dir, pattern = "\\.zip$")
    cat("Downloaded ZIP files:", length(zip_files), "\n")
    if (length(zip_files) > 0) {
      total_size <- sum(file.size(file.path(downloads_dir, zip_files))) / 1024 / 1024
      cat("Total download size:", round(total_size, 2), "MB\n")
    }
  } else {
    cat("No downloads directory found\n")
  }
  
  # Check extractions
  extracted_dir <- file.path("data", "extracted")
  if (dir.exists(extracted_dir)) {
    subdirs <- list.dirs(extracted_dir, recursive = FALSE)
    cat("Extracted taxonomic groups:", length(subdirs), "\n")
    if (length(subdirs) > 0) {
      for (subdir in subdirs) {
        group_name <- basename(subdir)
        csv_files <- list.files(subdir, pattern = "\\.csv$")
        cat("  -", group_name, ":", length(csv_files), "CSV files\n")
      }
    }
  } else {
    cat("No extracted data directory found\n")
  }
  
  # Check reports
  reports_dir <- "reports"
  if (dir.exists(reports_dir)) {
    report_files <- list.files(reports_dir, pattern = "\\.(csv|md|rds)$")
    cat("Report files:", length(report_files), "\n")
  } else {
    cat("No reports directory found\n")
  }
  
  cat("\n")
}

# Function to run downloads
run_downloads <- function() {
  cat("\n>>> Starting CONABIO ZIP downloads...\n")
  script_path <- file.path("scripts", "download_conabio_zips.R")
  
  if (file.exists(script_path)) {
    tryCatch({
      source(script_path, echo = FALSE)
      cat("✓ Downloads completed successfully!\n")
      return(TRUE)
    }, error = function(e) {
      cat("✗ Download failed:", e$message, "\n")
      return(FALSE)
    })
  } else {
    cat("✗ Download script not found:", script_path, "\n")
    return(FALSE)
  }
}

# Function to run extraction and exploration
run_extraction <- function() {
  cat("\n>>> Starting data extraction and exploration...\n")
  script_path <- file.path("scripts", "explore_conabio_data.R")
  
  if (file.exists(script_path)) {
    tryCatch({
      source(script_path, echo = FALSE)
      cat("✓ Extraction completed successfully!\n")
      return(TRUE)
    }, error = function(e) {
      cat("✗ Extraction failed:", e$message, "\n")
      return(FALSE)
    })
  } else {
    cat("✗ Extraction script not found:", script_path, "\n")
    return(FALSE)
  }
}

# Function to run complete workflow
run_complete_workflow <- function() {
  cat("\n>>> Running complete CONABIO workflow...\n")
  cat("This will download ZIP files and extract/analyze the data.\n")
  
  # Step 1: Downloads
  cat("\n=== STEP 1: DOWNLOADING DATA ===\n")
  download_success <- run_downloads()
  
  if (!download_success) {
    cat("✗ Workflow stopped due to download errors.\n")
    return(FALSE)
  }
  
  # Step 2: Extraction
  cat("\n=== STEP 2: EXTRACTING AND ANALYZING DATA ===\n")
  extract_success <- run_extraction()
  
  if (!extract_success) {
    cat("✗ Workflow completed downloads but extraction failed.\n")
    return(FALSE)
  }
  
  cat("\n✓ Complete workflow finished successfully!\n")
  cat("\nProject Summary:\n")
  check_status()
  
  return(TRUE)
}

# Function to clean temporary files
clean_temp_files <- function() {
  cat("\nCleaning temporary files...\n")
  
  temp_dirs <- c(
    file.path("data", "scraped_conabio"),
    file.path("data", "conabio_downloads"),
    file.path("data", "conabio_extracted")
  )
  
  files_removed <- 0
  for (temp_dir in temp_dirs) {
    if (dir.exists(temp_dir)) {
      temp_files <- list.files(temp_dir, full.names = TRUE, recursive = TRUE)
      if (length(temp_files) > 0) {
        unlink(temp_dir, recursive = TRUE)
        files_removed <- files_removed + length(temp_files)
        cat("Removed directory:", temp_dir, "\n")
      }
    }
  }
  
  if (files_removed > 0) {
    cat("✓ Cleaned", files_removed, "temporary files\n")
  } else {
    cat("No temporary files found to clean\n")
  }
}

# Function to show help
show_help <- function() {
  cat("\nCONABIO Data Processing Help\n")
  cat("============================\n\n")
  
  cat("This pipeline processes biodiversity data from CONABIO databases.\n\n")
  
  cat("WORKFLOW:\n")
  cat("1. Downloads ZIP files from URLs in 'Links CONABIO_2025.xlsx'\n")
  cat("2. Extracts CSV files from ZIP archives\n")
  cat("3. Analyzes data structure and generates reports\n\n")
  
  cat("DATA STRUCTURE:\n")
  cat("- downloads/: Original ZIP files from CONABIO\n")
  cat("- extracted/: CSV files organized by taxonomic group\n")
  cat("- reports/: Analysis summaries and metadata\n\n")
  
  cat("REQUIREMENTS:\n")
  cat("- Excel file 'Links CONABIO_2025.xlsx' in parent directory\n")
  cat("- Internet connection for downloads\n")
  cat("- R packages: readxl, readr, dplyr, stringr, purrr\n\n")
  
  cat("For detailed documentation, see README.md and README_webscraping.md\n\n")
}

# Main execution loop
main_loop <- function() {
  show_header()
  
  repeat {
    show_menu()
    choice <- readline()
    
    switch(choice,
      "1" = {
        success <- run_downloads()
        if (success) {
          cat("\nDownloads completed. You can now run extraction (option 2).\n")
        }
      },
      "2" = {
        success <- run_extraction()
        if (success) {
          cat("\nExtraction completed. Check the data/extracted directory.\n")
        }
      },
      "3" = {
        success <- run_complete_workflow()
        if (success) {
          cat("\nComplete workflow finished! All data is ready for analysis.\n")
        }
      },
      "4" = {
        check_status()
      },
      "5" = {
        clean_temp_files()
      },
      "6" = {
        show_help()
      },
      "7" = {
        cat("\nExiting CONABIO Data Processor. Goodbye!\n")
        break
      },
      {
        cat("Invalid choice. Please enter a number between 1 and 7.\n")
      }
    )
    
    cat("\nPress Enter to continue...")
    readline()
  }
}

# Check if required Excel file exists
excel_file <- file.path("..", "Links CONABIO_2025.xlsx")
if (!file.exists(excel_file)) {
  cat("WARNING: Excel file 'Links CONABIO_2025.xlsx' not found in parent directory.\n")
  cat("Please ensure this file exists before running downloads.\n")
}

# Auto-start if running in interactive mode
if (interactive()) {
  main_loop()
} else {
  cat("CONABIO Data Processor loaded.\n")
  cat("Run main_loop() to start the interactive menu.\n")
  cat("Or run specific functions:\n")
  cat("- run_downloads()\n")
  cat("- run_extraction()\n")
  cat("- run_complete_workflow()\n")
}
