# Script de validación de sintaxis para archivos R de biodiversidad
# Syntax validation script for biodiversity R files

# Clean workspace
rm(list=ls())

cat("=== VALIDACIÓN DE SINTAXIS DE SCRIPTS R ===\n")

# Lista de archivos a validar
scripts_to_validate <- c(
  "ocurrence_records_updated.R",
  "Data_biodiversity_updated.R", 
  "Organize_biodiversity_updated.R"
)

validation_results <- list()

# Función para validar sintaxis de un archivo R
validate_r_syntax <- function(file_path) {
  result <- list(
    file = basename(file_path),
    exists = file.exists(file_path),
    syntax_valid = FALSE,
    error_message = NULL,
    line_count = 0
  )
  
  if (!file.exists(file_path)) {
    result$error_message <- "Archivo no encontrado"
    return(result)
  }
  
  # Contar líneas
  lines <- readLines(file_path, warn = FALSE)
  result$line_count <- length(lines)
  
  # Validar sintaxis usando parse
  tryCatch({
    parsed <- parse(file_path)
    result$syntax_valid <- TRUE
    cat("✓", basename(file_path), "- Sintaxis VÁLIDA (", result$line_count, "líneas)\n")
  }, error = function(e) {
    result$syntax_valid <- FALSE
    result$error_message <- e$message
    cat("✗", basename(file_path), "- ERROR DE SINTAXIS:", e$message, "\n")
  })
  
  return(result)
}

# Función para verificar balance de paréntesis y corchetes
check_bracket_balance <- function(file_path) {
  if (!file.exists(file_path)) return(FALSE)
  
  content <- paste(readLines(file_path, warn = FALSE), collapse = "\n")
  
  # Contadores
  paren_count <- 0
  bracket_count <- 0
  brace_count <- 0
  
  # Recorrer cada caracter
  for (i in 1:nchar(content)) {
    char <- substr(content, i, i)
    
    switch(char,
      "(" = { paren_count <- paren_count + 1 },
      ")" = { paren_count <- paren_count - 1 },
      "[" = { bracket_count <- bracket_count + 1 },
      "]" = { bracket_count <- bracket_count - 1 },
      "{" = { brace_count <- brace_count + 1 },
      "}" = { brace_count <- brace_count - 1 }
    )
  }
  
  balanced <- (paren_count == 0 && bracket_count == 0 && brace_count == 0)
  
  cat("  Paréntesis: ", if(paren_count == 0) "✓ Balanceados" else paste("✗ Desbalanceados (", paren_count, ")"), "\n")
  cat("  Corchetes: ", if(bracket_count == 0) "✓ Balanceados" else paste("✗ Desbalanceados (", bracket_count, ")"), "\n")
  cat("  Llaves: ", if(brace_count == 0) "✓ Balanceados" else paste("✗ Desbalanceados (", brace_count, ")"), "\n")
  
  return(balanced)
}

# Validar cada script
cat("\n1. VALIDACIÓN DE SINTAXIS:\n")
for (script in scripts_to_validate) {
  result <- validate_r_syntax(script)
  validation_results[[script]] <- result
}

cat("\n2. VERIFICACIÓN DE BALANCE DE PARÉNTESIS/CORCHETES:\n")
for (script in scripts_to_validate) {
  if (file.exists(script)) {
    cat("Archivo:", script, "\n")
    balanced <- check_bracket_balance(script)
    validation_results[[script]]$brackets_balanced <- balanced
    if (balanced) {
      cat("  ✓ Todos los símbolos están balanceados\n")
    } else {
      cat("  ✗ Símbolos desbalanceados detectados\n")
    }
    cat("\n")
  }
}

# Función para verificar estructuras comunes de R
check_r_structures <- function(file_path) {
  if (!file.exists(file_path)) return(FALSE)
  
  lines <- readLines(file_path, warn = FALSE)
  issues <- c()
  
  for (i in 1:length(lines)) {
    line <- lines[i]
    
    # Verificar if sin else correspondiente (básico)
    if (grepl("^\\s*if\\s*\\(", line) && !grepl("\\{\\s*$", line)) {
      # Verificar si la siguiente línea tiene contenido pero no está indentada
      if (i < length(lines) && lines[i + 1] != "" && !grepl("^\\s\\s", lines[i + 1])) {
        issues <- c(issues, paste("Línea", i, ": Posible problema de indentación después de if"))
      }
    }
    
    # Verificar for loops
    if (grepl("^\\s*for\\s*\\(", line) && !grepl("\\{\\s*$", line)) {
      if (i < length(lines) && lines[i + 1] != "" && !grepl("^\\s\\s", lines[i + 1])) {
        issues <- c(issues, paste("Línea", i, ": Posible problema de indentación después de for"))
      }
    }
    
    # Verificar funciones sin cerrar
    if (grepl("function\\s*\\(", line) && !grepl("\\{\\s*$", line)) {
      if (i < length(lines) && lines[i + 1] != "" && !grepl("^\\s\\s", lines[i + 1])) {
        issues <- c(issues, paste("Línea", i, ": Posible problema de indentación después de function"))
      }
    }
  }
  
  if (length(issues) > 0) {
    cat("  Posibles problemas de estructura:\n")
    for (issue in issues[1:min(5, length(issues))]) {  # Mostrar máximo 5 problemas
      cat("    -", issue, "\n")
    }
    if (length(issues) > 5) {
      cat("    ... y", length(issues) - 5, "más\n")
    }
  } else {
    cat("  ✓ Estructura básica parece correcta\n")
  }
  
  return(length(issues) == 0)
}

cat("3. VERIFICACIÓN DE ESTRUCTURAS R:\n")
for (script in scripts_to_validate) {
  if (file.exists(script)) {
    cat("Archivo:", script, "\n")
    structure_ok <- check_r_structures(script)
    validation_results[[script]]$structure_ok <- structure_ok
    cat("\n")
  }
}

# Resumen final
cat("=== RESUMEN DE VALIDACIÓN ===\n")
all_valid <- TRUE

for (script in names(validation_results)) {
  result <- validation_results[[script]]
  status <- if (result$syntax_valid && 
                (is.null(result$brackets_balanced) || result$brackets_balanced) &&
                (is.null(result$structure_ok) || result$structure_ok)) {
    "✓ VÁLIDO"
  } else {
    all_valid <- FALSE
    "✗ REQUIERE ATENCIÓN"
  }
  
  cat(script, ":", status, "\n")
  if (result$exists) {
    cat("  - Líneas:", result$line_count, "\n")
    if (!is.null(result$error_message)) {
      cat("  - Error:", result$error_message, "\n")
    }
  } else {
    cat("  - Archivo no encontrado\n")
  }
}

if (all_valid) {
  cat("\n✓ TODOS LOS SCRIPTS HAN PASADO LA VALIDACIÓN\n")
  cat("Los archivos están listos para ejecutarse.\n")
} else {
  cat("\n✗ ALGUNOS SCRIPTS REQUIEREN CORRECCIÓN\n")
  cat("Revise los errores reportados arriba.\n")
}

cat("\n=== VALIDACIÓN COMPLETADA ===\n")
