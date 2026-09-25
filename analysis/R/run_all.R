#!/usr/bin/env Rscript
# run_all.R -- shared helpers for reading run CSVs, reporting integrity, and plotting.
# Source this file in RStudio, or run:
# Rscript analysis/R/00_participant_qc.R [--data <dir>] [--out <dir>] [--include-practice]
# Rscript analysis/R/90_simulate_data.R [--out-data <dir>]

# ---- RStudio/source settings ---------------------------------------------
# Edit these, then click Source. Command-line flags override them.
RUN_MODE <- "participant"       # "demo" | "participant" | "practice"
DATA_DIR <- ""                  # Optional explicit data root
OUTPUT_DIR <- ""                # Optional output directory
INCLUDE_PRACTICE <- FALSE       # TRUE only when analyzing practice/staff runs

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

here <- function(...) {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (!length(f)) {
    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), `[[`, "ofile"))
    f <- if (length(ofiles)) tail(unlist(ofiles), 1) else character()
  }
  root <- if (length(f)) normalizePath(file.path(dirname(f), "..", "..")) else getwd()
  file.path(root, ...)
}

source(here("analysis", "R", "io.R"))
source(here("analysis", "R", "plots.R"))

default_data_dir <- function(mode) {
  switch(mode,
    demo = here("experiment", "Data_demo"),
    participant = here("data", "lab", "Data"),
    practice = here("data", "lab", "Data_practice"),
    stop('Unknown RUN_MODE "', mode, '". Use demo, participant, or practice.')
  )
}

cli_options <- function(default_mode = RUN_MODE) {
  args <- commandArgs(trailingOnly = TRUE)
  get_arg <- function(flag, default = NULL) {
    i <- match(flag, args)
    if (is.na(i) || i == length(args)) default else args[[i + 1]]
  }
  if ("--simulate" %in% args) {
    stop("Simulation has its own script now: Rscript analysis/R/90_simulate_data.R")
  }
  mode <- default_mode
  list(
    mode = mode,
    data_dir = get_arg("--data", if (nzchar(DATA_DIR)) DATA_DIR else default_data_dir(mode)),
    out_dir = get_arg("--out", if (nzchar(OUTPUT_DIR)) OUTPUT_DIR else here("analysis", "output")),
    include_practice = INCLUDE_PRACTICE || "--include-practice" %in% args
  )
}

run_analysis <- function(mode = RUN_MODE, data_dir = NULL, out_dir = NULL,
                         include_practice = INCLUDE_PRACTICE) {
  mode <- tolower(mode)
  if (is.null(data_dir) || !nzchar(data_dir)) data_dir <- default_data_dir(mode)
  if (is.null(out_dir) || !nzchar(out_dir)) out_dir <- here("analysis", "output")
  include_practice <- include_practice || mode == "practice"
  tag <- if (grepl("Data_simulated$", normalizePath(data_dir, mustWork = FALSE))) "SIMULATED_" else ""

  fig_dir <- file.path(out_dir, "figures")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

  if (!dir.exists(data_dir)) {
    stop("Data directory not found: ", data_dir,
         "\nRun the demo, set DATA_DIR, or set RUN_MODE <- \"simulate\".")
  }

  auction <- load_auction(data_dir)
  contdc  <- load_contdc(data_dir)
  pref    <- load_pref(data_dir)
  timing  <- load_timing(data_dir)

  drop_practice <- function(df) {
    if (include_practice || is.null(df) || !("run_kind" %in% names(df))) return(df)
    df %>% filter(is.na(run_kind) | run_kind != "practice")
  }
  auction <- drop_practice(auction)
  contdc <- drop_practice(contdc)
  pref <- drop_practice(pref)

  if (is.null(auction) && is.null(contdc) && is.null(pref)) {
    stop("No run CSVs found under ", data_dir,
         "\nExpected <data>/auction/*.csv, <data>/cont_dc/*.csv, or <data>/pref/*.csv.")
  }

  report <- integrity_report(auction, contdc, pref, timing, data_dir, !nzchar(tag))
  cat("\n", strrep("=", 72), "\n", sep = "")
  if (nzchar(tag)) cat("SIMULATED DATA -- not participant data. See 90_simulate_data.R.\n\n")
  cat(report, "\n")
  cat(strrep("=", 72), "\n\n", sep = "")
  writeLines(report, file.path(out_dir, paste0(tag, "integrity_report.txt")))

  if (!is.null(auction))
    readr::write_csv(auction, file.path(out_dir, paste0(tag, "auction_trials.csv")))
  if (!is.null(contdc))
    readr::write_csv(contdc, file.path(out_dir, paste0(tag, "contdc_trials.csv")))
  if (!is.null(pref))
    readr::write_csv(pref, file.path(out_dir, paste0(tag, "pref_trials.csv")))
  if (!is.null(timing))
    readr::write_csv(timing, file.path(out_dir, paste0(tag, "timing.csv")))

  rev <- score_reversals(contdc)
  if (!is.null(rev))
    readr::write_csv(rev, file.path(out_dir, paste0(tag, "reversals.csv")))

  save_fig <- function(p, name, w = 9, h = 5.5) {
    if (is.null(p)) {
      cat(sprintf("  skipped  %-34s (no data for it)\n", name))
      return(invisible(NULL))
    }
    path <- file.path(fig_dir, paste0(tag, name, ".png"))
    ggsave(path, p, width = w, height = h, dpi = 160, bg = "white")
    cat(sprintf("  wrote    %s\n", basename(path)))
  }

  cat("Figures:\n")
  coverage <- plot_design_coverage(auction, contdc)
  save_fig(coverage$auction, "00_coverage_auction", 8, 4.2)
  save_fig(coverage$contdc,  "01_coverage_contdc",  8, 4.2)

  if (!is.null(auction)) {
    save_fig(plot_bid_vs_value(auction),   "10_auction_bid_vs_value")
    save_fig(plot_auction_outcomes(auction), "11_auction_outcomes")
    save_fig(plot_search_effort(auction),  "12_auction_search_effort", 8, 7)
    save_fig(plot_surplus(auction),        "13_auction_surplus")
  }

  if (!is.null(contdc)) {
    save_fig(plot_contdc_rt(contdc),        "20_contdc_rt")
    save_fig(plot_choice_share(contdc),     "21_contdc_choice_share")
    save_fig(plot_price_by_option(contdc),  "22_contdc_price_by_option")
    save_fig(plot_reversals(rev),           "23_contdc_reversals")
  }

  cat("\nOutput: ", normalizePath(out_dir), "\n", sep = "")
  invisible(list(auction = auction, contdc = contdc, pref = pref, timing = timing,
                 reversals = rev, report = report))
}

run_from_rstudio_source <- function() {
  !length(commandArgs(trailingOnly = TRUE))
}

invoked_directly <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  length(f) == 1 && basename(f) == "run_all.R"
}

if (invoked_directly()) {
  opt <- cli_options("participant")
  run_analysis(opt$mode, opt$data_dir, opt$out_dir, opt$include_practice)
}
