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
  dashboardHeader(title = "🗺️ Polygon Drawer"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Map", tabName = "mapa", icon = icon("map")),
      menuItem("Coordinates", tabName = "coordenadas", icon = icon("table")),
      menuItem("Biodiversity Query", tabName = "biodiversity", icon = icon("leaf")),
      menuItem("Results", tabName = "results", icon = icon("chart-bar")),
      menuItem("Script Data", tabName = "export_data", icon = icon("code"))
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
      # Map Tab
      tabItem(tabName = "mapa",
        fluidRow(
          box(
            title = "Controls", 
            status = "primary", 
            solidHeader = TRUE,
            width = 12,
            collapsible = TRUE,
            
            fluidRow(
              column(3,
                actionButton("start_drawing", 
                           "✏️ Start Drawing", 
                           class = "btn btn-primary btn-custom",
                           width = "100%")
              ),
              column(3,
                actionButton("finish_polygon", 
                           "✅ Finish Polygon", 
                           class = "btn btn-success btn-custom",
                           width = "100%")
              ),
              column(3,
                actionButton("clear_all", 
                           "🗑️ Clear All", 
                           class = "btn btn-danger btn-custom",
                           width = "100%")
              ),
              column(3,
                downloadButton("download_csv", 
                             "📥 Export CSV",
                             class = "btn btn-info btn-custom",
                             style = "width: 100%;")
              )
            ),
            
            br(),
            
            fluidRow(
              column(12,
                div(id = "status_info", 
                    style = "text-align: center; padding: 10px; background-color: #e8f4fd; border-radius: 5px;",
                    h4("📍 Status:", style = "margin: 0;"),
                    p("Click 'Start Drawing' to begin", style = "margin: 5px 0 0 0;")
                )
              )
            )
          )
        ),
        
        fluidRow(
          box(
            title = "Interactive Map",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            height = "570px",
            
            leafletOutput("map", height = "523px")
          )
        )
      ),
      
      # Coordinates Tab
      tabItem(tabName = "coordenadas",
        fluidRow(
          box(
            title = "Polygon Coordinates",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            
            DT::dataTableOutput("coordinates_table")
          )
        ),
        
        fluidRow(
          box(
            title = "Polygon Information",
            status = "info",
            solidHeader = TRUE,
            width = 6,
            
            valueBoxOutput("vertex_count"),
            valueBoxOutput("area_info")
          ),
          
          box(
            title = "Export Data",
            status = "success",
            solidHeader = TRUE,
            width = 6,
            
            h4("Export Format:"),
            radioButtons("export_format",
                        "Select format:",
                        choices = list(
                          "CSV (Comma separated)" = "csv",
                          "TXT (Tab separated)" = "txt",
                          "Excel" = "xlsx"
                        ),
                        selected = "csv"),
            
            br(),
            downloadButton("download_custom", 
                         "Download in selected format",
                         class = "btn btn-success",
                         style = "width: 100%;")
          )
        )
      ),
      
      # Biodiversity query tab
      tabItem(tabName = "biodiversity",
        fluidRow(
          box(
            title = "🌿 Biodiversity Query",
            status = "success",
            solidHeader = TRUE,
            width = 12,
            
            conditionalPanel(
              condition = "!output.polygon_ready",
              div(style = "text-align: center; padding: 20px;",
                  h4("⚠️ You must first draw and finish a polygon"),
                  p("Go to the 'Map' tab and draw your study area."),
                  actionButton("go_to_map", "🗺️ Go to Map", 
                             class = "btn btn-primary")
              )
            ),
            
            conditionalPanel(
              condition = "output.polygon_ready",
              h4("🎯 Database-Specific Query Configuration"),
              
              # Global settings
              fluidRow(
                column(12,
                  h5("� Global Configuration:"),
                  fluidRow(
                    column(3,
                      numericInput("bio_grid_size", 
                                 "Grid size (degrees):", 
                                 value = 1.0, min = 0.1, max = 3.0, step = 0.1),
                      helpText("🔍 Size of each grid cell.")
                    ),
                    column(3,
                      numericInput("max_boxes", 
                                 "Max boxes to query:", 
                                 value = 5, min = 1, max = 20, step = 1),
                      helpText("📦 Maximum number of grid cells.")
                    ),
                    column(3,
                      numericInput("year_start",
                                 "Start year:",
                                 value = 2000, min = 1900, max = as.numeric(format(Sys.Date(), "%Y")), step = 1),
                      helpText("📆 Initial year range.")
                    ),
                    column(3,
                      numericInput("year_end",
                                 "End year:",
                                 value = as.numeric(format(Sys.Date(), "%Y")),
                                 min = 1900, max = as.numeric(format(Sys.Date(), "%Y")), step = 1),
                      helpText("📆 Final year range.")
                    )
                  ),
                  
                  fluidRow(
                    column(4,
                      checkboxInput("only_coordinates",
                                   "Only records with coordinates",
                                   value = TRUE),
                      helpText("📍 Excludes observations without location.")
                    ),
                    column(4,
                      checkboxInput("remove_duplicates",
                                   "Remove duplicates",
                                   value = TRUE),
                      helpText("🔄 Removes repeated records.")
                    ),
                    column(4,
                      checkboxInput("spatial_filter",
                                   "Strict spatial filtering",
                                   value = TRUE),
                      helpText("🎯 Only records within the polygon.")
                    )
                  ),
                  
                  # Grid information
                  div(id = "box_info", style = "background-color: #e8f4fd; padding: 10px; border-radius: 5px; margin-top: 10px;",
                      h6("📋 Grid Information:", style = "margin: 0 0 5px 0; font-weight: bold;"),
                      textOutput("grid_info_text")
                  )
                )
              ),
              
              br(),
              
              # Database-specific tabs
              tabsetPanel(
                id = "database_tabs",
                
                # GBIF Tab
                tabPanel(
                  title = "🌍 GBIF",
                  value = "gbif_tab",
                  br(),
                  fluidRow(
                    column(6,
                      checkboxInput("enable_gbif",
                                   "Enable GBIF queries",
                                   value = TRUE),
                      helpText("🌍 Global Biodiversity Information Facility - Most complete global database")
                    ),
                    column(6,
                      conditionalPanel(
                        condition = "input.enable_gbif",
                        numericInput("gbif_records_per_box", 
                                   "Records per box (GBIF):", 
                                   value = 500, min = 100, max = 2000, step = 100),
                        helpText("📊 Maximum GBIF records per cell.")
                      )
                    )
                  ),
                  
                  conditionalPanel(
                    condition = "input.enable_gbif",
                    fluidRow(
                      column(6,
                        selectInput("gbif_rank",
                                  "Taxonomic rank:",
                                  choices = list(
                                    "All" = "",
                                    "Species" = "SPECIES",
                                    "Genus" = "GENUS",
                                    "Family" = "FAMILY"
                                  ),
                                  selected = ""),
                        helpText("🔬 Filter by specific taxonomic level.")
                      ),
                      column(6,
                        checkboxInput("gbif_unlimited",
                                     "Unlimited records",
                                     value = FALSE),
                        helpText("⚠️ May take a long time.")
                      )
                    )
                  )
                ),
                
                # eBird Tab
                tabPanel(
                  title = "🦜 eBird",
                  value = "ebird_tab",
                  br(),
                  fluidRow(
                    column(6,
                      checkboxInput("enable_ebird",
                                   "Habilitar consultas eBird",
                                   value = FALSE),
                      helpText("🦜 Base de datos de aves ciudadana más grande del mundo")
                    ),
                    column(6,
                      conditionalPanel(
                        condition = "input.enable_ebird",
                        numericInput("ebird_records_per_box", 
                                   "Records per box (eBird):", 
                                   value = 300, min = 50, max = 1000, step = 50),
                        helpText("📊 Maximum eBird records per cell.")
                      )
                    )
                  ),
                  
                  conditionalPanel(
                    condition = "input.enable_ebird",
                    fluidRow(
                      column(12,
                        h5("🔑 eBird API Configuration:"),
                        textInput("ebird_api_key",
                                 "eBird API Key:",
                                 placeholder = "Or create 'ebirdapi_key' file in folder"),
                        helpText("🔑 Get your free key at: https://ebird.org/api/keygen"),
                        
                        br(),
                        h5("⚙️ eBird-specific Configuration:"),
                        fluidRow(
                          column(6,
                            numericInput("ebird_days_back",
                                       "Days back:",
                                       value = 30, min = 1, max = 30, step = 1),
                            helpText("�️ Previous days to query (max. 30).")
                          ),
                          column(6,
                            selectInput("ebird_region_type",
                                      "Region type:",
                                      choices = list(
                                        "Any" = "any",
                                        "Hotspots" = "hotspot",
                                        "Locations" = "location"
                                      ),
                                      selected = "any"),
                            helpText("📍 Location type for queries.")
                          )
                        )
                      )
                    )
                  )
                ),
                
                # OBIS Tab
                tabPanel(
                  title = "🌊 OBIS",
                  value = "obis_tab",
                  br(),
                  fluidRow(
                    column(6,
                      checkboxInput("enable_obis",
                                   "Enable OBIS queries",
                                   value = FALSE),
                      helpText("🌊 Ocean Biodiversity Information System - Marine species")
                    ),
                    column(6,
                      conditionalPanel(
                        condition = "input.enable_obis",
                        numericInput("obis_records_per_box", 
                                   "Records per box (OBIS):", 
                                   value = 400, min = 100, max = 1500, step = 100),
                        helpText("📊 Maximum OBIS records per cell.")
                      )
                    )
                  ),
                  
                  conditionalPanel(
                    condition = "input.enable_obis",
                    fluidRow(
                      column(12,
                        h5("⚙️ OBIS-specific Configuration:"),
                        fluidRow(
                          column(6,
                            numericInput("obis_min_depth",
                                       "Minimum depth (m):",
                                       value = NA, min = 0, max = 10000, step = 10),
                            helpText("� Minimum observation depth.")
                          ),
                          column(6,
                            numericInput("obis_max_depth",
                                       "Maximum depth (m):",
                                       value = NA, min = 0, max = 10000, step = 10),
                            helpText("� Maximum observation depth.")
                          )
                        ),
                        fluidRow(
                          column(6,
                            selectInput("obis_habitat",
                                      "Habitat type:",
                                      choices = list(
                                        "All" = "",
                                        "Pelagic" = "pelagic",
                                        "Benthic" = "benthic",
                                        "Demersal" = "demersal"
                                      ),
                                      selected = ""),
                            helpText("🌊 Filter by marine habitat type.")
                          ),
                          column(6,
                            checkboxInput("obis_marine_only",
                                         "Marine species only",
                                         value = TRUE),
                            helpText("🐟 Exclude freshwater species.")
                          )
                        )
                      )
                    )
                  )
                ),
                
                # iDigBio Tab
                tabPanel(
                  title = "🔬 iDigBio",
                  value = "idigbio_tab",
                  br(),
                  fluidRow(
                    column(6,
                      checkboxInput("enable_idigbio",
                                   "Enable iDigBio queries",
                                   value = FALSE),
                      helpText("🔬 Integrated Digitized Biocollections - Museum specimens")
                    ),
                    column(6,
                      conditionalPanel(
                        condition = "input.enable_idigbio",
                        numericInput("idigbio_records_per_box", 
                                   "Records per box (iDigBio):", 
                                   value = 300, min = 50, max = 1000, step = 50),
                        helpText("📊 Maximum iDigBio records per cell.")
                      )
                    )
                  ),
                  
                  conditionalPanel(
                    condition = "input.enable_idigbio",
                    fluidRow(
                      column(12,
                        h5("⚙️ iDigBio-specific Configuration:"),
                        fluidRow(
                          column(6,
                            selectInput("idigbio_record_type",
                                      "Record type:",
                                      choices = list(
                                        "All" = "",
                                        "Specimens" = "specimens",
                                        "Fossils" = "fossils",
                                        "Observations" = "observations"
                                      ),
                                      selected = "specimens"),
                            helpText("� Museum record type.")
                          ),
                          column(6,
                            checkboxInput("idigbio_has_image",
                                         "Only with images",
                                         value = FALSE),
                            helpText("📷 Records that include images.")
                          )
                        ),
                        fluidRow(
                          column(6,
                            textInput("idigbio_institution",
                                    "Specific institution:",
                                    placeholder = "Ex: Smithsonian"),
                            helpText("� Filter by specific institution.")
                          ),
                          column(6,
                            selectInput("idigbio_quality",
                                      "Data quality:",
                                      choices = list(
                                        "All" = "",
                                        "High quality" = "high",
                                        "Medium quality" = "medium",
                                        "Any quality" = "any"
                                      ),
                                      selected = "medium"),
                            helpText("⭐ Data quality filter.")
                          )
                        )
                      )
                    )
                  )
                ),
                
                # iNaturalist Tab
                tabPanel(
                  title = "📱 iNaturalist",
                  value = "inat_tab",
                  br(),
                  fluidRow(
                    column(6,
                      checkboxInput("enable_inat",
                                   "Enable iNaturalist queries",
                                   value = FALSE),
                      helpText("📱 Citizen science platform for observations")
                    ),
                    column(6,
                      conditionalPanel(
                        condition = "input.enable_inat",
                        numericInput("inat_records_per_box", 
                                   "Records per box (iNaturalist):", 
                                   value = 400, min = 100, max = 1500, step = 100),
                        helpText("📊 Maximum iNaturalist records per cell.")
                      )
                    )
                  ),
                  
                  conditionalPanel(
                    condition = "input.enable_inat",
                    fluidRow(
                      column(12,
                        h5("⚙️ iNaturalist-specific Configuration:"),
                        fluidRow(
                          column(6,
                            selectInput("inat_quality_grade",
                                      "Quality grade:",
                                      choices = list(
                                        "All" = "",
                                        "Research grade" = "research",
                                        "Needs ID" = "needs_id",
                                        "Casual" = "casual"
                                      ),
                                      selected = "research"),
                            helpText("🏆 Observation quality grade.")
                          ),
                          column(6,
                            checkboxInput("inat_has_photos",
                                         "Only with photos",
                                         value = FALSE),
                            helpText("📸 Observations that include photos.")
                          )
                        ),
                        fluidRow(
                          column(6,
                            selectInput("inat_iconic_taxa",
                                      "Taxonomic group:",
                                      choices = list(
                                        "All" = "",
                                        "Plants" = "Plantae",
                                        "Animals" = "Animalia",
                                        "Birds" = "Aves",
                                        "Fish" = "Actinopterygii",
                                        "Fungi" = "Fungi",
                                        "Insects" = "Insecta"
                                      ),
                                      selected = ""),
                            helpText("🦋 Filter by taxonomic group.")
                          ),
                          column(6,
                            checkboxInput("inat_geo_referenced",
                                         "Only georeferenced",
                                         value = TRUE),
                            helpText("📍 Observations with precise coordinates.")
                          )
                        )
                      )
                    )
                  )
                ),
                
                # Merge Configuration Tab
                tabPanel(
                  title = "🔗 Results Combination",
                  value = "merge_tab",
                  br(),
                  fluidRow(
                    column(12,
                      h4("🔗 Data Combination Configuration"),
                      helpText("Configure how results from different databases will be combined."),
                      
                      br(),
                      fluidRow(
                        column(6,
                          h5("🎯 Combination Strategy:"),
                          radioButtons("merge_strategy",
                                     "Combination method:",
                                     choices = list(
                                       "Simple union (concatenate)" = "simple",
                                       "Remove duplicates by species and location" = "deduplicate",
                                       "Prioritize by data source" = "prioritize"
                                     ),
                                     selected = "deduplicate"),
                          helpText("📋 How to combine records from multiple sources.")
                        ),
                        column(6,
                          conditionalPanel(
                            condition = "input.merge_strategy == 'prioritize'",
                            h5("⚡ Priority Order:"),
                            selectInput("priority_order",
                                      "Primary source:",
                                      choices = list(
                                        "GBIF" = "gbif",
                                        "eBird" = "ebird", 
                                        "OBIS" = "obis",
                                        "iDigBio" = "idigbio",
                                        "iNaturalist" = "inat"
                                      ),
                                      selected = "gbif"),
                            helpText("🥇 Data source with highest priority.")
                          )
                        )
                      ),
                      
                      fluidRow(
                        column(6,
                          h5("🔍 Post-Combination Filters:"),
                          numericInput("merge_distance_threshold",
                                     "Distance threshold (meters):",
                                     value = 100, min = 10, max = 1000, step = 10),
                          helpText("📏 Minimum distance to consider records as duplicates."),
                          
                          checkboxInput("merge_temporal_filter",
                                       "Strict temporal filtering",
                                       value = FALSE),
                          helpText("�️ Remove records with inconsistent dates.")
                        ),
                        column(6,
                          h5("📊 Quality Control:"),
                          numericInput("merge_min_records_per_species",
                                     "Minimum records per species:",
                                     value = 1, min = 1, max = 10, step = 1),
                          helpText("🔢 Minimum number of records to include a species."),
                          
                          checkboxInput("merge_validate_coordinates",
                                       "Validate coordinates",
                                       value = TRUE),
                          helpText("✅ Verify that coordinates are valid.")
                        )
                      ),
                      
                      br(),
                      div(style = "background-color: #f8f9fa; padding: 15px; border-radius: 8px; border: 1px solid #dee2e6;",
                          h6("ℹ️ Information about Combination:", style = "margin-top: 0;"),
                          tags$ul(
                            tags$li("🔄 Combination runs automatically after all queries"),
                            tags$li("📊 Combined results will appear in the Results tab"),
                            tags$li("⚠️ Configuration only applies if multiple sources are enabled"),
                            tags$li("🎯 Spatial filtering always applies regardless of strategy")
                          )
                      )
                    )
                  )
                )
              ),
              
              br(),
              
              fluidRow(
                column(12,
                  div(style = "text-align: center; background-color: #f8f9fa; padding: 20px; border-radius: 10px; margin: 10px 0;",
                      h5("🚀 Query Control", style = "margin-top: 0;"),
                      
                      div(style = "margin: 15px 0;",
                          actionButton("start_individual_queries", 
                                     "🎯 Execute Individual Queries", 
                                     class = "btn btn-success btn-lg",
                                     style = "margin: 5px;"),
                          helpText("Execute queries only for enabled databases")
                      ),
                      
                      div(style = "margin: 15px 0;",
                          actionButton("start_query", 
                                     "🚀 Execute All Queries", 
                                     class = "btn btn-primary btn-lg",
                                     style = "margin: 5px;"),
                          helpText("Execute queries for all enabled databases and combine results")
                      ),
                      
                      div(
                          actionButton("stop_query", 
                                     "⏹️ Stop Query", 
                                     class = "btn btn-warning",
                                     style = "margin: 5px;"),
                          
                          actionButton("clear_results", 
                                     "🗑️ Clear Results", 
                                     class = "btn btn-danger",
                                     style = "margin: 5px;")
                      )
                  )
                )
              )
            )
          )
        ),
        
        # Query Status Panel
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
