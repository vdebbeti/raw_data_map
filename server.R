# =============================================================================
# server.R — Server logic
# SDTM Raw Dataset Mapping Dashboard
# =============================================================================

server <- function(input, output, session) {

  # ── Shared reactive state ─────────────────────────────────────────────────
  rv <- reactiveValues(
    raw_df        = NULL,   # data.frame: files found in folders
    refs_df       = NULL,   # data.frame: raw. references found in programs/logs
    mapping_df    = NULL,   # data.frame: combined mapping table
    scan_time     = NULL,   # POSIXct: timestamp of last scan
    verifications = list(), # named list: dataset_name -> verification tibble
    modal_ds      = NULL,   # character: dataset being verified (modal)
    modal_refs    = NULL    # data.frame: code references for modal dataset
  )

  # ── Run Scan ──────────────────────────────────────────────────────────────
  observeEvent(input$btn_scan, {
    withProgress(message = "Scanning...", value = 0, {

      setProgress(0.10, detail = "Reading EDC folder …")
      edc_df <- scan_raw_folder(input$path_edc, "EDC")

      setProgress(0.25, detail = "Reading External folder …")
      ext_df <- scan_raw_folder(input$path_ext, "External")

      raw_combined <- bind_rows(edc_df, ext_df)

      setProgress(0.45, detail = "Parsing programs & logs …")
      lib_names <- parse_lib_names(input$lib_names)
      refs_df <- scan_programs_for_raw(
        input$path_pgm,
        lib_names = lib_names,
        recursive = isTRUE(input$opt_recursive)
      )

      setProgress(0.80, detail = "Building mapping table …")
      mapping_df <- build_mapping(raw_combined, refs_df)

      rv$raw_df     <- raw_combined
      rv$refs_df    <- refs_df
      rv$mapping_df <- mapping_df
      rv$scan_time  <- Sys.time()
      setProgress(1.00, detail = "Done.")
    })

    updateTabItems(session, "sidebar_menu", "tab_dashboard")

    n_raw  <- nrow(rv$raw_df)
    n_refs <- nrow(rv$refs_df)
    n_pgms <- if (!is.null(rv$refs_df)) length(unique(rv$refs_df$program)) else 0

    libs_scanned <- paste(parse_lib_names(input$lib_names), collapse = ", ")
    showNotification(
      sprintf("Scan complete — %d raw datasets | %d references to [%s] in %d programs.",
              n_raw, n_refs, libs_scanned, n_pgms),
      type = "message", duration = 7
    )
  })

  # ── Reset ─────────────────────────────────────────────────────────────────
  observeEvent(input$btn_reset, {
    rv$raw_df        <- NULL
    rv$refs_df       <- NULL
    rv$mapping_df    <- NULL
    rv$scan_time     <- NULL
    rv$verifications <- list()
    rv$modal_ds      <- NULL
    rv$modal_refs    <- NULL
    showNotification("All data cleared.", type = "warning", duration = 3)
  })

  # ── Last scan time ────────────────────────────────────────────────────────
  output$last_scan_time <- renderText({
    if (is.null(rv$scan_time)) "Never"
    else format(rv$scan_time, "%Y-%m-%d %H:%M:%S")
  })

  # ── Info boxes ────────────────────────────────────────────────────────────
  .n_status <- function(s) {
    if (is.null(rv$mapping_df)) return(0L)
    sum(rv$mapping_df$status == s, na.rm = TRUE)
  }

  output$ibox_total <- renderInfoBox({
    n <- if (is.null(rv$mapping_df)) 0L else nrow(rv$mapping_df)
    infoBox("Total Datasets", n, icon = icon("database"),
            color = "blue", fill = TRUE)
  })
  output$ibox_mapped <- renderInfoBox({
    infoBox("Mapped", .n_status("Mapped"),
            icon = icon("check-circle"), color = "green", fill = TRUE)
  })
  output$ibox_unmapped <- renderInfoBox({
    infoBox("Unmapped", .n_status("Unmapped"),
            icon = icon("exclamation-triangle"), color = "yellow", fill = TRUE)
  })
  output$ibox_codeonly <- renderInfoBox({
    infoBox("Code-Only", .n_status("Code-Only"),
            icon = icon("times-circle"), color = "red", fill = TRUE)
  })
  output$ibox_multidomain <- renderInfoBox({
    infoBox("Multi-Domain", .n_status("Multi-Domain"),
            icon = icon("project-diagram"), color = "teal", fill = TRUE)
  })
  output$ibox_verified <- renderInfoBox({
    infoBox("Lead Verified", length(rv$verifications),
            icon = icon("clipboard-check"), color = "purple", fill = TRUE)
  })
  output$ibox_programs <- renderInfoBox({
    n <- if (!is.null(rv$refs_df)) length(unique(rv$refs_df$program)) else 0L
    infoBox("Programs Scanned", n, icon = icon("file-code"),
            color = "navy", fill = TRUE)
  })
  output$ibox_refs <- renderInfoBox({
    n <- if (!is.null(rv$refs_df)) nrow(rv$refs_df) else 0L
    infoBox("raw. References", n, icon = icon("link"),
            color = "olive", fill = TRUE)
  })

  # ── Dashboard plots ───────────────────────────────────────────────────────
  output$plot_status_source <- renderPlot({
    req(rv$mapping_df, nrow(rv$mapping_df) > 0)
    df <- rv$mapping_df |>
      count(source, status) |>
      mutate(status = factor(status, levels = STATUS_LEVELS))

    ggplot(df, aes(x = source, y = n, fill = status)) +
      geom_col(position = "dodge", width = 0.65) +
      geom_text(aes(label = n), position = position_dodge(width = 0.65),
                vjust = -0.4, size = 3.2, fontface = "bold") +
      scale_fill_manual(values = STATUS_COLORS, name = "Status") +
      labs(x = "Source", y = "Count", title = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom",
            legend.text = element_text(size = 9),
            panel.grid.major.x = element_blank())
  })

  output$plot_top_refs <- renderPlot({
    req(rv$refs_df, nrow(rv$refs_df) > 0)
    top <- rv$refs_df |>
      count(raw_dataset, sort = TRUE) |>
      slice_head(n = 15) |>
      mutate(raw_dataset = factor(raw_dataset, levels = rev(raw_dataset)))

    ggplot(top, aes(x = n, y = raw_dataset)) +
      geom_col(fill = "#17a2b8", width = 0.65) +
      geom_text(aes(label = n), hjust = -0.2, size = 3.2, fontface = "bold") +
      labs(x = "# References", y = NULL, title = NULL) +
      theme_minimal(base_size = 12) +
      theme(panel.grid.major.y = element_blank()) +
      scale_x_continuous(expand = expansion(mult = c(0, 0.12)))
  })

  # ── Attention table (dashboard quick view) ────────────────────────────────
  output$dt_attention <- renderDT({
    req(rv$mapping_df)
    df <- rv$mapping_df |>
      filter(status %in% c("Unmapped", "Code-Only", "Multi-Domain")) |>
      mutate(Status = sapply(status, status_badge)) |>
      select(Dataset = dataset_name, Source = source,
             `SDTM Domain(s)` = sdtm_domains,
             Programs = programs, Status)

    datatable(df, escape = FALSE, rownames = FALSE,
              options = list(pageLength = 8, dom = "tp",
                             columnDefs = list(
                               list(className = "dt-center", targets = c(1, 4))
                             )))
  })

  # ── Filtered mapping reactive ─────────────────────────────────────────────
  filtered_mapping <- reactive({
    req(rv$mapping_df)
    df <- rv$mapping_df

    # Attach current verification decisions
    ver_tbl <- if (length(rv$verifications) > 0) {
      bind_rows(rv$verifications, .id = "dataset_name") |>
        select(dataset_name, ver_status, ver_note, verified_time)
    } else {
      tibble(dataset_name = character(), ver_status = character(),
             ver_note = character(), verified_time = character())
    }

    df <- df |>
      left_join(ver_tbl, by = "dataset_name") |>
      mutate(
        ver_status    = if_else(is.na(ver_status),    "—", ver_status),
        ver_note      = if_else(is.na(ver_note),      "",  ver_note),
        verified_time = if_else(is.na(verified_time), "—", verified_time)
      )

    # Apply filters
    if (!is.null(input$flt_status) && input$flt_status != "All")
      df <- df |> filter(status == input$flt_status)

    if (!is.null(input$flt_source) && input$flt_source != "All")
      df <- df |> filter(source == input$flt_source)

    if (!is.null(input$flt_verified) && input$flt_verified != "All") {
      if (input$flt_verified == "Verified")
        df <- df |> filter(ver_status != "—")
      else
        df <- df |> filter(ver_status == "—")
    }

    df
  })

  # ── Main mapping DT ───────────────────────────────────────────────────────
  output$dt_mapping <- renderDT({
    df <- filtered_mapping()
    validate(need(nrow(df) > 0,
                  "No data yet — run a scan from the Configuration tab, or adjust filters."))

    disp <- df |>
      mutate(
        Status   = sapply(status,     status_badge),
        Verified = sapply(ver_status, ver_badge),
        Action   = sprintf(
          '<button class="btn-verify"
              onclick=\'Shiny.setInputValue("verify_click",
                        {ds:"%s", ts:Date.now()}, {priority:"event"})\'>
            &#128269; Verify
          </button>',
          dataset_name
        )
      ) |>
      select(
        `Dataset`         = dataset_name,
        `Source`          = source,
        `Library(ies)`    = lib_aliases,   # which libname(s) found in code
        `SDTM Domain(s)`  = sdtm_domains,
        `Programs`        = programs,
        `# Refs`          = ref_count,
        `Status`          = Status,
        `Lead Verified`   = Verified,
        `Action`          = Action
      )

    datatable(
      disp,
      escape     = FALSE,
      rownames   = FALSE,
      selection  = "none",
      filter     = "top",       # per-column search boxes
      extensions = "Buttons",
      options    = list(
        dom        = "Bfrtip",
        buttons    = list(
          "copy",
          list(
            extend        = "csv",
            title         = "SDTM_Raw_Mapping",
            # Strip HTML tags from badge/button columns before writing to file
            exportOptions = list(
              columns    = ":not(:last-child)",  # exclude Action column
              orthogonal = "display",
              format     = list(
                body = JS("function(data, row, col, node) {
                  return $('<div>').html(data).text();
                }")
              )
            )
          ),
          list(
            extend        = "excel",
            title         = "SDTM_Raw_Mapping",
            messageTop    = paste("Exported:", format(Sys.time(), "%Y-%m-%d %H:%M")),
            exportOptions = list(
              columns    = ":not(:last-child)",
              orthogonal = "display",
              format     = list(
                body = JS("function(data, row, col, node) {
                  return $('<div>').html(data).text();
                }")
              )
            )
          )
        ),
        pageLength  = 20,
        lengthMenu  = list(c(10, 20, 50, -1), c("10", "20", "50", "All")),
        scrollX     = TRUE,
        autoWidth   = FALSE,
        columnDefs  = list(
          list(width = "120px", targets = 0),   # Dataset
          list(width = "75px",  targets = 1),   # Source
          list(width = "100px", targets = 2),   # Library(ies)
          list(width = "150px", targets = 3),   # Domains
          list(width = "200px", targets = 4),   # Programs
          list(width = "55px",  targets = 5, className = "dt-center"),   # Refs
          list(width = "115px", targets = 6, className = "dt-center"),   # Status
          list(width = "120px", targets = 7, className = "dt-center"),   # Verified
          list(width = "75px",  targets = 8, orderable = FALSE,
               className = "dt-center")                                   # Action
        )
      )
    )
  }, server = FALSE)

  # ── Export mapping CSV ────────────────────────────────────────────────────
  output$dl_mapping_csv <- downloadHandler(
    filename = function() {
      paste0("sdtm_mapping_", format(Sys.Date(), "%Y%m%d"), ".csv")
    },
    content = function(file) {
      write.csv(filtered_mapping() |>
                  select(-in_folder, -in_code, -n_domains),
                file, row.names = FALSE)
    }
  )

  # ── Verify button click → populate modal state ────────────────────────────
  observeEvent(input$verify_click, {
    ds_name <- input$verify_click$ds
    req(nzchar(ds_name), rv$mapping_df)

    row <- rv$mapping_df |> filter(dataset_name == ds_name)
    if (nrow(row) == 0) {
      showNotification("Dataset not found.", type = "error")
      return()
    }
    row <- row[1, ]

    code_refs <- if (!is.null(rv$refs_df) && nrow(rv$refs_df) > 0) {
      rv$refs_df |> filter(raw_dataset == ds_name)
    } else {
      tibble()
    }

    rv$modal_ds   <- ds_name
    rv$modal_refs <- code_refs
    rv$modal_row  <- row

    # Current verification decision if exists
    cur <- rv$verifications[[ds_name]]
    cur_status <- if (!is.null(cur)) cur$ver_status else character(0)
    cur_note   <- if (!is.null(cur)) cur$ver_note   else ""

    showModal(modalDialog(
      title = div(
        tags$i(class = "fa fa-search"), " Verify Dataset: ",
        tags$b(toupper(ds_name)),
        tags$span(style = "margin-left:10px;",
                  HTML(status_badge(row$status)))
      ),
      size      = "l",
      easyClose = TRUE,
      footer    = NULL,

      # ── Summary row ─────────────────────────────────────────────
      div(style = "background:#f4f6f9; padding:10px 14px;
                   border-radius:5px; margin-bottom:12px;",
        fluidRow(
          column(2, tags$b("Source:"),          br(), row$source),
          column(2, tags$b("Library(ies):"),    br(), tags$code(row$lib_aliases)),
          column(3, tags$b("SDTM Domain(s):"),  br(), row$sdtm_domains),
          column(3, tags$b("Programs:"),        br(), tags$small(row$programs)),
          column(2, tags$b("# References:"),    br(), row$ref_count)
        )
      ),

      # ── Code occurrences table ───────────────────────────────────
      if (nrow(code_refs) > 0) {
        tagList(
          tags$h5(icon("code"),
                  paste0(" Code Occurrences  (", nrow(code_refs), " reference(s))")),
          DTOutput("dt_modal_refs"),
          br(),
          tags$h5(icon("align-left"), " Code Context"),
          helpText("Select a row above to view its surrounding code. Matching line is marked with >>>"),
          uiOutput("ui_modal_context")
        )
      } else {
        div(class = "alert alert-warning",
            icon("exclamation-triangle"),
            " No code references were found for this dataset in the scanned programs.")
      },

      hr(),

      # ── Verification form ────────────────────────────────────────
      div(class = "verify-form",
        tags$h5(icon("clipboard-check"), tags$b(" Lead Verification Decision")),
        fluidRow(
          column(5,
            radioButtons(
              "modal_ver_status",
              label    = NULL,
              choices  = c(
                "Confirmed Mapped"        = "Confirmed Mapped",
                "Confirmed Unmapped"      = "Confirmed Unmapped",
                "Flag for Review"         = "Flag for Review",
                "Intentional Code-Only"   = "Intentional Code-Only",
                "Needs Investigation"     = "Needs Investigation"
              ),
              selected = cur_status
            )
          ),
          column(7,
            textAreaInput(
              "modal_ver_note",
              label       = "Notes / Comments:",
              value       = cur_note,
              rows        = 5,
              placeholder = "e.g. 'raw.pe used only in exploratory macro, not in SDTM pipeline'"
            )
          )
        ),
        fluidRow(
          column(12,
            actionButton("modal_save", "Save Verification",
                         icon  = icon("save"), class = "btn-success"),
            tags$span(style = "margin-left:12px;"),
            modalButton("Close")
          )
        )
      )
    ))
  })

  # ── Modal: code references table ─────────────────────────────────────────
  output$dt_modal_refs <- renderDT({
    req(rv$modal_refs, nrow(rv$modal_refs) > 0)
    rv$modal_refs |>
      mutate(
        full_ref = paste0(lib_used, ".", raw_dataset)  # e.g. "rawdata.ae"
      ) |>
      select(
        Program       = program,
        Type          = file_type,
        `Domain Guess`= domain_guess,
        `Line #`      = line_number,
        `Reference`   = full_ref,      # shows exact libname.dataset used
        `Code Snippet`= code_snippet
      ) |>
      datatable(
        escape    = FALSE,
        rownames  = FALSE,
        selection = list(mode = "single", selected = 1),
        options   = list(
          pageLength = 5,
          dom        = "tp",
          scrollX    = TRUE,
          columnDefs = list(
            list(width = "130px", targets = 0),
            list(width = "60px",  targets = 1),
            list(width = "80px",  targets = 2),
            list(width = "50px",  targets = 3, className = "dt-center"),
            list(width = "90px",  targets = 4)
          )
        )
      )
  }, server = FALSE)

  # ── Modal: context viewer (updates on row selection) ─────────────────────
  output$ui_modal_context <- renderUI({
    req(rv$modal_refs)
    refs <- rv$modal_refs
    if (nrow(refs) == 0) return(NULL)

    sel <- input$dt_modal_refs_rows_selected
    idx <- if (length(sel) == 0 || sel < 1 || sel > nrow(refs)) 1L else as.integer(sel)

    ref <- refs[idx, ]
    ctx <- ref$context

    tagList(
      div(style = "font-size:0.82em; color:#666; margin-bottom:4px;",
          icon("file-code"), " ", tags$b(ref$program),
          tags$span(style = "margin-left:8px;",
                    paste0("Line ", ref$line_number))
      ),
      tags$pre(class = "context-pre", ctx)
    )
  })

  # ── Save verification ─────────────────────────────────────────────────────
  observeEvent(input$modal_save, {
    req(rv$modal_ds, input$modal_ver_status)
    ds <- rv$modal_ds
    rv$verifications[[ds]] <- tibble(
      ver_status    = input$modal_ver_status,
      ver_note      = trimws(input$modal_ver_note),
      verified_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )
    removeModal()
    showNotification(
      paste0("Verification saved for: ", toupper(ds), " → ", input$modal_ver_status),
      type = "message", duration = 4
    )
  })

  # ── Raw datasets DT ───────────────────────────────────────────────────────
  output$dt_raw <- renderDT({
    req(rv$raw_df)
    validate(need(nrow(rv$raw_df) > 0,
                  "No raw datasets found. Check the folder paths."))
    datatable(
      rv$raw_df |> select(Dataset = dataset_name, File = file_name,
                           Source = source, Folder = folder),
      rownames = FALSE, filter = "top",
      options  = list(pageLength = 20, scrollX = TRUE)
    )
  })

  # ── Programs DT ──────────────────────────────────────────────────────────
  output$dt_programs <- renderDT({
    req(rv$refs_df)
    validate(need(nrow(rv$refs_df) > 0,
                  "No raw. references found in the scanned programs."))
    datatable(
      rv$refs_df |>
        select(Program    = program,
               Type       = file_type,
               Domain     = domain_guess,
               `Line #`   = line_number,
               `Raw Dataset` = raw_dataset,
               `Code Snippet` = code_snippet),
      rownames = FALSE, filter = "top",
      options  = list(pageLength = 20, scrollX = TRUE,
                      columnDefs = list(
                        list(width = "55px",  targets = 2, className = "dt-center"),
                        list(width = "55px",  targets = 3, className = "dt-center")
                      ))
    )
  })

  # ── Verification log ──────────────────────────────────────────────────────
  ver_log_df <- reactive({
    if (length(rv$verifications) == 0) {
      return(tibble(
        dataset_name  = character(), ver_status    = character(),
        ver_note      = character(), verified_time = character()
      ))
    }
    bind_rows(rv$verifications, .id = "dataset_name") |>
      arrange(dataset_name)
  })

  output$dt_verlog <- renderDT({
    df <- ver_log_df()
    validate(need(nrow(df) > 0,
                  "No verifications recorded yet. Use the Verify button in the Mapping Table."))
    datatable(
      df |> select(
        `Dataset`          = dataset_name,
        `Lead Decision`    = ver_status,
        `Notes`            = ver_note,
        `Verified At`      = verified_time
      ),
      rownames = FALSE,
      options  = list(pageLength = 20, scrollX = TRUE)
    )
  })

  output$dl_verlog_csv <- downloadHandler(
    filename = function() {
      paste0("sdtm_verification_log_", format(Sys.Date(), "%Y%m%d"), ".csv")
    },
    content = function(file) {
      write.csv(ver_log_df(), file, row.names = FALSE)
    }
  )
}
