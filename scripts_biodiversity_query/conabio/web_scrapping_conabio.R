#' Web Scraping Script for CONABIO Links
#' Author: Ricardo Cavieses-Nuñez
#' Date: August 2025
#' Email: rcavieses@gmail.com
#' 
#' This script performs web scraping of biodiversity databases from links 
#' provided in the CONABIO Excel file. The extracted data will be later 
#' integrated with other biodiversity datasets.

# Clear workspace
rm(list=ls())

# Configure CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

#' Required packages for web scraping and data processing
required_packages <- c(
  "readxl",      # For reading Excel files
  "rvest",       # For web scraping
  "httr",        # For HTTP requests
  "xml2",        # For XML parsing
  "jsonlite",    # For JSON parsing
  "dplyr",       # For data manipulation
  "purrr",       # For functional programming
  "stringr",     # For string manipulation
  "tibble",      # For modern data frames
  "curl",        # For URL handling
  "RCurl",       # Additional web tools
  "progress",    # For progress bars
  "lubridate"    # For date handling
)

# Install and load packages with error handling
cat("Installing and loading required packages...\n")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    tryCatch({
      cat("Installing package:", pkg, "\n")
      install.packages(pkg, dependencies = TRUE)
      library(pkg, character.only = TRUE)
      cat("Successfully loaded:", pkg, "\n")
    }, error = function(e) {
      cat("Warning: Could not install package", pkg, ". Error:", e$message, "\n")
    })
  }
}

#' Define working directories
workpath <- getwd()
cat("Working directory:", workpath, "\n")

# Define paths
excel_file <- file.path(workpath, "Links CONABIO_2025.xlsx")
output_dir <- file.path(workpath, "data", "scraped_conabio")

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
  cat("Created output directory:", output_dir, "\n")
}

#' Function to safely read Excel file
read_conabio_links <- function(file_path) {
  tryCatch({
    cat("Reading Excel file:", file_path, "\n")
    
    # Check if file exists
    if (!file.exists(file_path)) {
      stop("Excel file not found: ", file_path)
    }
    
    # Get sheet names
    sheet_names <- excel_sheets(file_path)
    cat("Available sheets:", paste(sheet_names, collapse = ", "), "\n")
    
    # Read the first sheet (or specify sheet name if known)
    links_data <- read_excel(file_path, sheet = 1)
    
    cat("Successfully read", nrow(links_data), "rows from Excel file\n")
    return(links_data)
    
  }, error = function(e) {
    cat("Error reading Excel file:", e$message, "\n")
    return(NULL)
  })
}

#' Function to validate and clean URLs
validate_url <- function(url) {
  if (is.na(url) || url == "" || is.null(url)) {
    return(FALSE)
  }
  
  # Add http:// if missing
  if (!grepl("^https?://", url)) {
    url <- paste0("http://", url)
  }
  
  # Basic URL validation
  url_pattern <- "^https?://[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}.*"
  return(grepl(url_pattern, url))
}

#' Function to safely scrape a single URL
scrape_single_url <- function(url, source_name = "unknown", max_retries = 3) {
  
  cat("Scraping URL:", url, "\n")
  
  # Validate URL
  if (!validate_url(url)) {
    cat("Invalid URL, skipping:", url, "\n")
    return(NULL)
  }
  
  # Clean URL
  if (!grepl("^https?://", url)) {
    url <- paste0("http://", url)
  }
  
  for (attempt in 1:max_retries) {
    tryCatch({
      # Set user agent to avoid blocking
      user_agent <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      
      # Make HTTP request with timeout
      response <- GET(
        url,
        add_headers("User-Agent" = user_agent),
        timeout(30)
      )
      
      # Check if request was successful
      if (status_code(response) == 200) {
        
        # Get content type
        content_type <- headers(response)$`content-type`
        cat("Content type:", content_type, "\n")
        
        # Parse based on content type
        if (grepl("application/json", content_type, ignore.case = TRUE)) {
          # JSON content
          content_data <- content(response, as = "text", encoding = "UTF-8")
          parsed_data <- fromJSON(content_data, flatten = TRUE)
          
          result <- list(
            url = url,
            source = source_name,
            content_type = "json",
            data = parsed_data,
            scraped_at = Sys.time(),
            status = "success"
          )
          
        } else if (grepl("text/csv", content_type, ignore.case = TRUE)) {
          # CSV content
          content_data <- content(response, as = "text", encoding = "UTF-8")
          
          result <- list(
            url = url,
            source = source_name,
            content_type = "csv",
            data = content_data,
            scraped_at = Sys.time(),
            status = "success"
          )
          
        } else {
          # HTML content - scrape with rvest
          page <- read_html(response)
          
          # Extract basic information
          title <- page %>% html_element("title") %>% html_text() %>% str_trim()
          
          # Try to find data tables
          tables <- page %>% html_elements("table")
          
          # Try to find download links
          download_links <- page %>% 
            html_elements("a[href*='download'], a[href*='.csv'], a[href*='.xlsx'], a[href*='.json']") %>%
            html_attr("href")
          
          # Extract all text content
          text_content <- page %>% html_text() %>% str_trim()
          
          result <- list(
            url = url,
            source = source_name,
            content_type = "html",
            title = title,
            tables_count = length(tables),
            download_links = download_links,
            text_sample = substr(text_content, 1, 1000), # First 1000 characters
            scraped_at = Sys.time(),
            status = "success"
          )
        }
        
        cat("Successfully scraped:", url, "\n")
        return(result)
        
      } else {
        cat("HTTP error", status_code(response), "for URL:", url, "\n")
      }
      
    }, error = function(e) {
      cat("Attempt", attempt, "failed for URL:", url, "Error:", e$message, "\n")
      if (attempt == max_retries) {
        return(list(
          url = url,
          source = source_name,
          error = e$message,
          scraped_at = Sys.time(),
          status = "failed"
        ))
      }
      Sys.sleep(2) # Wait before retry
    })
  }
  
  return(NULL)
}

