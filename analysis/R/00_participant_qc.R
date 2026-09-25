#!/usr/bin/env Rscript
# Participant-data QC entrypoint. No simulation code runs from this script.

script_path <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) f[[1]] else file.path("analysis", "R", "00_participant_qc.R")
})

source(file.path(dirname(script_path), "run_all.R"))
opt <- cli_options("participant")
run_analysis(opt$mode, opt$data_dir, opt$out_dir, opt$include_practice)
