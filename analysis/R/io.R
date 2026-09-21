# io.R -- find, read and tidy the CSVs that utils.saveRun writes.
#
# The MATLAB side writes one .csv per run, long format, one row per trial,
# into <data>/auction/ and <data>/cont_dc/. Every row carries participant,
# session, run_id and task, so runs concatenate without further bookkeeping.
# See experiment/+utils/saveRun.m for where those key columns come from.
#
# Nothing here reads .mat. The .mat holds the full dataMat struct (anchors,
# attribute ratings, AOI rects, event log, gaze pointers); the CSV holds the
# trial table. Descriptives only need the CSV. Anything needing the struct
# goes through a MATLAB export step -- see analysis/README.md.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(stringr)
  library(purrr)
})

# MATLAB's writetable has emitted logicals as "true"/"false" and as 1/0
# depending on release. Rather than pin a release, accept both -- plus the
# NaN that a not-applicable logical arrives as (e.g. choseMoney on a pricing
# row, which has no choice).
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
CHR_COLS <- c("run_id", "task", "domain", "competition", "endReason", "taskType")

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
#'
#' @param data_dir the Data (or Data_demo) directory
#' @return tibble with task, path
find_run_files <- function(data_dir) {
  spec <- tibble::tibble(
    task = c("auction", "contdc"),
    dir  = file.path(data_dir, c("auction", "cont_dc"))
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
      # Surplus is the point of the BDM: a cleared bid transacts at the market
      # THRESHOLD, not at the participant's own bid, so surplus is value minus
      # what was actually paid -- for houses. For jobs the participant is the
      # seller (asking a wage), so the sign flips.
      surplus = case_when(
        !bidAccepted           ~ NA_real_,
        domain == "houses"     ~ trueValue - pricePaid,
        domain == "jobs"       ~ pricePaid - trueValue,
        TRUE                   ~ NA_real_
      ),
      # Bid expressed relative to the item's true value, so jobs (wages,
      # ~$25/hr) and houses (~$400k) are on one comparable scale.
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

#' Reconstruct the preference-reversal score from the CSV.
#'
#' The MATLAB side already computes this into dataMat.<domain>.reversals at
#' save time (continuous_DC_task.m:scoreReversals). Recomputing it here from
#' the CSV is deliberate: it is the check that the CSV alone is sufficient
#' for the headline measure, and it will disagree loudly if the two ever
#' drift apart.
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

#' Data-integrity report. Printed before any plot.
#'
#' This is the part that answers "are we reading the data correctly" -- it
#' says what is present, what is missing, and which design cells are empty,
#' rather than silently plotting whatever survived.
integrity_report <- function(auction, contdc, data_dir) {
  lines <- c(sprintf("Data root: %s", normalizePath(data_dir, mustWork = FALSE)), "")

  if (is.null(auction)) {
    lines <- c(lines, "AUCTION: no CSVs found.")
  } else {
    real <- auction %>% filter(!practice)
    cells <- real %>% count(domain, competition, .drop = FALSE)
    empty <- cells %>% filter(n == 0)
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
      if (nrow(empty) > 0)
        sprintf("  EMPTY CELLS     : %s",
                paste(sprintf("%s/%s", empty$domain, empty$competition), collapse = ", "))
      else "  design cells    : all populated",
      ""
    )
  }

  if (is.null(contdc)) {
    lines <- c(lines, "CONTDC: no CSVs found.")
  } else {
    cells <- contdc %>% count(domain, attrLevel, taskType, .drop = FALSE)
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
      ""
    )
  }

  paste(lines, collapse = "\n")
}
