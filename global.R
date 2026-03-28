# =============================================================================
# global.R — Libraries, constants, and core scanning/mapping functions
# SDTM Raw Dataset Mapping Dashboard
# =============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(shinydashboard)
  library(DT)
  library(stringr)
  library(dplyr)
  library(ggplot2)
  library(shinyjs)
  library(shinyWidgets)
  library(tools)
  library(tibble)
})

APP_TITLE   <- "SDTM Raw Dataset Mapping Dashboard"
APP_VERSION <- "1.0.0"

STATUS_LEVELS <- c("Multi-Domain", "Unmapped", "Code-Only", "Mapped", "Unknown")

STATUS_COLORS <- c(
  "Mapped"        = "#28a745",
  "Unmapped"      = "#e6a817",
  "Code-Only"     = "#dc3545",
  "Multi-Domain"  = "#17a2b8",
  "Unknown"       = "#6c757d"
)

STATUS_ICONS <- c(
  "Mapped"        = "check-circle",
  "Unmapped"      = "exclamation-triangle",
  "Code-Only"     = "times-circle",
  "Multi-Domain"  = "project-diagram",
  "Unknown"       = "question-circle"
)

# Raw dataset file extensions to detect (deliberately excludes .sas to avoid
# picking up program files from the raw folder)
RAW_EXTENSIONS <- "\\.(sas7bdat|csv|xlsx|xpt|xls|txt|dat)$"

# =============================================================================
# build_lib_pattern()
# Build a regex that matches <libname>.<datasetname> for one or more library
# names.  E.g. c("raw","rawdata","edc") produces:
#   (?i)\b(raw|rawdata|edc)\.([a-zA-Z_][a-zA-Z0-9_]*)
# The dataset name is always capture group 2.
# =============================================================================
build_lib_pattern <- function(lib_names) {
  # Sanitise: trim whitespace, drop empties
  libs <- unique(trimws(lib_names[nzchar(trimws(lib_names))]))
  if (length(libs) == 0) libs <- "raw"
  # SAS libnames are [A-Za-z_][A-Za-z0-9_]* so no special regex chars, but
  # escape dots defensively in case user pastes something unexpected.
  escaped <- str_replace_all(libs, "\\.", "\\\\.")
  paste0("(?i)\\b(", paste(escaped, collapse = "|"),
         ")\\.([a-zA-Z_][a-zA-Z0-9_]*)")
}

# Parse a comma-separated string of library names into a character vector.
parse_lib_names <- function(text) {
  libs <- trimws(unlist(str_split(text, "[,;\\s]+")))
  libs <- libs[nzchar(libs)]
  if (length(libs) == 0) "raw" else libs
}

# =============================================================================
# scan_raw_folder()
# Scan a directory for raw dataset files and return a tidy tibble.
# =============================================================================
scan_raw_folder <- function(folder_path, source_label) {
  EMPTY <- tibble(
    dataset_name = character(), file_name = character(),
    source       = character(), folder    = character()
  )
  if (is.null(folder_path) || !nzchar(trimws(folder_path))) return(EMPTY)
  fp <- trimws(folder_path)
  if (!dir.exists(fp)) return(EMPTY)

  files <- list.files(fp, pattern = RAW_EXTENSIONS,
                      ignore.case = TRUE, recursive = FALSE)
  if (length(files) == 0) return(EMPTY)

  tibble(
    dataset_name = tolower(file_path_sans_ext(files)),
    file_name    = files,
    source       = source_label,
    folder       = normalizePath(fp, mustWork = FALSE)
  )
}

# =============================================================================
# scan_programs_for_raw()
# Parse .sas and .log files; extract all <libname>.<dataset> references.
# lib_names: character vector of library names to search for, e.g.
#            c("raw", "rawdata", "edc") — case-insensitive.
# =============================================================================
scan_programs_for_raw <- function(programs_folder, lib_names = "raw",
                                   recursive = TRUE) {
  if (is.null(programs_folder) || !nzchar(trimws(programs_folder))) return(tibble())
  pf <- trimws(programs_folder)
  if (!dir.exists(pf)) return(tibble())

  files <- list.files(pf, pattern = "\\.(sas|log)$",
                      ignore.case = TRUE, recursive = recursive,
                      full.names = TRUE)
  if (length(files) == 0) return(tibble())

  lib_pattern <- build_lib_pattern(lib_names)

  results <- lapply(files, function(fp) {
    lines <- tryCatch(
      readLines(fp, warn = FALSE, encoding = "latin1"),
      error = function(e) character(0)
    )
    if (length(lines) == 0) return(NULL)

    stem         <- file_path_sans_ext(basename(fp))
    ext          <- tolower(file_ext(basename(fp)))
    file_type    <- if (ext == "log") "Log" else "Program"
    domain_guess <- toupper(str_extract(stem, "^[A-Za-z]+"))

    match_idx <- which(str_detect(lines, regex(lib_pattern, ignore_case = TRUE)))
    if (length(match_idx) == 0) return(NULL)

    rows <- lapply(match_idx, function(ln) {
      line_text <- lines[ln]
      # Each match is the full "libname.datasetname" token
      full_refs <- str_extract_all(line_text, regex(lib_pattern, ignore_case = TRUE))[[1]]
      # Library used (before the dot)
      lib_used  <- tolower(sub("\\..*$", "", full_refs))
      # Dataset name (after the dot)
      ds_names  <- tolower(sub("^[^.]+\\.", "", full_refs))

      ctx_start <- max(1, ln - 2)
      ctx_end   <- min(length(lines), ln + 2)
      context_lines <- lines[ctx_start:ctx_end]
      context_nums  <- ctx_start:ctx_end

      # Build context string with line numbers; mark the hit line with >>>
      context <- paste(
        ifelse(
          context_nums == ln,
          sprintf(">>> %5d | %s", context_nums, context_lines),
          sprintf("    %5d | %s", context_nums, context_lines)
        ),
        collapse = "\n"
      )

      tibble(
        program      = basename(fp),
        program_path = normalizePath(fp, mustWork = FALSE),
        file_type    = file_type,
        domain_guess = domain_guess,
        line_number  = as.integer(ln),
        lib_used     = lib_used,    # which library name was matched
        raw_dataset  = ds_names,    # one row per reference on this line
        code_snippet = trimws(line_text),
        context      = context
      )
    })
    bind_rows(rows)
  })

  bind_rows(results)
}

