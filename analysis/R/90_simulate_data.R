#!/usr/bin/env Rscript
# Explicit simulation entrypoint. This is separate from participant QC.

script_path <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) f[[1]] else file.path("analysis", "R", "90_simulate_data.R")
})

root <- normalizePath(file.path(dirname(script_path), "..", ".."), mustWork = FALSE)
source(file.path(root, "analysis", "R", "simulate_demo_data.R"))
source(file.path(root, "analysis", "R", "run_all.R"))

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1]]
}

data_dir <- get_arg("--out-data", file.path(root, "analysis", "Data_simulated"))
out_dir <- get_arg("--out", file.path(root, "analysis", "output", "simulated"))
n <- as.integer(get_arg("--n", "6"))

canonical <- normalizePath(file.path(root, "analysis", "Data_simulated"), mustWork = FALSE)
requested <- normalizePath(data_dir, mustWork = FALSE)
if (!identical(canonical, requested)) {
  stop("Refusing to simulate outside the canonical sandbox: ", canonical,
       "\nRequested: ", requested)
}

unlink(data_dir, recursive = TRUE)
simulate_battery(data_dir, n_participants = n)
cat("Simulated data written to ", data_dir, "\n", sep = "")
run_analysis("participant", data_dir, out_dir, include_practice = TRUE)
