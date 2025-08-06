# Script para extraer taxonomía usando API de Claude
# Autor: Asistente de IA
# Fecha: 2025-08-06

# Cargar librerías necesarias
library(dplyr)
library(readr)
library(stringr)
library(httr)
library(jsonlite)
library(tidyr)

# Función para llamar a la API de Claude
call_claude_api <- function(taxonomy_string, api_key) {
  # URL de la API de Claude (versión actualizada)
  url <- "https://api.anthropic.com/v1/messages"
  
  # Preparar el prompt para Claude
  prompt <- paste0(
    "Analiza esta cadena taxonómica de NCBI y extrae los nombres de cada nivel taxonómico estándar. ",
    "La cadena es: '", taxonomy_string, "'\n\n",
    "Por favor, identifica y extrae SOLO los nombres específicos (sin prefijos como 'unclassified', 'environmental samples', etc.) para estos niveles taxonómicos en este orden exacto:\n",
    "1. Superkingdom/Domain (Dominio)\n",
    "2. Kingdom (Reino)\n",
    "3. Subkingdom (Subreino)\n",
    "4. Superphylum (Superfilo)\n",
    "5. Phylum (Filo)\n",
    "6. Subphylum (Subfilo)\n",
    "7. Superclass (Superclase)\n",
    "8. Class (Clase)\n",
    "9. Subclass (Subclase)\n",
    "10. Infraclass (Infraclase)\n",
    "11. Cohort (Cohorte)\n",
    "12. Superorder (Superorden)\n",
    "13. Order (Orden)\n",
    "14. Suborder (Suborden)\n",
    "15. Infraorder (Infraorden)\n",
    "16. Parvorder (Parvorden)\n",
    "17. Section (Sección)\n",
    "18. Subsection (Subsección)\n",
    "19. Superfamily (Superfamilia)\n",
    "20. Family (Familia)\n",
    "21. Subfamily (Subfamilia)\n",
    "22. Tribe (Tribu)\n",
    "23. Subtribe (Subtribu)\n",
    "24. Genus (Género)\n",
    "25. Subgenus (Subgénero)\n",
    "26. Species_group (Grupo de especies)\n",
    "27. Species_subgroup (Subgrupo de especies)\n",
    "28. Species (Especie)\n",
    "29. Subspecies (Subespecie)\n",
    "30. Variety (Variedad)\n",
    "31. Subvariety (Subvariedad)\n",
    "32. Form (Forma)\n",
    "33. Subform (Subforma)\n",
    "34. Strain (Cepa)\n\n",
    "Responde ÚNICAMENTE en formato JSON con esta estructura exacta:\n",
    "{\n",
    "  \"superkingdom\": \"nombre_o_null\",\n",
    "  \"kingdom\": \"nombre_o_null\",\n",
    "  \"subkingdom\": \"nombre_o_null\",\n",
    "  \"superphylum\": \"nombre_o_null\",\n",
    "  \"phylum\": \"nombre_o_null\",\n",
    "  \"subphylum\": \"nombre_o_null\",\n",
    "  \"superclass\": \"nombre_o_null\",\n",
    "  \"class\": \"nombre_o_null\",\n",
    "  \"subclass\": \"nombre_o_null\",\n",
    "  \"infraclass\": \"nombre_o_null\",\n",
    "  \"cohort\": \"nombre_o_null\",\n",
    "  \"superorder\": \"nombre_o_null\",\n",
    "  \"order\": \"nombre_o_null\",\n",
    "  \"suborder\": \"nombre_o_null\",\n",
    "  \"infraorder\": \"nombre_o_null\",\n",
    "  \"parvorder\": \"nombre_o_null\",\n",
    "  \"section\": \"nombre_o_null\",\n",
    "  \"subsection\": \"nombre_o_null\",\n",
    "  \"superfamily\": \"nombre_o_null\",\n",
    "  \"family\": \"nombre_o_null\",\n",
    "  \"subfamily\": \"nombre_o_null\",\n",
    "  \"tribe\": \"nombre_o_null\",\n",
    "  \"subtribe\": \"nombre_o_null\",\n",
    "  \"genus\": \"nombre_o_null\",\n",
    "  \"subgenus\": \"nombre_o_null\",\n",
    "  \"species_group\": \"nombre_o_null\",\n",
    "  \"species_subgroup\": \"nombre_o_null\",\n",
    "  \"species\": \"nombre_o_null\",\n",
    "  \"subspecies\": \"nombre_o_null\",\n",
    "  \"variety\": \"nombre_o_null\",\n",
    "  \"subvariety\": \"nombre_o_null\",\n",
    "  \"form\": \"nombre_o_null\",\n",
    "  \"subform\": \"nombre_o_null\",\n",
    "  \"strain\": \"nombre_o_null\"\n",
    "}\n\n",
    "Si no puedes identificar un nivel taxonómico específico, usa null. No incluyas explicaciones adicionales."
  )
  
  # Preparar el cuerpo de la petición
  body <- list(
    model = "claude-3-5-sonnet-20241022",  # Modelo actualizado
    max_tokens = 1000,
    messages = list(
      list(
        role = "user",
        content = prompt
      )
    )
  )
  
  # Realizar la petición
  tryCatch({
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
    
    # Mostrar información de debug
    cat("Status code:", status_code(response), "\n")
    
    if (status_code(response) == 200) {
      response_text <- content(response, "text", encoding = "UTF-8")
      content_parsed <- fromJSON(response_text)
      
      # Verificar la estructura de la respuesta
      if ("content" %in% names(content_parsed) && nrow(content_parsed$content) > 0) {
        claude_response <- content_parsed$content$text[1]  # content es un data.frame
        
        # Limpiar la respuesta y extraer el JSON
        claude_response <- str_trim(claude_response)
        if (str_detect(claude_response, "^```json")) {
          claude_response <- str_extract(claude_response, "(?<=```json\\n)[\\s\\S]*?(?=\\n```)")
        }
        
        # Parsear JSON de taxonomía
        taxonomy_data <- fromJSON(claude_response)
        return(taxonomy_data)
      } else {
        cat("Estructura de respuesta inesperada:", str(content_parsed), "\n")
        return(NULL)
      }
    } else {
      # Mostrar más información sobre el error
      response_content <- content(response, "text")
      cat("Error response:", response_content, "\n")
      warning(paste("Error en API de Claude:", status_code(response)))
      return(NULL)
    }
  }, error = function(e) {
    warning(paste("Error al llamar a Claude API:", e$message))
    return(NULL)
  })
}

