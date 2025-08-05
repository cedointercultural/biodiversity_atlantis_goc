#' Script Simple para Descargar Archivos ZIP de CONABIO
#' Author: Ricardo Cavieses-Nuñez
#' Date: August 2025
#' Email: rcavieses@gmail.com

# Clear workspace
rm(list=ls())

# Configure CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Required packages
required_packages <- c("readxl", "utils")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# Create downloads directory
downloads_dir <- file.path(getwd(), "data", "downloads")
if (!dir.exists(downloads_dir)) {
  dir.create(downloads_dir, recursive = TRUE)
  cat("Created downloads directory:", downloads_dir, "\n")
}

# Function to read URLs from Excel file
get_conabio_urls <- function() {
  excel_file <- file.path("..", "Links CONABIO_2025.xlsx")
  
  if (!file.exists(excel_file)) {
    stop("Excel file not found: ", excel_file)
  }
  
  cat("Reading URLs from Excel file...\n")
  
  # Read Excel file
  links_data <- readxl::read_excel(excel_file, sheet = 1)
  
  # Find URL columns
  url_columns <- names(links_data)[sapply(links_data, function(col) {
    any(grepl("http", col, ignore.case = TRUE), na.rm = TRUE)
  })]
  
  cat("Found URL columns:", paste(url_columns, collapse = ", "), "\n")
  
  # Extract all URLs
  all_urls <- c()
  for (col in url_columns) {
    urls_in_col <- links_data[[col]][!is.na(links_data[[col]])]
    urls_in_col <- urls_in_col[urls_in_col != ""]
    all_urls <- c(all_urls, urls_in_col)
  }
  
  # Remove duplicates and clean URLs
  all_urls <- unique(all_urls)
  all_urls <- all_urls[grepl("http", all_urls, ignore.case = TRUE)]
  
  cat("Found", length(all_urls), "unique URLs\n")
  return(all_urls)
}

# Function to download a single ZIP file
download_zip_file <- function(url, downloads_dir) {
  cat("\n=== Downloading ===\n")
  cat("URL:", url, "\n")
  
  # Extract filename from URL
  filename <- basename(url)
  local_path <- file.path(downloads_dir, filename)
  
  cat("Saving to:", local_path, "\n")
  
  # Check if file already exists
  if (file.exists(local_path)) {
    cat("File already exists. Checking size...\n")
    file_size <- file.size(local_path)
    if (file_size > 1000) {  # If file is larger than 1KB, assume it's complete
      cat("File already downloaded (", file_size, "bytes). Skipping.\n")
      return(list(
        url = url,
        filename = filename,
        local_path = local_path,
        status = "already_exists",
        size = file_size
      ))
    } else {
      cat("File exists but is too small. Re-downloading...\n")
      file.remove(local_path)
    }
  }
  
  # Download the file
  tryCatch({
    cat("Starting download...\n")
    
    # Use download.file with appropriate method for Windows
    download.file(
      url = url,
      destfile = local_path,
      mode = "wb",           # Write binary mode for ZIP files
      method = "auto",       # Let R choose the best method
      quiet = FALSE,         # Show progress
      timeout = 300          # 5 minute timeout
    )
    
    # Check if download was successful
    if (file.exists(local_path)) {
      file_size <- file.size(local_path)
      
      if (file_size > 0) {
        cat("✓ Download successful! File size:", file_size, "bytes\n")
        
        return(list(
          url = url,
          filename = filename,
          local_path = local_path,
          status = "success",
          size = file_size
        ))
      } else {
        cat("✗ Downloaded file is empty\n")
        file.remove(local_path)
        
        return(list(
          url = url,
          filename = filename,
          status = "failed",
          error = "Empty file"
        ))
      }
    } else {
      cat("✗ Download failed - file not created\n")
      
      return(list(
        url = url,
        filename = filename,
        status = "failed",
        error = "File not created"
      ))
    }
    
  }, error = function(e) {
    cat("✗ Download error:", e$message, "\n")
    
    return(list(
      url = url,
      filename = filename,
      status = "failed",
      error = e$message
    ))
  })
}

