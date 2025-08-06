###Tablas 

# 1. Cargar librerías
library(readxl)
library(dplyr)
library(tidyr)

# Tabla 1 Mac Loughlin et al., 2024 
#Leer los archivos de Excel
Table_SP     <- read_excel("Table_SP.xlsx")
Table_PRESEN <- read_excel("Table_PRESEN.xlsx")
Table_SITES  <- read_excel("Table_SITES.xlsx")
Table_REGION <- read_excel("Table_REGION.xlsx")

# 3. Nombres de los 20 sitios (coinciden con nombres de columnas en Table_PRESEN)
site_codes <- c(
  "01.PLO","02.PLI","03.SLG","04.AGU1","05.AGU2","06.PAT","07.LOR","08.SPM",
  "09.SPN","10.TOR","11.MAR","12.PUL","13.CAR","14.DAN","15.MON","16.CAT",
  "17.MAT","18.CRU","19.DIE","20.POR"
)

# 4. Convertir de formato ancho a largo (long format)
Table_PRESEN_long <- Table_PRESEN %>%
  pivot_longer(
    cols = all_of(site_codes),
    names_to = "SiteCode",
    values_to = "Abundancia"
  )

# 5. Unir coordenadas (Table_SITES tiene Site_ID, Lat y Lon)
Table_with_coords <- Table_PRESEN_long %>%
  left_join(Table_SITES, by = c("SiteCode" = "Site_ID"))

# 6. Unir con información de especies
Table_with_species <- Table_with_coords %>%
  left_join(Table_SP, by = "ID")

# 7. Filtrar solo registros con especies presentes (abundancia > 0)
Final_Table_present <- Table_with_species %>%
  filter(Abundancia > 0)

# 8. Unir con datos de profundidad, temperatura y región
Final_Table_present <- Final_Table_present %>%
  left_join(Table_REGION, by = c("SiteCode" = "Site_ID"))

# 9. Ver resultado final en RStudio
View(Final_Table_present)

# 10. (Opcional) Exportar como CSV para Excel
write.csv(Final_Table_present,
          "C:/Users/52559/Downloads/Especies_por_sitio_completo.csv",
          row.names = FALSE)

###Tabla 2 Carrillo-Espinoza 2024

# Cargar paquetes necesarios
library(readxl)
library(dplyr)
library(tidyr)

# Leer las tablas
Tabla1_sitios      <- read_excel("Tabla1_sitios.xlsx")
Tabla2_abundancias <- read_excel("Tabla2_abundancias.xlsx")
Tabla3_SP          <- read_excel("Tabla3_SP.xlsx")

# Vector con los nombres de las columnas de sitio (exactamente como están en Tabla2_abundancias)
site_ids <- c("sn1", "sn2", "sn3", "sn4", 
              "sc1", "sc2", "sc3", "sc4", "sc5", "sc6", "sc7", "sc8", "sc9", "sc10", "sc11", "ss1",
              "dn1", "dn2", "dn3", "dn4", 
              "dc1", "dc2", "dc3", "dc4", "dc5", "dc6", "dc7", "dc8", "dc9", "dc10", "dc11", "ds1")

# 1. Convertir la tabla de abundancias de ancho a largo
Tabla2_long <- Tabla2_abundancias %>%
  pivot_longer(
    cols = all_of(site_ids),
    names_to = "Sample_ID",
    values_to = "Abundancia"
  )

# 2. Unir con metadatos de sitio (Tabla1_sitios)
Tabla_completa <- Tabla2_long %>%
  left_join(Tabla1_sitios, by = c("Sample_ID" = "Sample ID"))

# 3. Unir con la tabla de especies
Tabla_completa <- Tabla_completa %>%
  left_join(Tabla3_SP, by = "#")

# 4. (Opcional) Filtrar solo registros donde hay presencia
Tabla_presente <- Tabla_completa %>%
  filter(Abundancia > 0)

# 5. Ver resultado
View(Tabla_presente)

# 6. (Opcional) Exportar como archivo CSV
write.csv(Tabla_presente,
          "C:/Users/52559/Downloads/Tabla_especies_completa2.csv",
          row.names = FALSE)

######Tabla 3 Adrian Munguia 
# Leer las tablas
Tabla1_SITIOS      <- read_excel("Tabla1_SITIOS_Adrian.xlsx")
Tabla2_SP <- read_excel("Tabla2_SP_Adrian.xlsx")

# 1. Revisar estructura de Tabla2_SP
# Nombrar la primera columna sea 'Especie' (o ponle ese nombre)
colnames(Tabla2_SP)[1] <- "Especie"

# 2. Pivotear la tabla: pasar de ancho a largo
Tabla2_larga <- Tabla2_SP %>%
  pivot_longer(
    cols = -Especie,            # Todas las columnas menos 'Especie' son sitios
    names_to = "SAMPLE_NUM",    # Nombre para la nueva columna con los sitios
    values_to = "Abundancia"    # Nombre para la columna de valores
  )

# 3. Convertir SAMPLE_NUM a número si está como texto
Tabla2_larga$SAMPLE_NUM <- as.numeric(Tabla2_larga$SAMPLE_NUM)

# 4. Unir con la tabla de metadatos
Tabla_unida <- Tabla2_larga %>%
  left_join(Tabla1_SITIOS, by = "SAMPLE_NUM")

# 5. resultado
glimpse(Tabla_unida)
head(Tabla_unida)
View(Tabla_unida)

# 6. Guardar en archivo
#write.csv(Tabla_unida, "Tabla_Unida.csv", row.names = FALSE)