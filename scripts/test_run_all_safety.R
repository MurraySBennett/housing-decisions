#!/usr/bin/env Rscript

repo <- normalizePath(file.path(dirname(commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))][1]), ".."), mustWork = FALSE)
if (grepl("^--file=", repo)) {
  repo <- normalizePath(file.path(dirname(sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))][1])), ".."))
}

tmp <- tempfile("run-all-safety-")
data_dir <- file.path(tmp, "participant-data")
out_dir <- file.path(tmp, "out")
dir.create(data_dir, recursive = TRUE)
dir.create(file.path(data_dir, "auction"), recursive = TRUE)
marker <- file.path(data_dir, "auction", "sub-09999_real_marker.csv")
writeLines("participant,session\n9999,2", marker)

cmd <- file.path(repo, "analysis", "R", "run_all.R")
res <- system2("Rscript", c(cmd, "--simulate", "--data", data_dir, "--out", out_dir),
               stdout = TRUE, stderr = TRUE)
status <- attr(res, "status")
if (is.null(status)) status <- 0L

if (status == 0L) {
  cat(paste(res, collapse = "\n"), "\n")
  stop("run_all.R allowed --simulate to use an arbitrary --data directory")
}

if (!file.exists(marker)) {
  cat(paste(res, collapse = "\n"), "\n")
  stop("run_all.R deleted participant-looking data")
}

cat("run_all safety guard preserved arbitrary data directory\n")

res_data_only <- system2("Rscript", c(cmd, "--data", data_dir, "--out", out_dir),
                         stdout = TRUE, stderr = TRUE)
status_data_only <- attr(res_data_only, "status")
if (is.null(status_data_only)) status_data_only <- 0L

if (status_data_only == 0L) {
  cat(paste(res_data_only, collapse = "\n"), "\n")
  stop("run_all.R unexpectedly succeeded on an invalid data fixture")
}

if (any(grepl("--simulate may only write", res_data_only, fixed = TRUE))) {
  cat(paste(res_data_only, collapse = "\n"), "\n")
  stop("run_all.R treated --data without --simulate as simulate mode")
}

if (!file.exists(marker)) {
  cat(paste(res_data_only, collapse = "\n"), "\n")
  stop("run_all.R deleted data during --data-only analysis")
}

cat("run_all --data without --simulate stays in participant mode\n")
