#!/usr/bin/env Rscript
# Participant-data QC entrypoint. No simulation code runs from this script.

# ---- RStudio/source settings ---------------------------------------------
# Edit these, then click Source. Command-line flags override them.
RUN_MODE <- "participant"       # "demo" | "participant" | "practice"
DATA_DIR <- ""                  # Optional explicit data root
OUTPUT_DIR <- ""                # Optional output directory
INCLUDE_PRACTICE <- FALSE       # TRUE only when analyzing practice/staff runs

bootstrap <- local({
  args <- commandArgs(trailingOnly = FALSE)
  file_args <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_args)) normalizePath(file_args[[1]], mustWork = FALSE)
  else {
    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), `[[`, "ofile"))
    if (length(ofiles)) normalizePath(tail(unlist(ofiles), 1), mustWork = FALSE)
    else normalizePath(file.path("analysis", "R", "00_participant_qc.R"), mustWork = FALSE)
  }
})

source(file.path(dirname(bootstrap), "paths.R"))
root <- project_root("analysis/R/00_participant_qc.R")
options(housing.decisions.root = root)
source(repo_file("analysis", "R", "run_all.R"))
opt <- cli_options("participant")
run_analysis(opt$mode, opt$data_dir, opt$out_dir, opt$include_practice)