# Función para procesar taxonomía por lotes
process_taxonomy_batch <- function(taxonomy_strings, api_key, batch_size = 10) {
  n_strings <- length(taxonomy_strings)
  results <- list()
  
  cat("Procesando", n_strings, "entradas taxonómicas...\n")
  
  for (i in seq(1, n_strings, by = batch_size)) {
    end_idx <- min(i + batch_size - 1, n_strings)
    batch_indices <- i:end_idx
    
    cat("Procesando lote", ceiling(i/batch_size), "de", ceiling(n_strings/batch_size), 
        "(entradas", i, "a", end_idx, ")...\n")
    
    for (j in batch_indices) {
      taxonomy_string <- taxonomy_strings[j]
      
      # Solo procesar si la cadena no está vacía
      if (!is.na(taxonomy_string) && str_length(taxonomy_string) > 0) {
        result <- call_claude_api(taxonomy_string, api_key)
        
        if (!is.null(result)) {
          results[[j]] <- result
        } else {
          # Si falla, crear estructura vacía
          results[[j]] <- list(
            superkingdom = NULL, kingdom = NULL, subkingdom = NULL, superphylum = NULL,
            phylum = NULL, subphylum = NULL, superclass = NULL, class = NULL,
            subclass = NULL, infraclass = NULL, cohort = NULL, superorder = NULL,
            order = NULL, suborder = NULL, infraorder = NULL, parvorder = NULL,
            section = NULL, subsection = NULL, superfamily = NULL, family = NULL,
            subfamily = NULL, tribe = NULL, subtribe = NULL, genus = NULL,
            subgenus = NULL, species_group = NULL, species_subgroup = NULL, species = NULL,
            subspecies = NULL, variety = NULL, subvariety = NULL, form = NULL,
            subform = NULL, strain = NULL
          )
        }
      } else {
        # Para entradas vacías, crear estructura vacía
        results[[j]] <- list(
          superkingdom = NULL, kingdom = NULL, subkingdom = NULL, superphylum = NULL,
          phylum = NULL, subphylum = NULL, superclass = NULL, class = NULL,
          subclass = NULL, infraclass = NULL, cohort = NULL, superorder = NULL,
          order = NULL, suborder = NULL, infraorder = NULL, parvorder = NULL,
          section = NULL, subsection = NULL, superfamily = NULL, family = NULL,
          subfamily = NULL, tribe = NULL, subtribe = NULL, genus = NULL,
          subgenus = NULL, species_group = NULL, species_subgroup = NULL, species = NULL,
          subspecies = NULL, variety = NULL, subvariety = NULL, form = NULL,
          subform = NULL, strain = NULL
        )
      }
      
      # Pausa entre llamadas para evitar límites de tasa
      Sys.sleep(0.5)
    }
    
    # Pausa más larga entre lotes
    if (end_idx < n_strings) {
      cat("Pausa entre lotes...\n")
      Sys.sleep(2)
    }
  }
  
  return(results)
}

