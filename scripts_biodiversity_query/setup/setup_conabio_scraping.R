#' Configuration and Setup Script for CONABIO Web Scraping
#' Author: Ricardo Cavieses-Nuñez
#' Date: August 2025
#' Email: rcavieses@gmail.com
#' 
#' This script provides easy setup and execution of the CONABIO web scraping process.
#' Run this script to execute the complete web scraping workflow.

# Clear workspace
rm(list=ls())

cat("CONABIO Web Scraping Setup\n")
cat("==========================\n\n")

# Set working directory to script location
script_dir <- dirname(rstudioapi::getSourceEditorContext()$path)
if (dir.exists(script_dir)) {
  setwd(script_dir)
  cat("Working directory set to:", getwd(), "\n")
} else {
  cat("Using current working directory:", getwd(), "\n")
}

# Check if required files exist
excel_file <- "Links CONABIO_2025.xlsx"
scraping_script <- "web_scrapping_conabio.R"
analysis_script <- "analyze_scraped_data.R"

cat("\nChecking required files:\n")
cat("- Excel file (", excel_file, "):", ifelse(file.exists(excel_file), "✓ Found", "✗ Missing"), "\n")
cat("- Scraping script (", scraping_script, "):", ifelse(file.exists(scraping_script), "✓ Found", "✗ Missing"), "\n")
cat("- Analysis script (", analysis_script, "):", ifelse(file.exists(analysis_script), "✓ Found", "✗ Missing"), "\n")

# Create necessary directories
data_dir <- file.path(getwd(), "data")
scraped_dir <- file.path(data_dir, "scraped_conabio")

if (!dir.exists(data_dir)) {
  dir.create(data_dir)
  cat("\nCreated data directory:", data_dir, "\n")
}

if (!dir.exists(scraped_dir)) {
  dir.create(scraped_dir, recursive = TRUE)
  cat("Created scraped data directory:", scraped_dir, "\n")
}

# Function to display menu and get user choice
show_menu <- function() {
  cat("\n\n")
  cat("CONABIO Web Scraping Menu\n")
  cat("=========================\n")
  cat("1. Run web scraping only\n")
  cat("2. Run analysis only (requires existing scraped data)\n")
  cat("3. Run complete workflow (scraping + analysis)\n")
  cat("4. Check system requirements\n")
  cat("5. View project structure\n")
  cat("6. Exit\n")
  cat("\nEnter your choice (1-6): ")
}

# Function to check system requirements
check_requirements <- function() {
  cat("\nChecking system requirements...\n")
  cat("===============================\n")
  
  # Check R version
  r_version <- R.version.string
  cat("R Version:", r_version, "\n")
  
  # Check internet connection
  internet_check <- tryCatch({
    con <- url("http://www.google.com", "r")
    close(con)
    TRUE
  }, error = function(e) FALSE)
  
  cat("Internet connection:", ifelse(internet_check, "✓ Available", "✗ Not available"), "\n")
  
  # Check required packages
  required_packages <- c(
    "readxl", "rvest", "httr", "xml2", "jsonlite", "dplyr", 
    "purrr", "stringr", "tibble", "curl", "RCurl", "progress", "lubridate"
  )
  
  cat("\nRequired packages:\n")
  for (pkg in required_packages) {
    is_installed <- requireNamespace(pkg, quietly = TRUE)
    cat("-", pkg, ":", ifelse(is_installed, "✓ Installed", "✗ Not installed"), "\n")
  }
  
  # Check file permissions
  temp_file <- tempfile()
  can_write <- tryCatch({
    writeLines("test", temp_file)
    file.remove(temp_file)
    TRUE
  }, error = function(e) FALSE)
  
  cat("\nFile write permissions:", ifelse(can_write, "✓ Available", "✗ Not available"), "\n")
}

# Function to view project structure
view_structure <- function() {
  cat("\nCurrent project structure:\n")
  cat("==========================\n")
  
  files <- list.files(getwd(), recursive = TRUE)
  dirs <- unique(dirname(files[dirname(files) != "."]))
  
  # Show directories
  if (length(dirs) > 0) {
    cat("Directories:\n")
    for (d in sort(dirs)) {
      cat("  📁", d, "\n")
    }
    cat("\n")
  }
  
  # Show R scripts
  r_files <- files[grepl("\\.R$", files, ignore.case = TRUE)]
  if (length(r_files) > 0) {
    cat("R Scripts:\n")
    for (f in sort(r_files)) {
      cat("  📄", f, "\n")
    }
    cat("\n")
  }
  
  # Show data files
  data_files <- files[grepl("\\.(csv|xlsx|xls|json|rds)$", files, ignore.case = TRUE)]
  if (length(data_files) > 0) {
    cat("Data Files:\n")
    for (f in sort(data_files)) {
      cat("  📊", f, "\n")
    }
  }
}

