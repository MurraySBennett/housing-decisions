# simulate_demo_data.R -- fabricate CSVs in the exact schema utils.saveRun writes.
#
# NOT DATA: output goes under Data_simulated, participant IDs in the 90000s.
# Usage: Rscript analysis/R/simulate_demo_data.R [outdir] [n_participants]

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

simulate_battery <- function(outdir, n_participants = 6, seed = 20260915) {
  set.seed(seed)

  dir.create(file.path(outdir, "auction"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(outdir, "cont_dc"), recursive = TRUE, showWarnings = FALSE)

  # Matches utils.config: nTrials = 24, attrLevels = [2 4 6], nPairs = 20 per domain.
  n_trials  <- 24
  levels_   <- c(2, 4, 6)
  n_pairs   <- c(jobs = 20, houses = 20)

  for (p in seq_len(n_participants)) {
    pid <- 90000L + p
    dom <- if (p %% 2 == 1) "jobs" else "houses"
    sess <- 1L
      # Anchor: reservation wage ($/hr) for jobs, budget for houses.
      anchor <- if (dom == "jobs") round(rnorm(1, 25, 4), 2) else
                  round(rnorm(1, 400000, 90000), -3)
      stamp <- format(as.POSIXct("2026-09-15 09:00:00", tz = "UTC") + p * 3600,
                      "%Y%m%d_%H%M%S")

      # ---- auction ----------------------------------------------------
      run_id <- sprintf("sub-%05d_ses-%02d_task-auction_dom-%s_%s", pid, sess, dom, stamp)
      comp <- sample(rep(c("low", "high"), length.out = n_trials))
      # One saved practice episode precedes the real trials.
      comp <- c(comp[1], comp)
      practice <- c(TRUE, rep(FALSE, n_trials))
      trial_no <- c(0L, seq_len(n_trials))

      true_value <- if (dom == "jobs") pmax(8, rnorm(length(comp), anchor, anchor * 0.22))
                    else pmax(80000, rnorm(length(comp), anchor, anchor * 0.25))

      # Bid drifts toward the anchor -- the effect the design is built to detect.
      bid <- 0.72 * true_value + 0.28 * anchor
      bid <- bid * rnorm(length(comp), 1, 0.09)

      mult <- ifelse(comp == "high", 1.10, 0.90)
      threshold <- true_value * mult * rnorm(length(comp), 1, 0.12)
      # Houses: a buyer must bid ABOVE threshold. Jobs: a seeker must ask BELOW it.
      accepted <- if (dom == "houses") bid >= threshold else bid <= threshold
      bid_made <- runif(length(comp)) > ifelse(comp == "high", 0.22, 0.10)
      accepted <- accepted & bid_made

      end_reason <- ifelse(accepted, "accepted",
                    ifelse(runif(length(comp)) < 0.6, "timeout", "exhausted"))

      auction <- tibble::tibble(
        participant = pid,
        session     = sess,
        run_id      = run_id,
        task        = "auction",
        domain      = dom,
        trial       = trial_no,
        practice    = practice,
        competition = comp,
        nAttrs      = 6L,
        nPresented  = sample(6:12, length(comp), replace = TRUE),
        nRejected   = NA_integer_,
        durationSec = round(pmin(90, rgamma(length(comp), 4,
                                            scale = ifelse(comp == "high", 4.5, 6))), 2),
        bidAccepted = accepted,
        bid         = ifelse(bid_made, round(bid, 2), NA_real_),
        bidRT       = ifelse(bid_made, round(rgamma(length(comp), 3, scale = 1.4), 2), NA_real_),
        threshold   = round(threshold, 2),
        pricePaid   = ifelse(accepted, round(threshold, 2), NA_real_),
        trueValue   = round(true_value, 2),
        bidStimIdx  = ifelse(bid_made, sample(1:60, length(comp), replace = TRUE), NA_integer_),
        endReason   = end_reason,
        anchor      = anchor
      ) %>%
        mutate(nRejected = pmin(nPresented,
                                rbinom(dplyr::n(), nPresented,
                                       ifelse(competition == "high", 0.55, 0.40))))

      write_csv(auction, file.path(outdir, "auction", paste0(run_id, ".csv")), na = "NaN")

      # ---- contdc -----------------------------------------------------
      run_id <- sprintf("sub-%05d_ses-%02d_task-contdc_dom-%s_%s", pid, sess, dom, stamp)
      np <- n_pairs[[dom]]
      rows <- list()
      block <- 0L

      for (lv in sample(levels_)) {           # level order randomised per participant
        contrast <- round(runif(np, 0.15, 0.85), 3)
        money_val <- anchor * runif(np, 0.8, 1.2)

        # One latent preference per pair, read by both blocks; independent draws would put reversals at chance.
        latent <- 4.0 * (contrast - 0.5) + rnorm(np, 0, 0.6)

        # choice block
        block <- block + 1L
        p_money <- plogis(2.5 * latent + 0.15 * (lv - 4))
        chose_money <- runif(np) < p_money
        timed_out_c <- runif(np) < 0.03
        rows[[length(rows) + 1]] <- tibble::tibble(
          block = block, attrLevel = lv, taskType = "choice",
          pairIdx = seq_len(np),
          chosenIdx = ifelse(timed_out_c, NA_integer_, ifelse(chose_money, 1L, 2L)),
          choseMoney = ifelse(timed_out_c, NA, chose_money),
          itemIdx = NA_integer_, isMoneyOption = NA,
          postedValue = NA_real_, price = NA_real_,
          contrast = contrast,
          rt = round(rgamma(np, 3, scale = 0.35 + 0.12 * lv), 3),
          timedOut = timed_out_c
        )

        # pricing block -- same pairs, both options priced separately
        block <- block + 1L
        base <- money_val
        money_price    <- base * (1 + 0.10 * latent) * rnorm(np, 1, 0.05)
        quality_price  <- base * (1 - 0.10 * latent) * rnorm(np, 1, 0.05)
        timed_out_p <- runif(2 * np) < 0.02
        rows[[length(rows) + 1]] <- tibble::tibble(
          block = block, attrLevel = lv, taskType = "price",
          pairIdx = rep(seq_len(np), each = 2),
          chosenIdx = NA_integer_, choseMoney = NA,
          itemIdx = sample(1:80, 2 * np, replace = TRUE),
          isMoneyOption = rep(c(TRUE, FALSE), times = np),
          postedValue = round(rep(base, each = 2) * rnorm(2 * np, 1, 0.05), 2),
          price = round(ifelse(timed_out_p, NA_real_,
                               as.vector(rbind(money_price, quality_price))), 2),
          contrast = rep(contrast, each = 2),
          rt = round(rgamma(2 * np, 3, scale = 0.5 + 0.15 * lv), 3),
          timedOut = timed_out_p
        )
      }

      contdc <- bind_rows(rows) %>%
        mutate(participant = pid, session = sess, run_id = run_id,
               task = "contdc", domain = dom, .before = 1)
    write_csv(contdc, file.path(outdir, "cont_dc", paste0(run_id, ".csv")), na = "NaN")
  }

  invisible(outdir)
}

# Run only when executed directly, never when sourced by run_all.R.
.invoked_directly <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  length(f) == 1 && basename(f) == "simulate_demo_data.R"
})
if (.invoked_directly) {
  args <- commandArgs(trailingOnly = TRUE)
  outdir <- if (length(args) >= 1) args[[1]] else "analysis/Data_simulated"
  n <- if (length(args) >= 2) as.integer(args[[2]]) else 6L
  simulate_battery(outdir, n)
  cat(sprintf("Simulated %d participants into %s\n", n, outdir))
}
