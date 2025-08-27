# Configurar CRAN mirror para evitar el error
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Verificar configuración
cat("CRAN mirror configurado:", getOption("repos"), "\n")

# Opcional: Instalar paquetes básicos necesarios
required_packages <- c(
  "dismo", "data.table", "xml2", "jsonlite", "graphics", "maps",
  "sf", "magrittr", "dplyr", "Hmisc", "readxl", 
  "ridigbio", "rvertnet", "ecoengine", "rbison", "rgbif", "rebird"
)

cat("Instalando paquetes necesarios...\n")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat("Instalando:", pkg, "\n")
    install.packages(pkg, dependencies = TRUE, quiet = TRUE)
  } else {
    cat("Paquete ya instalado:", pkg, "\n")
  }
}

cat("Configuración completada!\n")
