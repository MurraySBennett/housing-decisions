# io.R -- find, read and tidy the CSVs that utils.saveRun writes.
#
# One CSV per run, long format, keyed by participant/session/run_id/task.
# Descriptives need only the CSV; the .mat struct needs a MATLAB export step.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(stringr)
  library(purrr)
})

# writetable emits logicals as "true"/"false" or 1/0 depending on release; NaN means not applicable.
as_lgl_flex <- function(x) {
  if (is.logical(x)) return(x)
  if (is.numeric(x)) return(ifelse(is.na(x), NA, x != 0))
  s <- str_trim(tolower(as.character(x)))
  out <- rep(NA, length(s))
  out[s %in% c("true", "t", "1", "yes")]  <- TRUE
  out[s %in% c("false", "f", "0", "no")]  <- FALSE
  out
}

# Columns the tasks write that must be read as text, not guessed.
CHR_COLS <- c("run_id", "task", "run_kind", "domain", "competition", "endReason",
              "taskType", "section", "photoId", "areaVar", "leftAreaVar",
              "rightAreaVar", "responseSide")

read_run_csv <- function(path) {
  df <- suppressWarnings(readr::read_csv(
    path,
    na = c("", "NA", "NaN", "nan", "Inf", "-Inf"),
    show_col_types = FALSE,
    progress = FALSE
  ))
  for (cc in intersect(CHR_COLS, names(df))) df[[cc]] <- as.character(df[[cc]])
  df$source_file <- basename(path)
  df
}

#' Discover every run CSV under a data root.
find_run_files <- function(data_dir) {
  spec <- tibble::tibble(
    task = c("auction", "contdc", "pref"),
    dir  = file.path(data_dir, c("auction", "cont_dc", "pref"))
  )
  spec %>%
    mutate(path = map(dir, ~ list.files(.x, pattern = "\\.csv$", full.names = TRUE))) %>%
    tidyr::unnest(path) %>%
    select(task, path)
}

#' Load and tidy the auction runs.
load_auction <- function(data_dir) {
  files <- find_run_files(data_dir) %>% filter(task == "auction")
  if (nrow(files) == 0) return(NULL)

  bind_rows(lapply(files$path, read_run_csv)) %>%
    mutate(
      competition = factor(competition, levels = c("low", "high")),
      endReason   = factor(endReason, levels = c("accepted", "timeout", "exhausted")),
      practice    = as_lgl_flex(practice),
      bidAccepted = as_lgl_flex(bidAccepted),
      domain      = factor(domain, levels = c("jobs", "houses")),
      # Cleared bids transact at the threshold, not the bid; jobs flip the sign (seller).
      surplus = case_when(
        !bidAccepted           ~ NA_real_,
        domain == "houses"     ~ trueValue - pricePaid,
        domain == "jobs"       ~ pricePaid - trueValue,
        TRUE                   ~ NA_real_
      ),
      # Puts wages (~$25/hr) and houses (~$400k) on one comparable scale.
      bid_ratio = bid / trueValue
    ) %>%
    arrange(participant, session, run_id, trial)
}

#' Load and tidy the continuous / discrete-choice runs.
load_contdc <- function(data_dir) {
  files <- find_run_files(data_dir) %>% filter(task == "contdc")
  if (nrow(files) == 0) return(NULL)

  bind_rows(lapply(files$path, read_run_csv)) %>%
    mutate(
      taskType      = factor(taskType, levels = c("choice", "price")),
      attrLevel     = factor(attrLevel, levels = sort(unique(attrLevel))),
      domain        = factor(domain, levels = c("jobs", "houses")),
      choseMoney    = as_lgl_flex(choseMoney),
      isMoneyOption = as_lgl_flex(isMoneyOption),
      timedOut      = as_lgl_flex(timedOut)
    ) %>%
    arrange(participant, session, run_id, block, pairIdx)
}

