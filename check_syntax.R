# Validación simple de sintaxis
cat("Validando sintaxis de scripts R...\n")

# Validar ocurrence_records_updated.R
tryCatch({
  parse("ocurrence_records_updated.R")
  cat("✓ ocurrence_records_updated.R - Sintaxis VÁLIDA\n")
}, error = function(e) {
  cat("✗ ocurrence_records_updated.R - ERROR:", e$message, "\n")
})

# Validar Data_biodiversity_updated.R  
tryCatch({
  parse("Data_biodiversity_updated.R")
  cat("✓ Data_biodiversity_updated.R - Sintaxis VÁLIDA\n")
}, error = function(e) {
  cat("✗ Data_biodiversity_updated.R - ERROR:", e$message, "\n")
})

# Validar Organize_biodiversity_updated.R
tryCatch({
  parse("Organize_biodiversity_updated.R")
  cat("✓ Organize_biodiversity_updated.R - Sintaxis VÁLIDA\n")
}, error = function(e) {
  cat("✗ Organize_biodiversity_updated.R - ERROR:", e$message, "\n")
})

cat("Validación completada.\n")
