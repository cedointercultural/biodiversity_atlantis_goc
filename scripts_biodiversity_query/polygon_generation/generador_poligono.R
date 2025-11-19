# Cargar librerías necesarias
# Suprimir warnings para servicios externos temporalmente no disponibles
suppressWarnings({
  options(warn = -1)
  library(shiny)
  library(leaflet)
  library(DT)
  library(shinydashboard)
  library(shinyWidgets)
  library(shinyjs)  # Para manipulación de JavaScript
  library(sf)  # Para procesamiento geoespacial
  library(jsonlite)  # Para exportar JSON
  library(rgbif)  # Para consultas GBIF
  library(spocc)  # Para consultas adicionales
  library(dplyr)  # Para manipulación de datos
  library(plotly)  # Para gráficos interactivos
  library(rebird)  # Para consultas eBird
  library(robis)  # Para consultas OBIS (Ocean Biodiversity Information System)
  library(ridigbio)  # Para consultas iDigBio
  options(warn = 0)
})

# UI (Interfaz de Usuario)
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "🗺️ Dibujador de Polígonos"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Mapa", tabName = "mapa", icon = icon("map")),
      menuItem("Coordenadas", tabName = "coordenadas", icon = icon("table")),
      menuItem("Consulta Biodiversidad", tabName = "biodiversity", icon = icon("leaf")),
      menuItem("Resultados", tabName = "results", icon = icon("chart-bar")),
      menuItem("Datos para Scripts", tabName = "export_data", icon = icon("code"))
    )
  ),
  
  dashboardBody(
    useShinyjs(),  # Inicializar shinyjs
    tags$head(
      tags$style(HTML("
        .content-wrapper, .right-side {
          background-color: #f4f4f4;
        }
        .box {
          border-radius: 10px;
        }
        .btn-custom {
          margin: 5px;
          border-radius: 20px;
        }
        @keyframes pulse {
          0% { opacity: 1; }
          50% { opacity: 0.7; }
          100% { opacity: 1; }
        }
        .spinner-border {
          width: 1rem;
          height: 1rem;
          border: 0.125em solid currentColor;
          border-right-color: transparent;
          border-radius: 50%;
          animation: spinner-border .75s linear infinite;
        }
        @keyframes spinner-border {
          to { transform: rotate(360deg); }
        }
      "))
    ),
    
    tabItems(
      # Pestaña del Mapa
      tabItem(tabName = "mapa",
        fluidRow(
          box(
            title = "Controles", 
            status = "primary", 
            solidHeader = TRUE,
            width = 12,
            collapsible = TRUE,
            
            fluidRow(
              column(3,
                actionButton("start_drawing", 
                           "✏️ Comenzar Dibujo", 
                           class = "btn btn-primary btn-custom",
                           width = "100%")
              ),
              column(3,
                actionButton("finish_polygon", 
                           "✅ Finalizar Polígono", 
                           class = "btn btn-success btn-custom",
                           width = "100%")
              ),
              column(3,
                actionButton("clear_all", 
                           "🗑️ Limpiar Todo", 
                           class = "btn btn-danger btn-custom",
                           width = "100%")
              ),
              column(3,
                downloadButton("download_csv", 
                             "📥 Exportar CSV",
                             class = "btn btn-info btn-custom",
                             style = "width: 100%;")
              )
            ),
            
            br(),
            
            fluidRow(
              column(12,
                div(id = "status_info", 
                    style = "text-align: center; padding: 10px; background-color: #e8f4fd; border-radius: 5px;",
                    h4("📍 Estado:", style = "margin: 0;"),
                    p("Haz clic en 'Comenzar Dibujo' para empezar", style = "margin: 5px 0 0 0;")
                )
              )
            )
          )
        ),
        
        fluidRow(
          box(
            title = "Mapa Interactivo",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            height = "600px",
            
            leafletOutput("map", height = "550px")
          )
        )
      ),
      
      # Pestaña de Coordenadas
      tabItem(tabName = "coordenadas",
        fluidRow(
          box(
            title = "Coordenadas del Polígono",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            
            DT::dataTableOutput("coordinates_table")
          )
        ),
        
        fluidRow(
          box(
            title = "Información del Polígono",
            status = "info",
            solidHeader = TRUE,
            width = 6,
            
            valueBoxOutput("vertex_count"),
            valueBoxOutput("area_info")
          ),
          
          box(
            title = "Exportar Datos",
            status = "success",
            solidHeader = TRUE,
            width = 6,
            
            h4("Formato de Exportación:"),
            radioButtons("export_format",
                        "Selecciona el formato:",
                        choices = list(
                          "CSV (Coma separado)" = "csv",
                          "TXT (Tab separado)" = "txt",
                          "Excel" = "xlsx"
                        ),
                        selected = "csv"),
            
            br(),
            downloadButton("download_custom", 
                         "Descargar en formato seleccionado",
                         class = "btn btn-success",
                         style = "width: 100%;")
          )
        )
      ),
      
      # Nueva pestaña para consulta de biodiversidad
      tabItem(tabName = "biodiversity",
        fluidRow(
          box(
            title = "🌿 Consulta de Biodiversidad",
            status = "success",
            solidHeader = TRUE,
            width = 12,
            
            conditionalPanel(
              condition = "!output.polygon_ready",
              div(style = "text-align: center; padding: 20px;",
                  h4("⚠️ Primero debes dibujar y finalizar un polígono"),
                  p("Ve a la pestaña 'Mapa' y dibuja tu área de estudio."),
                  actionButton("go_to_map", "🗺️ Ir al Mapa", 
                             class = "btn btn-primary")
              )
            ),
            
            conditionalPanel(
              condition = "output.polygon_ready",
              h4("🎯 Configuración de Consultas"),
              
              fluidRow(
                column(4,
                  h5("📐 Parámetros del Grid:"),
                  numericInput("bio_grid_size", 
                             "Tamaño de grid (grados):", 
                             value = 1.0, min = 0.1, max = 3.0, step = 0.1),
                  helpText("🔍 Tamaño de cada celda del grid en grados decimales. Valores menores = más precisión pero más consultas."),
                  
                  numericInput("max_boxes", 
                             "Máximo de boxes a consultar:", 
                             value = 5, min = 1, max = 20, step = 1),
                  helpText("📦 Número máximo de celdas del grid a procesar. Limita el tiempo de consulta."),
                  
                  numericInput("records_per_box", 
                             "Registros por box:", 
                             value = 500, min = 100, max = 2000, step = 100),
                  helpText("📊 Cantidad máxima de registros a obtener por cada celda del grid."),
                  
                  checkboxInput("unlimited_records",
                              "Sin límite de registros",
                              value = FALSE),
                  helpText("⚠️ Consultas sin límites - puede tardar más tiempo pero recuperará todos los registros disponibles."),
                  
                  # Información de boxes
                  div(id = "box_info", style = "background-color: #e8f4fd; padding: 10px; border-radius: 5px; margin-top: 10px;",
                      h6("📋 Información del Grid:", style = "margin: 0 0 5px 0; font-weight: bold;"),
                      textOutput("grid_info_text")
                  )
                ),
                
                column(4,
                  h5("🗄️ Bases de Datos:"),
                  checkboxGroupInput("databases",
                                   "Selecciona fuentes:",
                                   choices = list(
                                     "GBIF (Global)" = "gbif",
                                     "iNaturalist" = "inat",
                                     "eBird" = "ebird",
                                     "OBIS (Marino)" = "obis",
                                     "iDigBio" = "idigbio"
                                   ),
                                   selected = c("gbif")),
                  helpText("🌍 GBIF: Base global más completa | 🦜 eBird: Aves (requiere API) | 🌊 OBIS: Especies marinas | 🔬 iDigBio: Especímenes de museos"),
                  
                  selectInput("gbif_rank",
                            "Rango taxonómico (GBIF):",
                            choices = list(
                              "Todos" = "",
                              "Especies" = "SPECIES",
                              "Género" = "GENUS",
                              "Familia" = "FAMILY"
                            ),
                            selected = ""),
                  helpText("🔬 Filtra GBIF por nivel taxonómico específico para datos más refinados.")
                ),
                
                column(4,
                  h5("📅 Filtros Temporales:"),
                  numericInput("year_start",
                             "Año inicial:",
                             value = 2000, min = 1900, max = as.numeric(format(Sys.Date(), "%Y")), step = 1),
                  
                  numericInput("year_end",
                             "Año final:",
                             value = as.numeric(format(Sys.Date(), "%Y")),
                             min = 1900, max = as.numeric(format(Sys.Date(), "%Y")), step = 1),
                  helpText("📆 Rango de años para filtrar observaciones. Usar rangos amplios puede aumentar resultados."),
                  
                  h5("🔧 Opciones de Filtrado:"),
                  checkboxInput("only_coordinates",
                               "Solo registros con coordenadas",
                               value = TRUE),
                  helpText("📍 Excluye observaciones sin ubicación geográfica precisa."),
                  
                  checkboxInput("remove_duplicates",
                               "Remover duplicados",
                               value = TRUE),
                  helpText("🔄 Elimina registros repetidos basado en especie y ubicación."),
                  
                  checkboxInput("spatial_filter",
                               "Filtrado espacial estricto",
                               value = TRUE),
                  helpText("🎯 Solo incluye registros que caen exactamente dentro del polígono dibujado."),
                  
                  br(),
                  h5("🔑 Configuración API:"),
                  textInput("ebird_api_key",
                           "eBird API Key (opcional):",
                           placeholder = "O crea archivo 'ebirdapi_key' en la carpeta del proyecto"),
                  helpText("🔑 Prioridad: 1) Campo arriba, 2) Archivo 'ebirdapi_key', 3) Variable EBIRD_KEY. Obtén tu clave gratuita en: https://ebird.org/api/keygen")
                )
              ),
              
              br(),
              
              fluidRow(
                column(12,
                  div(style = "text-align: center;",
                      actionButton("start_query", 
                                 "🚀 Iniciar Consulta de Biodiversidad", 
                                 class = "btn btn-success btn-lg",
                                 style = "margin: 10px;"),
                      
                      actionButton("stop_query", 
                                 "⏹️ Detener Consulta", 
                                 class = "btn btn-warning",
                                 style = "margin: 10px;"),
                      
                      actionButton("clear_results", 
                                 "🗑️ Limpiar Resultados", 
                                 class = "btn btn-danger",
                                 style = "margin: 10px;")
                  )
                )
              )
            )
          )
        ),
        
        # Panel de Estado de Consulta
        fluidRow(
          box(
            title = NULL,
            status = "primary",
            solidHeader = FALSE,
            width = 12,
            background = NULL,
            
            div(id = "query_status_panel",
                style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                         color: white; 
                         padding: 20px; 
                         border-radius: 10px; 
                         text-align: center; 
                         margin: 10px 0;
                         box-shadow: 0 4px 8px rgba(0,0,0,0.1);",
                
                h3(id = "status_title", "🔍 Estado de Consulta", style = "margin-top: 0; font-weight: bold;"),
                
                div(id = "status_message", 
                    style = "font-size: 18px; margin: 15px 0;",
                    "Listo para comenzar consulta de biodiversidad"),
                
                div(id = "status_details", 
                    style = "font-size: 14px; opacity: 0.9; margin: 10px 0;",
                    "Selecciona las bases de datos y haz clic en 'Iniciar Consulta'"),
                
                div(id = "progress_container", 
                    style = "margin: 20px 0; display: none;",
                    
                    div(style = "background: rgba(255,255,255,0.2); height: 20px; border-radius: 10px; overflow: hidden; margin: 10px 0;",
                        div(id = "progress_bar", 
                            style = "background: #28a745; height: 100%; width: 0%; transition: width 0.3s ease; border-radius: 10px;")
                    ),
                    
                    div(id = "progress_stats", 
                        style = "font-size: 14px; margin: 10px 0;",
                        "0% completado - 0 de 0 boxes procesados - 0 registros encontrados")
                )
            )
          )
        ),
        
        fluidRow(
          box(
            title = "📊 Progreso de Consultas",
            status = "info",
            solidHeader = TRUE,
            width = 12,
            
            fluidRow(
              column(4,
                valueBoxOutput("query_progress", width = 12)
              ),
              column(4,
                valueBoxOutput("total_records", width = 12)
              ),
              column(4,
                valueBoxOutput("unique_species", width = 12)
              )
            ),
            
            br(),
            
            fluidRow(
              column(12,
                div(style = "text-align: center; margin: 20px 0;",
                    actionButton("toggle_logs", 
                               "📝 Mostrar/Ocultar Logs Detallados", 
                               class = "btn btn-info btn-sm")
                ),
                
                div(id = "logs_panel",
                    style = "display: none; background: #f8f9fa; padding: 15px; border-radius: 8px; border: 1px solid #dee2e6; margin: 10px 0; max-height: 400px; overflow-y: auto;",
                    
                    div(style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;",
                        h6("📋 Registro Detallado de Actividad", style = "margin: 0; color: #495057;"),
                        actionButton("clear_logs", "🗑️ Limpiar", class = "btn btn-outline-secondary btn-xs")
                    ),
                    
                    div(id = "detailed_log_content",
                        style = "font-family: 'Courier New', monospace; font-size: 12px; line-height: 1.4; color: #495057; white-space: pre-wrap;",
                        "Esperando inicio de consulta..."
                    )
                )
              )
            )
              )
            )
          )
        )
      ),
      
      # Nueva pestaña de resultados
      tabItem(tabName = "results",
        fluidRow(
          box(
            title = "📈 Resumen de Resultados",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            
            conditionalPanel(
              condition = "!output.has_results",
              div(style = "text-align: center; padding: 20px;",
                  h4("📭 No hay resultados disponibles"),
                  p("Ejecuta una consulta de biodiversidad para ver los resultados aquí."),
                  actionButton("go_to_biodiversity", "🌿 Ir a Consulta", 
                             class = "btn btn-success")
              )
            ),
            
            conditionalPanel(
              condition = "output.has_results",
              fluidRow(
                column(3,
                  valueBoxOutput("final_records", width = 12)
                ),
                column(3,
                  valueBoxOutput("final_species", width = 12)
                ),
                column(3,
                  valueBoxOutput("data_sources", width = 12)
                ),
                column(3,
                  valueBoxOutput("area_covered", width = 12)
                )
              )
            )
          )
        ),
        
        conditionalPanel(
          condition = "output.has_results",
          fluidRow(
            box(
              title = "🗺️ Mapa de Resultados",
              status = "success",
              solidHeader = TRUE,
              width = 8,
              
              leafletOutput("results_map", height = "400px")
            ),
            
            box(
              title = "📊 Gráficos",
              status = "info",
              solidHeader = TRUE,
              width = 4,
              
              tabsetPanel(
                tabPanel("Por Fuente", 
                         plotlyOutput("source_plot", height = "180px")),
                tabPanel("Por Año", 
                         plotlyOutput("year_plot", height = "180px")),
                tabPanel("Top Especies", 
                         plotlyOutput("species_plot", height = "180px"))
              )
            )
          ),
          
          fluidRow(
            box(
              title = "📋 Tabla de Resultados",
              status = "warning",
              solidHeader = TRUE,
              width = 12,
              
              DT::dataTableOutput("results_table"),
              
              br(),
              
              fluidRow(
                column(4,
                  downloadButton("download_results_csv", 
                               "📥 Descargar CSV",
                               class = "btn btn-primary")
                ),
                column(4,
                  downloadButton("download_results_excel", 
                               "📊 Descargar Excel",
                               class = "btn btn-success")
                ),
                column(4,
                  downloadButton("download_results_shapefile", 
                               "🗺️ Descargar Shapefile",
                               class = "btn btn-info")
                )
              )
            )
          )
        )
      ),
      
      # Nueva pestaña para datos de scripts
      tabItem(tabName = "export_data",
        fluidRow(
          box(
            title = "Datos para Script de Biodiversidad",
            status = "success",
            solidHeader = TRUE,
            width = 12,
            
            h4("🎯 Formatos de Exportación para Scripts de R"),
            p("Esta sección genera los datos del polígono en los formatos necesarios para usar en scripts de biodiversidad."),
            
            fluidRow(
              column(6,
                h5("📐 Información del Polígono:"),
                verbatimTextOutput("polygon_info")
              ),
              column(6,
                h5("🗺️ Coordenadas WKT:"),
                verbatimTextOutput("wkt_output")
              )
            )
          )
        ),
        
        fluidRow(
          box(
            title = "Bounding Boxes para APIs",
            status = "primary",
            solidHeader = TRUE,
            width = 6,
            
            h5("📦 Bounding Box Principal:"),
            verbatimTextOutput("main_bbox"),
            
            br(),
            h5("🔲 Grid de Bounding Boxes:"),
            numericInput("grid_size", "Tamaño de grid (grados):", value = 1.0, min = 0.1, max = 5.0, step = 0.1),
            verbatimTextOutput("grid_bboxes")
          ),
          
          box(
            title = "Exportar Código R",
            status = "warning",
            solidHeader = TRUE,
            width = 6,
            
            h5("📝 Código R Generado:"),
            verbatimTextOutput("r_code"),
            
            br(),
            fluidRow(
              column(6,
                downloadButton("download_r_code", 
                             "💾 Descargar Código R",
                             class = "btn btn-warning",
                             style = "width: 100%;")
              ),
              column(6,
                downloadButton("download_wkt_data", 
                             "📊 Datos WKT/Bbox",
                             class = "btn btn-info",
                             style = "width: 100%;")
              )
            )
          )
        ),
        
        fluidRow(
          box(
            title = "Vista Previa de Datos",
            status = "info",
            solidHeader = TRUE,
            width = 12,
            
            tabsetPanel(
              tabPanel("Coordenadas WKT", 
                       br(),
                       DT::dataTableOutput("wkt_table")),
              tabPanel("Bounding Boxes", 
                       br(),
                       DT::dataTableOutput("bbox_table")),
              tabPanel("Código R Completo", 
                       br(),
                       verbatimTextOutput("full_r_code"))
            )
          )
        )
      )
    )



# SERVER (Lógica del servidor)
server <- function(input, output, session) {
  # Variables reactivas
  values <- reactiveValues(
    vertices = data.frame(lat = numeric(0), lng = numeric(0)),
    is_drawing = FALSE,
    polygon_complete = FALSE,
    click_count = 0,
    wkt_data = character(0),
    bbox_data = character(0),
    grid_wkt = character(0),
    grid_bbox = character(0),
    # Nuevas variables para consultas de biodiversidad
    biodiversity_data = data.frame(
      species = character(0),
      lon = numeric(0),
      lat = numeric(0),
      year = numeric(0),
      month = numeric(0),
      day = numeric(0),
      date_recorded = character(0),
      taxonRank = character(0), # Añadir taxonRank
      source = character(0),
      stringsAsFactors = FALSE
    ),
    query_running = FALSE,
    query_progress = 0,
    query_log = character(),
    current_box = 0,
    total_boxes = 0,
    has_results = FALSE,
    # Nuevas variables para estado detallado
    query_status = "idle", # idle, working, completed, error
    current_database = "",
    total_records_found = 0,
    unique_species_count = 0,
    detailed_log = character(),
    start_time = NULL,
    boxes_processed = 0
  )
  
  # Inicializar mapa
  output$map <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      setView(lng = -106.0, lat = 20.0, zoom = 6) %>%  # Pacífico Mexicano
      addProviderTiles(providers$OpenStreetMap)
  })
  
  # Manejar eventos de click en el mapa
  observeEvent(input$map_click, {
    if (values$is_drawing && !values$polygon_complete) {
      click <- input$map_click
      
      # Agregar nuevo vértice
      new_vertex <- data.frame(lat = click$lat, lng = click$lng)
      values$vertices <- rbind(values$vertices, new_vertex)
      values$click_count <- values$click_count + 1
      
      # Actualizar mapa con nuevo marcador
      leafletProxy("map") %>%
        addCircleMarkers(
          lng = click$lng,
          lat = click$lat,
          radius = 8,
          color = "#3498db",
          fillColor = "#3498db",
          fillOpacity = 0.8,
          popup = paste("Vértice", nrow(values$vertices)),
          layerId = paste0("vertex_", nrow(values$vertices))
        )
      
      # Si hay más de un vértice, dibujar líneas
      if (nrow(values$vertices) > 1) {
        for (i in 2:nrow(values$vertices)) {
          leafletProxy("map") %>%
            addPolylines(
              lng = c(values$vertices$lng[i-1], values$vertices$lng[i]),
              lat = c(values$vertices$lat[i-1], values$vertices$lat[i]),
              color = "#e74c3c",
              weight = 3,
              opacity = 0.8,
              layerId = paste0("line_", i)
            )
        }
      }
      
      # Actualizar estado
      updateStatus()
    }
  })
  
  # Función para actualizar el estado
  updateStatus <- function() {
    vertex_count <- nrow(values$vertices)
    
    if (vertex_count == 0) {
      status_text <- "Haz clic en 'Comenzar Dibujo' para empezar"
    } else if (vertex_count < 3) {
      status_text <- paste("Vértices creados:", vertex_count, "(mínimo 3 para polígono)")
    } else {
      status_text <- paste("Vértices creados:", vertex_count, "- Listo para finalizar polígono")
    }
    
    output$status_info <- renderUI({
      div(style = "text-align: center; padding: 10px; background-color: #e8f4fd; border-radius: 5px;",
          h4("📍 Estado:", style = "margin: 0;"),
          p(status_text, style = "margin: 5px 0 0 0;")
      )
    })
  }
  
  # Comenzar dibujo
  observeEvent(input$start_drawing, {
    values$is_drawing <- TRUE
    values$polygon_complete <- FALSE
    values$vertices <- data.frame(lat = numeric(0), lng = numeric(0))
    
    # Limpiar mapa
    leafletProxy("map") %>%
      clearMarkers() %>%
      clearShapes()
    
    updateStatus()
    
    showNotification("Modo dibujo activado. Haz clic en el mapa para agregar vértices.", 
                     type = "default", duration = 3)
  })
  
  # Finalizar polígono
  observeEvent(input$finish_polygon, {
    if (nrow(values$vertices) >= 3) {
      values$is_drawing <- FALSE
      values$polygon_complete <- TRUE
      
      # Agregar polígono al mapa
      leafletProxy("map") %>%
        addPolygons(
          lng = values$vertices$lng,
          lat = values$vertices$lat,
          color = "#2ecc71",
          weight = 3,
          opacity = 1,
          fillColor = "#2ecc71",
          fillOpacity = 0.3,
          layerId = "final_polygon"
        )
      
      # Generar datos WKT y bounding boxes
      generatePolygonData()
      
      updateStatus()
      showNotification("¡Polígono completado! Ahora puedes exportar las coordenadas.", 
                       type = "default", duration = 3)
    } else {
      showNotification("Necesitas al menos 3 vértices para crear un polígono.", 
                       type = "error", duration = 3)
    }
  })
  
  # Función para generar datos del polígono
  generatePolygonData <- function() {
    if (nrow(values$vertices) >= 3) {
      # Crear matriz de coordenadas (cerrar el polígono)
      coords_matrix <- as.matrix(values$vertices[, c("lng", "lat")])
      coords_matrix <- rbind(coords_matrix, coords_matrix[1, ])  # Cerrar polígono
      
      # Generar WKT
      wkt_coords <- paste(coords_matrix[, 1], coords_matrix[, 2], collapse = ", ")
      values$wkt_data <- paste0("POLYGON((", wkt_coords, "))")
      
      # Calcular bounding box principal
      min_lng <- min(values$vertices$lng)
      max_lng <- max(values$vertices$lng)
      min_lat <- min(values$vertices$lat)
      max_lat <- max(values$vertices$lat)
      
      values$bbox_data <- paste(min_lng, min_lat, max_lng, max_lat, sep = ",")
      
      # Generar grid de bounding boxes
      generateGridData()
    }
  }
  
  # Función para generar grid de bounding boxes
  generateGridData <- function() {
    if (nrow(values$vertices) >= 3) {
      grid_size <- input$grid_size
      if (is.null(grid_size)) grid_size <- 1.0
      
      # Calcular bounds del polígono
      min_lng <- min(values$vertices$lng)
      max_lng <- max(values$vertices$lng)
      min_lat <- min(values$vertices$lat)
      max_lat <- max(values$vertices$lat)
      
      # Generar secuencias para el grid
      lng_seq <- seq(min_lng, max_lng, by = grid_size)
      lat_seq <- seq(min_lat, max_lat, by = grid_size)
      
      wkt_list <- character()
      bbox_list <- character()
      
      for (lat in lat_seq) {
        for (lng in lng_seq) {
          # Crear bounding box
          lat_min <- lat
          lat_max <- min(lat + grid_size, max_lat)
          lng_min <- lng
          lng_max <- min(lng + grid_size, max_lng)
          
          # Skip si el box está fuera de bounds
          if (lat_min >= lat_max || lng_min >= lng_max) next
          
          # Crear WKT polygon
          wkt_polygon <- sprintf("POLYGON((%f %f, %f %f, %f %f, %f %f, %f %f))",
                                lng_min, lat_min,  # bottom-left
                                lng_max, lat_min,  # bottom-right
                                lng_max, lat_max,  # top-right
                                lng_min, lat_max,  # top-left
                                lng_min, lat_min)  # close polygon
          
          wkt_list <- c(wkt_list, wkt_polygon)
          
          # Bounding box para otras APIs
          bbox <- paste(lng_min, lat_min, lng_max, lat_max, sep = ",")
          bbox_list <- c(bbox_list, bbox)
        }
      }
      
      values$grid_wkt <- wkt_list
      values$grid_bbox <- bbox_list
    }
  }
  
  # Actualizar grid cuando cambie el tamaño
  observeEvent(input$grid_size, {
    if (values$polygon_complete) {
      generateGridData()
    }
  })
  
  # Limpiar todo
  observeEvent(input$clear_all, {
    values$vertices <- data.frame(lat = numeric(0), lng = numeric(0))
    values$is_drawing <- FALSE
    values$polygon_complete <- FALSE
    values$click_count <- 0
    values$wkt_data <- character(0)
    values$bbox_data <- character(0)
    values$grid_wkt <- character(0)
    values$grid_bbox <- character(0)
    
    leafletProxy("map") %>%
      clearMarkers() %>%
      clearShapes()
    
    updateStatus()
    showNotification("Mapa limpiado.", type = "warning", duration = 2)
  })
  
  # Tabla de coordenadas
  output$coordinates_table <- DT::renderDataTable({
    if (nrow(values$vertices) > 0) {
      coord_table <- values$vertices
      coord_table$Vertice <- 1:nrow(coord_table)
      coord_table$Latitud <- round(coord_table$lat, 6)
      coord_table$Longitud <- round(coord_table$lng, 6)
      coord_table <- coord_table[, c("Vertice", "Latitud", "Longitud")]
      
      DT::datatable(coord_table,
                    options = list(pageLength = 15, scrollX = TRUE),
                    rownames = FALSE)
    } else {
      DT::datatable(data.frame(Mensaje = "No hay coordenadas disponibles"),
                    options = list(pageLength = 15),
                    rownames = FALSE)
    }
  })
  
  # Value boxes
  output$vertex_count <- renderValueBox({
    valueBox(
      value = nrow(values$vertices),
      subtitle = "Vértices",
      icon = icon("map-pin"),
      color = "blue"
    )
  })
  
  output$area_info <- renderValueBox({
    area_text <- if (values$polygon_complete) "Completado" else "En progreso"
    valueBox(
      value = area_text,
      subtitle = "Estado del Polígono",
      icon = icon("check-circle"),
      color = if (values$polygon_complete) "green" else "yellow"
    )
  })
  
  # Descarga CSV
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("poligono_coordenadas_", Sys.Date(), ".csv")
    },
    content = function(file) {
      if (nrow(values$vertices) > 0) {
        coord_data <- data.frame(
          Vertice = 1:nrow(values$vertices),
          Latitud = round(values$vertices$lat, 6),
          Longitud = round(values$vertices$lng, 6)
        )
        write.csv(coord_data, file, row.names = FALSE)
      }
    }
  )
  
  # Descarga personalizada
  output$download_custom <- downloadHandler(
    filename = function() {
      ext <- switch(input$export_format,
                    "csv" = ".csv",
                    "txt" = ".txt",
                    "xlsx" = ".xlsx")
      paste0("poligono_coordenadas_", Sys.Date(), ext)
    },
    content = function(file) {
      if (nrow(values$vertices) > 0) {
        coord_data <- data.frame(
          Vertice = 1:nrow(values$vertices),
          Latitud = round(values$vertices$lat, 6),
          Longitud = round(values$vertices$lng, 6)
        )
        
        switch(input$export_format,
               "csv" = write.csv(coord_data, file, row.names = FALSE),
               "txt" = write.table(coord_data, file, sep = "\t", row.names = FALSE),
               "xlsx" = {
                 if (require(openxlsx)) {
                   openxlsx::write.xlsx(coord_data, file)
                 } else {
                   write.csv(coord_data, file, row.names = FALSE)
                 }
               }
        )
      }
    }
  )
  
  # ========================================
  # OUTPUTS PARA LA NUEVA PESTAÑA
  # ========================================
  
  # Información del polígono
  output$polygon_info <- renderText({
    if (values$polygon_complete && nrow(values$vertices) > 0) {
      min_lng <- round(min(values$vertices$lng), 6)
      max_lng <- round(max(values$vertices$lng), 6)
      min_lat <- round(min(values$vertices$lat), 6)
      max_lat <- round(max(values$vertices$lat), 6)
      
      paste0(
        "Vértices: ", nrow(values$vertices), "\n",
        "Área Aprox: ", round((max_lng - min_lng) * (max_lat - min_lat), 4), " grados²\n",
        "Longitud: ", min_lng, " a ", max_lng, "\n",
        "Latitud: ", min_lat, " a ", max_lat, "\n",
        "Grid boxes: ", length(values$grid_wkt)
      )
    } else {
      "Dibuja y finaliza un polígono para ver la información"
    }
  })
  
  # WKT Output
  output$wkt_output <- renderText({
    if (values$polygon_complete && length(values$wkt_data) > 0) {
      values$wkt_data
    } else {
      "WKT se generará cuando completes el polígono"
    }
  })
  
  # Bounding box principal
  output$main_bbox <- renderText({
    if (values$polygon_complete && length(values$bbox_data) > 0) {
      paste0(
        "Formato: min_lng,min_lat,max_lng,max_lat\n",
        values$bbox_data
      )
    } else {
      "Bounding box se generará cuando completes el polígono"
    }
  })
  
  # Grid de bounding boxes
  output$grid_bboxes <- renderText({
    if (length(values$grid_bbox) > 0) {
      paste0(
        "Total de boxes: ", length(values$grid_bbox), "\n",
        "Ejemplos:\n",
        paste(head(values$grid_bbox, 3), collapse = "\n"),
        if (length(values$grid_bbox) > 3) "\n..." else ""
      )
    } else {
      "Grid se generará cuando completes el polígono"
    }
  })
  
  # Código R generado
  output$r_code <- renderText({
    if (values$polygon_complete) {
      paste0(
        "# Datos del polígono generados automáticamente\n",
        "# Fecha: ", Sys.Date(), "\n\n",
        "# WKT del polígono principal\n",
        "polygon_wkt <- \"", values$wkt_data, "\"\n\n",
        "# Bounding box principal\n",
        "main_bbox <- \"", values$bbox_data, "\"\n\n",
        "# Grid de WKT polygons\n",
        "wkt.data <- c(\n",
        if (length(values$grid_wkt) > 0) {
          paste0("  \"", head(values$grid_wkt, 5), "\"", collapse = ",\n")
        } else {"  # No grid data"},
        if (length(values$grid_wkt) > 5) "\n  # ... más polígonos" else "",
        "\n)\n\n",
        "# Grid de bounding boxes\n",
        "boxes.data <- c(\n",
        if (length(values$grid_bbox) > 0) {
          paste0("  \"", head(values$grid_bbox, 5), "\"", collapse = ",\n")
        } else {"  # No bbox data"},
        if (length(values$grid_bbox) > 5) "\n  # ... más boxes" else "",
        "\n)"
      )
    } else {
      "# El código R se generará cuando completes el polígono"
    }
  })
  
  # Tabla WKT
  output$wkt_table <- DT::renderDataTable({
    if (length(values$grid_wkt) > 0) {
      wkt_df <- data.frame(
        ID = 1:length(values$grid_wkt),
        WKT_Polygon = values$grid_wkt,
        stringsAsFactors = FALSE
      )
      DT::datatable(wkt_df, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
    } else {
      DT::datatable(data.frame(Mensaje = "No hay datos WKT disponibles"), rownames = FALSE)
    }
  })
  
  # Tabla Bounding Boxes
  output$bbox_table <- DT::renderDataTable({
    if (length(values$grid_bbox) > 0) {
      bbox_df <- data.frame(
        ID = 1:length(values$grid_bbox),
        Bounding_Box = values$grid_bbox,
        stringsAsFactors = FALSE
      )
      DT::datatable(bbox_df, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
    } else {
      DT::datatable(data.frame(Mensaje = "No hay datos de bounding box disponibles"), rownames = FALSE)
    }
  })
  
  # Código R completo
  output$full_r_code <- renderText({
    if (values$polygon_complete) {
      paste0(
        "# ============================================\n",
        "# POLÍGONO PERSONALIZADO PARA BIODIVERSIDAD\n",
        "# Generado automáticamente el ", Sys.Date(), "\n",
        "# ============================================\n\n",
        "library(sf)\n",
        "library(rgbif)\n\n",
        "# Coordenadas originales del polígono\n",
        "polygon_vertices <- data.frame(\n",
        paste0("  lat = c(", paste(round(values$vertices$lat, 6), collapse = ", "), "),\n"),
        paste0("  lng = c(", paste(round(values$vertices$lng, 6), collapse = ", "), ")\n"),
        ")\n\n",
        "# WKT del polígono principal\n",
        "polygon_wkt <- \"", values$wkt_data, "\"\n\n",
        "# Bounding box principal (min_lng,min_lat,max_lng,max_lat)\n",
        "main_bbox <- \"", values$bbox_data, "\"\n\n",
        "# Grid de WKT polygons para consultas GBIF\n",
        "wkt.data <- c(\n",
        if (length(values$grid_wkt) > 0) {
          paste0("  \"", values$grid_wkt, "\"", collapse = ",\n")
        } else {"  # No hay datos WKT"},
        "\n)\n\n",
        "# Grid de bounding boxes para otras APIs\n",
        "boxes.data <- c(\n",
        if (length(values$grid_bbox) > 0) {
          paste0("  \"", values$grid_bbox, "\"", collapse = ",\n")
        } else {"  # No hay datos de bbox"},
        "\n)\n\n",
        "# Crear polígono sf para filtrado espacial\n",
        "coords_matrix <- matrix(c(\n",
        paste0("  ", apply(cbind(values$vertices$lng, values$vertices$lat), 1, 
               function(x) paste(x, collapse = ", ")), collapse = ",\n"),
        ",\n",
        paste0("  ", values$vertices$lng[1], ", ", values$vertices$lat[1], "  # Cerrar polígono\n"),
        "), ncol = 2, byrow = TRUE)\n\n",
        "custom_polygon <- st_polygon(list(coords_matrix))\n",
        "custom_shape <- st_sfc(custom_polygon, crs = st_crs(4326))\n\n",
        "# Para usar en el script de biodiversidad:\n",
        "# 1. Reemplaza wkt.data con el array generado arriba\n",
        "# 2. Reemplaza boxes.data con el array generado arriba\n",
        "# 3. Usa custom_shape en lugar de goc.shape para filtrado espacial\n\n",
        "cat('Polígono personalizado cargado con', length(wkt.data), 'boxes para consultas\\n')"
      )
    } else {
      "# Completa el polígono para generar el código R completo"
    }
  })
  
  # Descargas de la nueva pestaña
  output$download_r_code <- downloadHandler(
    filename = function() {
      paste0("polygon_data_", Sys.Date(), ".R")
    },
    content = function(file) {
      if (values$polygon_complete) {
        r_code_content <- paste0(
          "# ============================================\n",
          "# POLÍGONO PERSONALIZADO PARA BIODIVERSIDAD\n",
          "# Generado automáticamente el ", Sys.Date(), "\n",
          "# ============================================\n\n",
          "# WKT del polígono principal\n",
          "polygon_wkt <- \"", values$wkt_data, "\"\n\n",
          "# Bounding box principal\n",
          "main_bbox <- \"", values$bbox_data, "\"\n\n",
          "# Grid de WKT polygons\n",
          "wkt.data <- c(\n",
          if (length(values$grid_wkt) > 0) {
            paste0("  \"", values$grid_wkt, "\"", collapse = ",\n")
          } else {"  # No hay datos"},
          "\n)\n\n",
          "# Grid de bounding boxes\n",
          "boxes.data <- c(\n",
          if (length(values$grid_bbox) > 0) {
            paste0("  \"", values$grid_bbox, "\"", collapse = ",\n")
          } else {"  # No hay datos"},
          "\n)\n\n",
          "cat('Datos del polígono cargados:', length(wkt.data), 'WKT polygons y', length(boxes.data), 'bounding boxes\\n')"
        )
        writeLines(r_code_content, file)
      }
    }
  )
  
  output$download_wkt_data <- downloadHandler(
    filename = function() {
      paste0("polygon_wkt_bbox_", Sys.Date(), ".csv")
    },
    content = function(file) {
      if (values$polygon_complete) {
        # Crear dataframe combinado
        max_length <- max(length(values$grid_wkt), length(values$grid_bbox))
        
        export_data <- data.frame(
          ID = 1:max_length,
          WKT_Polygon = c(values$grid_wkt, rep(NA, max_length - length(values$grid_wkt))),
          Bounding_Box = c(values$grid_bbox, rep(NA, max_length - length(values$grid_bbox))),
          stringsAsFactors = FALSE
        )
        
        write.csv(export_data, file, row.names = FALSE)
      }
    }
  )
  
  # ========================================
  # FUNCIONALIDADES DE BIODIVERSIDAD
  # ========================================
  
  # Verificar si el polígono está listo
  output$polygon_ready <- reactive({
    values$polygon_complete
  })
  outputOptions(output, 'polygon_ready', suspendWhenHidden = FALSE)
  
  # Verificar si hay resultados
  output$has_results <- reactive({
    values$has_results && nrow(values$biodiversity_data) > 0
  })
  outputOptions(output, 'has_results', suspendWhenHidden = FALSE)
  
  # Información del grid
  output$grid_info_text <- renderText({
    if (!values$polygon_complete) {
      return("⚠️ Primero dibuja y finaliza un polígono")
    }
    
    tryCatch({
      # Obtener el polígono
      polygon_sf <- createPolygonSF()
      if (is.null(polygon_sf)) {
        return("❌ Error al crear el polígono")
      }
      
      # Calcular el bounding box
      bbox <- sf::st_bbox(polygon_sf)
      
      # Obtener el tamaño del grid
      grid_size <- if(is.null(input$bio_grid_size)) 1.0 else input$bio_grid_size
      
      # Calcular número de celdas
      lon_range <- bbox["xmax"] - bbox["xmin"]
      lat_range <- bbox["ymax"] - bbox["ymin"]
      
      boxes_lon <- ceiling(lon_range / grid_size)
      boxes_lat <- ceiling(lat_range / grid_size)
      total_boxes <- boxes_lon * boxes_lat
      
      # Límite máximo
      max_boxes <- if(is.null(input$max_boxes)) 5 else input$max_boxes
      actual_boxes <- min(total_boxes, max_boxes)
      
      # Calcular área aproximada
      area_km2 <- round(as.numeric(sf::st_area(polygon_sf)) / 1000000, 2)
      
      paste0(
        "🌍 Área: ~", area_km2, " km²\n",
        "📐 Grid: ", grid_size, "° (", boxes_lon, "×", boxes_lat, ")\n",
        "📦 Total boxes: ", total_boxes, "\n",
        "🎯 Boxes a consultar: ", actual_boxes, "\n",
        "⏱️ Tiempo estimado: ~", ceiling(actual_boxes * 3 / 60), " min"
      )
    }, error = function(e) {
      return("⚠️ Error al calcular información del grid")
    })
  })
  
  # Navegación entre pestañas
  observeEvent(input$go_to_map, {
    updateTabItems(session, "sidebar", "mapa")
  })
  
  observeEvent(input$go_to_biodiversity, {
    updateTabItems(session, "sidebar", "biodiversity")
  })
  
  # Actualizar información del grid cuando cambien los parámetros
  observeEvent(list(input$bio_grid_size, input$max_boxes), {
    # Esto forzará la re-evaluación de grid_info_text
    NULL
  })
  
  # Toggle para mostrar/ocultar logs
  observeEvent(input$toggle_logs, {
    shinyjs::toggle("logs_panel")
  })
  
  # Limpiar logs detallados
  observeEvent(input$clear_logs, {
    values$detailed_log <- character()
    values$query_log <- character()
  })
  
  # Observador para actualizar la interfaz de estado
  observe({
    # Actualizar panel principal de estado
    if (values$query_status == "idle") {
      shinyjs::runjs("
        document.getElementById('status_message').textContent = 'Listo para comenzar consulta de biodiversidad';
        document.getElementById('status_details').textContent = 'Selecciona las bases de datos y haz clic en \\'Iniciar Consulta\\'';
        document.getElementById('progress_container').style.display = 'none';
        document.getElementById('query_status_panel').style.background = 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
      ")
    } else if (values$query_status == "working") {
      current_db <- if(nchar(values$current_database) > 0) values$current_database else "Preparando"
      progress_pct <- round((values$boxes_processed / max(values$total_boxes, 1)) * 100, 1)
      
      shinyjs::runjs(paste0("
        document.getElementById('status_message').innerHTML = '🔄 Consultando ", current_db, " - Box ", values$current_box, " de ", values$total_boxes, " <div style=\"display:inline-block; margin-left: 10px;\"><div class=\"spinner-border spinner-border-sm\" role=\"status\" style=\"border-width: 2px;\"></div></div>';
        document.getElementById('status_details').textContent = 'Procesando datos de biodiversidad, por favor espera...';
        document.getElementById('progress_container').style.display = 'block';
        document.getElementById('progress_bar').style.width = '", progress_pct, "%';
        document.getElementById('progress_stats').textContent = '", progress_pct, "% completado - ", values$boxes_processed, " de ", values$total_boxes, " boxes procesados - ", values$total_records_found, " registros encontrados';
        document.getElementById('query_status_panel').style.background = 'linear-gradient(135deg, #28a745 0%, #20c997 100%)';
        document.getElementById('query_status_panel').style.animation = 'pulse 2s infinite';
      "))
    } else if (values$query_status == "completed") {
      elapsed_time <- if(!is.null(values$start_time)) {
        paste0(round(as.numeric(difftime(Sys.time(), values$start_time, units = "secs")), 1), " segundos")
      } else "N/A"
      
      shinyjs::runjs(paste0("
        document.getElementById('status_message').textContent = '✅ Consulta completada: ", values$total_records_found, " registros finales';
        document.getElementById('status_details').textContent = 'Tiempo transcurrido: ", elapsed_time, " | Especies únicas: ", values$unique_species_count, "';
        document.getElementById('progress_container').style.display = 'block';
        document.getElementById('progress_bar').style.width = '100%';
        document.getElementById('progress_stats').textContent = '100% completado - ", values$total_boxes, " de ", values$total_boxes, " boxes procesados - ", values$total_records_found, " registros finales';
        document.getElementById('query_status_panel').style.background = 'linear-gradient(135deg, #28a745 0%, #34ce57 100%)';
        document.getElementById('query_status_panel').style.animation = 'none';
      "))
    } else if (values$query_status == "error") {
      shinyjs::runjs("
        document.getElementById('status_message').textContent = '❌ Error en la consulta';
        document.getElementById('status_details').textContent = 'Revisa los logs para más detalles';
        document.getElementById('progress_container').style.display = 'none';
        document.getElementById('query_status_panel').style.background = 'linear-gradient(135deg, #dc3545 0%, #c82333 100%)';
        document.getElementById('query_status_panel').style.animation = 'none';
      ")
    }
    
    # Actualizar logs detallados
    if (length(values$detailed_log) > 0) {
      log_content <- paste(values$detailed_log, collapse = "\n")
      shinyjs::runjs(paste0("
        document.getElementById('detailed_log_content').textContent = `", gsub("`", "\\`", log_content), "`;
        var logDiv = document.getElementById('detailed_log_content');
        logDiv.scrollTop = logDiv.scrollHeight;
      "))
    }
  })
  
  # Iniciar consulta de biodiversidad
  observeEvent(input$start_query, {
    if (!values$polygon_complete) {
      showNotification("Primero debes dibujar y finalizar un polígono", type = "error")
      return()
    }
    
    # Reiniciar variables
    values$query_running <- TRUE
    values$query_progress <- 0
    values$current_box <- 0
    values$query_log <- character()
    values$biodiversity_data <- data.frame()
    
    # Generar grid con parámetros actuales
    generateGridForBiodiversity()
    
    # Iniciar consultas
    runBiodiversityQueries()
  })
  
  # Función para generar grid específico para biodiversidad
  generateGridForBiodiversity <- function() {
    if (nrow(values$vertices) >= 3) {
      grid_size <- input$bio_grid_size
      if (is.null(grid_size)) grid_size <- 1.0
      
      # Calcular bounds del polígono
      min_lng <- min(values$vertices$lng)
      max_lng <- max(values$vertices$lng)
      min_lat <- min(values$vertices$lat)
      max_lat <- max(values$vertices$lat)
      
      # Generar secuencias para el grid
      lng_seq <- seq(min_lng, max_lng, by = grid_size)
      lat_seq <- seq(min_lat, max_lat, by = grid_size)
      
      wkt_list <- character()
      bbox_list <- character()
      
      for (lat in lat_seq) {
        for (lng in lng_seq) {
          # Crear bounding box
          lat_min <- lat
          lat_max <- min(lat + grid_size, max_lat)
          lng_min <- lng
          lng_max <- min(lng + grid_size, max_lng)
          
          # Skip si el box está fuera de bounds
          if (lat_min >= lat_max || lng_min >= lng_max) next
          
          # Crear WKT polygon
          wkt_polygon <- sprintf("POLYGON((%f %f, %f %f, %f %f, %f %f, %f %f))",
                                lng_min, lat_min,  # bottom-left
                                lng_max, lat_min,  # bottom-right
                                lng_max, lat_max,  # top-right
                                lng_min, lat_max,  # top-left
                                lng_min, lat_min)  # close polygon
          
          wkt_list <- c(wkt_list, wkt_polygon)
          
          # Bounding box para otras APIs
          bbox <- paste(lng_min, lat_min, lng_max, lat_max, sep = ",")
          bbox_list <- c(bbox_list, bbox)
        }
      }
      
      # Limitar número de boxes
      max_boxes <- input$max_boxes
      if (is.null(max_boxes)) max_boxes <- 5
      
      if (length(wkt_list) > max_boxes) {
        wkt_list <- wkt_list[1:max_boxes]
        bbox_list <- bbox_list[1:max_boxes]
      }
      
      values$grid_wkt <- wkt_list
      values$grid_bbox <- bbox_list
      values$total_boxes <- length(wkt_list)
      
      # Log inicial
      log_message <- paste("Grid generado:", length(wkt_list), "boxes de", grid_size, "grados")
      values$query_log <- c(values$query_log, log_message)
    }
  }
  
  # Función para crear polígono SF para filtrado espacial
  createPolygonSF <- function() {
    tryCatch({
      if (nrow(values$vertices) >= 3) {
        coords_matrix <- as.matrix(values$vertices[, c("lng", "lat")])
        coords_matrix <- rbind(coords_matrix, coords_matrix[1, ])  # Cerrar polígono
        
        # Verificar que no hay vértices duplicados consecutivos
        valid_coords <- !duplicated(coords_matrix)
        if (sum(valid_coords) >= 4) {  # Mínimo 3 puntos únicos + punto de cierre
          coords_matrix <- coords_matrix[valid_coords, ]
          coords_matrix <- rbind(coords_matrix, coords_matrix[1, ])  # Re-cerrar
          
          custom_polygon <- st_polygon(list(coords_matrix))
          custom_shape <- st_sfc(custom_polygon, crs = st_crs(4326))
          
          # Validar geometría
          if (st_is_valid(custom_shape)) {
            return(custom_shape)
          }
        }
      }
      return(NULL)
    }, error = function(e) {
      return(NULL)
    })
  }
  
  # Función para filtrar espacialmente los datos
  spatialFilterData <- function(data_df, polygon_sf) {
    if (is.null(polygon_sf) || nrow(data_df) == 0) {
      return(data_df)
    }
    
    tryCatch({
      # Convertir datos a sf
      data_sf <- st_as_sf(
        data_df,
        coords = c("lon", "lat"),
        crs = st_crs(4326)
      )
      
      # Usar st_within para filtrado estricto dentro del polígono
      within_polygon <- st_within(data_sf, polygon_sf, sparse = FALSE)
      filtered_data <- data_sf[within_polygon[,1], ]
      
      if (nrow(filtered_data) > 0) {
        coords <- st_coordinates(filtered_data)
        # Reconstruir el data.frame
        result <- data.frame(
          species = filtered_data$species,
          lon = coords[, "X"],
          lat = coords[, "Y"],
          year = filtered_data$year,
          month = filtered_data$month,
          day = filtered_data$day,
          date_recorded = filtered_data$date_recorded,
          taxonRank = filtered_data$taxonRank, # Añadir taxonRank
          source = filtered_data$source,
          stringsAsFactors = FALSE
        )
        return(result)
      }
      
      return(data.frame())
    }, error = function(e) {
      # Si falla el filtrado espacial, usar filtrado por bounding box
      bbox <- st_bbox(polygon_sf)
      bbox_filtered <- data_df[
        data_df$lon >= bbox["xmin"] &
        data_df$lon <= bbox["xmax"] &
        data_df$lat >= bbox["ymin"] &
        data_df$lat <= bbox["ymax"],
      ]
      return(bbox_filtered)
    })
  }
  
  # Función para consultar GBIF
  queryGBIF <- function(box_index, records_per_box, year_start, year_end) {
    tryCatch({
      # Verificar si estamos en modo sin límites
      is_unlimited <- records_per_box >= 10000
      
      # Configuración para consultas sin límites (con paginación)
      if (is_unlimited) {
        # Inicializar dataframe para todos los resultados
        all_results <- data.frame()
        
        # Parámetros de paginación
        page_size <- 1000  # Tamaño de cada página
        offset <- 0        # Inicio de la paginación
        more_records <- TRUE
        
        # Bucle de paginación
        while (more_records) {
          gbif_params <- list(
            geometry = values$grid_wkt[box_index],
            limit = page_size,
            offset = offset,
            fields = c('scientificName', 'decimalLatitude', 'decimalLongitude',
                      'year', 'month', 'day', 'eventDate', 'basisOfRecord', 'taxonRank'),
            hasCoordinate = TRUE,
            year = paste0(year_start, ",", year_end)
          )
          
          # Agregar filtro de rango taxonómico si está especificado
          if (!is.null(input$gbif_rank) && input$gbif_rank != "") {
            gbif_params$rank <- input$gbif_rank
          }
          
          # Ejecutar consulta
          gbif_data <- do.call(rgbif::occ_search, gbif_params)
          
          # Verificar si hay resultados
          if (!is.null(gbif_data) && !is.null(gbif_data$data) && nrow(gbif_data$data) > 0) {
            # Agregar resultados al dataframe acumulativo
            all_results <- rbind(all_results, gbif_data$data)
            
            # Actualizar offset para la siguiente página
            offset <- offset + nrow(gbif_data$data)
            
            # Verificar si hay más registros por obtener (si la página está llena)
            more_records <- nrow(gbif_data$data) == page_size
          } else {
            more_records <- FALSE
          }
          
          # Agregar mensaje de log
          log_message <- paste("  🔄 GBIF box", box_index, "- paginando:", nrow(all_results), "registros hasta ahora")
          values$query_log <- c(values$query_log, log_message)
        }
        
        # Procesar todos los resultados acumulados
        if (nrow(all_results) > 0) {
          data_df <- all_results
          
          temp_df <- data.frame(
            species = tolower(data_df$scientificName),
            lon = as.numeric(data_df$decimalLongitude),
            lat = as.numeric(data_df$decimalLatitude),
            year = if("year" %in% names(data_df)) as.numeric(data_df$year) else NA,
            month = if("month" %in% names(data_df)) as.numeric(data_df$month) else NA,
            day = if("day" %in% names(data_df)) as.numeric(data_df$day) else NA,
            date_recorded = if("eventDate" %in% names(data_df)) as.character(data_df$eventDate) else NA,
            taxonRank = if("taxonRank" %in% names(data_df)) as.character(data_df$taxonRank) else NA,
            source = "GBIF",
            stringsAsFactors = FALSE
          )
          
          # Filtrar datos válidos
          temp_df <- temp_df[!is.na(temp_df$species) & !is.na(temp_df$lon) & !is.na(temp_df$lat), ]
          
          # Aplicar filtrado espacial si está activado
          if (input$spatial_filter && !is.null(createPolygonSF())) {
            temp_df <- spatialFilterData(temp_df, createPolygonSF())
          }
          
          return(temp_df)
        }
        
        return(data.frame())
      } else {
        # Consulta normal con límite
        gbif_params <- list(
          geometry = values$grid_wkt[box_index],
          limit = records_per_box,
          fields = c('scientificName', 'decimalLatitude', 'decimalLongitude',
                     'year', 'month', 'day', 'eventDate', 'basisOfRecord', 'taxonRank'), # Añadir taxonRank
        hasCoordinate = TRUE,
        year = paste0(year_start, ",", year_end)
      )
      
      # Agregar filtro de rango taxonómico si está especificado
      if (!is.null(input$gbif_rank) && input$gbif_rank != "") {
        gbif_params$rank <- input$gbif_rank
      }
      
      gbif_data <- do.call(rgbif::occ_search, gbif_params)
      
      if (!is.null(gbif_data) && !is.null(gbif_data$data) && nrow(gbif_data$data) > 0) {
        data_df <- gbif_data$data
        
        temp_df <- data.frame(
          species = tolower(data_df$scientificName), # Convertir a minúsculas
          lon = as.numeric(data_df$decimalLongitude),
          lat = as.numeric(data_df$decimalLatitude),
          year = if("year" %in% names(data_df)) as.numeric(data_df$year) else NA,
          month = if("month" %in% names(data_df)) as.numeric(data_df$month) else NA,
          day = if("day" %in% names(data_df)) as.numeric(data_df$day) else NA,
          date_recorded = if("eventDate" %in% names(data_df)) as.character(data_df$eventDate) else NA,
          taxonRank = if("taxonRank" %in% names(data_df)) as.character(data_df$taxonRank) else NA, # Añadir taxonRank
          source = "GBIF",
          stringsAsFactors = FALSE
        )
        
        # Filtrar datos válidos y por año
        temp_df <- temp_df[!is.na(temp_df$species) & !is.na(temp_df$lon) & !is.na(temp_df$lat), ]
        if (nrow(temp_df) > 0 && !is.na(year_start) && !is.na(year_end)) {
          temp_df <- temp_df[is.na(temp_df$year) | (temp_df$year >= year_start & temp_df$year <= year_end), ]
        }
        
        # Aplicar filtrado espacial si está activado
        if (input$spatial_filter && !is.null(createPolygonSF())) {
          temp_df <- spatialFilterData(temp_df, createPolygonSF())
        }
        
        return(temp_df)
      }
      
      return(data.frame())
      } # Cerrar el bloque else
      
      return(data.frame())
    }, error = function(e) {
      log_message <- paste("  ✗ Error GBIF box", box_index, ":", e$message)
      values$query_log <- c(values$query_log, log_message)
      return(data.frame())
    })
  }
  
  # Función para consultar iNaturalist
  queryiNaturalist <- function(box_index, records_per_box, year_start, year_end) {
    tryCatch({
      bbox_parts <- as.numeric(strsplit(values$grid_bbox[box_index], ",")[[1]])
      if (length(bbox_parts) == 4) {
        # Verificar si estamos en modo sin límites
        is_unlimited <- records_per_box >= 10000
        
        # iNat tiene límites más bajos, así que usamos un enfoque diferente para consultas sin límites
        if (is_unlimited) {
          # Inicializar el dataframe para acumular resultados
          all_inat_data <- data.frame()
          page <- 1
          per_page <- 200  # Máximo permitido por iNat
          more_records <- TRUE
          
          while (more_records) {
            # Consultar página actual
            inat_data <- spocc::occ(
              from = "inat",
              geometry = paste(bbox_parts, collapse = ","),
              limit = per_page,
              start = ((page - 1) * per_page)
            )
            
            # Verificar si hay resultados
            if (!is.null(inat_data) && !is.null(inat_data$inat) && !is.null(inat_data$inat$data) && nrow(inat_data$inat$data) > 0) {
              # Agregar resultados al dataframe acumulativo
              all_inat_data <- rbind(all_inat_data, inat_data$inat$data)
              
              # Actualizar página y verificar si hay más registros
              page <- page + 1
              more_records <- nrow(inat_data$inat$data) == per_page
              
              # Agregar mensaje de log
              log_message <- paste("  🔄 iNaturalist box", box_index, "- paginando:", nrow(all_inat_data), "registros hasta ahora")
              values$query_log <- c(values$query_log, log_message)
            } else {
              more_records <- FALSE
            }
          }
          
          # Procesar todos los resultados acumulados
          if (nrow(all_inat_data) > 0) {
            inat_df <- all_inat_data
            
            temp_df <- data.frame(
              species = tolower(inat_df$name), # Convertir a minúsculas
              lon = as.numeric(inat_df$longitude),
              lat = as.numeric(inat_df$latitude),
              year = if("year" %in% names(inat_df)) as.numeric(inat_df$year) else NA,
              month = if("month" %in% names(inat_df)) as.numeric(inat_df$month) else NA,
              day = if("day" %in% names(inat_df)) as.numeric(inat_df$day) else NA,
              date_recorded = if("created" %in% names(inat_df)) as.character(inat_df$created) else NA,
              taxonRank = NA,  # iNat no proporciona rank directamente
              source = "iNaturalist",
              stringsAsFactors = FALSE
            )
            
            # Filtrar datos válidos
            temp_df <- temp_df[!is.na(temp_df$species) & !is.na(temp_df$lon) & !is.na(temp_df$lat), ]
            
            # Aplicar filtrado espacial si está activado
            if (input$spatial_filter && !is.null(createPolygonSF())) {
              temp_df <- spatialFilterData(temp_df, createPolygonSF())
            }
            
            return(temp_df)
          }
          
          return(data.frame())
        } else {
          # Consulta normal con límite
          inat_data <- spocc::occ(
            from = "inat",
            geometry = paste(bbox_parts, collapse = ","),
            limit = min(records_per_box, 200)  # iNat tiene límites más bajos
          )
          
          if (!is.null(inat_data) && !is.null(inat_data$inat) && !is.null(inat_data$inat$data) && nrow(inat_data$inat$data) > 0) {
            inat_df <- inat_data$inat$data
            
            temp_df <- data.frame(
              species = tolower(inat_df$name), # Convertir a minúsculas
              lon = as.numeric(inat_df$longitude),
              lat = as.numeric(inat_df$latitude),
              year = if("year" %in% names(inat_df)) as.numeric(inat_df$year) else NA,
              month = if("month" %in% names(inat_df)) as.numeric(inat_df$month) else NA,
              day = if("day" %in% names(inat_df)) as.numeric(inat_df$day) else NA,
              date_recorded = if("date" %in% names(inat_df)) as.character(inat_df$date) else NA,
              taxonRank = NA, # iNaturalist no devuelve taxonRank directamente
              source = "iNaturalist",
              stringsAsFactors = FALSE
            )
          
          # Filtrar datos válidos y por año
          temp_df <- temp_df[!is.na(temp_df$species) & !is.na(temp_df$lon) & !is.na(temp_df$lat), ]
          if (nrow(temp_df) > 0 && !is.na(year_start) && !is.na(year_end)) {
            temp_df <- temp_df[is.na(temp_df$year) | (temp_df$year >= year_start & temp_df$year <= year_end), ]
          }
          
          # Aplicar filtrado espacial si está activado
          if (input$spatial_filter && !is.null(createPolygonSF())) {
            temp_df <- spatialFilterData(temp_df, createPolygonSF())
          }
          
          return(temp_df)
        }
        } # Cerrar el bloque else
      } # Cerrar el bloque if (length(bbox_parts) == 4)
      
      return(data.frame())
    }, error = function(e) {
      log_message <- paste("  ⚠️ iNaturalist box", box_index, "no disponible (error del servidor)")
      values$query_log <- c(values$query_log, log_message)
      return(data.frame())
    })
  }
  
  # Función para consultar eBird
  queryeBird <- function(box_index, records_per_box, year_start, year_end) {
    tryCatch({
      # Verificar si hay API key disponible
      api_key <- NULL
      
      # Prioridad 1: Input del usuario en la interfaz
      if (!is.null(input$ebird_api_key) && nchar(input$ebird_api_key) > 0) {
        api_key <- input$ebird_api_key
      } 
      # Prioridad 2: Archivo ebirdapi_key en el directorio actual
      else if (file.exists("ebirdapi_key")) {
        api_key <- trimws(readLines("ebirdapi_key", warn = FALSE)[1])
        if (is.na(api_key) || api_key == "") {
          api_key <- NULL
        }
      }
      # Prioridad 3: Variable de entorno
      else if (Sys.getenv("EBIRD_KEY") != "") {
        api_key <- Sys.getenv("EBIRD_KEY")
      }
      
      if (is.null(api_key) || api_key == "" || api_key == "tu_clave_api_aqui") {
        stop("You must provide an API key from eBird. You can:\n1. Create a file 'ebirdapi_key' with your API key\n2. Set the EBIRD_KEY environment variable\n3. Enter it in the interface\nGet your free key at: https://ebird.org/api/keygen")
      }
      
      bbox_parts <- as.numeric(strsplit(values$grid_bbox[box_index], ",")[[1]])
      if (length(bbox_parts) == 4) {
        # eBird requiere una región o coordenadas específicas
        # Usar el centro del bounding box
        center_lat <- mean(c(bbox_parts[2], bbox_parts[4]))
        center_lng <- mean(c(bbox_parts[1], bbox_parts[3]))
        
        # Consultar observaciones recientes en un radio de 25km
        ebird_data <- ebirdgeo(
          lat = center_lat,
          lng = center_lng,
          dist = 25,  # 25 km radius
          back = min(30, (year_end - year_start + 1) * 365),  # Días hacia atrás
          key = api_key  # Usar la API key
        )
        
        if (!is.null(ebird_data) && nrow(ebird_data) > 0) {
          temp_df <- data.frame(
            species = tolower(ebird_data$sciName), # Convertir a minúsculas
            lon = as.numeric(ebird_data$lng),
            lat = as.numeric(ebird_data$lat),
            year = as.numeric(format(as.Date(ebird_data$obsDt), "%Y")),
            month = as.numeric(format(as.Date(ebird_data$obsDt), "%m")),
            day = as.numeric(format(as.Date(ebird_data$obsDt), "%d")),
            date_recorded = as.character(ebird_data$obsDt),
            taxonRank = NA, # eBird no devuelve taxonRank directamente
            source = "eBird",
            stringsAsFactors = FALSE
          )
          
          # Filtrar datos válidos y por año
          temp_df <- temp_df[!is.na(temp_df$species) & !is.na(temp_df$lon) & !is.na(temp_df$lat), ]
          if (nrow(temp_df) > 0 && !is.na(year_start) && !is.na(year_end)) {
            temp_df <- temp_df[is.na(temp_df$year) | (temp_df$year >= year_start & temp_df$year <= year_end), ]
          }
          
          # Aplicar filtrado espacial si está activado
          if (input$spatial_filter && !is.null(createPolygonSF())) {
            temp_df <- spatialFilterData(temp_df, createPolygonSF())
          }
          
          # Verificar si estamos en modo sin límites
          is_unlimited <- records_per_box >= 10000
          
          # Limitar número de registros solo si no estamos en modo sin límites
          if (!is_unlimited && nrow(temp_df) > records_per_box) {
            temp_df <- temp_df[1:records_per_box, ]
          }
          
          return(temp_df)
        }
      }
      
      return(data.frame())
    }, error = function(e) {
      log_message <- paste("  ⚠️ eBird box", box_index, "no disponible:", e$message)
      values$query_log <- c(values$query_log, log_message)
      return(data.frame())
    })
  }
  
  # Función para consultar OBIS
  queryOBIS <- function(box_index, records_per_box, year_start, year_end) {
    tryCatch({
      bbox_parts <- as.numeric(strsplit(values$grid_bbox[box_index], ",")[[1]])
      if (length(bbox_parts) == 4) {
        # OBIS usa robis package
        obis_data <- occurrence(
          geometry = paste(bbox_parts, collapse = ","),
          startdate = paste0(year_start, "-01-01"),
          enddate = paste0(year_end, "-12-31")
        )
        
        # Verificar si estamos en modo sin límites
        is_unlimited <- records_per_box >= 10000
        
        # Limitamos los resultados después de la consulta solo si no estamos en modo sin límites
        if (!is_unlimited && !is.null(obis_data) && nrow(obis_data) > 0) {
          obis_data <- obis_data[1:min(nrow(obis_data), records_per_box), ]
        }
        
        if (!is.null(obis_data) && nrow(obis_data) > 0) {
          temp_df <- data.frame(
            species = tolower(obis_data$scientificName), # Convertir a minúsculas
            lon = as.numeric(obis_data$decimalLongitude),
            lat = as.numeric(obis_data$decimalLatitude),
            year = if("year" %in% names(obis_data)) as.numeric(obis_data$year) else
                   as.numeric(format(as.Date(obis_data$eventDate), "%Y")),
            month = if("month" %in% names(obis_data)) as.numeric(obis_data$month) else
                    as.numeric(format(as.Date(obis_data$eventDate), "%m")),
            day = if("day" %in% names(obis_data)) as.numeric(obis_data$day) else
                  as.numeric(format(as.Date(obis_data$eventDate), "%d")),
            date_recorded = if("eventDate" %in% names(obis_data)) as.character(obis_data$eventDate) else NA,
            taxonRank = if("taxonRank" %in% names(obis_data)) as.character(obis_data$taxonRank) else NA, # Añadir taxonRank
            source = "OBIS",
            stringsAsFactors = FALSE
          )
          
          # Filtrar datos válidos
          temp_df <- temp_df[!is.na(temp_df$species) & !is.na(temp_df$lon) & !is.na(temp_df$lat), ]
          
          # Aplicar filtrado espacial si está activado
          if (input$spatial_filter && !is.null(createPolygonSF())) {
            temp_df <- spatialFilterData(temp_df, createPolygonSF())
          }
          
          return(temp_df)
        }
      }
      
      return(data.frame())
    }, error = function(e) {
      log_message <- paste("  ⚠️ OBIS box", box_index, "no disponible:", e$message)
      values$query_log <- c(values$query_log, log_message)
      return(data.frame())
    })
  }
  
  # Función para consultar iDigBio
  queryiDigBio <- function(box_index, records_per_box, year_start, year_end) {
    tryCatch({
      bbox_parts <- as.numeric(strsplit(values$grid_bbox[box_index], ",")[[1]])
      if (length(bbox_parts) == 4) {
        # Verificar si estamos en modo sin límites
        is_unlimited <- records_per_box >= 10000
        
        # iDigBio usa ridigbio package
        query_params <- list(
          geopoint = list(
            type = "geo_bounding_box",
            top_left = list(lat = bbox_parts[4], lon = bbox_parts[1]),
            bottom_right = list(lat = bbox_parts[2], lon = bbox_parts[3])
          )
        )
        
        # Agregar filtro de fecha si está disponible
        if (!is.na(year_start) && !is.na(year_end)) {
          query_params$datecollected = list(
            type = "range",
            gte = paste0(year_start, "-01-01"),
            lte = paste0(year_end, "-12-31")
          )
        }
        
        if (is_unlimited) {
          # Inicializar dataframe para todos los resultados
          all_results <- data.frame()
          offset <- 0
          page_size <- 1000  # Tamaño máximo de página en iDigBio
          more_records <- TRUE
          
          # Bucle de paginación
          while (more_records) {
            idigbio_data <- idig_search_records(
              rq = query_params,
              limit = page_size,
              offset = offset
            )
            
            # Verificar si hay resultados
            if (!is.null(idigbio_data) && nrow(idigbio_data) > 0) {
              # Agregar resultados al dataframe acumulativo
              all_results <- rbind(all_results, idigbio_data)
              
              # Actualizar offset para la siguiente página
              offset <- offset + nrow(idigbio_data)
              
              # Verificar si hay más registros (si la página está llena)
              more_records <- nrow(idigbio_data) == page_size
              
              # Agregar mensaje de log
              log_message <- paste("  🔄 iDigBio box", box_index, "- paginando:", nrow(all_results), "registros hasta ahora")
              values$query_log <- c(values$query_log, log_message)
            } else {
              more_records <- FALSE
            }
          }
          
          # Usar todos los resultados acumulados
          idigbio_data <- all_results
        } else {
          # Consulta normal con límite
          idigbio_data <- idig_search_records(
            rq = query_params,
            limit = min(records_per_box, 1000)
          )
        }
        
        if (!is.null(idigbio_data) && nrow(idigbio_data) > 0) {
          temp_df <- data.frame(
            species = tolower(idigbio_data$scientificname), # Convertir a minúsculas
            lon = as.numeric(idigbio_data$geopoint.lon),
            lat = as.numeric(idigbio_data$geopoint.lat),
            year = if("datecollected" %in% names(idigbio_data))
                   as.numeric(format(as.Date(idigbio_data$datecollected), "%Y")) else NA,
            month = if("datecollected" %in% names(idigbio_data))
                    as.numeric(format(as.Date(idigbio_data$datecollected), "%m")) else NA,
            day = if("datecollected" %in% names(idigbio_data))
                  as.numeric(format(as.Date(idigbio_data$datecollected), "%d")) else NA,
            date_recorded = if("datecollected" %in% names(idigbio_data))
                           as.character(idigbio_data$datecollected) else NA,
            taxonRank = if("taxonrank" %in% names(idigbio_data)) as.character(idigbio_data$taxonrank) else NA, # Añadir taxonRank
            source = "iDigBio",
            stringsAsFactors = FALSE
          )
          
          # Filtrar datos válidos
          temp_df <- temp_df[!is.na(temp_df$species) & !is.na(temp_df$lon) & !is.na(temp_df$lat), ]
          
          # Aplicar filtrado espacial si está activado
          if (input$spatial_filter && !is.null(createPolygonSF())) {
            temp_df <- spatialFilterData(temp_df, createPolygonSF())
          }
          
          return(temp_df)
        }
      }
      
      return(data.frame())
    }, error = function(e) {
      log_message <- paste("  ⚠️ iDigBio box", box_index, "no disponible:", e$message)
      values$query_log <- c(values$query_log, log_message)
      return(data.frame())
    })
  }
  
  # Función para ejecutar consultas de biodiversidad
  runBiodiversityQueries <- function() {
    if (length(values$grid_wkt) == 0) {
      showNotification("No hay boxes para consultar", type = "error")
      values$query_running <- FALSE
      values$query_status <- "error"
      return()
    }
    
    # Inicializar estado de consulta
    values$query_status <- "working"
    values$query_running <- TRUE
    values$start_time <- Sys.time()
    values$boxes_processed <- 0
    values$total_records_found <- 0
    values$unique_species_count <- 0
    values$current_database <- "Preparando"
    values$detailed_log <- character()
    
    # Agregar mensaje inicial al log
    start_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 🚀 Iniciando consulta de biodiversidad...")
    values$detailed_log <- c(values$detailed_log, start_msg)
    
    # Crear polígono de referencia para filtrado espacial mejorado
    polygon_sf <- createPolygonSF()
    
    # Inicializar dataframe de biodiversidad
    all_biodiversity <- data.frame(
      species = character(0),
      lon = numeric(0),
      lat = numeric(0),
      year = numeric(0),
      month = numeric(0),
      day = numeric(0),
      date_recorded = character(0),
      taxonRank = character(0), # Añadir taxonRank
      source = character(0),
      stringsAsFactors = FALSE
    )
    
    databases <- input$databases
    if (is.null(databases)) databases <- "gbif"
    
    records_per_box <- input$records_per_box
    if (is.null(records_per_box)) records_per_box <- 500
    
    # Verificar si se desean registros ilimitados
    unlimited_records <- input$unlimited_records
    if (!is.null(unlimited_records) && unlimited_records) {
      records_per_box <- 100000  # Número muy alto, prácticamente ilimitado
      
      # Agregar mensaje de advertencia
      log_message <- "⚠️ Modo sin límites activado - las consultas pueden tardar mucho tiempo"
      values$query_log <- c(values$query_log, log_message)
    }
    
    # Obtener filtros de año
    year_start <- input$year_start
    year_end <- input$year_end
    if (is.null(year_start)) year_start <- 2000
    if (is.null(year_end)) year_end <- as.numeric(format(Sys.Date(), "%Y"))
    
    # Consultar cada box
    values$total_boxes <- length(values$grid_wkt)
    
    for (i in seq_along(values$grid_wkt)) {
      if (!values$query_running) {
        values$detailed_log <- c(values$detailed_log, paste("[", format(Sys.time(), "%H:%M:%S"), "] ⏹️ Consulta detenida por el usuario"))
        break
      }
      
      values$current_box <- i
      values$query_progress <- round((i - 1) / length(values$grid_wkt) * 100)
      
      # Log del box actual
      box_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 📦 Procesando box", i, "de", length(values$grid_wkt))
      values$detailed_log <- c(values$detailed_log, box_msg)
      
      log_message <- paste("Consultando box", i, "de", length(values$grid_wkt))
      values$query_log <- c(values$query_log, log_message)
      
      # Consulta GBIF
      if ("gbif" %in% databases) {
        values$current_database <- "GBIF"
        gbif_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 🌍 Consultando GBIF...")
        values$detailed_log <- c(values$detailed_log, gbif_msg)
        
        temp_df <- queryGBIF(i, records_per_box, year_start, year_end)
        if (nrow(temp_df) > 0) {
          all_biodiversity <- rbind(all_biodiversity, temp_df)
          success_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ✅ GBIF box", i, "- agregados", nrow(temp_df), "registros")
          values$detailed_log <- c(values$detailed_log, success_msg)
          log_message <- paste("  ✓ GBIF box", i, "- agregados", nrow(temp_df), "registros")
          values$query_log <- c(values$query_log, log_message)
        } else {
          no_results_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ⚪ GBIF box", i, "- sin resultados")
          values$detailed_log <- c(values$detailed_log, no_results_msg)
        }
        values$total_records_found <- nrow(all_biodiversity)
      }
      
      # Consulta iNaturalist
      if ("inat" %in% databases) {
        values$current_database <- "iNaturalist"
        inat_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 🔬 Consultando iNaturalist...")
        values$detailed_log <- c(values$detailed_log, inat_msg)
        
        temp_df <- queryiNaturalist(i, records_per_box, year_start, year_end)
        if (nrow(temp_df) > 0) {
          all_biodiversity <- rbind(all_biodiversity, temp_df)
          success_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ✅ iNaturalist box", i, "- agregados", nrow(temp_df), "registros")
          values$detailed_log <- c(values$detailed_log, success_msg)
          log_message <- paste("  ✓ iNat box", i, "- agregados", nrow(temp_df), "registros")
          values$query_log <- c(values$query_log, log_message)
        } else {
          no_results_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ⚪ iNaturalist box", i, "- sin resultados")
          values$detailed_log <- c(values$detailed_log, no_results_msg)
        }
        values$total_records_found <- nrow(all_biodiversity)
      }
      
      # Consulta eBird
      if ("ebird" %in% databases) {
        values$current_database <- "eBird"
        ebird_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 🦜 Consultando eBird...")
        values$detailed_log <- c(values$detailed_log, ebird_msg)
        
        temp_df <- queryeBird(i, records_per_box, year_start, year_end)
        if (nrow(temp_df) > 0) {
          all_biodiversity <- rbind(all_biodiversity, temp_df)
          success_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ✅ eBird box", i, "- agregados", nrow(temp_df), "registros")
          values$detailed_log <- c(values$detailed_log, success_msg)
          log_message <- paste("  ✓ eBird box", i, "- agregados", nrow(temp_df), "registros")
          values$query_log <- c(values$query_log, log_message)
        } else {
          no_results_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ⚪ eBird box", i, "- sin resultados")
          values$detailed_log <- c(values$detailed_log, no_results_msg)
        }
        values$total_records_found <- nrow(all_biodiversity)
      }
      
      # Consulta OBIS
      if ("obis" %in% databases) {
        values$current_database <- "OBIS"
        obis_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 🌊 Consultando OBIS...")
        values$detailed_log <- c(values$detailed_log, obis_msg)
        
        temp_df <- queryOBIS(i, records_per_box, year_start, year_end)
        if (nrow(temp_df) > 0) {
          all_biodiversity <- rbind(all_biodiversity, temp_df)
          success_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ✅ OBIS box", i, "- agregados", nrow(temp_df), "registros")
          values$detailed_log <- c(values$detailed_log, success_msg)
          log_message <- paste("  ✓ OBIS box", i, "- agregados", nrow(temp_df), "registros")
          values$query_log <- c(values$query_log, log_message)
        } else {
          no_results_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ⚪ OBIS box", i, "- sin resultados")
          values$detailed_log <- c(values$detailed_log, no_results_msg)
        }
        values$total_records_found <- nrow(all_biodiversity)
      }
      
      # Consulta iDigBio
      if ("idigbio" %in% databases) {
        values$current_database <- "iDigBio"
        idigbio_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 🏛️ Consultando iDigBio...")
        values$detailed_log <- c(values$detailed_log, idigbio_msg)
        
        temp_df <- queryiDigBio(i, records_per_box, year_start, year_end)
        if (nrow(temp_df) > 0) {
          all_biodiversity <- rbind(all_biodiversity, temp_df)
          success_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ✅ iDigBio box", i, "- agregados", nrow(temp_df), "registros")
          values$detailed_log <- c(values$detailed_log, success_msg)
          log_message <- paste("  ✓ iDigBio box", i, "- agregados", nrow(temp_df), "registros")
          values$query_log <- c(values$query_log, log_message)
        } else {
          no_results_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ⚪ iDigBio box", i, "- sin resultados")
          values$detailed_log <- c(values$detailed_log, no_results_msg)
        }
        values$total_records_found <- nrow(all_biodiversity)
      }
      
      # Actualizar progreso del box completado
      values$boxes_processed <- i
      
      # Pequeña pausa entre consultas
      Sys.sleep(0.5)
    }
    
      # Procesar resultados finales
      processing_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 🔄 Procesando resultados finales...")
      values$detailed_log <- c(values$detailed_log, processing_msg)
      values$current_database <- "Finalizando"
      
      if (nrow(all_biodiversity) > 0) {
        # Remover duplicados si está activado
        if (input$remove_duplicates) {
          initial_count <- nrow(all_biodiversity)
          all_biodiversity <- all_biodiversity[!duplicated(all_biodiversity[, c('species', 'lon', 'lat')]), ]
          removed_count <- initial_count - nrow(all_biodiversity)
          
          dup_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 🔄 Removidos", removed_count, "duplicados")
          values$detailed_log <- c(values$detailed_log, dup_msg)
          log_message <- paste("Removidos", removed_count, "duplicados")
          values$query_log <- c(values$query_log, log_message)
        }
        
        # Aplicar filtrado espacial final si está activado y no se aplicó por box
        if (input$spatial_filter) {
          polygon_sf <- createPolygonSF()
          if (!is.null(polygon_sf)) {
            initial_count <- nrow(all_biodiversity)
            all_biodiversity <- spatialFilterData(all_biodiversity, polygon_sf)
            final_count <- nrow(all_biodiversity)
            
            if (final_count < initial_count) {
              spatial_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 🗺️ Filtrado espacial final: mantenidos", final_count, "de", initial_count, "registros")
              values$detailed_log <- c(values$detailed_log, spatial_msg)
              log_message <- paste("Filtrado espacial final: mantenidos", final_count, "de", initial_count, "registros dentro del polígono")
              values$query_log <- c(values$query_log, log_message)
          }
        } else {
          log_message <- "⚠️ No se pudo crear polígono para filtrado espacial final"
          values$query_log <- c(values$query_log, log_message)
        }
      }
      
      # Filtrar por rango de años si se especificó
      year_start <- input$year_start
      year_end <- input$year_end
      if (!is.null(year_start) && !is.null(year_end) && nrow(all_biodiversity) > 0) {
        initial_count <- nrow(all_biodiversity)
        all_biodiversity <- all_biodiversity[
          is.na(all_biodiversity$year) |
          (all_biodiversity$year >= year_start & all_biodiversity$year <= year_end),
        ]
        final_count <- nrow(all_biodiversity)
        
        if (final_count < initial_count) {
          log_message <- paste("Filtrado temporal:", final_count, "registros entre", year_start, "y", year_end)
          values$query_log <- c(values$query_log, log_message)
        }
      }
      
        values$biodiversity_data <- all_biodiversity
        values$has_results <- TRUE
        values$unique_species_count <- length(unique(all_biodiversity$species))
        values$total_records_found <- nrow(all_biodiversity)
        
        completion_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ✅ Consulta completada:", nrow(all_biodiversity), "registros finales")
        values$detailed_log <- c(values$detailed_log, completion_msg)
        
        species_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 🌿 Especies únicas encontradas:", values$unique_species_count)
        values$detailed_log <- c(values$detailed_log, species_msg)
        
        log_message <- paste("✅ Consulta completada:", nrow(all_biodiversity), "registros finales")
        values$query_log <- c(values$query_log, log_message)
        
        showNotification(paste("Consulta completada:", nrow(all_biodiversity), "registros encontrados"),
                         type = "default", duration = 5)
      } else {
        no_data_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ❌ No se encontraron datos en ninguna consulta")
        values$detailed_log <- c(values$detailed_log, no_data_msg)
        
        log_message <- "❌ No se encontraron datos en ninguna consulta"
        values$query_log <- c(values$query_log, log_message)
        
        showNotification("No se encontraron datos en las consultas", type = "warning", duration = 5)
      }
      
      # Finalizar estado de consulta
      values$query_running <- FALSE
      values$query_progress <- 100
      values$current_database <- ""
      
      if (values$has_results) {
        values$query_status <- "completed"
      } else {
        values$query_status <- "error"
      }
      
      # Mensaje final de tiempo transcurrido
      if (!is.null(values$start_time)) {
        elapsed_time <- round(as.numeric(difftime(Sys.time(), values$start_time, units = "secs")), 1)
        time_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ⏱️ Tiempo total transcurrido:", elapsed_time, "segundos")
        values$detailed_log <- c(values$detailed_log, time_msg)
      } else {
      # Si no hay datos iniciales
      no_data_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ❌ No se encontraron datos en ninguna consulta")
      values$detailed_log <- c(values$detailed_log, no_data_msg)
      
      log_message <- "❌ No se encontraron datos en ninguna consulta"
      values$query_log <- c(values$query_log, log_message)
      
      showNotification("No se encontraron datos en las consultas", type = "warning", duration = 5)
      
      values$query_running <- FALSE
      values$query_progress <- 100
      values$query_status <- "error"
      values$current_database <- ""
      
      # Mensaje final de tiempo transcurrido (incluso si no hay datos)
      if (!is.null(values$start_time)) {
        elapsed_time <- round(as.numeric(difftime(Sys.time(), values$start_time, units = "secs")), 1)
        time_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ⏱️ Tiempo total transcurrido:", elapsed_time, "segundos")
        values$detailed_log <- c(values$detailed_log, time_msg)
      }
    }
  }
  
  # Detener consulta
  observeEvent(input$stop_query, {
    if (values$query_running) {
      stop_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ⏹️ Consulta detenida por el usuario")
      values$detailed_log <- c(values$detailed_log, stop_msg)
      
      # Calcular tiempo transcurrido si hay un tiempo de inicio
      if (!is.null(values$start_time)) {
        elapsed_time <- round(as.numeric(difftime(Sys.time(), values$start_time, units = "secs")), 1)
        time_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] ⏱️ Tiempo transcurrido antes de detener:", elapsed_time, "segundos")
        values$detailed_log <- c(values$detailed_log, time_msg)
      }
      
      showNotification("Consulta detenida por el usuario", type = "warning", duration = 3)
    }
    
    values$query_running <- FALSE
    values$query_status <- "idle"
    values$current_database <- ""
    values$query_progress <- 0
  })
  
  # Limpiar resultados
  observeEvent(input$clear_results, {
    # Agregar mensaje de limpieza al log antes de limpiarlo
    clear_msg <- paste("[", format(Sys.time(), "%H:%M:%S"), "] 🗑️ Limpiando todos los resultados y logs...")
    values$detailed_log <- c(values$detailed_log, clear_msg)
    
    # Pequeña pausa para que se vea el mensaje
    Sys.sleep(0.5)
    
    # Limpiar todos los datos
    values$biodiversity_data <- data.frame()
    values$has_results <- FALSE
    values$query_log <- character()
    values$detailed_log <- character()
    values$query_progress <- 0
    values$query_status <- "idle"
    values$current_database <- ""
    values$total_records_found <- 0
    values$unique_species_count <- 0
    values$boxes_processed <- 0
    values$current_box <- 0
    values$total_boxes <- 0
    values$start_time <- NULL
    
    showNotification("✅ Todos los resultados y logs han sido limpiados", type = "success", duration = 3)
  })
  
  # ========================================
  # OUTPUTS PARA PESTAÑAS DE BIODIVERSIDAD
  # ========================================
  
  # Progress boxes
  output$query_progress <- renderValueBox({
    valueBox(
      value = paste0(values$query_progress, "%"),
      subtitle = paste("Box", values$current_box, "de", values$total_boxes),
      icon = icon("chart-line"),
      color = if (values$query_running) "yellow" else if (values$query_progress == 100) "green" else "blue"
    )
  })
  
  output$total_records <- renderValueBox({
    valueBox(
      value = nrow(values$biodiversity_data),
      subtitle = "Total Registros",
      icon = icon("database"),
      color = "blue"
    )
  })
  
  output$unique_species <- renderValueBox({
    unique_count <- if (nrow(values$biodiversity_data) > 0) {
      length(unique(values$biodiversity_data$species[!is.na(values$biodiversity_data$species)]))
    } else {
      0
    }
    
    valueBox(
      value = unique_count,
      subtitle = "Especies Únicas",
      icon = icon("leaf"),
      color = "green"
    )
  })
  
  # Query log
  output$query_log <- renderText({
    if (length(values$query_log) > 0) {
      paste(tail(values$query_log, 20), collapse = "\n")
    } else {
      "No hay actividad de consultas aún..."
    }
  })
  
  # Current status
  output$current_status <- renderText({
    if (values$query_running) {
      paste("🔄 Ejecutando consultas... Box", values$current_box, "de", values$total_boxes)
    } else if (values$has_results) {
      paste("✅ Consultas completadas -", nrow(values$biodiversity_data), "registros")
    } else {
      "⏸️ No hay consultas en progreso"
    }
  })
  
  # Results value boxes
  output$final_records <- renderValueBox({
    valueBox(
      value = nrow(values$biodiversity_data),
      subtitle = "Registros Totales",
      icon = icon("chart-bar"),
      color = "blue"
    )
  })
  
  output$final_species <- renderValueBox({
    unique_count <- if (nrow(values$biodiversity_data) > 0) {
      length(unique(values$biodiversity_data$species[!is.na(values$biodiversity_data$species)]))
    } else {
      0
    }
    
    valueBox(
      value = unique_count,
      subtitle = "Especies Únicas",
      icon = icon("leaf"),
      color = "green"
    )
  })
  
  output$data_sources <- renderValueBox({
    sources_count <- if (nrow(values$biodiversity_data) > 0) {
      length(unique(values$biodiversity_data$source))
    } else {
      0
    }
    
    valueBox(
      value = sources_count,
      subtitle = "Fuentes de Datos",
      icon = icon("database"),
      color = "aqua"
    )
  })
  
  output$area_covered <- renderValueBox({
    if (values$polygon_complete) {
      min_lng <- min(values$vertices$lng)
      max_lng <- max(values$vertices$lng)
      min_lat <- min(values$vertices$lat)
      max_lat <- max(values$vertices$lat)
      area_approx <- round((max_lng - min_lng) * (max_lat - min_lat), 2)
      
      valueBox(
        value = paste0(area_approx, " deg²"),
        subtitle = "Área Aproximada",
        icon = icon("map"),
        color = "orange"
      )
    } else {
      valueBox(
        value = "N/A",
        subtitle = "Área Aproximada",
        icon = icon("map"),
        color = "light-blue"
      )
    }
  })
  
  # Results map
  output$results_map <- renderLeaflet({
    if (nrow(values$biodiversity_data) > 0) {
      # Crear paleta de colores por fuente
      sources <- unique(values$biodiversity_data$source)
      color_palette <- c("#e74c3c", "#3498db", "#2ecc71", "#f39c12", "#9b59b6")
      colors <- color_palette[1:min(length(sources), length(color_palette))]
      color_map <- setNames(colors, sources)
      
      # Calcular bounds que incluyan tanto datos como polígono
      all_lng <- c(values$biodiversity_data$lon, values$vertices$lng)
      all_lat <- c(values$biodiversity_data$lat, values$vertices$lat)
      
      map <- leaflet() %>%
        addTiles() %>%
        fitBounds(
          min(all_lng, na.rm = TRUE), min(all_lat, na.rm = TRUE),
          max(all_lng, na.rm = TRUE), max(all_lat, na.rm = TRUE)
        )
      
      # Agregar polígono del área de estudio PRIMERO (para que esté abajo)
      if (values$polygon_complete) {
        map <- map %>%
          addPolygons(
            lng = values$vertices$lng,
            lat = values$vertices$lat,
            color = "#2ecc71",
            weight = 3,
            opacity = 0.8,
            fillColor = "#2ecc71",
            fillOpacity = 0.15,
            popup = paste("Área de estudio<br>Vértices:", nrow(values$vertices)),
            group = "Área de Estudio"
          )
      }
      
      # Agregar puntos de biodiversidad por fuente
      for (source in sources) {
        source_data <- values$biodiversity_data[values$biodiversity_data$source == source, ]
        if (nrow(source_data) > 0) {
          map <- map %>%
            addCircleMarkers(
              data = source_data,
              lng = ~lon, lat = ~lat,
              radius = 3,  # Reducido de 5 a 3
              color = "white",
              fillColor = color_map[source],
              weight = 1,
              fillOpacity = 0.7,  # Reducido un poco la opacidad para mejor visualización
              popup = ~paste(
                "<b>Especie:</b>", ifelse(is.na(species), "No identificada", species), "<br>",
                "<b>Nivel Taxonómico:</b>", ifelse(is.na(taxonRank), "No disponible", taxonRank), "<br>", # Añadir nivel taxonómico
                "<b>Fuente:</b>", source, "<br>",
                "<b>Coordenadas:</b>", round(lat, 4), ",", round(lon, 4), "<br>",
                "<b>Fecha:</b>", ifelse(is.na(date_recorded), "No disponible", date_recorded)
              ),
              group = paste0(source, " (", nrow(source_data), ")")
            )
        }
      }
      
      # Agregar control de capas
      map %>% addLayersControl(
        overlayGroups = sources,
        options = layersControlOptions(collapsed = FALSE)
      )
    } else {
      leaflet() %>% addTiles() %>% setView(-99.1332, 19.4326, zoom = 5)
    }
  })
  
  # Results table
  output$results_table <- DT::renderDataTable({
    if (nrow(values$biodiversity_data) > 0) {
      display_data <- values$biodiversity_data
      display_data$lon <- round(display_data$lon, 6)
      display_data$lat <- round(display_data$lat, 6)
      
      DT::datatable(
        display_data,
        options = list(
          pageLength = 15,
          scrollX = TRUE,
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel')
        ),
        rownames = FALSE,
        filter = 'top'
      )
    } else {
      DT::datatable(
        data.frame(Mensaje = "No hay datos de biodiversidad disponibles"),
        options = list(pageLength = 15),
        rownames = FALSE
      )
    }
  })
  
  # Plots
  output$source_plot <- renderPlotly({
    if (nrow(values$biodiversity_data) > 0) {
      source_counts <- table(values$biodiversity_data$source)
      
      p <- plot_ly(
        x = names(source_counts),
        y = as.numeric(source_counts),
        type = 'bar',
        marker = list(color = rainbow(length(source_counts)))
      ) %>%
        layout(
          title = "Registros por Fuente",
          xaxis = list(title = "Fuente"),
          yaxis = list(title = "Registros"),
          margin = list(l = 50, r = 20, t = 50, b = 50)
        )
      p
    } else {
      plot_ly() %>% layout(title = "No hay datos")
    }
  })
  
  output$year_plot <- renderPlotly({
    if (nrow(values$biodiversity_data) > 0 && any(!is.na(values$biodiversity_data$year))) {
      year_data <- values$biodiversity_data[!is.na(values$biodiversity_data$year), ]
      year_counts <- table(year_data$year)
      
      p <- plot_ly(
        x = as.numeric(names(year_counts)),
        y = as.numeric(year_counts),
        type = 'scatter',
        mode = 'lines+markers'
      ) %>%
        layout(
          title = "Registros por Año",
          xaxis = list(title = "Año"),
          yaxis = list(title = "Registros"),
          margin = list(l = 50, r = 20, t = 50, b = 50)
        )
      p
    } else {
      plot_ly() %>% layout(title = "No hay datos de años")
    }
  })
  
  output$species_plot <- renderPlotly({
    if (nrow(values$biodiversity_data) > 0) {
      species_counts <- table(values$biodiversity_data$species)
      top_species <- head(sort(species_counts, decreasing = TRUE), 10)
      
      p <- plot_ly(
        y = names(top_species),
        x = as.numeric(top_species),
        type = 'bar',
        orientation = 'h'
      ) %>%
        layout(
          title = "Top 10 Especies",
          xaxis = list(title = "Registros"),
          yaxis = list(title = "Especies"),
          margin = list(l = 150, r = 20, t = 50, b = 50)
        )
      p
    } else {
      plot_ly() %>% layout(title = "No hay datos")
    }
  })
  
  # Download handlers for results
  output$download_results_csv <- downloadHandler(
    filename = function() {
      paste0("biodiversity_results_", Sys.Date(), ".csv")
    },
    content = function(file) {
      if (nrow(values$biodiversity_data) > 0) {
        write.csv(values$biodiversity_data, file, row.names = FALSE)
      }
    }
  )
  
  output$download_results_excel <- downloadHandler(
    filename = function() {
      paste0("biodiversity_results_", Sys.Date(), ".xlsx")
    },
    content = function(file) {
      if (nrow(values$biodiversity_data) > 0) {
        if (require(openxlsx, quietly = TRUE)) {
          openxlsx::write.xlsx(values$biodiversity_data, file)
        } else {
          write.csv(values$biodiversity_data, file, row.names = FALSE)
        }
      }
    }
  )

}
# Ejecutar la aplicación
shinyApp(ui = ui, server = server)