#' Load and tidy the preference-task runs.
load_pref <- function(data_dir) {
  files <- find_run_files(data_dir) %>% filter(task == "pref")
  if (nrow(files) == 0) return(NULL)

  bind_rows(lapply(files$path, read_run_csv)) %>%
    mutate(
      section = factor(section, levels = c("rating", "pwc")),
      domain  = factor(domain, levels = c("jobs", "houses"))
    ) %>%
    arrange(participant, session, run_id, section, trial)
}

#' Load per-section timing rows written by run_battery.
load_timing <- function(data_dir) {
  timing_dir <- file.path(data_dir, "sessions")
  if (!dir.exists(timing_dir)) return(NULL)
  files <- list.files(timing_dir, pattern = "_timing\\.csv$", full.names = TRUE)
  if (!length(files)) return(NULL)
  bind_rows(lapply(files, read_run_csv)) %>%
    arrange(participant, session, task, section)
}

#' Reversal score recomputed from the CSV alone; disagrees loudly if it drifts from the MATLAB-side computation.
score_reversals <- function(contdc) {
  if (is.null(contdc) || nrow(contdc) == 0) return(NULL)

  choices <- contdc %>%
    filter(taskType == "choice", !timedOut, !is.na(choseMoney)) %>%
    select(participant, session, run_id, domain, attrLevel, pairIdx, choseMoney)

  prices <- contdc %>%
    filter(taskType == "price", !is.na(price), !is.na(isMoneyOption)) %>%
    select(participant, session, run_id, domain, attrLevel, pairIdx,
           isMoneyOption, price) %>%
    mutate(which_option = ifelse(isMoneyOption, "money_price", "quality_price")) %>%
    select(-isMoneyOption) %>%
    tidyr::pivot_wider(names_from = which_option, values_from = price,
                       values_fn = dplyr::first)

  choices %>%
    inner_join(prices, by = c("participant", "session", "run_id",
                              "domain", "attrLevel", "pairIdx")) %>%
    filter(!is.na(money_price), !is.na(quality_price)) %>%
    mutate(
      pricedMoneyHigher = money_price > quality_price,
      reversal          = choseMoney != pricedMoneyHigher
    )
}