# Función principal
extract_taxonomy_with_claude <- function(input_file, output_file, api_key, sample_size = NULL) {
  cat("=== EXTRACCIÓN DE TAXONOMÍA CON CLAUDE ===\n")
  cat("Fecha:", Sys.time(), "\n\n")
  
  # Verificar que existe la clave API
  if (is.null(api_key) || api_key == "") {
    stop("Error: Debes proporcionar una clave API válida de Claude")
  }
  
  # Leer el archivo CSV
  cat("Leyendo archivo:", input_file, "\n")
  data <- read_csv(input_file, show_col_types = FALSE)
  
  cat("Dimensiones originales:", nrow(data), "filas,", ncol(data), "columnas\n")
  
  # Si se especifica un tamaño de muestra, tomar una muestra aleatoria
  if (!is.null(sample_size) && sample_size < nrow(data)) {
    cat("Tomando muestra de", sample_size, "filas para procesamiento\n")
    set.seed(123)  # Para reproducibilidad
    data <- data %>% slice_sample(n = sample_size)
  }
  
  # Extraer taxonomías únicas para optimizar las llamadas a la API
  unique_taxonomies <- data$`NCBI Taxonomy` %>% 
    unique() %>% 
    na.omit()
  
  cat("Taxonomías únicas a procesar:", length(unique_taxonomies), "\n\n")
  
  # Procesar taxonomías con Claude
  cat("Iniciando procesamiento con Claude API...\n")
  taxonomy_results <- process_taxonomy_batch(unique_taxonomies, api_key)
  
  # Convertir resultados a data frame
  taxonomy_df <- data.frame(
    ncbi_taxonomy = unique_taxonomies,
    stringsAsFactors = FALSE
  )
  
  # Extraer cada nivel taxonómico
  for (i in seq_along(taxonomy_results)) {
    result <- taxonomy_results[[i]]
    if (!is.null(result)) {
      taxonomy_df$superkingdom[i] <- ifelse(is.null(result$superkingdom), NA, result$superkingdom)
      taxonomy_df$kingdom[i] <- ifelse(is.null(result$kingdom), NA, result$kingdom)
      taxonomy_df$subkingdom[i] <- ifelse(is.null(result$subkingdom), NA, result$subkingdom)
      taxonomy_df$superphylum[i] <- ifelse(is.null(result$superphylum), NA, result$superphylum)
      taxonomy_df$phylum[i] <- ifelse(is.null(result$phylum), NA, result$phylum)
      taxonomy_df$subphylum[i] <- ifelse(is.null(result$subphylum), NA, result$subphylum)
      taxonomy_df$superclass[i] <- ifelse(is.null(result$superclass), NA, result$superclass)
      taxonomy_df$class[i] <- ifelse(is.null(result$class), NA, result$class)
      taxonomy_df$subclass[i] <- ifelse(is.null(result$subclass), NA, result$subclass)
      taxonomy_df$infraclass[i] <- ifelse(is.null(result$infraclass), NA, result$infraclass)
      taxonomy_df$cohort[i] <- ifelse(is.null(result$cohort), NA, result$cohort)
      taxonomy_df$superorder[i] <- ifelse(is.null(result$superorder), NA, result$superorder)
      taxonomy_df$order[i] <- ifelse(is.null(result$order), NA, result$order)
      taxonomy_df$suborder[i] <- ifelse(is.null(result$suborder), NA, result$suborder)
      taxonomy_df$infraorder[i] <- ifelse(is.null(result$infraorder), NA, result$infraorder)
      taxonomy_df$parvorder[i] <- ifelse(is.null(result$parvorder), NA, result$parvorder)
      taxonomy_df$section[i] <- ifelse(is.null(result$section), NA, result$section)
      taxonomy_df$subsection[i] <- ifelse(is.null(result$subsection), NA, result$subsection)
      taxonomy_df$superfamily[i] <- ifelse(is.null(result$superfamily), NA, result$superfamily)
      taxonomy_df$family[i] <- ifelse(is.null(result$family), NA, result$family)
      taxonomy_df$subfamily[i] <- ifelse(is.null(result$subfamily), NA, result$subfamily)
      taxonomy_df$tribe[i] <- ifelse(is.null(result$tribe), NA, result$tribe)
      taxonomy_df$subtribe[i] <- ifelse(is.null(result$subtribe), NA, result$subtribe)
      taxonomy_df$genus[i] <- ifelse(is.null(result$genus), NA, result$genus)
      taxonomy_df$subgenus[i] <- ifelse(is.null(result$subgenus), NA, result$subgenus)
      taxonomy_df$species_group[i] <- ifelse(is.null(result$species_group), NA, result$species_group)
      taxonomy_df$species_subgroup[i] <- ifelse(is.null(result$species_subgroup), NA, result$species_subgroup)
      taxonomy_df$species[i] <- ifelse(is.null(result$species), NA, result$species)
      taxonomy_df$subspecies[i] <- ifelse(is.null(result$subspecies), NA, result$subspecies)
      taxonomy_df$variety[i] <- ifelse(is.null(result$variety), NA, result$variety)
      taxonomy_df$subvariety[i] <- ifelse(is.null(result$subvariety), NA, result$subvariety)
      taxonomy_df$form[i] <- ifelse(is.null(result$form), NA, result$form)
      taxonomy_df$subform[i] <- ifelse(is.null(result$subform), NA, result$subform)
      taxonomy_df$strain[i] <- ifelse(is.null(result$strain), NA, result$strain)
    }
  }
  
  # Unir con los datos originales
  cat("Uniendo resultados con datos originales...\n")
  final_data <- data %>%
    left_join(taxonomy_df, by = c("NCBI Taxonomy" = "ncbi_taxonomy"))
  
  # Reorganizar columnas: NCBI Taxonomy, niveles taxonómicos, luego el resto
  other_cols <- setdiff(names(data), "NCBI Taxonomy")
  taxonomic_cols <- c("superkingdom", "kingdom", "subkingdom", "superphylum", "phylum", "subphylum", 
                     "superclass", "class", "subclass", "infraclass", "cohort", "superorder", 
                     "order", "suborder", "infraorder", "parvorder", "section", "subsection", 
                     "superfamily", "family", "subfamily", "tribe", "subtribe", "genus", 
                     "subgenus", "species_group", "species_subgroup", "species", "subspecies", 
                     "variety", "subvariety", "form", "subform", "strain")
  
  final_data <- final_data %>%
    select(`NCBI Taxonomy`, all_of(taxonomic_cols), all_of(other_cols))
  
  # Guardar resultado
  cat("Guardando resultado en:", output_file, "\n")
  write_csv(final_data, output_file)
  
  # Generar reporte
  cat("\n=== REPORTE FINAL ===\n")
  cat("Archivo de entrada:", input_file, "\n")
  cat("Archivo de salida:", output_file, "\n")
  cat("Filas procesadas:", nrow(final_data), "\n")
  cat("Columnas finales:", ncol(final_data), "\n")
  cat("Taxonomías únicas procesadas:", length(unique_taxonomies), "\n")
  
  # Estadísticas de completitud por nivel taxonómico
  cat("\nCompletitud por nivel taxonómico:\n")
  levels <- c("superkingdom", "kingdom", "subkingdom", "superphylum", "phylum", "subphylum", 
             "superclass", "class", "subclass", "infraclass", "cohort", "superorder", 
             "order", "suborder", "infraorder", "parvorder", "section", "subsection", 
             "superfamily", "family", "subfamily", "tribe", "subtribe", "genus", 
             "subgenus", "species_group", "species_subgroup", "species", "subspecies", 
             "variety", "subvariety", "form", "subform", "strain")
  for (level in levels) {
    if (level %in% names(final_data)) {
      complete_count <- sum(!is.na(final_data[[level]]))
      percentage <- round(complete_count / nrow(final_data) * 100, 1)
      cat(sprintf("  %s: %d/%d (%s%%)\n", level, complete_count, nrow(final_data), percentage))
    }
  }
  
  cat("\nProceso completado exitosamente!\n")
  return(final_data)
}