# Function to download all ZIP files
download_all_zips <- function() {
  cat("CONABIO ZIP File Downloader\n")
  cat("===========================\n\n")
  
  # Get URLs from Excel file
  urls <- get_conabio_urls()
  
  if (length(urls) == 0) {
    cat("No URLs found to download\n")
    return(NULL)
  }
  
  cat("\nURLs to download:\n")
  for (i in seq_along(urls)) {
    cat(sprintf("%2d. %s\n", i, urls[i]))
  }
  
  cat("\nStarting downloads...\n")
  cat("Download directory:", downloads_dir, "\n")
  
  # Download each file
  results <- list()
  successful_downloads <- 0
  failed_downloads <- 0
  
  for (i in seq_along(urls)) {
    cat("\n", sprintf("[%d/%d]", i, length(urls)), "\n")
    
    result <- download_zip_file(urls[i], downloads_dir)
    results[[i]] <- result
    
    if (result$status %in% c("success", "already_exists")) {
      successful_downloads <- successful_downloads + 1
    } else {
      failed_downloads <- failed_downloads + 1
    }
    
    # Small pause between downloads to be respectful
    if (i < length(urls)) {
      cat("Waiting 2 seconds before next download...\n")
      Sys.sleep(2)
    }
  }
  
  # Summary
  cat("\n\n")
  cat("DOWNLOAD SUMMARY\n")
  cat("================\n")
  cat("Total URLs:", length(urls), "\n")
  cat("Successful downloads:", successful_downloads, "\n")
  cat("Failed downloads:", failed_downloads, "\n")
  cat("Download directory:", downloads_dir, "\n")
  
  # List downloaded files
  cat("\nDownloaded files:\n")
  downloaded_files <- list.files(downloads_dir, pattern = "\\.zip$", full.names = FALSE)
  
  if (length(downloaded_files) > 0) {
    for (file in downloaded_files) {
      file_path <- file.path(downloads_dir, file)
      file_size <- file.size(file_path)
      cat("- ", file, " (", file_size, " bytes)\n")
    }
  } else {
    cat("No ZIP files found in download directory\n")
  }
  
  # Save download summary
  summary_data <- data.frame(
    url = sapply(results, function(x) x$url),
    filename = sapply(results, function(x) x$filename),
    status = sapply(results, function(x) x$status),
    size = sapply(results, function(x) ifelse(is.null(x$size), 0, x$size)),
    error = sapply(results, function(x) ifelse(is.null(x$error), "", x$error)),
    stringsAsFactors = FALSE
  )
  
  summary_file <- file.path(downloads_dir, paste0("download_summary_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"))
  write.csv(summary_data, summary_file, row.names = FALSE)
  cat("\nDownload summary saved to:", summary_file, "\n")
  
  return(results)
}

# Function to verify ZIP file integrity
verify_zip_files <- function() {
  cat("\nVerifying ZIP file integrity...\n")
  cat("===============================\n")
  
  zip_files <- list.files(downloads_dir, pattern = "\\.zip$", full.names = TRUE)
  
  if (length(zip_files) == 0) {
    cat("No ZIP files found to verify\n")
    return(NULL)
  }
  
  for (zip_file in zip_files) {
    cat("Checking:", basename(zip_file), "\n")
    
    tryCatch({
      # Try to list contents of ZIP file
      contents <- unzip(zip_file, list = TRUE)
      
      cat("✓ Valid ZIP file with", nrow(contents), "files\n")
      
      # Show contents
      if (nrow(contents) > 0) {
        cat("  Contents:\n")
        for (i in 1:min(5, nrow(contents))) {
          cat("  -", contents$Name[i], "(", contents$Length[i], "bytes )\n")
        }
        if (nrow(contents) > 5) {
          cat("  ... and", nrow(contents) - 5, "more files\n")
        }
      }
      
    }, error = function(e) {
      cat("✗ Invalid or corrupted ZIP file:", e$message, "\n")
    })
    
    cat("\n")
  }
}

# Main execution
cat("Starting CONABIO ZIP download process...\n")
download_results <- download_all_zips()

if (!is.null(download_results)) {
  verify_zip_files()
  cat("\nProcess completed! Check the download directory for your files.\n")
  cat("Directory:", downloads_dir, "\n")
} else {
  cat("Download process failed. Please check the Excel file and try again.\n")
}
