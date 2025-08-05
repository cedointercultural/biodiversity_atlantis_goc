#' Analysis Script for Scraped CONABIO Data
#' Author: Ricardo Cavieses-Nuñez
#' Date: August 2025
#' Email: rcavieses@gmail.com
#' 
#' This script provides functions to analyze and process the data
#' obtained from web scraping CONABIO links.

# Clear workspace
rm(list=ls())

# Configure CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

#' Required packages for data analysis
required_packages <- c(
  "dplyr", "purrr", "stringr", "tibble", "readr",
  "ggplot2", "DT", "knitr", "rmarkdown", "rlang"
)

# Load packages
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# Load required libraries explicitly to avoid namespace issues
library(dplyr)
library(purrr)
library(stringr)
library(tibble)
library(readr)
library(rlang)

# Define null-coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Function to load all scraped results
load_scraped_results <- function(scraped_dir = file.path(getwd(), "data", "scraped_conabio")) {
  
  cat("Loading scraped results from:", scraped_dir, "\n")
  
  if (!dir.exists(scraped_dir)) {
    stop("Scraped data directory not found: ", scraped_dir)
  }
  
  # Find all .rds files
  rds_files <- list.files(scraped_dir, pattern = "\\.rds$", full.names = TRUE)
  
  if (length(rds_files) == 0) {
    stop("No .rds files found in directory: ", scraped_dir)
  }
  
  cat("Found", length(rds_files), "result files\n")
  
  # Load all results
  results <- map(rds_files, function(file) {
    tryCatch({
      readRDS(file)
    }, error = function(e) {
      cat("Error loading file", file, ":", e$message, "\n")
      return(NULL)
    })
  })
  
  # Remove NULL results
  results <- results[!map_lgl(results, is.null)]
  
  cat("Successfully loaded", length(results), "results\n")
  return(results)
}

#' Function to create summary statistics
create_summary_stats <- function(scraped_results) {
  
  cat("Creating summary statistics...\n")
  
  # Extract basic info from each result
  summary_info <- map_dfr(scraped_results, function(result) {
    if (!is.null(result)) {
      tibble(
        url = result$url %||% "unknown",
        source = result$source %||% "unknown",
        content_type = result$content_type %||% "unknown",
        status = result$status %||% "unknown",
        scraped_at = result$scraped_at %||% Sys.time(),
        has_data = !is.null(result$data),
        has_tables = ifelse(!is.null(result$tables_count), result$tables_count > 0, FALSE),
        has_download_links = ifelse(!is.null(result$download_links), length(result$download_links) > 0, FALSE),
        error_message = result$error %||% ""
      )
    }
  })
  
  # Summary statistics
  stats <- list(
    total_urls = nrow(summary_info),
    successful_scrapes = sum(summary_info$status == "success", na.rm = TRUE),
    failed_scrapes = sum(summary_info$status == "failed", na.rm = TRUE),
    content_types = table(summary_info$content_type),
    sources = table(summary_info$source),
    urls_with_data = sum(summary_info$has_data, na.rm = TRUE),
    urls_with_tables = sum(summary_info$has_tables, na.rm = TRUE),
    urls_with_downloads = sum(summary_info$has_download_links, na.rm = TRUE)
  )
  
  return(list(
    summary_table = summary_info,
    statistics = stats
  ))
}

#' Function to extract biodiversity data from scraped results
extract_biodiversity_data <- function(scraped_results) {
  
  cat("Extracting biodiversity data...\n")
  
  biodiversity_data <- list()
  
  for (i in seq_along(scraped_results)) {
    result <- scraped_results[[i]]
    
    if (is.null(result) || result$status != "success") {
      next
    }
    
    tryCatch({
      
      if (result$content_type == "json" && !is.null(result$data)) {
        # Process JSON data
        if (is.data.frame(result$data)) {
          biodiversity_data[[i]] <- result$data %>%
            mutate(
              source_url = result$url,
              source_name = result$source,
              scraped_at = result$scraped_at
            )
        } else if (is.list(result$data)) {
          # Try to convert list to data frame
          df_data <- tryCatch({
            bind_rows(result$data)
          }, error = function(e) {
            # If that fails, try to flatten the list
            as_tibble(result$data)
          })
          
          if (nrow(df_data) > 0) {
            biodiversity_data[[i]] <- df_data %>%
              mutate(
                source_url = result$url,
                source_name = result$source,
                scraped_at = result$scraped_at
              )
          }
        }
        
      } else if (result$content_type == "csv" && !is.null(result$data)) {
        # Process CSV data
        csv_data <- read_csv(result$data, show_col_types = FALSE)
        
        if (nrow(csv_data) > 0) {
          biodiversity_data[[i]] <- csv_data %>%
            mutate(
              source_url = result$url,
              source_name = result$source,
              scraped_at = result$scraped_at
            )
        }
        
      } else if (result$content_type == "html" && !is.null(result$download_links)) {
        # For HTML pages, we mainly have download links
        # Store the download links for further processing
        download_info <- tibble(
          download_url = result$download_links,
          source_url = result$url,
          source_name = result$source,
          scraped_at = result$scraped_at
        )
        
        biodiversity_data[[i]] <- download_info
      }
      
    }, error = function(e) {
      cat("Error processing result", i, ":", e$message, "\n")
    })
  }
  
  # Combine all data
  if (length(biodiversity_data) > 0) {
    # Remove NULL elements
    biodiversity_data <- biodiversity_data[!map_lgl(biodiversity_data, is.null)]
    
    if (length(biodiversity_data) > 0) {
      # Try to combine data frames with similar structure
      combined_data <- tryCatch({
        bind_rows(biodiversity_data, .id = "result_id")
      }, error = function(e) {
        cat("Could not combine all data frames. Returning list.\n")
        return(biodiversity_data)
      })
      
      return(combined_data)
    }
  }
  
  cat("No biodiversity data could be extracted.\n")
  return(NULL)
}

