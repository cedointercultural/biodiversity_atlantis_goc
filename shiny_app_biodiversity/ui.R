# Cargar librerías necesarias para la UI
library(shiny)
library(leaflet)
library(DT)
library(shinydashboard)
library(shinyWidgets)
library(shinyjs) # Para manipulación de JavaScript
library(plotly) # Para gráficos interactivos

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
    useShinyjs(), # Inicializar shinyjs
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
          width: 1.5rem; /* Aumentar tamaño */
          height: 1.5rem; /* Aumentar tamaño */
          border: 0.15em solid currentColor; /* Ajustar grosor */
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
            height = "570px",
            
            leafletOutput("map", height = "523px")
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
              
              # Sección de parámetros generales
              fluidRow(
                box(
                  title = "⚙️ Parámetros Generales", 
                  status = "primary", 
                  solidHeader = TRUE,
                  width = 12,
                  collapsible = TRUE,
                  
                  fluidRow(
                    column(4,
                      h5("📐 Configuración del Grid:"),
                      numericInput("bio_grid_size", 
                                 "Tamaño de grid (grados):", 
                                 value = 1.0, min = 0.1, max = 3.0, step = 0.1),
                      helpText("🔍 Tamaño de cada celda del grid en grados decimales. Valores menores = más precisión pero más consultas."),
                      
                      numericInput("max_boxes", 
                                 "Máximo de boxes a consultar:", 
                                 value = 5, min = 1, max = 20, step = 1),
                      helpText("📦 Número máximo de celdas del grid a procesar. Limita el tiempo de consulta."),
                      
                      # Información de boxes
                      div(id = "box_info", style = "background-color: #e8f4fd; padding: 10px; border-radius: 5px; margin-top: 10px;",
                          h6("📋 Información del Grid:", style = "margin: 0 0 5px 0; font-weight: bold;"),
                          textOutput("grid_info_text")
                      )
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
                      helpText("📆 Rango de años para filtrar observaciones. Usar rangos amplios puede aumentar resultados.")
                    ),
                    
                    column(4,
                      h5("🔧 Opciones Generales:"),
                      checkboxInput("unlimited_records",
                                  "Sin límite de registros",
                                  value = FALSE),
                      helpText("⚠️ Consultas sin límites - puede tardar más tiempo."),
                      
                      checkboxInput("only_coordinates",
                                   "Solo registros con coordenadas",
                                   value = TRUE),
                      helpText("📍 Excluye observaciones sin ubicación geográfica."),
                      
                      checkboxInput("remove_duplicates",
                                   "Remover duplicados",
                                   value = TRUE),
                      helpText("🔄 Elimina registros repetidos."),
                      
                      checkboxInput("spatial_filter",
                                   "Filtrado espacial estricto",
                                   value = TRUE),
                      helpText("🎯 Solo registros dentro del polígono.")
                    )
                  )
                )
              ),
              
              br(),
              
              # Sección GBIF
              fluidRow(
                box(
                  title = "🌍 GBIF - Global Biodiversity Information Facility", 
                  status = "success", 
                  solidHeader = TRUE,
                  width = 12,
                  collapsible = TRUE,
                  collapsed = FALSE,
                  
                  fluidRow(
                    column(2,
                      checkboxInput("enable_gbif",
                                   "Activar GBIF",
                                   value = TRUE),
                      helpText("💚 Base de datos global más completa")
                    ),
                    column(5,
                      selectInput("gbif_rank",
                                "Rango taxonómico:",
                                choices = list(
                                  "Todos los rangos" = "",
                                  "Especies" = "SPECIES",
                                  "Género" = "GENUS", 
                                  "Familia" = "FAMILY",
                                  "Orden" = "ORDER",
                                  "Clase" = "CLASS"
                                ),
                                selected = ""),
                      helpText("🔬 Filtra por nivel taxonómico específico"),
                      
                      checkboxInput("gbif_georeferenced",
                                   "Solo registros georreferenciados",
                                   value = TRUE),
                      helpText("📍 Requiere coordenadas precisas")
                    ),
                    column(5,
                      numericInput("gbif_records_per_box",
                                 "Registros GBIF por box:",
                                 value = 500, min = 100, max = 2000, step = 100),
                      helpText("📊 Registros GBIF por celda del grid"),
                      
                      numericInput("gbif_records_limit",
                                 "Límite total de registros GBIF:",
                                 value = 1000, min = 100, max = 5000, step = 100),
                      helpText("📊 Máximo total de registros GBIF por consulta"),
                      
                      selectInput("gbif_basis_of_record",
                                "Tipo de registro:",
                                choices = list(
                                  "Todos" = "",
                                  "Especímenes preservados" = "PRESERVED_SPECIMEN",
                                  "Observaciones humanas" = "HUMAN_OBSERVATION", 
                                  "Observaciones de máquina" = "MACHINE_OBSERVATION",
                                  "Especímenes fósiles" = "FOSSIL_SPECIMEN"
                                ),
                                selected = ""),
                      helpText("🔍 Tipo de evidencia del registro")
                    )
                  )
                )
              ),
              
              # Sección eBird
              fluidRow(
                box(
                  title = "🦜 eBird - Global Bird Occurrence Database", 
                  status = "info", 
                  solidHeader = TRUE,
                  width = 12,
                  collapsible = TRUE,
                  collapsed = TRUE,
                  
                  fluidRow(
                    column(2,
                      checkboxInput("enable_ebird",
                                   "Activar eBird",
                                   value = FALSE),
                      helpText("🐦 Base de datos especializada en aves")
                    ),
                    column(5,
                      textInput("ebird_api_key",
                               "eBird API Key:",
                               placeholder = "Ingresa tu clave API"),
                      helpText("🔑 Obtén tu clave gratuita en: https://ebird.org/api/keygen"),
                      
                      numericInput("ebird_records_per_box",
                                 "Registros eBird por box:",
                                 value = 300, min = 50, max = 1000, step = 50),
                      helpText("📊 Registros eBird por celda del grid"),
                      
                      numericInput("ebird_max_results",
                                 "Máximo total resultados eBird:",
                                 value = 1000, min = 100, max = 10000, step = 100),
                      helpText("📊 Límite total de registros por consulta eBird")
                    ),
                    column(5,
                      numericInput("ebird_days_back",
                                 "Días hacia atrás:",
                                 value = 30, min = 1, max = 365, step = 1),
                      helpText("📅 Número de días desde hoy hacia atrás"),
                      
                      checkboxInput("ebird_include_provisional",
                                   "Incluir registros provisionales",
                                   value = FALSE),
                      helpText("⚠️ Incluye observaciones sin verificar"),
                      
                      checkboxInput("ebird_only_hotspots",
                                   "Solo de hotspots",
                                   value = FALSE),
                      helpText("🏆 Solo de ubicaciones populares de observación")
                    )
                  )
                )
              ),
              
              # Sección OBIS
              fluidRow(
                box(
                  title = "🌊 OBIS - Ocean Biodiversity Information System", 
                  status = "primary", 
                  solidHeader = TRUE,
                  width = 12,
                  collapsible = TRUE,
                  collapsed = TRUE,
                  
                  fluidRow(
                    column(2,
                      checkboxInput("enable_obis",
                                   "Activar OBIS",
                                   value = FALSE),
                      helpText("🌊 Especializada en biodiversidad marina")
                    ),
                    column(5,
                      numericInput("obis_records_per_box",
                                 "Registros OBIS por box:",
                                 value = 400, min = 100, max = 1500, step = 50),
                      helpText("📊 Registros OBIS por celda del grid"),
                      
                      numericInput("obis_max_results",
                                 "Máximo total resultados OBIS:",
                                 value = 1000, min = 100, max = 5000, step = 100),
                      helpText("📊 Límite total de registros marinos por consulta"),
                      
                      numericInput("obis_min_depth",
                                 "Profundidad mínima (m):",
                                 value = -1000, min = -11000, max = 0, step = 10),
                      helpText("🏊 Profundidad mínima en metros (negativo)")
                    ),
                    column(5,
                      numericInput("obis_max_depth",
                                 "Profundidad máxima (m):",
                                 value = 0, min = -11000, max = 0, step = 10),
                      helpText("🏄 Profundidad máxima en metros (negativo)"),
                      
                      checkboxInput("obis_absence_data",
                                   "Incluir datos de ausencia",
                                   value = FALSE),
                      helpText("❌ Incluye registros donde no se encontró la especie"),
                      
                      textInput("obis_quality_flags",
                               "Flags de calidad (separados por coma):",
                               placeholder = "ej: 4,8,9"),
                      helpText("🚩 Códigos de calidad OBIS a incluir")
                    )
                  )
                )
              ),
              
              # Sección iNaturalist
              fluidRow(
                box(
                  title = "📱 iNaturalist - Citizen Science Platform", 
                  status = "warning", 
                  solidHeader = TRUE,
                  width = 12,
                  collapsible = TRUE,
                  collapsed = TRUE,
                  
                  fluidRow(
                    column(2,
                      checkboxInput("enable_inaturalist",
                                   "Activar iNaturalist",
                                   value = FALSE),
                      helpText("👥 Ciencia ciudadana y observaciones comunitarias")
                    ),
                    column(5,
                      selectInput("inat_quality_grade",
                                "Grado de calidad:",
                                choices = list(
                                  "Todos" = "",
                                  "Research Grade" = "research",
                                  "Needs ID" = "needs_id",
                                  "Casual" = "casual"
                                ),
                                selected = "research"),
                      helpText("✅ Nivel de verificación de la observación"),
                      
                      numericInput("inat_records_per_box",
                                 "Registros iNaturalist por box:",
                                 value = 200, min = 50, max = 800, step = 50),
                      helpText("📊 Registros iNaturalist por celda del grid"),
                      
                      numericInput("inat_per_page",
                                 "Registros por página:",
                                 value = 200, min = 50, max = 500, step = 50),
                      helpText("📄 Registros por consulta individual iNaturalist")
                    ),
                    column(5,
                      checkboxInput("inat_photos_only",
                                   "Solo con fotografías",
                                   value = TRUE),
                      helpText("📷 Requiere evidencia fotográfica"),
                      
                      checkboxInput("inat_sounds_only",
                                   "Solo con sonidos",
                                   value = FALSE),
                      helpText("🔊 Requiere evidencia de audio"),
                      
                      textInput("inat_iconic_taxa",
                               "Grupos taxonómicos:",
                               placeholder = "ej: Aves,Mammalia,Plantae"),
                      helpText("🌿 Grupos específicos separados por coma")
                    )
                  )
                )
              ),
              
              # Sección iDigBio
              fluidRow(
                box(
                  title = "🏛️ iDigBio - Museum Specimen Database", 
                  status = "danger", 
                  solidHeader = TRUE,
                  width = 12,
                  collapsible = TRUE,
                  collapsed = TRUE,
                  
                  fluidRow(
                    column(2,
                      checkboxInput("enable_idigbio",
                                   "Activar iDigBio",
                                   value = FALSE),
                      helpText("🏛️ Especímenes de museos e instituciones")
                    ),
                    column(5,
                      numericInput("idigbio_records_per_box",
                                 "Registros iDigBio por box:",
                                 value = 300, min = 50, max = 1000, step = 50),
                      helpText("📊 Especímenes iDigBio por celda del grid"),
                      
                      numericInput("idigbio_limit",
                                 "Límite total de registros:",
                                 value = 1000, min = 100, max = 5000, step = 100),
                      helpText("📊 Máximo total de especímenes por consulta"),
                      
                      textInput("idigbio_institution",
                               "Institución específica:",
                               placeholder = "ej: Harvard University"),
                      helpText("🏫 Filtrar por institución específica")
                    ),
                    column(5,
                      selectInput("idigbio_record_type",
                                "Tipo de registro:",
                                choices = list(
                                  "Todos" = "",
                                  "Especímenes" = "specimens",
                                  "Fósiles" = "fossils",
                                  "Tejidos" = "tissues"
                                ),
                                selected = ""),
                      helpText("🔬 Tipo de material biológico"),
                      
                      checkboxInput("idigbio_has_image",
                                   "Solo con imágenes",
                                   value = FALSE),
                      helpText("📸 Requiere fotografías del espécimen")
                    )
                  )
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
                div(id = "query_spinner",
                    class = "spinner-border text-light",
                    role = "status",
                    style = "display: none; margin-left: 10px;"),
                
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
            verbatimTextOutput("detailed_log")
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
  )
)
