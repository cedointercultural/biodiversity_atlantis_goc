# Script de debug para API de Claude
library(httr)
library(jsonlite)
library(stringr)

# Cargar API key
source("extract_taxonomy_with_claude.R")

debug_claude_api <- function() {
  cat("=== DEBUG DE API DE CLAUDE ===\n")
  
  # Cargar API key
  api_key <- read_api_key()
  if (is.null(api_key)) {
    stop("No se pudo cargar la API key")
  }
  
  # Taxonomía de prueba
  test_taxonomy <- "NCBI;cellular organisms;Eukaryota;Opisthokonta;Metazoa"
  
  # Preparar petición
  url <- "https://api.anthropic.com/v1/messages"
  
  prompt <- paste0(
    "Analiza esta cadena taxonómica: '", test_taxonomy, "'\n",
    "Extrae solo kingdom, phylum, class.\n",
    "Responde en JSON: {\"kingdom\": \"valor\", \"phylum\": \"valor\", \"class\": \"valor\"}"
  )
  
  body <- list(
    model = "claude-3-5-sonnet-20241022",
    max_tokens = 300,
    messages = list(
      list(
        role = "user",
        content = prompt
      )
    )
  )
  
  cat("Enviando petición a:", url, "\n")
  cat("Modelo:", body$model, "\n")
  
  response <- POST(
    url,
    add_headers(
      "Content-Type" = "application/json",
      "x-api-key" = api_key,
      "anthropic-version" = "2023-06-01"
    ),
    body = toJSON(body, auto_unbox = TRUE),
    encode = "raw"
  )
  
  cat("Status code:", status_code(response), "\n")
  
  if (status_code(response) == 200) {
    cat("✅ Respuesta exitosa\n")
    
    # Obtener respuesta raw
    response_text <- content(response, "text", encoding = "UTF-8")
    cat("Respuesta raw (primeros 500 caracteres):\n")
    cat(substr(response_text, 1, 500), "\n\n")
    
    # Intentar parsear JSON
    tryCatch({
      content_parsed <- fromJSON(response_text)
      cat("Estructura de la respuesta:\n")
      str(content_parsed)
      
      if ("content" %in% names(content_parsed)) {
        if (length(content_parsed$content) > 0) {
          claude_text <- content_parsed$content[[1]]$text
          cat("\nTexto de Claude:\n")
          cat(claude_text, "\n")
          
          # Intentar extraer JSON
          if (str_detect(claude_text, "\\{.*\\}")) {
            json_match <- str_extract(claude_text, "\\{[^}]*\\}")
            cat("\nJSON extraído:", json_match, "\n")
            
            taxonomy_result <- fromJSON(json_match)
            cat("\nResultado final:\n")
            str(taxonomy_result)
            
            return(taxonomy_result)
          }
        }
      }
    }, error = function(e) {
      cat("Error al parsear JSON:", e$message, "\n")
    })
  } else {
    cat("❌ Error en la petición\n")
    error_content <- content(response, "text")
    cat("Error:", error_content, "\n")
  }
  
  return(NULL)
}

# Ejecutar debug
result <- debug_claude_api()