# Función para leer la API key desde archivo
read_api_key <- function() {
  api_key_file <- "C:/Users/ricar/OneDrive/Documentos/Proyectos/miscredenciales/anthropic-apikey"
  
  if (file.exists(api_key_file)) {
    api_key <- readLines(api_key_file, n = 1, warn = FALSE)
    api_key <- str_trim(api_key)
    
    if (str_length(api_key) > 0) {
      cat("✓ API key cargada desde:", api_key_file, "\n")
      return(api_key)
    } else {
      warning("El archivo de API key está vacío")
      return(NULL)
    }
  } else {
    warning(paste("No se encontró el archivo de API key:", api_key_file))
    return(NULL)
  }
}

# Función para ejecutar con configuración predeterminada
run_taxonomy_extraction <- function(api_key = NULL, sample_size = NULL) {
  # Archivos de entrada y salida
  input_file <- "c:/Users/ricar/OneDrive/Documentos/Proyectos/Atlantis/tablas_taxon/Tablas taxon 050825/Tablas/Tabla2_SP_Adrian.csv"
  output_file <- "c:/Users/ricar/OneDrive/Documentos/Proyectos/Atlantis/Tabla2_SP_Adrian_with_taxonomy.csv"
  
  # Verificar que existe el archivo de entrada
  if (!file.exists(input_file)) {
    stop("Error: No se encontró el archivo de entrada: ", input_file)
  }
  
  # Intentar cargar API key desde archivo si no se proporciona
  if (is.null(api_key)) {
    cat("Intentando cargar API key desde archivo...\n")
    api_key <- read_api_key()
    
    # Si no se pudo cargar desde archivo, solicitar manualmente
    if (is.null(api_key)) {
      cat("Este script requiere una clave API de Claude (Anthropic).\n")
      cat("Puedes obtener una en: https://console.anthropic.com/\n\n")
      api_key <- readline(prompt = "Ingresa tu clave API de Claude: ")
    }
  }
  
  # Ejecutar extracción
  result <- extract_taxonomy_with_claude(input_file, output_file, api_key, sample_size)
  
  return(result)
}

