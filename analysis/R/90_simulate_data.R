#!/usr/bin/env Rscript
# Explicit simulation entrypoint. This is separate from participant QC.

bootstrap <- local({
  args <- commandArgs(trailingOnly = FALSE)
  file_args <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_args)) normalizePath(file_args[[1]], mustWork = FALSE)
  else {
    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), `[[`, "ofile"))
    if (length(ofiles)) normalizePath(tail(unlist(ofiles), 1), mustWork = FALSE)
    else normalizePath(file.path("analysis", "R", "90_simulate_data.R"), mustWork = FALSE)
  }
})

source(file.path(dirname(bootstrap), "paths.R"))
root <- project_root("analysis/R/90_simulate_data.R")
options(housing.decisions.root = root)
source(repo_file("analysis", "R", "simulate_demo_data.R"))
source(repo_file("analysis", "R", "run_all.R"))

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