#' Function to save scraped data
save_scraped_data <- function(scraped_results, output_dir) {
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # Save individual results
  for (i in seq_along(scraped_results)) {
    if (!is.null(scraped_results[[i]])) {
      result <- scraped_results[[i]]
      filename <- paste0("scraped_", i, "_", timestamp, ".rds")
      filepath <- file.path(output_dir, filename)
      saveRDS(result, filepath)
      cat("Saved result", i, "to:", filepath, "\n")
    }
  }
  
  # Save summary
  summary_data <- map_dfr(scraped_results, function(x) {
    if (!is.null(x)) {
      tibble(
        url = x$url %||% NA,
        source = x$source %||% NA,
        content_type = x$content_type %||% NA,
        status = x$status %||% NA,
        scraped_at = x$scraped_at %||% NA,
        error = x$error %||% NA
      )
    }
  })
  
  summary_file <- file.path(output_dir, paste0("scraping_summary_", timestamp, ".csv"))
  write.csv(summary_data, summary_file, row.names = FALSE)
  cat("Saved summary to:", summary_file, "\n")
  
  return(summary_data)
}

#' Main scraping function
main_scraping <- function() {
  
  cat("Starting CONABIO web scraping process...\n")
  cat("=" %>% rep(50) %>% paste(collapse = ""), "\n")
  
  # Read links from Excel file
  links_data <- read_conabio_links(excel_file)
  
  if (is.null(links_data)) {
    stop("Could not read links from Excel file")
  }
  
  # Display structure of the data
  cat("\nStructure of the Excel data:\n")
  str(links_data)
  
  # Find URL columns (look for columns containing URLs)
  url_columns <- names(links_data)[sapply(links_data, function(col) {
    any(grepl("http", col, ignore.case = TRUE), na.rm = TRUE)
  })]
  
  cat("\nDetected URL columns:", paste(url_columns, collapse = ", "), "\n")
  
  if (length(url_columns) == 0) {
    cat("No URL columns detected. Showing first few rows of data:\n")
    print(head(links_data))
    cat("\nPlease check the Excel file structure and modify the script accordingly.\n")
    return(NULL)
  }
  
  # Extract all URLs
  all_urls <- c()
  all_sources <- c()
  
  for (col in url_columns) {
    urls_in_col <- links_data[[col]][!is.na(links_data[[col]])]
    urls_in_col <- urls_in_col[urls_in_col != ""]
    
    if (length(urls_in_col) > 0) {
      all_urls <- c(all_urls, urls_in_col)
      all_sources <- c(all_sources, rep(col, length(urls_in_col)))
    }
  }
  
  cat("\nTotal URLs to scrape:", length(all_urls), "\n")
  
  if (length(all_urls) == 0) {
    cat("No valid URLs found in the Excel file.\n")
    return(NULL)
  }
  
  # Show first few URLs
  cat("\nFirst few URLs to scrape:\n")
  for (i in 1:min(5, length(all_urls))) {
    cat(i, ": ", all_urls[i], "\n")
  }
  
  # Create progress bar
  pb <- progress_bar$new(
    format = "Scraping [:bar] :percent :etas",
    total = length(all_urls),
    clear = FALSE,
    width = 60
  )
  
  # Scrape each URL
  scraped_results <- list()
  
  for (i in seq_along(all_urls)) {
    pb$tick()
    
    cat("\n--- Scraping", i, "of", length(all_urls), "---\n")
    
    result <- scrape_single_url(
      url = all_urls[i], 
      source_name = all_sources[i]
    )
    
    scraped_results[[i]] <- result
    
    # Pause between requests to be respectful
    Sys.sleep(1)
  }
  
  # Save results
  cat("\nSaving scraped data...\n")
  summary_data <- save_scraped_data(scraped_results, output_dir)
  
  # Print summary
  cat("\n" %>% rep(2) %>% paste(collapse = ""))
  cat("SCRAPING COMPLETED\n")
  cat("=" %>% rep(50) %>% paste(collapse = ""), "\n")
  cat("Total URLs processed:", length(all_urls), "\n")
  cat("Successful scrapes:", sum(summary_data$status == "success", na.rm = TRUE), "\n")
  cat("Failed scrapes:", sum(summary_data$status == "failed", na.rm = TRUE), "\n")
  cat("Results saved to:", output_dir, "\n")
  
  return(summary_data)
}

# Execute main function
tryCatch({
  summary_results <- main_scraping()
  cat("\nWeb scraping process completed successfully!\n")
}, error = function(e) {
  cat("\nError in main scraping process:", e$message, "\n")
  cat("Please check the Excel file and script configuration.\n")
})