#' Function to identify potential species columns
identify_species_columns <- function(data) {
  
  if (is.null(data) || !is.data.frame(data)) {
    return(NULL)
  }
  
  # Common column names for species information
  species_patterns <- c(
    "species", "scientific_name", "scientificname", "taxon", "organism",
    "binomial", "latin_name", "nombre_cientifico", "especie"
  )
  
  coordinate_patterns <- c(
    "lat", "lon", "latitude", "longitude", "decimal_latitude", "decimal_longitude",
    "x", "y", "coord", "latitud", "longitud"
  )
  
  date_patterns <- c(
    "date", "fecha", "year", "month", "day", "tiempo", "collection_date",
    "event_date", "occurrence_date"
  )
  
  # Find columns that match patterns
  column_names <- tolower(names(data))
  
  species_cols <- names(data)[str_detect(column_names, paste(species_patterns, collapse = "|"))]
  coord_cols <- names(data)[str_detect(column_names, paste(coordinate_patterns, collapse = "|"))]
  date_cols <- names(data)[str_detect(column_names, paste(date_patterns, collapse = "|"))]
  
  return(list(
    species_columns = species_cols,
    coordinate_columns = coord_cols,
    date_columns = date_cols,
    all_columns = names(data)
  ))
}

#' Function to generate analysis report
generate_analysis_report <- function(scraped_results, output_dir = getwd()) {
  
  cat("Generating analysis report...\n")
  
  # Create summary
  summary_stats <- create_summary_stats(scraped_results)
  
  # Extract biodiversity data
  biodiversity_data <- extract_biodiversity_data(scraped_results)
  
  # Identify species columns if data exists
  species_info <- NULL
  if (!is.null(biodiversity_data) && is.data.frame(biodiversity_data)) {
    species_info <- identify_species_columns(biodiversity_data)
  }
  
  # Create report
  report_content <- paste0(
    "# CONABIO Web Scraping Analysis Report\n\n",
    "Generated on: ", Sys.time(), "\n\n",
    "## Summary Statistics\n\n",
    "- Total URLs processed: ", summary_stats$statistics$total_urls, "\n",
    "- Successful scrapes: ", summary_stats$statistics$successful_scrapes, "\n",
    "- Failed scrapes: ", summary_stats$statistics$failed_scrapes, "\n",
    "- URLs with data: ", summary_stats$statistics$urls_with_data, "\n",
    "- URLs with tables: ", summary_stats$statistics$urls_with_tables, "\n",
    "- URLs with download links: ", summary_stats$statistics$urls_with_downloads, "\n\n",
    
    "## Content Types Found\n\n",
    paste(capture.output(print(summary_stats$statistics$content_types)), collapse = "\n"), "\n\n",
    
    "## Data Sources\n\n",
    paste(capture.output(print(summary_stats$statistics$sources)), collapse = "\n"), "\n\n"
  )
  
  if (!is.null(biodiversity_data)) {
    if (is.data.frame(biodiversity_data)) {
      report_content <- paste0(report_content,
        "## Extracted Biodiversity Data\n\n",
        "- Total records: ", nrow(biodiversity_data), "\n",
        "- Total columns: ", ncol(biodiversity_data), "\n\n"
      )
      
      if (!is.null(species_info)) {
        report_content <- paste0(report_content,
          "### Identified Column Types\n\n",
          "**Potential species columns:** ", paste(species_info$species_columns, collapse = ", "), "\n\n",
          "**Potential coordinate columns:** ", paste(species_info$coordinate_columns, collapse = ", "), "\n\n",
          "**Potential date columns:** ", paste(species_info$date_columns, collapse = ", "), "\n\n"
        )
      }
    }
  } else {
    report_content <- paste0(report_content,
      "## Extracted Biodiversity Data\n\n",
      "No structured biodiversity data could be extracted from the scraped websites.\n",
      "Most sites may require direct download or have data in formats that need special processing.\n\n"
    )
  }
  
  # Save report
  report_file <- file.path(output_dir, paste0("conabio_scraping_report_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".md"))
  writeLines(report_content, report_file)
  
  cat("Report saved to:", report_file, "\n")
  
  # Also save summary data
  summary_file <- file.path(output_dir, paste0("scraping_summary_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"))
  write_csv(summary_stats$summary_table, summary_file)
  
  # Save biodiversity data if available
  if (!is.null(biodiversity_data) && is.data.frame(biodiversity_data)) {
    bio_file <- file.path(output_dir, paste0("extracted_biodiversity_data_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"))
    write_csv(biodiversity_data, bio_file)
    cat("Biodiversity data saved to:", bio_file, "\n")
  }
  
  return(list(
    summary_stats = summary_stats,
    biodiversity_data = biodiversity_data,
    species_info = species_info,
    report_file = report_file
  ))
}

#' Main analysis function
analyze_scraped_data <- function() {
  
  cat("Starting analysis of scraped CONABIO data...\n")
  
  # Load results
  scraped_results <- load_scraped_results()
  
  # Generate analysis report
  analysis_results <- generate_analysis_report(scraped_results)
  
  cat("Analysis completed successfully!\n")
  return(analysis_results)
}

# Example usage (uncomment to run):
# analysis_results <- analyze_scraped_data()