#' Data-integrity report, printed before any plot.
integrity_report <- function(auction, contdc, pref = NULL, timing = NULL,
                             data_dir, include_sidecars = TRUE) {
  lines <- c(sprintf("Data root: %s", normalizePath(data_dir, mustWork = FALSE)), "")

  if (is.null(auction)) {
    lines <- c(lines, "AUCTION: no CSVs found.")
  } else {
    real <- auction %>% filter(!practice)
    cells <- real %>%
      mutate(domain = droplevels(domain), competition = droplevels(competition)) %>%
      count(domain, competition, .drop = FALSE)
    expected <- real %>%
      group_by(run_id, domain) %>%
      summarise(real_trials = dplyr::n(),
                practice_trials = sum(auction$practice[auction$run_id == first(run_id)], na.rm = TRUE),
                .groups = "drop") %>%
      mutate(status = ifelse(real_trials == 24, "OK", "CHECK"))
    lines <- c(lines,
      "AUCTION",
      sprintf("  runs            : %d", dplyr::n_distinct(auction$run_id)),
      sprintf("  participants    : %d", dplyr::n_distinct(auction$participant)),
      sprintf("  trials          : %d real, %d practice",
              nrow(real), sum(auction$practice, na.rm = TRUE)),
      sprintf("  domains         : %s",
              paste(levels(droplevels(auction$domain)), collapse = ", ")),
      sprintf("  end reasons     : %s",
              paste(sprintf("%s=%d", names(table(real$endReason)),
                            as.integer(table(real$endReason))), collapse = "  ")),
      sprintf("  bids placed     : %d of %d trials (%.0f%%)",
              sum(!is.na(real$bid)), nrow(real),
              100 * mean(!is.na(real$bid))),
      sprintf("  missing bid RTs : %d", sum(is.na(real$bidRT) & !is.na(real$bid))),
      sprintf("  current expected: 24 real trials per domain/run"),
      sprintf("  observed runs   : %s",
              paste(sprintf("%s/%s real=%d practice=%d %s",
                            expected$run_id, expected$domain, expected$real_trials,
                            expected$practice_trials, expected$status),
                    collapse = "; ")),
      "  competition cells:",
      paste(sprintf("    %s/%s = %d", cells$domain, cells$competition, cells$n),
            collapse = "\n"),
      ""
    )
  }

  if (is.null(contdc)) {
    lines <- c(lines, "CONTDC: no CSVs found.")
  } else {
    cells <- contdc %>%
      mutate(domain = droplevels(domain), attrLevel = droplevels(attrLevel),
             taskType = droplevels(taskType)) %>%
      count(domain, attrLevel, taskType, .drop = FALSE)
    empty <- cells %>% filter(n == 0)
    balance <- cells %>%
      tidyr::pivot_wider(names_from = taskType, values_from = n, values_fill = 0) %>%
      rename(choice_rows = choice, price_rows = price) %>%
      mutate(balanced = price_rows == 2 * choice_rows)
    imbalanced <- balance %>% filter(!balanced)
    rev <- score_reversals(contdc)
    lines <- c(lines,
      "CONTDC",
      sprintf("  runs            : %d", dplyr::n_distinct(contdc$run_id)),
      sprintf("  participants    : %d", dplyr::n_distinct(contdc$participant)),
      sprintf("  rows            : %d choice, %d price",
              sum(contdc$taskType == "choice"), sum(contdc$taskType == "price")),
      sprintf("  attribute levels: %s",
              paste(levels(droplevels(contdc$attrLevel)), collapse = ", ")),
      sprintf("  timed out       : %d (%.1f%%)",
              sum(contdc$timedOut, na.rm = TRUE),
              100 * mean(contdc$timedOut, na.rm = TRUE)),
      sprintf("  reversal-scorable pairs: %d", if (is.null(rev)) 0L else nrow(rev)),
      if (!is.null(rev) && nrow(rev) > 0)
        sprintf("  reversal rate   : %.1f%%", 100 * mean(rev$reversal))
      else "  reversal rate   : not computable (need choice AND both prices per pair)",
      if (nrow(empty) > 0)
        sprintf("  EMPTY CELLS     : %s",
                paste(sprintf("%s/L%s/%s", empty$domain, empty$attrLevel,
                              empty$taskType), collapse = ", "))
      else "  design cells    : all populated",
      if (nrow(imbalanced) > 0)
        sprintf("  CELL IMBALANCE  : %s",
                paste(sprintf("%s/L%s choice=%d price=%d",
                              imbalanced$domain, imbalanced$attrLevel,
                              imbalanced$choice_rows, imbalanced$price_rows),
                      collapse = ", "))
      else "  cell balance    : price rows are exactly 2x choice rows",
      sprintf("  current expected: per domain, L2/L4/L6 each has 20 choice + 40 price rows"),
      ""
    )
  }

  if (is.null(pref)) {
    lines <- c(lines, "PREF: no CSVs found.")
  } else {
    sec <- pref %>%
      mutate(domain = droplevels(domain), section = droplevels(section)) %>%
      count(run_id, domain, section, name = "rows")
    rating <- pref %>% filter(section == "rating")
    pwc <- pref %>% filter(section == "pwc")
    area_counts <- if (nrow(rating) > 0) {
      rating %>% count(run_id, areaVar, name = "n") %>%
        mutate(label = sprintf("%s=%d", areaVar, n)) %>%
        group_by(run_id) %>%
        summarise(area_summary = paste(label, collapse = " "), .groups = "drop")
    } else NULL
    cross_area <- if (nrow(pwc) > 0 && all(c("leftAreaVar", "rightAreaVar") %in% names(pwc))) {
      sum(!is.na(pwc$leftAreaVar) & !is.na(pwc$rightAreaVar) &
            pwc$leftAreaVar != pwc$rightAreaVar)
    } else NA_integer_
    reused_outside_rating <- if (nrow(rating) > 0 && nrow(pwc) > 0 &&
                                all(c("leftPhotoId", "rightPhotoId") %in% names(pwc))) {
      rated <- unique(rating$photoId)
      sum(!(pwc$leftPhotoId %in% rated) | !(pwc$rightPhotoId %in% rated), na.rm = TRUE)
    } else NA_integer_
    lines <- c(lines,
      "PREF",
      sprintf("  runs            : %d", dplyr::n_distinct(pref$run_id)),
      sprintf("  participants    : %d", dplyr::n_distinct(pref$participant)),
      sprintf("  rows by section : %s",
              paste(sprintf("%s/%s/%s=%d", sec$run_id, sec$domain,
                            sec$section, sec$rows), collapse = "; ")),
      if (!is.null(area_counts))
        sprintf("  rating areas    : %s",
                paste(sprintf("%s: %s", area_counts$run_id,
                              area_counts$area_summary), collapse = "; "))
      else "  rating areas    : not present",
      if (!is.na(cross_area))
        sprintf("  cross-area pairs: %d", cross_area)
      else "  cross-area pairs: not applicable",
      if (!is.na(reused_outside_rating))
        sprintf("  pair photos not in rated set: %d", reused_outside_rating)
      else "  pair photos not in rated set: not applicable",
      "  current expected: houses rating=60 (10/area), houses pwc=160, jobs pwc=160",
      ""
    )
  }

  if (is.null(timing)) {
    lines <- c(lines, "TIMING: no session timing CSVs found.")
  } else {
    totals <- timing %>%
      group_by(participant, session, task, domains) %>%
      summarise(seconds = sum(seconds, na.rm = TRUE), .groups = "drop") %>%
      mutate(label = sprintf("sub-%05d ses-%02d %s/%s %.1f min",
                             participant, session, task, domains, seconds / 60))
    lines <- c(lines,
      "TIMING",
      sprintf("  files/rows      : %d rows", nrow(timing)),
      sprintf("  task totals     : %s", paste(totals$label, collapse = "; ")),
      ""
    )
  }

  if (include_sidecars) {
    lines <- c(lines, sidecar_report(data_dir, auction, contdc, pref), "")
  }

  paste(lines, collapse = "\n")
}

