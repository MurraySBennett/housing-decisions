# Shared project-root helpers for source() and Rscript entrypoints.

script_path <- function(default_rel) {
  args <- commandArgs(trailingOnly = FALSE)
  file_args <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_args)) return(normalizePath(file_args[[1]], mustWork = FALSE))

  ofiles <- Filter(Negate(is.null), lapply(sys.frames(), `[[`, "ofile"))
  if (length(ofiles)) return(normalizePath(tail(unlist(ofiles), 1), mustWork = FALSE))

  normalizePath(default_rel, mustWork = FALSE)
}

project_root <- function(default_rel) {
  if (requireNamespace("here", quietly = TRUE)) {
    try(here::i_am(default_rel), silent = TRUE)
    rooted <- try(here::here(), silent = TRUE)
    if (!inherits(rooted, "try-error") &&
        file.exists(file.path(rooted, default_rel))) {
      return(normalizePath(rooted, mustWork = FALSE))
    }
  }

  path <- script_path(default_rel)
  normalizePath(file.path(dirname(path), "..", ".."), mustWork = FALSE)
}

repo_file <- function(..., root = getOption("housing.decisions.root")) {
  if (is.null(root) || !nzchar(root)) {
    stop("Project root has not been initialised. Source analysis/R/paths.R first.")
  }
  file.path(root, ...)
}