# Function to run web scraping
run_scraping <- function() {
  cat("\nStarting web scraping process...\n")
  cat("================================\n")
  
  if (!file.exists(scraping_script)) {
    cat("Error: Scraping script not found:", scraping_script, "\n")
    return(FALSE)
  }
  
  if (!file.exists(excel_file)) {
    cat("Error: Excel file not found:", excel_file, "\n")
    cat("Please ensure the CONABIO links Excel file is in the working directory.\n")
    return(FALSE)
  }
  
  tryCatch({
    source(scraping_script, echo = FALSE)
    cat("\nWeb scraping completed successfully!\n")
    return(TRUE)
  }, error = function(e) {
    cat("Error during web scraping:", e$message, "\n")
    return(FALSE)
  })
}

# Function to run analysis
run_analysis <- function() {
  cat("\nStarting data analysis...\n")
  cat("========================\n")
  
  if (!file.exists(analysis_script)) {
    cat("Error: Analysis script not found:", analysis_script, "\n")
    return(FALSE)
  }
  
  if (!dir.exists(scraped_dir)) {
    cat("Error: No scraped data directory found:", scraped_dir, "\n")
    cat("Please run web scraping first.\n")
    return(FALSE)
  }
  
  rds_files <- list.files(scraped_dir, pattern = "\\.rds$")
  if (length(rds_files) == 0) {
    cat("Error: No scraped data files found in:", scraped_dir, "\n")
    cat("Please run web scraping first.\n")
    return(FALSE)
  }
  
  tryCatch({
    source(analysis_script, echo = FALSE)
    # Run the analysis function that should be available after sourcing
    if (exists("analyze_scraped_data")) {
      analysis_results <- analyze_scraped_data()
      cat("\nData analysis completed successfully!\n")
      return(TRUE)
    } else {
      cat("Error: analyze_scraped_data function not found in analysis script.\n")
      return(FALSE)
    }
  }, error = function(e) {
    cat("Error during analysis:", e$message, "\n")
    return(FALSE)
  })
}

# Main execution loop
main_loop <- function() {
  repeat {
    show_menu()
    choice <- readline()
    
    switch(choice,
      "1" = {
        success <- run_scraping()
        if (success) {
          cat("\nWeb scraping completed. You can now run analysis (option 2) or exit.\n")
        }
      },
      "2" = {
        success <- run_analysis()
        if (success) {
          cat("\nAnalysis completed. Check the output directory for results.\n")
        }
      },
      "3" = {
        cat("\nRunning complete workflow...\n")
        scraping_success <- run_scraping()
        if (scraping_success) {
          cat("\nWeb scraping successful. Starting analysis...\n")
          analysis_success <- run_analysis()
          if (analysis_success) {
            cat("\nComplete workflow finished successfully!\n")
          }
        } else {
          cat("\nWorkflow stopped due to scraping errors.\n")
        }
      },
      "4" = {
        check_requirements()
      },
      "5" = {
        view_structure()
      },
      "6" = {
        cat("\nExiting CONABIO Web Scraping Setup. Goodbye!\n")
        break
      },
      {
        cat("Invalid choice. Please enter a number between 1 and 6.\n")
      }
    )
  }
}

# Auto-start if running in interactive mode
if (interactive()) {
  cat("\nWelcome to the CONABIO Web Scraping Tool!\n")
  cat("This tool will help you scrape biodiversity data from CONABIO database links.\n")
  
  # Check if we can start immediately
  if (file.exists(excel_file) && file.exists(scraping_script)) {
    cat("\nAll required files found. Ready to start!\n")
  } else {
    cat("\nSome required files are missing. Please check the file list above.\n")
  }
  
  main_loop()
} else {
  cat("\nConfiguration script loaded. You can now run:\n")
  cat("- run_scraping() to start web scraping\n")
  cat("- run_analysis() to analyze scraped data\n")
  cat("- check_requirements() to check system requirements\n")
  cat("- view_structure() to see project structure\n")
}
