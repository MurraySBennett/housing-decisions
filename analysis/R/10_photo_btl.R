#!/usr/bin/env Rscript
# Bradley-Terry-Luce estimates for house-photo pairwise preference trials.

# ---- RStudio/source settings ---------------------------------------------
# Edit these, then click Source. Command-line flags override them.
DATA_DIR <- ""                  # Directory containing pref_trials.csv, or a run-data root
OUTPUT_DIR <- ""                # Output directory

bootstrap <- local({
  args <- commandArgs(trailingOnly = FALSE)
  file_args <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_args)) normalizePath(file_args[[1]], mustWork = FALSE)
  else {
    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), `[[`, "ofile"))
    if (length(ofiles)) normalizePath(tail(unlist(ofiles), 1), mustWork = FALSE)
    else normalizePath(file.path("analysis", "R", "10_photo_btl.R"), mustWork = FALSE)
  }
})

source(file.path(dirname(bootstrap), "paths.R"))
root <- project_root("analysis/R/10_photo_btl.R")
options(housing.decisions.root = root)
source(repo_file("analysis", "R", "io.R"))
source(repo_file("analysis", "R", "plots.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(tidyr)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1]]
}

default_data_dir <- function() {
  candidate <- repo_file("analysis", "output")
  if (file.exists(file.path(candidate, "pref_trials.csv"))) return(candidate)
  repo_file("data")
}

read_pref_trials <- function(data_dir) {
  pref_csv <- file.path(data_dir, "pref_trials.csv")
  if (file.exists(pref_csv)) {
    return(read_run_csv(pref_csv))
  }

  pref <- load_pref(data_dir)
  if (is.null(pref)) {
    stop("No preference data found. Expected ", pref_csv,
         " or <data>/pref/*.csv.")
  }
  pref
}

z_score <- function(x) {
  s <- stats::sd(x, na.rm = TRUE)
  if (is.na(s) || s == 0) return(rep(0, length(x)))
  (x - mean(x, na.rm = TRUE)) / s
}

range01 <- function(x) {
  lo <- min(x, na.rm = TRUE)
  hi <- max(x, na.rm = TRUE)
  if (!is.finite(lo) || !is.finite(hi) || hi == lo) return(rep(0.5, length(x)))
  (x - lo) / (hi - lo)
}

photo_components <- function(df) {
  photos <- sort(unique(c(df$leftPhotoId, df$rightPhotoId)))
  photos <- photos[!is.na(photos) & nzchar(photos)]
  seen <- setNames(rep(FALSE, length(photos)), photos)
  component <- setNames(rep(NA_integer_, length(photos)), photos)
  component_id <- 0L

  for (photo in photos) {
    if (seen[[photo]]) next
    component_id <- component_id + 1L
    queue <- photo
    seen[[photo]] <- TRUE
    component[[photo]] <- component_id

    while (length(queue)) {
      current <- queue[[1]]
      queue <- queue[-1]
      rows <- df$leftPhotoId == current | df$rightPhotoId == current
      neighbors <- unique(c(df$leftPhotoId[rows], df$rightPhotoId[rows]))
      neighbors <- neighbors[!is.na(neighbors) & nzchar(neighbors)]
      for (neighbor in neighbors) {
        if (!seen[[neighbor]]) {
          seen[[neighbor]] <- TRUE
          component[[neighbor]] <- component_id
          queue <- c(queue, neighbor)
        }
      }
    }
  }

  tibble(photoId = names(component),
         component_id = unname(component))
}

fit_btl_group <- function(df) {
  photos <- sort(unique(c(df$leftPhotoId, df$rightPhotoId)))
  photos <- photos[!is.na(photos) & nzchar(photos)]
  if (length(photos) < 2) return(tibble())

  ref_photo <- photos[[length(photos)]]
  kept <- photos[photos != ref_photo]
  x <- matrix(0, nrow = nrow(df), ncol = length(kept))
  colnames(x) <- make.names(kept, unique = TRUE)
  for (j in seq_along(kept)) {
    x[, j] <- as.integer(df$leftPhotoId == kept[[j]]) -
      as.integer(df$rightPhotoId == kept[[j]])
  }

  model_df <- as.data.frame(x, check.names = FALSE)
  model_df$left_chosen <- as.integer(df$chosenPhotoId == df$leftPhotoId)
  fit <- suppressWarnings(glm(left_chosen ~ . - 1, data = model_df,
                              family = stats::binomial()))

  worth <- stats::coef(fit)
  worth[is.na(worth)] <- 0
  out <- tibble(photoId = kept, k_btl = unname(worth))
  bind_rows(out, tibble(photoId = ref_photo, k_btl = 0)) %>%
    mutate(k_btl = k_btl - mean(k_btl, na.rm = TRUE),
           k_btl_z = z_score(k_btl))
}

fit_photo_btl <- function(pref) {
  pwc <- pref %>%
    filter(section == "pwc",
           !is.na(leftPhotoId), !is.na(rightPhotoId),
           !is.na(chosenPhotoId),
           nzchar(leftPhotoId), nzchar(rightPhotoId),
           chosenPhotoId %in% c(leftPhotoId, rightPhotoId)) %>%
    mutate(areaVar = dplyr::coalesce(leftAreaVar, rightAreaVar, areaVar, "all"))

  if (!nrow(pwc)) stop("No BTL-ready pairwise photo rows found in preference data.")

  keys <- c("participant", "session", "run_id", "domain", "areaVar")

  counts <- bind_rows(
    pwc %>% transmute(across(all_of(keys)), photoId = leftPhotoId, exposure = 1L,
                      win = as.integer(chosenPhotoId == leftPhotoId),
                      loss = as.integer(chosenPhotoId != leftPhotoId)),
    pwc %>% transmute(across(all_of(keys)), photoId = rightPhotoId, exposure = 1L,
                      win = as.integer(chosenPhotoId == rightPhotoId),
                      loss = as.integer(chosenPhotoId != rightPhotoId))
  ) %>%
    group_by(across(all_of(c(keys, "photoId")))) %>%
    summarise(exposures = sum(exposure), wins = sum(win), losses = sum(loss),
              .groups = "drop")

  btl <- pwc %>%
    group_by(across(all_of(keys))) %>%
    group_modify(~ fit_btl_group(.x)) %>%
    ungroup()

  ratings <- pref %>%
    filter(section == "rating", !is.na(photoId), nzchar(photoId), !is.na(rating)) %>%
    mutate(areaVar = dplyr::coalesce(areaVar, "all")) %>%
    group_by(across(all_of(c(keys, "photoId")))) %>%
    summarise(rating = mean(rating, na.rm = TRUE),
              rating_n = dplyr::n(), .groups = "drop") %>%
    group_by(across(all_of(keys))) %>%
    mutate(rating_z = z_score(rating)) %>%
    ungroup()

  estimates <- btl %>%
    left_join(counts, by = c(keys, "photoId")) %>%
    left_join(ratings, by = c(keys, "photoId")) %>%
    mutate(across(c(exposures, wins, losses, rating_n), ~ tidyr::replace_na(.x, 0L))) %>%
    arrange(participant, session, run_id, domain, areaVar, desc(k_btl), photoId)

  summary <- estimates %>%
    group_by(across(all_of(keys))) %>%
    summarise(
      n_photos = dplyr::n(),
      n_pwc = sum(exposures, na.rm = TRUE) / 2,
      n_rated = sum(rating_n > 0, na.rm = TRUE),
      cor_btl_rating = if (sum(!is.na(rating)) >= 3)
        stats::cor(k_btl, rating, use = "complete.obs", method = "spearman")
      else NA_real_,
      mean_abs_rank_diff = if (sum(!is.na(rating)) >= 2) {
        btl_rank <- dplyr::min_rank(dplyr::desc(k_btl))
        rating_rank <- dplyr::min_rank(dplyr::desc(rating))
        mean(abs(btl_rank - rating_rank), na.rm = TRUE)
      } else NA_real_,
      .groups = "drop"
    ) %>%
    arrange(participant, session, run_id, domain, areaVar)

  list(estimates = estimates, summary = summary)
}

rating_norms <- function(pref) {
  pref %>%
    filter(section == "rating", !is.na(photoId), nzchar(photoId), !is.na(rating)) %>%
    mutate(areaVar = dplyr::coalesce(areaVar, "all")) %>%
    group_by(participant, session, run_id, domain, areaVar) %>%
    mutate(rating_within_rater_area_z = z_score(rating)) %>%
    ungroup() %>%
    group_by(domain, areaVar, photoId) %>%
    summarise(
      rating_mean = mean(rating, na.rm = TRUE),
      rating_median = stats::median(rating, na.rm = TRUE),
      rating_sd = stats::sd(rating, na.rm = TRUE),
      rating_n = dplyr::n(),
      n_participants_rating = dplyr::n_distinct(participant),
      rating_within_rater_area_z = mean(rating_within_rater_area_z, na.rm = TRUE),
      rating_within_rater_area_z_sd = stats::sd(rating_within_rater_area_z, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    group_by(domain, areaVar) %>%
    mutate(rating_norm_rank = dplyr::min_rank(dplyr::desc(rating_within_rater_area_z))) %>%
    ungroup() %>%
    arrange(domain, areaVar, rating_norm_rank, photoId)
}

fit_pooled_area_btl <- function(pref) {
  pwc <- pref %>%
    filter(section == "pwc",
           !is.na(leftPhotoId), !is.na(rightPhotoId),
           !is.na(chosenPhotoId),
           nzchar(leftPhotoId), nzchar(rightPhotoId),
           chosenPhotoId %in% c(leftPhotoId, rightPhotoId)) %>%
    mutate(areaVar = dplyr::coalesce(leftAreaVar, rightAreaVar, areaVar, "all"))

  keys <- c("domain", "areaVar")

  components <- pwc %>%
    group_by(across(all_of(keys))) %>%
    group_modify(~ photo_components(.x)) %>%
    ungroup()

  pwc <- pwc %>%
    left_join(components, by = c(keys, "leftPhotoId" = "photoId")) %>%
    rename(left_component_id = component_id) %>%
    left_join(components, by = c(keys, "rightPhotoId" = "photoId")) %>%
    rename(right_component_id = component_id) %>%
    filter(left_component_id == right_component_id) %>%
    mutate(component_id = left_component_id) %>%
    select(-left_component_id, -right_component_id)

  fit_keys <- c(keys, "component_id")

  counts <- bind_rows(
    pwc %>% transmute(across(all_of(fit_keys)), photoId = leftPhotoId, exposure = 1L,
                      win = as.integer(chosenPhotoId == leftPhotoId),
                      loss = as.integer(chosenPhotoId != leftPhotoId),
                      participant = participant),
    pwc %>% transmute(across(all_of(fit_keys)), photoId = rightPhotoId, exposure = 1L,
                      win = as.integer(chosenPhotoId == rightPhotoId),
                      loss = as.integer(chosenPhotoId != rightPhotoId),
                      participant = participant)
  ) %>%
    group_by(across(all_of(c(fit_keys, "photoId")))) %>%
    summarise(exposures = sum(exposure), wins = sum(win), losses = sum(loss),
              n_participants_pwc = dplyr::n_distinct(participant),
              .groups = "drop")

  btl <- pwc %>%
    group_by(across(all_of(fit_keys))) %>%
    group_modify(~ fit_btl_group(.x)) %>%
    ungroup()

  norm_ratings <- rating_norms(pref)

  ratings <- norm_ratings %>%
    left_join(components, by = c(keys, "photoId")) %>%
    group_by(across(all_of(c(fit_keys, "photoId")))) %>%
    summarise(rating = mean(rating_mean, na.rm = TRUE),
              rating_n = sum(rating_n, na.rm = TRUE),
              n_participants_rating = sum(n_participants_rating, na.rm = TRUE),
              rating_within_rater_area_z = mean(rating_within_rater_area_z, na.rm = TRUE),
              .groups = "drop") %>%
    group_by(across(all_of(fit_keys))) %>%
    mutate(rating_z = z_score(rating)) %>%
    ungroup()

  estimates <- btl %>%
    left_join(counts, by = c(fit_keys, "photoId")) %>%
    left_join(ratings, by = c(fit_keys, "photoId")) %>%
    mutate(across(c(exposures, wins, losses, n_participants_pwc,
                    rating_n, n_participants_rating),
                  ~ tidyr::replace_na(.x, 0L))) %>%
    group_by(across(all_of(fit_keys))) %>%
    mutate(k_btl_01 = range01(k_btl),
           rating_display_01 = range01(rating_within_rater_area_z)) %>%
    ungroup() %>%
    arrange(domain, areaVar, component_id, desc(k_btl), photoId)

  component_counts <- components %>%
    count(across(all_of(keys)), name = "n_graph_photos") %>%
    left_join(components %>% count(across(all_of(keys)), component_id,
                                   name = "n_component_photos"),
              by = keys)

  participant_counts <- pwc %>%
    group_by(across(all_of(fit_keys))) %>%
    summarise(n_participants_pwc = dplyr::n_distinct(participant),
              .groups = "drop")

  rating_participant_counts <- pref %>%
    filter(section == "rating", !is.na(photoId), nzchar(photoId), !is.na(rating)) %>%
    mutate(areaVar = dplyr::coalesce(areaVar, "all")) %>%
    left_join(components, by = c(keys, "photoId")) %>%
    group_by(across(all_of(fit_keys))) %>%
    summarise(n_participants_rating = dplyr::n_distinct(participant),
              .groups = "drop")

  summary <- estimates %>%
    group_by(across(all_of(fit_keys))) %>%
    summarise(
      n_photos = dplyr::n(),
      n_pwc = sum(exposures, na.rm = TRUE) / 2,
      n_rated = sum(rating_n > 0, na.rm = TRUE),
      cor_btl_rating = if (sum(!is.na(rating_within_rater_area_z)) >= 3)
        stats::cor(k_btl, rating_within_rater_area_z,
                   use = "complete.obs", method = "spearman")
      else NA_real_,
      mean_abs_rank_diff = if (sum(!is.na(rating_within_rater_area_z)) >= 2) {
        btl_rank <- dplyr::min_rank(dplyr::desc(k_btl))
        rating_rank <- dplyr::min_rank(dplyr::desc(rating_within_rater_area_z))
        mean(abs(btl_rank - rating_rank), na.rm = TRUE)
      } else NA_real_,
      .groups = "drop"
    ) %>%
    left_join(component_counts, by = fit_keys) %>%
    left_join(participant_counts, by = fit_keys) %>%
    left_join(rating_participant_counts, by = fit_keys) %>%
    arrange(domain, areaVar, component_id)

  list(estimates = estimates, summary = summary)
}

save_photo_figures <- function(pooled, norms, out_dir) {
  fig_dir <- file.path(out_dir, "figures")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

  save_fig <- function(plot, filename, width = 9, height = 6) {
    path <- file.path(fig_dir, filename)
    ggplot2::ggsave(path, plot, width = width, height = height, dpi = 160, bg = "white")
    cat("Wrote ", path, "\n", sep = "")
  }

  joined <- pooled$estimates %>%
    filter(!is.na(rating_within_rater_area_z), !is.na(k_btl_z))

  if (nrow(joined)) {
    p <- ggplot(joined, aes(rating_display_01, k_btl_01)) +
      geom_abline(slope = 1, intercept = 0, linewidth = 0.35,
                  colour = INK_SECONDARY, linetype = "22") +
      geom_point(aes(size = exposures), colour = PAL[1], alpha = 0.78) +
      facet_wrap(~ areaVar) +
      coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
      scale_size_continuous(name = "PWC exposures", range = c(1.8, 4.5)) +
      labs(title = "Pairwise worth tracks explicit photo ratings",
           subtitle = "Each point is one photo; axes are min-max scaled within area/component for display",
           x = "explicit rating norm (0-1 display scale)",
           y = "BTL worth (0-1 display scale)") +
      theme_hw()
    save_fig(p, "30_photo_btl_vs_rating.png", 9, 6)
  }

  ranks <- joined %>%
    group_by(domain, areaVar, component_id) %>%
    mutate(btl_rank = min_rank(desc(k_btl)),
           rating_rank = min_rank(desc(rating_within_rater_area_z))) %>%
    ungroup()

  if (nrow(ranks)) {
    p <- ggplot(ranks, aes(rating_rank, btl_rank)) +
      geom_abline(slope = 1, intercept = 0, linewidth = 0.35,
                  colour = INK_SECONDARY, linetype = "22") +
      geom_point(aes(size = exposures), colour = PAL[2], alpha = 0.78) +
      scale_x_reverse() +
      scale_y_reverse() +
      facet_wrap(~ areaVar, scales = "free") +
      scale_size_continuous(name = "PWC exposures", range = c(1.8, 4.5)) +
      labs(title = "BTL ranks compared with explicit-rating ranks",
           subtitle = "Dashed line marks rank agreement within each area/component",
           x = "explicit-rating rank",
           y = "BTL rank") +
      theme_hw()
    save_fig(p, "31_photo_rank_agreement.png", 9, 6)
  }

  coverage <- pooled$estimates %>%
    group_by(domain, areaVar, exposures) %>%
    summarise(n_photos = n(), .groups = "drop")

  if (nrow(coverage)) {
    p <- ggplot(coverage, aes(exposures, n_photos)) +
      geom_col(fill = PAL[3], width = 0.75) +
      facet_wrap(~ areaVar) +
      scale_x_continuous(breaks = sort(unique(coverage$exposures))) +
      labs(title = "Pairwise coverage per photo",
           subtitle = "Photos with more pairwise exposures have more stable BTL estimates",
           x = "PWC exposures",
           y = "photos") +
      theme_hw()
    save_fig(p, "32_photo_pairwise_coverage.png", 9, 6)
  }

  invisible(NULL)
}

data_dir <- get_arg("--data", if (nzchar(DATA_DIR)) DATA_DIR else default_data_dir())
out_dir <- get_arg("--out", if (nzchar(OUTPUT_DIR)) OUTPUT_DIR else data_dir)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

pref <- read_pref_trials(data_dir)
result <- fit_photo_btl(pref)
norms <- rating_norms(pref)
pooled <- fit_pooled_area_btl(pref)

readr::write_csv(result$estimates, file.path(out_dir, "photo_btl_estimates.csv"))
readr::write_csv(result$summary, file.path(out_dir, "photo_btl_summary.csv"))
readr::write_csv(norms, file.path(out_dir, "photo_rating_norms.csv"))
readr::write_csv(pooled$estimates, file.path(out_dir, "photo_btl_area_estimates.csv"))
readr::write_csv(pooled$summary, file.path(out_dir, "photo_btl_area_summary.csv"))
save_photo_figures(pooled, norms, out_dir)

cat("Wrote ", file.path(out_dir, "photo_btl_estimates.csv"), "\n", sep = "")
cat("Wrote ", file.path(out_dir, "photo_btl_summary.csv"), "\n", sep = "")
cat("Wrote ", file.path(out_dir, "photo_rating_norms.csv"), "\n", sep = "")
cat("Wrote ", file.path(out_dir, "photo_btl_area_estimates.csv"), "\n", sep = "")
cat("Wrote ", file.path(out_dir, "photo_btl_area_summary.csv"), "\n", sep = "")