sidecar_report <- function(data_dir, auction, contdc, pref) {
  csvs <- find_run_files(data_dir)
  if (nrow(csvs) == 0) return("SIDECARS: no run CSVs found.")
  missing_mat <- csvs$path[!file.exists(sub("\\.csv$", ".mat", csvs$path))]
  all_runs <- bind_rows(
    if (!is.null(auction)) auction %>% distinct(run_id, domain) else NULL,
    if (!is.null(contdc)) contdc %>% distinct(run_id, domain) else NULL,
    if (!is.null(pref)) pref %>% distinct(run_id, domain) else NULL
  )
  gaze_dir <- file.path(data_dir, "gaze")
  missing_gaze <- character()
  if (nrow(all_runs) > 0) {
    expected <- file.path(gaze_dir, sprintf("%s_%s_gaze.mat", all_runs$run_id, all_runs$domain))
    missing_gaze <- expected[!file.exists(expected)]
  }
  c(
    "SIDECARS",
    sprintf("  run CSVs        : %d", nrow(csvs)),
    sprintf("  missing .mat    : %d%s", length(missing_mat),
            if (length(missing_mat)) paste0(" (", paste(basename(missing_mat), collapse = ", "), ")") else ""),
    sprintf("  missing gaze    : %d%s", length(missing_gaze),
            if (length(missing_gaze)) paste0(" (", paste(basename(missing_gaze), collapse = ", "), ")") else "")
  )
}