# =============================================================================
# build_mapping()
# Combine folder scan results and program scan results into a unified table.
# Status logic:
#   Mapped       — in folder AND referenced in exactly 1 domain's code
#   Multi-Domain — in folder AND referenced in 2+ different domains
#   Unmapped     — in folder but NOT found in any code
#   Code-Only    — found in code but NOT in any scanned folder
#   Unknown      — neither (shouldn't occur in practice)
# =============================================================================
build_mapping <- function(raw_df, refs_df) {
  from_folders <- if (!is.null(raw_df)  && nrow(raw_df)  > 0) raw_df$dataset_name          else character(0)
  from_code    <- if (!is.null(refs_df) && nrow(refs_df) > 0) unique(refs_df$raw_dataset)  else character(0)
  all_ds       <- unique(c(from_folders, from_code))
  if (length(all_ds) == 0) return(tibble())

  # Per-dataset folder summary
  folder_summary <- if (length(from_folders) > 0) {
    raw_df |>
      group_by(dataset_name) |>
      summarise(
        source    = paste(sort(unique(source)),    collapse = " / "),
        file_name = paste(sort(unique(file_name)), collapse = "; "),
        .groups   = "drop"
      )
  } else {
    tibble(dataset_name = character(), source = character(), file_name = character())
  }

  # Per-dataset code reference summary
  code_summary <- if (length(from_code) > 0) {
    refs_df |>
      group_by(raw_dataset) |>
      summarise(
        sdtm_domains = paste(sort(unique(domain_guess)), collapse = ", "),
        programs     = paste(sort(unique(program)),      collapse = ", "),
        lib_aliases  = paste(sort(unique(lib_used)),     collapse = ", "),
        ref_count    = n(),
        .groups      = "drop"
      )
  } else {
    tibble(raw_dataset = character(), sdtm_domains = character(),
           programs = character(), lib_aliases = character(),
           ref_count = integer())
  }

  tibble(dataset_name = all_ds) |>
    left_join(folder_summary, by = "dataset_name") |>
    left_join(code_summary,   by = c("dataset_name" = "raw_dataset")) |>
    mutate(
      in_folder    = dataset_name %in% from_folders,
      in_code      = dataset_name %in% from_code,
      source       = if_else(is.na(source),       "—", source),
      file_name    = if_else(is.na(file_name),    "—", file_name),
      sdtm_domains = if_else(is.na(sdtm_domains), "—", sdtm_domains),
      programs     = if_else(is.na(programs),     "—", programs),
      lib_aliases  = if_else(is.na(lib_aliases),  "—", lib_aliases),
      ref_count    = if_else(is.na(ref_count),    0L,  as.integer(ref_count)),
      n_domains    = if_else(sdtm_domains == "—", 0L,
                             as.integer(str_count(sdtm_domains, ",") + 1L)),
      status = case_when(
        in_folder & in_code & n_domains > 1 ~ "Multi-Domain",
        in_folder & in_code                  ~ "Mapped",
        in_folder & !in_code                 ~ "Unmapped",
        !in_folder & in_code                 ~ "Code-Only",
        TRUE                                  ~ "Unknown"
      )
    ) |>
    arrange(match(status, STATUS_LEVELS), dataset_name)
}

# =============================================================================
# status_badge() — Bootstrap 3 badge HTML for a status string
# =============================================================================
status_badge <- function(status) {
  cls <- switch(status,
    "Mapped"        = "badge-success",
    "Unmapped"      = "badge-warning",
    "Code-Only"     = "badge-danger",
    "Multi-Domain"  = "badge-info",
    "badge-secondary"
  )
  sprintf('<span class="badge %s" style="font-size:0.82em;padding:4px 8px">%s</span>',
          cls, htmltools::htmlEscape(status))
}

# =============================================================================
# ver_badge() — badge for lead verification decision
# =============================================================================
ver_badge <- function(v) {
  if (is.na(v) || v == "—") {
    '<span class="badge badge-secondary" style="font-size:0.82em;padding:4px 8px">Pending</span>'
  } else {
    sprintf('<span class="badge badge-primary" style="font-size:0.82em;padding:4px 8px">%s</span>',
            htmltools::htmlEscape(v))
  }
}
