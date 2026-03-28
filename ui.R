# =============================================================================
# ui.R — Dashboard UI
# SDTM Raw Dataset Mapping Dashboard
# =============================================================================

ui <- dashboardPage(
  skin = "blue",

  # ---------------------------------------------------------------------------
  # Header
  # ---------------------------------------------------------------------------
  dashboardHeader(
    title = tagList(tags$i(class = "fa fa-flask"), " SDTM Raw Mapper"),
    titleWidth = 260
  ),

  # ---------------------------------------------------------------------------
  # Sidebar
  # ---------------------------------------------------------------------------
  dashboardSidebar(
    width = 260,
    useShinyjs(),

    sidebarMenu(
      id = "sidebar_menu",
      menuItem("Configuration",    tabName = "tab_config",    icon = icon("cog")),
      menuItem("Dashboard",        tabName = "tab_dashboard", icon = icon("tachometer-alt")),
      menuItem("Mapping Table",    tabName = "tab_mapping",   icon = icon("table")),
      menuItem("Raw Datasets",     tabName = "tab_raw",       icon = icon("database")),
      menuItem("Programs & Logs",  tabName = "tab_programs",  icon = icon("file-code")),
      menuItem("Verification Log", tabName = "tab_verlog",    icon = icon("clipboard-check"))
    ),

    hr(),

    div(style = "padding:8px 16px; font-size:0.82em; color:#ccc;",
      tags$b("Last scan:"), br(),
      textOutput("last_scan_time", inline = FALSE)
    )
  ),

  # ---------------------------------------------------------------------------
  # Body
  # ---------------------------------------------------------------------------
  dashboardBody(

    tags$head(
      # Custom CSS
      tags$style(HTML("
        /* ── Bootstrap badge overrides ── */
        .badge-success   { background-color:#28a745 !important; }
        .badge-warning   { background-color:#e6a817 !important; color:#212529 !important; }
        .badge-danger    { background-color:#dc3545 !important; }
        .badge-info      { background-color:#17a2b8 !important; }
        .badge-secondary { background-color:#6c757d !important; }
        .badge-primary   { background-color:#3b6fd4 !important; }

        /* ── Code context viewer ── */
        .context-pre {
          background:#1e1e1e; color:#d4d4d4;
          padding:12px 16px; border-radius:6px;
          font-family:'Consolas','Courier New',monospace;
          font-size:0.80em; overflow-x:auto;
          white-space:pre; max-height:260px; overflow-y:auto;
          line-height:1.5;
        }

        /* ── Verify form ── */
        .verify-form {
          background:#f8f9fa; padding:16px; border-radius:6px;
          border:1px solid #dee2e6; margin-top:12px;
        }

        /* ── Table action button ── */
        .btn-verify {
          font-size:11px; padding:2px 8px;
          background:#17a2b8; color:#fff; border:none; border-radius:3px;
          cursor:pointer;
        }
        .btn-verify:hover { background:#138496; color:#fff; }

        /* ── Info box numbers ── */
        .info-box-number { font-size:26px !important; }

        /* ── Dashboard section title ── */
        .section-title { font-size:14px; font-weight:600;
                         color:#444; margin-bottom:4px; }

        /* ── Modal wider ── */
        .modal-lg { width:900px !important; }

        /* ── Sidebar scan time ── */
        #last_scan_time { color:#aaa; font-size:0.9em; }

        /* ── DT filter row ── */
        .filter-row { background:#f4f6f9; padding:10px 15px;
                      border-radius:4px; margin-bottom:10px; }
      "))
    ),

    tabItems(

      # ── Configuration ─────────────────────────────────────────────────────
      tabItem(tabName = "tab_config",
        fluidRow(
          box(
            title = "Scan Configuration", width = 8,
            status = "primary", solidHeader = TRUE,

            fluidRow(
              column(6,
                tags$h5(icon("hospital"), tags$b(" EDC Raw Datasets")),
                textInput("path_edc", "Folder path",
                          value       = "sample_data/raw/edc",
                          placeholder = "/path/to/raw/edc"),
                helpText("Files: .sas7bdat, .csv, .xlsx, .xpt, .dat …")
              ),
              column(6,
                tags$h5(icon("external-link-alt"), tags$b(" External Raw Datasets")),
                textInput("path_ext", "Folder path",
                          value       = "sample_data/raw/external",
                          placeholder = "/path/to/raw/external"),
                helpText("External / third-party raw datasets")
              )
            ),

            hr(),

            fluidRow(
              column(8,
                tags$h5(icon("code"), tags$b(" SDTM Programs / Logs")),
                textInput("path_pgm", "Folder path",
                          value       = "sample_data/programs",
                          placeholder = "/path/to/sdtm/programs"),
                helpText("SAS programs (.sas) and/or log files (.log)")
              ),
              column(4,
                br(), br(),
                checkboxInput("opt_recursive", "Scan subfolders recursively",
                              value = TRUE)
              )
            ),

            hr(),

            fluidRow(
              column(8,
                tags$h5(icon("search"), tags$b(" Library Name(s) to Scan For")),
                textInput(
                  "lib_names",
                  label       = NULL,
                  value       = "raw",
                  placeholder = "raw, rawdata, edc, ext, src, indata …"
                ),
                helpText(
                  "Enter one or more SAS library names, separated by commas.",
                  "The scanner will detect references like",
                  tags$code("raw.ae"), ",",
                  tags$code("rawdata.dm"), ",",
                  tags$code("edc.lb"), ", etc.",
                  "Case-insensitive."
                )
              ),
              column(4,
                br(),
                tags$small(tags$b("Common conventions:")),
                tags$ul(style = "font-size:0.82em; padding-left:16px; margin-top:4px;",
                  tags$li(tags$code("raw"), " — most common default"),
                  tags$li(tags$code("rawdata"), " — some sponsors"),
                  tags$li(tags$code("edc, ext"), " — source-based naming"),
                  tags$li(tags$code("src, indata"), " — legacy studies")
                )
              )
            ),

            hr(),

            fluidRow(
              column(12,
                actionButton("btn_scan",  "Run Scan",
                             icon = icon("play"), class = "btn-success btn-lg"),
                tags$span(style = "margin-left:12px;"),
                actionButton("btn_reset", "Reset All",
                             icon = icon("undo"),  class = "btn-default")
              )
            )
          ),

          box(
            title = "How It Works", width = 4,
            status = "info", solidHeader = TRUE, collapsible = TRUE,
            tags$ol(style = "padding-left:18px; line-height:1.9;",
              tags$li("Set paths to your EDC and External raw dataset folders."),
              tags$li("Set the path to your SDTM programs / logs folder."),
              tags$li("Click ", tags$b("Run Scan"), " to parse all folders and files."),
              tags$li("Review the ", tags$b("Dashboard"), " for a summary."),
              tags$li("Open the ", tags$b("Mapping Table"), " to review dataset-by-dataset."),
              tags$li("Click ", tags$b("Verify"), " on any row to record your decision."),
              tags$li("Export from the ", tags$b("Verification Log"), " tab.")
            ),
            hr(),
            tags$h5(tags$b("Status Legend")),
            tags$ul(style = "list-style:none; padding-left:0; line-height:2;",
              tags$li(HTML('<span class="badge badge-success">Mapped</span>'),
                      " In folder & referenced in code"),
              tags$li(HTML('<span class="badge badge-warning">Unmapped</span>'),
                      " In folder, not found in code"),
              tags$li(HTML('<span class="badge badge-danger">Code-Only</span>'),
                      " In code, not found in folder"),
              tags$li(HTML('<span class="badge badge-info">Multi-Domain</span>'),
                      " Referenced across multiple domains")
            )
          )
        )
      ),

      # ── Dashboard ──────────────────────────────────────────────────────────
      tabItem(tabName = "tab_dashboard",
        fluidRow(
          infoBoxOutput("ibox_total",      width = 3),
          infoBoxOutput("ibox_mapped",     width = 3),
          infoBoxOutput("ibox_unmapped",   width = 3),
          infoBoxOutput("ibox_codeonly",   width = 3)
        ),
        fluidRow(
          infoBoxOutput("ibox_multidomain",width = 3),
          infoBoxOutput("ibox_verified",   width = 3),
          infoBoxOutput("ibox_programs",   width = 3),
          infoBoxOutput("ibox_refs",       width = 3)
        ),
        fluidRow(
          box(
            title = "Mapping Status by Source", width = 6,
            status = "primary", solidHeader = TRUE,
            plotOutput("plot_status_source", height = "270px")
          ),
          box(
            title = "Top 15 Most-Referenced Datasets", width = 6,
            status = "info", solidHeader = TRUE,
            plotOutput("plot_top_refs", height = "270px")
          )
        ),
        fluidRow(
          box(
            title = "Datasets Requiring Attention (Unmapped / Code-Only / Multi-Domain)",
            width = 12, status = "warning", solidHeader = TRUE, collapsible = TRUE,
            DTOutput("dt_attention")
          )
        )
      ),

      # ── Mapping Table ──────────────────────────────────────────────────────
      tabItem(tabName = "tab_mapping",
        fluidRow(
          box(
            title = "Raw Dataset ↔ SDTM Domain Mapping",
            width = 12, status = "primary", solidHeader = TRUE,

            div(class = "filter-row",
              fluidRow(
                column(3,
                  pickerInput("flt_status",
                    "Status:",
                    choices  = c("All", "Mapped", "Unmapped", "Code-Only", "Multi-Domain"),
                    selected = "All"
                  )
                ),
                column(3,
                  pickerInput("flt_source",
                    "Source:",
                    choices  = c("All", "EDC", "External", "EDC / External"),
                    selected = "All"
                  )
                ),
                column(3,
                  pickerInput("flt_verified",
                    "Lead Verified:",
                    choices  = c("All", "Verified", "Pending"),
                    selected = "All"
                  )
                ),
                column(3,
                  br(),
                  downloadButton("dl_mapping_csv", "Export CSV",
                                 class = "btn-sm btn-info btn-block")
                )
              )
            ),

            DTOutput("dt_mapping"),
            br(),
            div(style = "font-size:0.82em; color:#888;",
              icon("info-circle"),
              " Click ", tags$b("Verify"), " on any row to record the lead's decision.",
              " Use the column search boxes to narrow results.")
          )
        )
      ),

      # ── Raw Datasets ───────────────────────────────────────────────────────
      tabItem(tabName = "tab_raw",
        fluidRow(
          box(
            title = "Raw Datasets Found in Folders",
            width = 12, status = "success", solidHeader = TRUE,
            DTOutput("dt_raw")
          )
        )
      ),

      # ── Programs & Logs ────────────────────────────────────────────────────
      tabItem(tabName = "tab_programs",
        fluidRow(
          box(
            title = "All raw. References Found in SAS Programs & Logs",
            width = 12, status = "warning", solidHeader = TRUE,
            DTOutput("dt_programs")
          )
        )
      ),

      # ── Verification Log ───────────────────────────────────────────────────
      tabItem(tabName = "tab_verlog",
        fluidRow(
          box(
            title = "Lead Verification Log",
            width = 12, status = "success", solidHeader = TRUE,

            fluidRow(
              column(3,
                downloadButton("dl_verlog_csv", "Download CSV",
                               class = "btn-success btn-sm")
              ),
              column(9,
                div(style = "font-size:0.82em; color:#666; padding-top:6px;",
                  icon("info-circle"),
                  " All decisions made via the Mapping Table Verify button are recorded here."
                )
              )
            ),
            br(),
            DTOutput("dt_verlog")
          )
        )
      )

    ) # end tabItems
  )
)