# Instrucciones de uso
cat("=== SCRIPT DE EXTRACCIÓN DE TAXONOMÍA CON CLAUDE ===\n")
cat("Este script lee la Tabla2_SP_Adrian.csv y usa la API de Claude para extraer\n")
cat("los niveles taxonómicos de la columna 'NCBI Taxonomy'.\n\n")
cat("Para usar este script:\n")
cat("1. Asegúrate de que tu API key esté en: C:/Users/ricar/OneDrive/Documentos/Proyectos/miscredenciales/anthropic-apikey\n")
cat("2. Ejecuta: result <- run_taxonomy_extraction()\n")
cat("3. Para probar con una muestra: result <- run_taxonomy_extraction(sample_size = 100)\n")
cat("4. También puedes especificar tu API key manualmente: run_taxonomy_extraction(api_key = 'tu_clave')\n\n")
cat("El resultado se guardará en: Tabla2_SP_Adrian_with_taxonomy.csv\n")
cat("Las nuevas columnas serán: superkingdom, kingdom, subkingdom, superphylum, phylum, subphylum,\n")
cat("  superclass, class, subclass, infraclass, cohort, superorder, order, suborder,\n")
cat("  infraorder, parvorder, section, subsection, superfamily, family, subfamily,\n")
cat("  tribe, subtribe, genus, subgenus, species_group, species_subgroup, species,\n")
cat("  subspecies, variety, subvariety, form, subform, strain (34 niveles totales)\n\n")

# Ejemplo de uso (comentado para evitar ejecución accidental):
# # Para ejecutar el script completo:
# result <- run_taxonomy_extraction()
# 
# # Para probar con una muestra pequeña primero:
# result_sample <- run_taxonomy_extraction(sample_size = 50)
# 
# # Para usar una API key específica:
# result <- run_taxonomy_extraction(api_key = "tu_clave_api_aqui")
