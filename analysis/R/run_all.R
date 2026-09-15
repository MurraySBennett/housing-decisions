#!/usr/bin/env Rscript
# run_all.R -- read every run CSV under a data root, print an integrity
# report, and write the descriptive figures.
#
#   Rscript analysis/R/run_all.R                                  # demo sandbox
#   Rscript analysis/R/run_all.R --data experiment/Data_demo
#   Rscript analysis/R/run_all.R --data /path/to/share/Data --out analysis/output
#   Rscript analysis/R/run_all.R --simulate                       # no MATLAB needed
#
# --simulate fabricates data first (analysis/R/simulate_demo_data.R) so the
# whole pipeline can be shown working before participant 1 exists. Figures
# produced that way are stamped as simulated in their file names.

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

here <- function(...) {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  root <- if (length(f)) normalizePath(file.path(dirname(f), "..", "..")) else getwd()
  file.path(root, ...)
}

source(here("analysis", "R", "io.R"))
source(here("analysis", "R", "plots.R"))

# ---- arguments ------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1]]
}
simulate <- "--simulate" %in% args
data_dir <- get_arg("--data", if (simulate) here("analysis", "Data_simulated")
                              else here("experiment", "Data_demo"))
out_dir  <- get_arg("--out", here("analysis", "output"))
tag      <- if (simulate) "SIMULATED_" else ""

if (simulate) {
  source(here("analysis", "R", "simulate_demo_data.R"))
  unlink(data_dir, recursive = TRUE)
  simulate_battery(data_dir, n_participants = 6)
  cat("Simulated data written to ", data_dir, "\n", sep = "")
}

fig_dir <- file.path(out_dir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

if (!dir.exists(data_dir)) {
  stop("Data directory not found: ", data_dir,
       "\nRun the demo first (experiment/demo_battery.m), or pass --simulate.")
}

# ---- load -----------------------------------------------------------------
auction <- load_auction(data_dir)
contdc  <- load_contdc(data_dir)

if (is.null(auction) && is.null(contdc)) {
  stop("No run CSVs found under ", data_dir,
       "\nExpected <data>/auction/*.csv and <data>/cont_dc/*.csv.")
}

# ---- integrity report -----------------------------------------------------
report <- integrity_report(auction, contdc, data_dir)
cat("\n", strrep("=", 72), "\n", sep = "")
if (simulate) cat("SIMULATED DATA -- not participant data. See simulate_demo_data.R.\n\n")
cat(report, "\n")
cat(strrep("=", 72), "\n\n", sep = "")
writeLines(report, file.path(out_dir, paste0(tag, "integrity_report.txt")))

# ---- tidy exports ---------------------------------------------------------
# One combined CSV per task, so the next person can start from a single file
# rather than re-deriving the concatenation.
if (!is.null(auction))
  readr::write_csv(auction, file.path(out_dir, paste0(tag, "auction_trials.csv")))
if (!is.null(contdc))
  readr::write_csv(contdc, file.path(out_dir, paste0(tag, "contdc_trials.csv")))

rev <- score_reversals(contdc)
if (!is.null(rev))
  readr::write_csv(rev, file.path(out_dir, paste0(tag, "reversals.csv")))

# ---- figures --------------------------------------------------------------
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
