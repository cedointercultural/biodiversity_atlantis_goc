# Cargar librerías necesarias para la aplicación principal
library(shiny)
library(shinydashboard)
library(leaflet)
library(DT)
library(shinyWidgets)
library(shinyjs)
library(sf)
library(jsonlite)
library(rgbif)
library(spocc)
library(dplyr)
library(plotly)
library(rebird)
library(robis)
library(ridigbio)
library(openxlsx)

# Suprimir warnings para servicios externos temporalmente no disponibles
suppressWarnings({
  options(warn = -1)
})

# Cargar UI y Server desde archivos separados
source("ui.R")
source("server_logic.R")

# Ejecutar la aplicación
shinyApp(ui = ui, server = server)
