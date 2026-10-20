# checks.R -- named study-integrity checks with explicit pass criteria.
#
# This is QC, not analysis. Every check answers "is the study running as
# designed", every criterion comes from a constant in design.R that mirrors a
# MATLAB source line, and nothing here fits a model or reports a p-value.
#
# Severity is a property of the check, fixed at definition:
#   FAIL  the study is running wrong -- stop and fix before the next participant
#   CHECK a human should look at this
#   INFO  descriptive, never fails
#
# Status is the outcome: PASS / FAIL / CHECK / SKIP / INFO. SKIP matters as much
# as PASS -- an absent pref run, or a gaze check with no export to read, must not
# read as a pass. Every SKIP prints why it skipped.

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(tidyr)
  library(stringr)
  library(purrr)
})

# ---- the check builder -----------------------------------------------------

#' One check result.
#'
#' @param pass TRUE, FALSE, or NA. NA means "could not be evaluated" and
#'   becomes SKIP -- pass `detail` saying what was missing.
#' @param severity "FAIL", "CHECK" or "INFO". Drives what a FALSE becomes.
check <- function(id, section, severity, pass, detail, n = NA_integer_) {
  stopifnot(severity %in% c("FAIL", "CHECK", "INFO"))
  status <- if (severity == "INFO") {
    "INFO"
  } else if (length(pass) != 1 || is.na(pass)) {
    "SKIP"
  } else if (isTRUE(pass)) {
    "PASS"
  } else {
    severity
  }
  tibble(id = id, section = section, severity = severity,
         status = status, detail = detail, n = as.integer(n))
}

# A check that needs a table which is absent.
skipped <- function(id, section, severity, why) {
  check(id, section, severity, NA, paste0("skipped: ", why))
}

has_cols <- function(df, ...) {
  !is.null(df) && nrow(df) > 0 && all(c(...) %in% names(df))
}

# Offender lists keep `detail` short; an RA does not need 40 run ids.
name_offenders <- function(x, max_n = 4) {
  x <- unique(as.character(x))
  if (!length(x)) return("")
  if (length(x) <= max_n) return(paste(x, collapse = ", "))
  paste0(paste(utils::head(x, max_n), collapse = ", "),
         sprintf(" (+%d more)", length(x) - max_n))
}

pct <- function(x) sprintf("%.1f%%", 100 * x)

#' Participant/run key frame over whatever tables are present.
run_keys <- function(...) {
  dfs <- Filter(function(d) !is.null(d) && nrow(d) > 0, list(...))
  if (!length(dfs)) return(NULL)
  bind_rows(lapply(dfs, function(d) {
    d %>% distinct(participant, session, run_id, task, domain)
  })) %>%
    distinct() %>%
    arrange(participant, session, task)
}

# ---- 1. structural / completeness ------------------------------------------

checks_structural <- function(auction, contdc, pref, timing, spec = design_spec()) {
  out <- list()
  keys <- run_keys(auction, contdc, pref)

  # S01 -- one run of each task per participant.
  out$S01 <- if (is.null(keys)) {
    skipped("S01", "structural", "FAIL", "no run CSVs at all")
  } else {
    got <- keys %>%
      group_by(participant) %>%
      summarise(tasks = paste(sort(unique(task)), collapse = ","), .groups = "drop")
    want <- paste(sort(spec$tasks), collapse = ",")
    bad <- got %>% filter(tasks != want)
    check("S01", "structural", "FAIL", nrow(bad) == 0,
          if (nrow(bad) == 0) sprintf("all %d participants have %s",
                                      nrow(got), want)
          else sprintf("expected %s; participants missing a run: %s", want,
                       name_offenders(sprintf("%s[%s]", bad$participant, bad$tasks))),
          nrow(got))
  }

  # S02 -- between-subjects collection is session 1 only.
  out$S02 <- if (is.null(keys)) {
    skipped("S02", "structural", "FAIL", "no run CSVs")
  } else {
    bad <- keys %>% filter(session != spec$session_num)
    check("S02", "structural", "FAIL", nrow(bad) == 0,
          if (nrow(bad) == 0) sprintf("every run is session %d", spec$session_num)
          else sprintf("runs outside session %d: %s", spec$session_num,
                       name_offenders(bad$run_id)),
          nrow(keys))
  }

  # S03 -- one assigned domain per participant.
  out$S03 <- if (is.null(keys)) {
    skipped("S03", "structural", "FAIL", "no run CSVs")
  } else {
    multi <- keys %>%
      group_by(participant) %>%
      summarise(nd = n_distinct(domain), doms = paste(sort(unique(as.character(domain))),
                                                      collapse = "+"), .groups = "drop") %>%
      filter(nd > 1)
    check("S03", "structural", "FAIL", nrow(multi) == 0,
          if (nrow(multi) == 0) "every participant has exactly one domain"
          else sprintf("participants with more than one domain: %s",
                       name_offenders(sprintf("%s[%s]", multi$participant, multi$doms))),
          n_distinct(keys$participant))
  }

  # S04 -- 24 real auction trials per run.
  out$S04 <- if (is.null(auction)) {
    skipped("S04", "structural", "FAIL", "no auction CSVs")
  } else {
    got <- auction %>% filter(!practice) %>% count(run_id, name = "trials")
    bad <- got %>% filter(trials != spec$auction_n_trials)
    check("S04", "structural", "FAIL", nrow(bad) == 0,
          sprintf("expected %d real trials/run; %s", spec$auction_n_trials,
                  if (nrow(bad) == 0) sprintf("all %d runs correct", nrow(got))
                  else sprintf("off: %s", name_offenders(
                    sprintf("%s=%d", bad$run_id, bad$trials)))),
          nrow(got))
  }

  # S05 -- exactly one saved practice episode, identified by the practice flag.
  #
  # Deliberately does NOT require block to be NA. auction_task.m:713 writes
  # block = NaN for the practice row, but combine_blocks.m:116 overwrites the
  # whole column with the checkpoint ordinal, and the assert above it exempts
  # NaN rows -- so in a combined export the practice row carries a real block
  # number. Identify practice by `practice` (or trial == 0), never by is.na(block).
  out$S05 <- if (is.null(auction)) {
    skipped("S05", "structural", "CHECK", "no auction CSVs")
  } else {
    got <- auction %>% group_by(run_id) %>%
      summarise(np = sum(practice, na.rm = TRUE),
                trial_ok = all(trial[practice] == 0) || !any(practice),
                .groups = "drop")
    bad <- got %>% filter(np != spec$auction_n_practice | !trial_ok)
    check("S05", "structural", "CHECK", nrow(bad) == 0,
          sprintf("expected %d practice row/run at trial 0; %s",
                  spec$auction_n_practice,
                  if (nrow(bad) == 0) "all runs correct"
                  else sprintf("off: %s", name_offenders(
                    sprintf("%s n=%d", bad$run_id, bad$np)))),
          nrow(got))
  }

  # S06 -- six contdc blocks, each (attrLevel x taskType) cell exactly once.
  out$S06 <- if (!has_cols(contdc, "block", "attrLevel", "taskType")) {
    skipped("S06", "structural", "FAIL", "contdc CSVs lack block/attrLevel/taskType")
  } else {
    got <- contdc %>%
      distinct(run_id, block, attrLevel, taskType) %>%
      group_by(run_id) %>%
      summarise(n_blocks = n_distinct(block),
                n_cells = n_distinct(paste(attrLevel, taskType)),
                .groups = "drop")
    bad <- got %>% filter(n_blocks != spec$contdc_n_blocks |
                            n_cells != spec$contdc_n_blocks)
    check("S06", "structural", "FAIL", nrow(bad) == 0,
          sprintf("expected %d blocks covering %d distinct level x type cells; %s",
                  spec$contdc_n_blocks, spec$contdc_n_blocks,
                  if (nrow(bad) == 0) "all runs correct"
                  else sprintf("off: %s", name_offenders(
                    sprintf("%s blocks=%d cells=%d", bad$run_id,
                            bad$n_blocks, bad$n_cells)))),
          nrow(got))
  }

  # S07 -- 20 choice rows, 40 price rows per block.
  out$S07 <- if (!has_cols(contdc, "block", "taskType", "domain")) {
    skipped("S07", "structural", "FAIL", "contdc CSVs lack block/taskType/domain")
  } else {
    got <- contdc %>%
      count(run_id, domain, block, taskType, name = "rows") %>%
      mutate(want = expected_contdc_rows(as.character(taskType),
                                         as.character(domain), spec))
    bad <- got %>% filter(rows != want)
    check("S07", "structural", "FAIL", nrow(bad) == 0,
          sprintf("expected %d choice / %d price rows per block; %s",
                  spec$contdc_n_pairs[["houses"]], 2L * spec$contdc_n_pairs[["houses"]],
                  if (nrow(bad) == 0) sprintf("all %d blocks correct", nrow(got))
                  else sprintf("off: %s", name_offenders(
                    sprintf("%s b%s/%s got=%d want=%d", bad$run_id, bad$block,
                            bad$taskType, bad$rows, bad$want)))),
          nrow(got))
  }

  # S08 -- pref section counts per domain.
  out$S08 <- if (!has_cols(pref, "section", "domain")) {
    skipped("S08", "structural", "FAIL", "no pref CSVs")
  } else {
    got <- pref %>% count(run_id, domain, section, name = "rows")
    want <- got %>%
      mutate(want = map2_int(as.character(domain), as.character(section),
                             ~ as.integer(expected_pref_rows(.x, spec)[[.y]])))
    bad <- want %>% filter(rows != want)
    check("S08", "structural", "FAIL", nrow(bad) == 0,
          sprintf("houses %d rating + %d pwc, jobs %d pwc; %s",
                  spec$pref_n_rating_houses, spec$pref_n_pwc_houses,
                  spec$pref_n_pwc_jobs,
                  if (nrow(bad) == 0) "all sections correct"
                  else sprintf("off: %s", name_offenders(
                    sprintf("%s/%s got=%d want=%d", bad$run_id, bad$section,
                            bad$rows, bad$want)))),
          nrow(got))
  }

  # S09 -- houses ratings are 10 per photo area across six areas.
  out$S09 <- if (!has_cols(pref, "section", "areaVar")) {
    skipped("S09", "structural", "FAIL", "no pref CSVs with areaVar")
  } else {
    rating <- pref %>% filter(section == "rating", domain == "houses")
    if (nrow(rating) == 0) {
      skipped("S09", "structural", "FAIL", "no houses rating rows (jobs-only sample)")
    } else {
      got <- rating %>% count(run_id, areaVar, name = "rows")
      bad <- got %>% filter(rows != spec$pref_area_quota)
      missing_area <- got %>% group_by(run_id) %>%
        summarise(na = n_distinct(areaVar), .groups = "drop") %>%
        filter(na != length(spec$pref_areas))
      check("S09", "structural", "FAIL",
            nrow(bad) == 0 && nrow(missing_area) == 0,
            sprintf("expected %d ratings in each of %d areas; %s",
                    spec$pref_area_quota, length(spec$pref_areas),
                    if (nrow(bad) == 0 && nrow(missing_area) == 0) "all quotas met"
                    else sprintf("off: %s", name_offenders(c(
                      sprintf("%s/%s=%d", bad$run_id, bad$areaVar, bad$rows),
                      sprintf("%s has %d areas", missing_area$run_id, missing_area$na))))),
            nrow(got))
    }
  }

  # S10 -- no duplicate trial keys.
  dup_detail <- character()
  if (has_cols(auction, "trial")) {
    d <- auction %>% count(run_id, trial, practice, name = "k") %>% filter(k > 1)
    if (nrow(d)) dup_detail <- c(dup_detail,
                                 sprintf("auction %s", name_offenders(d$run_id)))
  }
  if (has_cols(contdc, "block", "pairIdx")) {
    d <- contdc %>% count(run_id, block, pairIdx, taskType, itemIdx, name = "k") %>%
      filter(k > 1)
    if (nrow(d)) dup_detail <- c(dup_detail,
                                 sprintf("contdc %s", name_offenders(d$run_id)))
  }
  if (has_cols(pref, "section", "trial")) {
    d <- pref %>% count(run_id, section, trial, name = "k") %>% filter(k > 1)
    if (nrow(d)) dup_detail <- c(dup_detail,
                                 sprintf("pref %s", name_offenders(d$run_id)))
  }
  out$S10 <- if (is.null(keys)) {
    skipped("S10", "structural", "FAIL", "no run CSVs")
  } else {
    check("S10", "structural", "FAIL", length(dup_detail) == 0,
          if (length(dup_detail) == 0) "no duplicate trial keys in any table"
          else paste("duplicate keys:", paste(dup_detail, collapse = "; ")))
  }

  # S11 -- run_kind is uniform within a run.
  rk <- Filter(function(d) has_cols(d, "run_kind"), list(auction, contdc, pref))
  out$S11 <- if (!length(rk)) {
    skipped("S11", "structural", "CHECK", "no run_kind column (pre-schema CSVs)")
  } else {
    mixed <- bind_rows(lapply(rk, function(d) d %>% distinct(run_id, run_kind))) %>%
      count(run_id, name = "k") %>% filter(k > 1)
    kinds <- bind_rows(lapply(rk, function(d) d %>% distinct(run_kind)))$run_kind
    check("S11", "structural", "CHECK", nrow(mixed) == 0,
          if (nrow(mixed) == 0) sprintf("uniform within every run; kinds present: %s",
                                        name_offenders(kinds))
          else sprintf("mixed run_kind within: %s", name_offenders(mixed$run_id)))
  }

  # S12 -- the auction is fixed at six attributes.
  out$S12 <- if (!has_cols(auction, "nAttrs")) {
    skipped("S12", "structural", "CHECK", "auction CSVs lack nAttrs")
  } else {
    bad <- auction %>% filter(nAttrs != spec$auction_n_attrs)
    check("S12", "structural", "CHECK", nrow(bad) == 0,
          sprintf("expected nAttrs=%d on every row; %s", spec$auction_n_attrs,
                  if (nrow(bad) == 0) "all rows correct"
                  else sprintf("%d rows differ (%s)", nrow(bad),
                               name_offenders(bad$nAttrs))),
          nrow(auction))
  }

  # S13 -- the attribute-load levels are exactly 2/4/6.
  out$S13 <- if (!has_cols(contdc, "attrLevel")) {
    skipped("S13", "structural", "CHECK", "no contdc CSVs")
  } else {
    got <- sort(unique(as.integer(as.character(contdc$attrLevel))))
    check("S13", "structural", "CHECK", identical(got, as.integer(spec$attr_levels)),
          sprintf("expected %s; observed %s",
                  paste(spec$attr_levels, collapse = "/"), paste(got, collapse = "/")))
  }

  # S14 -- a timing row exists for every run.
  out$S14 <- if (is.null(timing) || is.null(keys)) {
    skipped("S14", "structural", "CHECK", "no session timing CSVs found")
  } else {
    seen <- timing %>% distinct(participant, session, task)
    want <- keys %>% distinct(participant, session, task)
    missing <- anti_join(want, seen, by = c("participant", "session", "task"))
    check("S14", "structural", "CHECK", nrow(missing) == 0,
          if (nrow(missing) == 0) sprintf("timing rows cover all %d runs", nrow(want))
          else sprintf("runs with no timing row: %s",
                       name_offenders(sprintf("%s/%s", missing$participant, missing$task))),
          nrow(want))
  }

  bind_rows(out)
}

# ---- 2. order and counterbalancing -----------------------------------------

checks_counterbalance <- function(auction, contdc, pref, timing, spec = design_spec()) {
  out <- list()
  keys <- run_keys(auction, contdc, pref)

  # O01 -- domain follows ID parity.
  out$O01 <- if (is.null(keys)) {
    skipped("O01", "counterbalance", "FAIL", "no run CSVs")
  } else {
    got <- keys %>%
      distinct(participant, domain) %>%
      mutate(want = expected_domain(participant),
             ok = as.character(domain) == want)
    bad <- got %>% filter(!ok)
    check("O01", "counterbalance", "FAIL", nrow(bad) == 0,
          sprintf("odd=jobs, even=houses; %s",
                  if (nrow(bad) == 0) sprintf("all %d participants correct", nrow(got))
                  else sprintf("MISASSIGNED: %s", name_offenders(
                    sprintf("%s got=%s want=%s", bad$participant, bad$domain, bad$want)))),
          nrow(got))
  }

  # O02 -- executed task order matches the counterbalancing slot.
  # Row order in the timing CSV is execution order: run_battery appends after
  # every run (run_battery.m:196-206), so first appearance gives the sequence.
  out$O02 <- if (!has_cols(timing, "task", "file_row")) {
    skipped("O02", "counterbalance", "FAIL",
            "needs session timing CSVs with preserved row order")
  } else {
    got <- timing %>%
      arrange(participant, session, file_row) %>%
      group_by(participant, session) %>%
      summarise(observed = paste(unique(task), collapse = ">"), .groups = "drop") %>%
      mutate(expected = map_chr(participant,
                                ~ paste(expected_task_order(.x, spec$tasks), collapse = ">")),
             ok = observed == expected)
    bad <- got %>% filter(!ok)
    check("O02", "counterbalance", "FAIL", nrow(bad) == 0,
          sprintf("slot mod(ceil(p/2)-1,6)+1; %s",
                  if (nrow(bad) == 0) sprintf("all %d participants in the expected order",
                                              nrow(got))
                  else sprintf("WRONG ORDER: %s", name_offenders(
                    sprintf("%s ran=%s want=%s", bad$participant,
                            bad$observed, bad$expected)))),
          nrow(got))
  }

  # O03 -- the six orders should appear about equally across the sample.
  out$O03 <- if (is.null(keys)) {
    skipped("O03", "counterbalance", "INFO", "no run CSVs")
  } else {
    slots <- keys %>% distinct(participant) %>%
      mutate(slot = expected_task_order_slot(participant)) %>%
      count(slot, name = "k")
    full <- tibble(slot = seq_len(spec$n_task_orders)) %>%
      left_join(slots, by = "slot") %>% mutate(k = coalesce(k, 0L))
    check("O03", "counterbalance", "INFO", TRUE,
          sprintf("task-order slots used: %s",
                  paste(sprintf("%d=%d", full$slot, full$k), collapse = " ")),
          n_distinct(keys$participant))
  }

  # O04 -- the auction competition sequence is ABBA, trial by trial.
  out$O04 <- if (!has_cols(auction, "competition", "trial", "practice")) {
    skipped("O04", "counterbalance", "FAIL", "no auction CSVs")
  } else {
    got <- auction %>%
      filter(!practice) %>%
      arrange(run_id, trial) %>%
      group_by(participant, run_id) %>%
      summarise(observed = paste(as.character(competition), collapse = ""),
                n = n(), .groups = "drop") %>%
      mutate(expected = map2_chr(participant, n, function(p, nn) {
        paste(expected_competition_sequence(p, n_trials = nn,
                                            n_blocks = spec$auction_n_blocks), collapse = "")
      }), ok = observed == expected)
    bad <- got %>% filter(!ok)
    check("O04", "counterbalance", "FAIL", nrow(bad) == 0,
          sprintf("ABBA blocks of %d, not ABAB; %s",
                  spec$auction_n_trials %/% spec$auction_n_blocks,
                  if (nrow(bad) == 0) sprintf("all %d runs match the ABBA walk", nrow(got))
                  else sprintf("SEQUENCE WRONG: %s", name_offenders(bad$run_id))),
          nrow(got))
  }

  # O05 -- which level block 1 uses is set by parity.
  out$O05 <- if (!has_cols(auction, "competition", "trial", "practice")) {
    skipped("O05", "counterbalance", "FAIL", "no auction CSVs")
  } else {
    got <- auction %>%
      filter(!practice) %>%
      group_by(participant, run_id) %>%
      arrange(trial, .by_group = TRUE) %>%
      summarise(started = as.character(first(competition)), .groups = "drop") %>%
      mutate(want = map_chr(participant, ~ expected_start_competition(.x)),
             ok = started == want)
    bad <- got %>% filter(!ok)
    check("O05", "counterbalance", "FAIL", nrow(bad) == 0,
          sprintf("odd starts high, even starts low; %s",
                  if (nrow(bad) == 0) "all runs start on the expected level"
                  else sprintf("WRONG START: %s", name_offenders(
                    sprintf("%s got=%s want=%s", bad$run_id, bad$started, bad$want)))),
          nrow(got))
  }

  # O06 -- twelve trials per competition level.
  out$O06 <- if (!has_cols(auction, "competition", "practice")) {
    skipped("O06", "counterbalance", "FAIL", "no auction CSVs")
  } else {
    per_level <- spec$auction_n_trials %/% length(spec$competition_levels)
    got <- auction %>% filter(!practice) %>%
      count(run_id, competition, .drop = FALSE, name = "k")
    bad <- got %>% filter(k != per_level)
    check("O06", "counterbalance", "FAIL", nrow(bad) == 0,
          sprintf("expected %d trials per level; %s", per_level,
                  if (nrow(bad) == 0) "every run balanced"
                  else sprintf("off: %s", name_offenders(
                    sprintf("%s/%s=%d", bad$run_id, bad$competition, bad$k)))),
          nrow(got))
  }

  # O07 -- ABBA's purpose: both levels at the same mean serial position.
  out$O07 <- if (!has_cols(auction, "competition", "trial", "practice")) {
    skipped("O07", "counterbalance", "CHECK", "no auction CSVs")
  } else {
    got <- auction %>% filter(!practice) %>%
      group_by(run_id, competition) %>%
      summarise(mean_pos = mean(trial), .groups = "drop") %>%
      pivot_wider(names_from = competition, values_from = mean_pos) %>%
      mutate(gap = abs(low - high))
    worst <- suppressWarnings(max(got$gap, na.rm = TRUE))
    # One trial of slack: ABBA is exact, so anything above that is a real defect.
    check("O07", "counterbalance", "CHECK",
          is.finite(worst) && worst <= 1,
          sprintf("largest low-vs-high mean serial position gap: %.2f trials (ABBA makes this 0)",
                  worst),
          nrow(got))
  }

  # O08 -- block and blockPos are well formed.
  out$O08 <- if (!has_cols(auction, "block", "blockPos")) {
    skipped("O08", "counterbalance", "FAIL",
            "auction CSVs lack block/blockPos (pre-schema export)")
  } else {
    per_block <- spec$auction_n_trials %/% spec$auction_n_blocks
    got <- auction %>% filter(!practice) %>%
      group_by(run_id) %>%
      summarise(blocks_ok = identical(sort(unique(block)),
                                      as.numeric(seq_len(spec$auction_n_blocks))),
                pos_ok = all(sort(unique(blockPos)) == seq_len(per_block)),
                .groups = "drop")
    bad <- got %>% filter(!blocks_ok | !pos_ok)
    check("O08", "counterbalance", "FAIL", nrow(bad) == 0,
          sprintf("block 1..%d, blockPos 1..%d; %s",
                  spec$auction_n_blocks, per_block,
                  if (nrow(bad) == 0) "well formed in every run"
                  else sprintf("malformed: %s", name_offenders(bad$run_id))),
          nrow(got))
  }

  # O09 -- contdc task type is blocked: blocks 1-3 one type, 4-6 the other.
  out$O09 <- if (!has_cols(contdc, "block", "taskType")) {
    skipped("O09", "counterbalance", "FAIL", "no contdc CSVs")
  } else {
    got <- contdc %>%
      distinct(run_id, block, taskType) %>%
      arrange(run_id, block) %>%
      group_by(run_id) %>%
      summarise(halves = n_distinct(paste(block > (spec$contdc_n_blocks / 2), taskType)),
                blocked = n_distinct(taskType[block <= spec$contdc_n_blocks / 2]) == 1 &&
                  n_distinct(taskType[block > spec$contdc_n_blocks / 2]) == 1,
                .groups = "drop")
    bad <- got %>% filter(!blocked)
    check("O09", "counterbalance", "FAIL", nrow(bad) == 0,
          sprintf("blocks 1-%d one task type, %d-%d the other; %s",
                  spec$contdc_n_blocks / 2, spec$contdc_n_blocks / 2 + 1,
                  spec$contdc_n_blocks,
                  if (nrow(bad) == 0) "blocked correctly in every run"
                  else sprintf("INTERLEAVED: %s", name_offenders(bad$run_id))),
          nrow(got))
  }

  # O10 -- which task type comes first is set by parity.
  out$O10 <- if (!has_cols(contdc, "block", "taskType")) {
    skipped("O10", "counterbalance", "FAIL", "no contdc CSVs")
  } else {
    got <- contdc %>%
      group_by(participant, run_id) %>%
      arrange(block, .by_group = TRUE) %>%
      summarise(first_type = as.character(first(taskType)), .groups = "drop") %>%
      mutate(want = map_chr(participant, ~ expected_contdc_type_order(.x)[[1]]),
             ok = first_type == want)
    bad <- got %>% filter(!ok)
    check("O10", "counterbalance", "FAIL", nrow(bad) == 0,
          sprintf("even participants start on choice; %s",
                  if (nrow(bad) == 0) "all runs start on the expected type"
                  else sprintf("WRONG: %s", name_offenders(
                    sprintf("%s got=%s want=%s", bad$run_id, bad$first_type, bad$want)))),
          nrow(got))
  }

  # O11 -- each half covers every attribute level exactly once.
  out$O11 <- if (!has_cols(contdc, "block", "attrLevel", "taskType")) {
    skipped("O11", "counterbalance", "CHECK", "no contdc CSVs")
  } else {
    got <- contdc %>%
      distinct(run_id, taskType, attrLevel) %>%
      count(run_id, taskType, name = "n_levels")
    bad <- got %>% filter(n_levels != length(spec$attr_levels))
    check("O11", "counterbalance", "CHECK", nrow(bad) == 0,
          sprintf("each task type covers all %d levels once; %s",
                  length(spec$attr_levels),
                  if (nrow(bad) == 0) "all halves complete"
                  else sprintf("off: %s", name_offenders(
                    sprintf("%s/%s=%d", bad$run_id, bad$taskType, bad$n_levels)))),
          nrow(got))
  }

  # O12 -- level order is randomised, so it should not be identical everywhere.
  out$O12 <- if (!has_cols(contdc, "block", "attrLevel", "taskType")) {
    skipped("O12", "counterbalance", "INFO", "no contdc CSVs")
  } else {
    orders <- contdc %>%
      distinct(run_id, taskType, block, attrLevel) %>%
      arrange(run_id, taskType, block) %>%
      group_by(run_id, taskType) %>%
      summarise(order = paste(attrLevel, collapse = ">"), .groups = "drop")
    tally <- orders %>% count(order, name = "k") %>% arrange(desc(k))
    check("O12", "counterbalance", "INFO", TRUE,
          sprintf("%d distinct level orders over %d halves: %s",
                  nrow(tally), nrow(orders),
                  paste(sprintf("%s=%d", tally$order, tally$k), collapse = " ")),
          nrow(orders))
  }

  # O13 -- pref section order counterbalanced (houses, both sections).
  out$O13 <- if (!has_cols(pref, "section", "trial")) {
    skipped("O13", "counterbalance", "CHECK", "no pref CSVs")
  } else {
    both <- pref %>% group_by(run_id) %>%
      filter(n_distinct(section) > 1) %>%
      arrange(trial, .by_group = TRUE) %>%
      summarise(first_section = as.character(first(section)), .groups = "drop")
    if (nrow(both) == 0) {
      skipped("O13", "counterbalance", "CHECK",
              "no run has both pref sections (jobs is pwc-only)")
    } else {
      tally <- both %>% count(first_section, name = "k")
      share <- max(tally$k) / sum(tally$k)
      # This check is EXPECTED to fire, and the cause is known. SECTION_ORDER is
      # 'counterbalanced' and resolveSections (preference_task.m:266-272) swaps on
      # mod(participant,2)==0 -- but only houses has two sections
      # (preference_task.m:95-104) and houses IS the even half
      # (batteryPlan.m:17). So the {'pwc','rating'} branch is unreachable and
      # every houses participant gets rating first. A real confound, not a data
      # anomaly; see the follow-ons in the plan.
      check("O13", "counterbalance", "CHECK", share <= 0.75 || nrow(both) < 4,
            sprintf("first section across %d runs: %s. KNOWN CONFOUND: the counterbalance branch at preference_task.m:266-272 keys on even-vs-odd, but only houses has two sections and houses is always even -- so rating-first is structural, not sampled.",
                    nrow(both),
                    paste(sprintf("%s=%d", tally$first_section, tally$k), collapse = " ")),
            nrow(both))
    }
  }

  # O14 -- pref pairwise side balance; a strong bias is a strategy or a stuck mouse.
  out$O14 <- if (!has_cols(pref, "responseSide")) {
    skipped("O14", "counterbalance", "CHECK", "pref CSVs lack responseSide")
  } else {
    got <- pref %>%
      filter(!is.na(responseSide), responseSide != "") %>%
      group_by(participant, run_id) %>%
      summarise(p_left = mean(responseSide == "left"), k = n(), .groups = "drop")
    if (nrow(got) == 0) {
      skipped("O14", "counterbalance", "CHECK", "no pairwise responses recorded")
    } else {
      bad <- got %>% filter(pmax(p_left, 1 - p_left) > spec$qc$side_bias_max)
      check("O14", "counterbalance", "CHECK", nrow(bad) == 0,
            sprintf("one side above %s of choices flags a bias; %s",
                    pct(spec$qc$side_bias_max),
                    if (nrow(bad) == 0) sprintf("worst observed %s left",
                                                pct(max(pmax(got$p_left, 1 - got$p_left))))
                    else sprintf("biased: %s", name_offenders(
                      sprintf("%s %s left", bad$run_id, pct(bad$p_left))))),
            nrow(got))
    }
  }

  # O15 -- contdc side balance is NOT computable from the CSV. See the plan.
  out$O15 <- skipped("O15", "counterbalance", "CHECK",
                     paste("moneyOnLeft is never written to the CSV and chosenIdx is a",
                           "stimulus index, not a side -- needs the trial-plan export.",
                           "Do not approximate it from chosenIdx."))

  bind_rows(out)
}

# ---- 3. stimulus usage and identity ----------------------------------------

checks_stimuli <- function(auction, contdc, pref, plan = NULL, stimuli_shown = NULL,
                           spec = design_spec()) {
  out <- list()
  no_plan <- paste("needs the frozen trial-plan export",
                   "(scripts/export_gaze_csv.m -> plan/*_trial_plan.csv);",
                   "the auction CSV records only bidStimIdx and rejectedStimIdx,",
                   "never the full set presented")

  plan_ok <- has_cols(plan, "run_id", "trial", "stimIdx")

  # T01 -- a stimulus must never appear twice within one trial.
  out$T01 <- if (!plan_ok) {
    skipped("T01", "stimuli", "FAIL", no_plan)
  } else {
    dup <- plan %>% count(run_id, trial, stimIdx, name = "k") %>% filter(k > 1)
    check("T01", "stimuli", "FAIL", nrow(dup) == 0,
          if (nrow(dup) == 0) "no within-trial duplicates"
          else sprintf("DUPLICATE within trial: %s", name_offenders(
            sprintf("%s t%s stim%s x%d", dup$run_id, dup$trial, dup$stimIdx, dup$k))),
          nrow(plan))
  }

  # T02 -- twelve options planned per trial.
  out$T02 <- if (!plan_ok) {
    skipped("T02", "stimuli", "FAIL", no_plan)
  } else {
    got <- plan %>% count(run_id, trial, name = "k")
    bad <- got %>% filter(k != spec$auction_n_options)
    check("T02", "stimuli", "FAIL", nrow(bad) == 0,
          sprintf("expected %d options/trial; %s", spec$auction_n_options,
                  if (nrow(bad) == 0) sprintf("all %d trials correct", nrow(got))
                  else sprintf("off: %s", name_offenders(
                    sprintf("%s t%s=%d", bad$run_id, bad$trial, bad$k)))),
          nrow(got))
  }

  # T03 -- exposure counts should be near-uniform: the pool is repmat + shuffle.
  out$T03 <- if (!plan_ok) {
    skipped("T03", "stimuli", "CHECK", no_plan)
  } else {
    got <- plan %>%
      group_by(run_id) %>%
      mutate(n_avail = n_distinct(stimIdx), need = n()) %>%
      count(run_id, stimIdx, n_avail, need, name = "uses") %>%
      group_by(run_id) %>%
      summarise(lo = min(uses), hi = max(uses),
                band_lo = floor(first(need) / first(n_avail)) - spec$qc$exposure_tol,
                band_hi = ceiling(first(need) / first(n_avail)) + spec$qc$exposure_tol,
                .groups = "drop")
    bad <- got %>% filter(lo < band_lo | hi > band_hi)
    check("T03", "stimuli", "CHECK", nrow(bad) == 0,
          sprintf("near-uniform by construction (+/-%d slack); %s", spec$qc$exposure_tol,
                  if (nrow(bad) == 0) sprintf("all %d runs inside the band", nrow(got))
                  else sprintf("skewed: %s", name_offenders(
                    sprintf("%s uses %d-%d want %d-%d", bad$run_id, bad$lo, bad$hi,
                            bad$band_lo, bad$band_hi)))),
          nrow(got))
  }

  # T04 -- repIdx is the running exposure count per stimulus.
  out$T04 <- if (!has_cols(plan, "repIdx")) {
    skipped("T04", "stimuli", "FAIL", no_plan)
  } else {
    recomputed <- plan %>%
      arrange(run_id, trial) %>%
      group_by(run_id, stimIdx) %>%
      mutate(want = row_number()) %>%
      ungroup()
    bad <- recomputed %>% filter(repIdx != want)
    check("T04", "stimuli", "FAIL", nrow(bad) == 0,
          if (nrow(bad) == 0) "repIdx matches a recomputed running count"
          else sprintf("%d rows disagree with the recomputed count (%s)", nrow(bad),
                       name_offenders(bad$run_id)),
          nrow(recomputed))
  }

  # T05 -- the degenerate-pool guard must never have fired.
  out$T05 <- if (!plan_ok) {
    skipped("T05", "stimuli", "CHECK", no_plan)
  } else {
    short <- plan %>% count(run_id, trial, name = "k") %>%
      filter(k < spec$auction_n_options)
    check("T05", "stimuli", "CHECK", nrow(short) == 0,
          if (nrow(short) == 0)
            sprintf("every trial reached %d options without the guard topping up",
                    spec$auction_n_options)
          else sprintf("short trials (guard at trialPlan.m:87-92 fired): %s",
                       name_offenders(sprintf("%s t%s=%d", short$run_id,
                                              short$trial, short$k))),
          nrow(plan))
  }

  # T06 -- won stimuli are retired and never presented again.
  #
  # Deliberately checked against RUNTIME evidence, not the frozen plan. The plan
  # is built before the session (trialPlan.m:62-99) and retirement happens
  # during it (auction_task.m:374-379), so a won stimulus legitimately stays in
  # a later trial's planned set and is simply skipped when that trial runs.
  # Comparing against the plan would therefore flag correct sessions. The only
  # runtime-observed presentations in the CSV are the option bid on and the
  # options rejected, so those are what this uses.
  out$T06 <- if (!has_cols(auction, "bidStimIdx", "bidAccepted", "trial")) {
    skipped("T06", "stimuli", "CHECK", "auction CSVs lack bidStimIdx/bidAccepted")
  } else {
    won <- auction %>% filter(!practice, bidAccepted, !is.na(bidStimIdx)) %>%
      transmute(run_id, won_trial = trial, idx = as.integer(bidStimIdx))
    seen <- auction %>% filter(!practice) %>%
      transmute(run_id, trial,
                idx = map2(as.integer(bidStimIdx), as.character(rejectedStimIdx),
                           function(b, r) {
                             rr <- if (is.na(r) || !nzchar(r)) integer(0)
                                   else as.integer(strsplit(r, ";", fixed = TRUE)[[1]])
                             unique(c(if (is.na(b)) integer(0) else b, rr))
                           })) %>%
      tidyr::unnest(idx)
    if (nrow(won) == 0) {
      skipped("T06", "stimuli", "CHECK", "no cleared bids yet, so nothing retired")
    } else {
      leak <- seen %>%
        inner_join(won, by = c("run_id", "idx"), relationship = "many-to-many") %>%
        filter(trial > won_trial)
      check("T06", "stimuli", "CHECK", nrow(leak) == 0,
            sprintf("%d stimuli won; %s", nrow(won),
                    if (nrow(leak) == 0) "none presented again afterwards"
                    else sprintf("RETIREMENT LEAK: %s", name_offenders(
                      sprintf("%s stim%d won t%s seen t%s", leak$run_id,
                              leak$idx, leak$won_trial, leak$trial)))),
            nrow(won))
    }
  }

  # T07 -- rejectedStimIdx count agrees with nRejected.
  out$T07 <- if (!has_cols(auction, "rejectedStimIdx", "nRejected")) {
    skipped("T07", "stimuli", "CHECK", "auction CSVs lack rejectedStimIdx")
  } else {
    got <- auction %>%
      filter(!practice) %>%
      mutate(parsed = map_int(as.character(rejectedStimIdx), function(s) {
        if (is.na(s) || !nzchar(s)) return(0L)
        length(strsplit(s, ";", fixed = TRUE)[[1]])
      }), ok = parsed == coalesce(as.integer(nRejected), 0L))
    bad <- got %>% filter(!ok)
    check("T07", "stimuli", "CHECK", nrow(bad) == 0,
          if (nrow(bad) == 0) "rejectedStimIdx length matches nRejected on every trial"
          else sprintf("%d trials disagree (%s)", nrow(bad), name_offenders(bad$run_id)),
          nrow(got))
  }

  # T08 -- presented/rejected counts are internally consistent.
  out$T08 <- if (!has_cols(auction, "nPresented", "nRejected")) {
    skipped("T08", "stimuli", "CHECK", "auction CSVs lack nPresented/nRejected")
  } else {
    bad <- auction %>% filter(!practice) %>%
      filter(nRejected > nPresented | nPresented < 0 | nRejected < 0)
    check("T08", "stimuli", "CHECK", nrow(bad) == 0,
          if (nrow(bad) == 0) "nRejected never exceeds nPresented"
          else sprintf("%d impossible trials (%s)", nrow(bad), name_offenders(bad$run_id)),
          sum(!auction$practice, na.rm = TRUE))
  }

  # T09 -- contdc item reuse within a level, against the real maxUse formula.
  # maxUse = max(2, ceil(2*nPairs/n)) (buildPairs.m:70) -- depends on the window
  # size, so it must be computed per run, not hardcoded to 2.
  out$T09 <- if (!has_cols(contdc, "itemIdx", "attrLevel")) {
    skipped("T09", "stimuli", "CHECK", "contdc CSVs lack itemIdx")
  } else {
    got <- contdc %>%
      filter(!is.na(itemIdx)) %>%
      group_by(run_id, domain, attrLevel) %>%
      mutate(n_items = n_distinct(itemIdx)) %>%
      count(run_id, domain, attrLevel, itemIdx, n_items, name = "uses") %>%
      group_by(run_id, domain, attrLevel) %>%
      summarise(worst = max(uses), n_items = first(n_items), .groups = "drop") %>%
      mutate(np = map_int(as.character(domain), ~ as.integer(spec$contdc_n_pairs[[.x]])),
             # Pricing writes two rows per pair, so an item used once appears twice.
             max_use = pmax(2L, ceiling(2 * np / n_items)) * 2L)
    bad <- got %>% filter(worst > max_use)
    check("T09", "stimuli", "CHECK", nrow(bad) == 0,
          sprintf("cap is max(2, ceil(2*nPairs/n)) per buildPairs.m:70; %s",
                  if (nrow(bad) == 0) sprintf("worst use %d, all within cap",
                                              max(got$worst))
                  else sprintf("over cap: %s", name_offenders(
                    sprintf("%s L%s used=%d cap=%d", bad$run_id, bad$attrLevel,
                            bad$worst, bad$max_use)))),
          nrow(got))
  }

  # T10 -- cross-level reuse is expected: allowCrossLevelReuse = TRUE.
  out$T10 <- if (!has_cols(contdc, "itemIdx", "attrLevel")) {
    skipped("T10", "stimuli", "INFO", "contdc CSVs lack itemIdx")
  } else {
    got <- contdc %>% filter(!is.na(itemIdx)) %>%
      distinct(run_id, attrLevel, itemIdx) %>%
      count(run_id, itemIdx, name = "levels") %>%
      group_by(run_id) %>%
      summarise(reused = mean(levels > 1), .groups = "drop")
    check("T10", "stimuli", "INFO", TRUE,
          sprintf("items appearing at more than one attribute level: %s of items (median over runs); expected non-zero, allowCrossLevelReuse=TRUE",
                  pct(median(got$reused))),
          nrow(got))
  }

  # T11 -- pref photoId is the one stable ID, so this pools across participants.
  out$T11 <- if (!has_cols(pref, "photoId")) {
    skipped("T11", "stimuli", "CHECK", "no pref CSVs with photoId")
  } else {
    rated <- pref %>% filter(!is.na(photoId), photoId != "")
    if (nrow(rated) == 0) {
      skipped("T11", "stimuli", "CHECK", "no rating rows with photoId (jobs-only sample)")
    } else {
      tally <- rated %>% count(photoId, name = "uses")
      check("T11", "stimuli", "CHECK", TRUE,
            sprintf("%d distinct photoIds, %d-%d uses each (median %d) across %d participants",
                    nrow(tally), min(tally$uses), max(tally$uses),
                    as.integer(median(tally$uses)), n_distinct(rated$participant)),
            nrow(tally))
    }
  }

  # T12 -- houses pairs are within-area; jobs pairs are cross-industry.
  out$T12 <- if (!has_cols(pref, "leftAreaVar", "rightAreaVar")) {
    skipped("T12", "stimuli", "CHECK", "pref CSVs lack left/rightAreaVar")
  } else {
    houses <- pref %>% filter(domain == "houses", section == "pwc",
                              !is.na(leftAreaVar), !is.na(rightAreaVar),
                              leftAreaVar != "", rightAreaVar != "")
    cross <- houses %>% filter(leftAreaVar != rightAreaVar)
    jobs_cross <- if (has_cols(pref, "leftIndustry", "rightIndustry")) {
      j <- pref %>% filter(domain == "jobs", section == "pwc",
                           !is.na(leftIndustry), !is.na(rightIndustry),
                           leftIndustry != "", rightIndustry != "")
      if (nrow(j)) mean(j$leftIndustry != j$rightIndustry) else NA_real_
    } else NA_real_
    if (nrow(houses) == 0 && is.na(jobs_cross)) {
      skipped("T12", "stimuli", "CHECK", "no pairwise rows with area/industry labels")
    } else {
      # Houses pairs ARE constrained to one photo area. Jobs pairs are NOT
      # stratified by industry: buildJobPreferencePlan.m:20 calls
      # samplePairs(1:128, 160) over the whole table, so with 8 industries x 16
      # titles about 15/127 = 11.8% of pairs land within an industry. The
      # "cross-industry" wording at preference_task.m:11 is the doc being wrong,
      # not the code -- so a non-zero within-industry share is expected here.
      check("T12", "stimuli", "CHECK", nrow(cross) == 0,
            sprintf("houses pairs must be within-area: %d cross-area of %d%s",
                    nrow(cross), nrow(houses),
                    if (is.na(jobs_cross)) ""
                    else sprintf("; jobs cross-industry share %s (expected ~88.2%%, pairs are NOT industry-stratified)",
                                 pct(jobs_cross))),
            nrow(houses))
    }
  }

  # T13 -- displayed attribute values must match the source stimulus table.
  out$T13 <- if (!has_cols(stimuli_shown, "stimIdx")) {
    skipped("T13", "stimuli", "CHECK",
            paste("needs the stimuli_shown export; stimulus indices are",
                  "participant-specific row numbers and cannot be resolved",
                  "from the CSVs alone"))
  } else {
    check("T13", "stimuli", "CHECK", TRUE,
          sprintf("stimuli_shown present for %d runs; value-level comparison runs in 20_stimulus_audit.R",
                  n_distinct(stimuli_shown$run_id)),
          nrow(stimuli_shown))
  }

  # T14 -- the sampled window honours spread and minN around the anchor.
  out$T14 <- if (!has_cols(auction, "trueValue", "anchor")) {
    skipped("T14", "stimuli", "CHECK", "auction CSVs lack trueValue/anchor")
  } else {
    got <- auction %>% filter(!practice, !is.na(trueValue), !is.na(anchor), anchor > 0) %>%
      mutate(ratio = trueValue / anchor) %>%
      group_by(run_id) %>%
      summarise(lo = min(ratio), hi = max(ratio), .groups = "drop")
    # The window is a sampling target, not a hard clamp: fitToWindow maps values
    # onto it by rank, so allow generous slack and flag only gross departures.
    slack <- 1.5
    bad <- got %>% filter(lo < spec$sampling_spread[[1]] / slack |
                            hi > spec$sampling_spread[[2]] * slack)
    check("T14", "stimuli", "CHECK", nrow(bad) == 0,
          sprintf("value/anchor should sit near [%.2f, %.2f]; observed %.2f-%.2f%s",
                  spec$sampling_spread[[1]], spec$sampling_spread[[2]],
                  min(got$lo), max(got$hi),
                  if (nrow(bad) == 0) "" else sprintf(" -- outside: %s",
                                                      name_offenders(bad$run_id))),
          nrow(got))
  }

  # T15 -- pref jobs uses the ecological arm while the other tasks use synthetic.
  out$T15 <- if (!has_cols(pref, "leftTitle")) {
    skipped("T15", "stimuli", "CHECK", "pref CSVs lack job title columns")
  } else {
    titles <- pref %>% filter(domain == "jobs") %>%
      select(any_of(c("leftTitle", "rightTitle"))) %>%
      unlist(use.names = FALSE)
    titles <- unique(titles[!is.na(titles) & titles != ""])
    if (!length(titles)) {
      skipped("T15", "stimuli", "CHECK", "no jobs pairwise rows (houses-only sample)")
    } else {
      # preference_task.m:100 forces the ecological file and
      # buildJobPreferencePlan.m:9-12 hard-errors on `title_` placeholders, so
      # MATLAB already refuses to run this wrong. This is the belt-and-braces
      # check that the guard is still in place in the data that reached disk.
      placeholders <- titles[str_detect(titles, "^title_")]
      check("T15", "stimuli", "CHECK", length(placeholders) == 0,
            sprintf("%d distinct job titles in pref; %s",
                    length(titles),
                    if (length(placeholders) == 0)
                      "none are synthetic placeholders, so the ecological arm was used (enforced at buildJobPreferencePlan.m:9-12)"
                    else sprintf("SYNTHETIC PLACEHOLDERS REACHED A SCREEN: %s",
                                 name_offenders(placeholders))),
            length(titles))
    }
  }

  # T16 -- pooled exposure, reported WITHOUT implying it should be uniform.
  out$T16 <- if (!plan_ok) {
    skipped("T16", "stimuli", "INFO", no_plan)
  } else {
    tally <- plan %>% count(domain, stimIdx, name = "uses")
    check("T16", "stimuli", "INFO", TRUE,
          sprintf("pooled exposure spans %d-%d uses per index. NOT a balance requirement: participants see different stimuli by design (experiment/README.md:56-67). Diagnostic of a degenerate sampling rule only.",
                  min(tally$uses), max(tally$uses)),
          nrow(tally))
  }

  # T17 -- houses stimulus indices are stable across participants; jobs are not.
  #
  # This asymmetry is worth stating because it is easy to get backwards. Both
  # domains run fitToWindow (config.m:152-167), and fitToWindow returns
  # idx = find(~isnan(values)) over the WHOLE table (fitToWindow.m:12-13), which
  # applyWindow then uses as `stimuli(w.idx,:)` (applyWindow.m:19-20). Every
  # listPrice in house_stimuli.csv is present (80/80), so for houses w.idx is
  # 1:80 and a stimulus index is a stable row number into that file -- the same
  # integer means the same house for every participant, and pooled exposure is
  # therefore meaningful without any export.
  #
  # Jobs are different: auction_task.m cuts the table to the participant's top
  # industries (cfg.sampling.nTopIndustries) BEFORE applyWindow, so jobs indices
  # are participant-specific and only resolvable via the stimuli_shown export.
  out$T17 <- {
    obs <- list()
    if (has_cols(auction, "bidStimIdx", "domain")) {
      obs$auction <- auction %>% filter(domain == "houses", !is.na(bidStimIdx)) %>%
        transmute(run_id, idx = as.integer(bidStimIdx))
    }
    if (has_cols(contdc, "itemIdx", "domain")) {
      obs$contdc <- contdc %>% filter(domain == "houses", !is.na(itemIdx)) %>%
        transmute(run_id, idx = as.integer(itemIdx))
    }
    houses_idx <- bind_rows(obs)
    n_houses_rows <- nrow(read_stimulus_defs_n("houses"))
    if (nrow(houses_idx) == 0) {
      skipped("T17", "stimuli", "CHECK",
              "no houses runs in this sample (jobs indices are participant-specific and need the export)")
    } else if (n_houses_rows == 0) {
      skipped("T17", "stimuli", "CHECK",
              "experiment/stimuli/house_stimuli.csv not readable for the bound check")
    } else {
      bad <- houses_idx %>% filter(idx < 1 | idx > n_houses_rows)
      tally <- houses_idx %>% count(idx, name = "uses")
      check("T17", "stimuli", "CHECK", nrow(bad) == 0,
            sprintf("houses indices must lie in 1..%d and join to house_stimuli.csv row order; %s. %d of %d houses rows observed, %d-%d uses each -- these ARE comparable across participants.",
                    n_houses_rows,
                    if (nrow(bad) == 0) "all in range"
                    else sprintf("OUT OF RANGE: %s", name_offenders(
                      sprintf("%s idx=%d", bad$run_id, bad$idx))),
                    nrow(tally), n_houses_rows, min(tally$uses), max(tally$uses)),
            nrow(houses_idx))
    }
  }

  bind_rows(out)
}

# Row count of a source stimulus table, or NA if it cannot be read.
read_stimulus_defs_n <- function(domain) {
  path <- tryCatch(
    switch(domain,
           houses = repo_file("experiment", "stimuli", "house_stimuli.csv"),
           jobs   = repo_file("experiment", "stimuli", "prepared",
                              "job_stimuli_synthetic.csv"),
           NULL),
    error = function(e) NULL)
  if (is.null(path) || !file.exists(path)) return(tibble())
  out <- tryCatch(
    suppressWarnings(readr::read_csv(path, show_col_types = FALSE,
                                     progress = FALSE)),
    error = function(e) tibble())
  out
}

# ---- 4. manipulation checks ------------------------------------------------

checks_manipulation <- function(auction, contdc, reversals = NULL, spec = design_spec()) {
  out <- list()

  # M01 -- a zero contrast means buildPairs fell back to random pairing.
  out$M01 <- if (!has_cols(contdc, "contrast")) {
    skipped("M01", "manipulation", "FAIL", "contdc CSVs lack contrast")
  } else {
    bad <- contdc %>% filter(!is.na(contrast), contrast <= 0)
    runs <- unique(bad$run_id)
    check("M01", "manipulation", "FAIL", nrow(bad) == 0,
          if (nrow(bad) == 0)
            sprintf("all %d rows have a positive money-vs-quality contrast", nrow(contdc))
          else sprintf("ZERO CONTRAST on %d rows (%s) -- buildPairs hit its fallback and warned that reversals will not be detectable (buildPairs.m:38-42,60-65)",
                       nrow(bad), name_offenders(runs)),
          nrow(contdc))
  }

  # M02 -- the money-favouring option, by domain-signed direction.
  #
  # NOT simply "the higher posted value". buildPairs.m:21 scores money as
  #   money = zscore(value) * A.core(1).dir
  # and attributes.m:25 sets dir = -1 for the house listed price (a higher
  # price is worse for a buyer) while attributes.m:60 sets dir = +1 for the
  # offered wage. So the money-favouring house is the CHEAPER one and the
  # money-favouring job is the BETTER-PAID one. Asserting "higher" in both
  # domains would fail every houses run.
  out$M02 <- if (!has_cols(contdc, "isMoneyOption", "postedValue", "pairIdx")) {
    skipped("M02", "manipulation", "FAIL", "contdc CSVs lack isMoneyOption/postedValue")
  } else {
    paired <- contdc %>%
      filter(taskType == "price", !is.na(isMoneyOption), !is.na(postedValue)) %>%
      group_by(run_id, domain, block, attrLevel, pairIdx) %>%
      filter(n() == 2, n_distinct(isMoneyOption) == 2) %>%
      summarise(money = postedValue[isMoneyOption],
                quality = postedValue[!isMoneyOption], .groups = "drop") %>%
      mutate(dir = if_else(domain == "houses", -1, 1),
             ok = dir * (money - quality) > 0)
    if (nrow(paired) == 0) {
      skipped("M02", "manipulation", "FAIL", "no complete priced pairs")
    } else {
      bad <- paired %>% filter(!ok)
      check("M02", "manipulation", "FAIL", nrow(bad) == 0,
            sprintf("houses money option posts the LOWER price (dir=-1), jobs the HIGHER wage (dir=+1), per attributes.m:25,60 and buildPairs.m:21; %s",
                    if (nrow(bad) == 0) sprintf("all %d pairs correct", nrow(paired))
                    else sprintf("INVERTED on %d of %d pairs (%s)", nrow(bad),
                                 nrow(paired), name_offenders(bad$run_id))),
            nrow(paired))
    }
  }

  # M03 -- two price rows per pair, one money one quality.
  out$M03 <- if (!has_cols(contdc, "isMoneyOption", "pairIdx")) {
    skipped("M03", "manipulation", "CHECK", "contdc CSVs lack isMoneyOption")
  } else {
    got <- contdc %>% filter(taskType == "price") %>%
      count(run_id, block, pairIdx, name = "rows")
    bad <- got %>% filter(rows != 2)
    check("M03", "manipulation", "CHECK", nrow(bad) == 0,
          sprintf("expected 2 price rows per pair; %s",
                  if (nrow(bad) == 0) sprintf("all %d pairs correct", nrow(got))
                  else sprintf("off: %s", name_offenders(
                    sprintf("%s b%s p%s=%d", bad$run_id, bad$block,
                            bad$pairIdx, bad$rows)))),
          nrow(got))
  }

  # M04 -- pairs are selected by descending contrast, so spread should be modest.
  out$M04 <- if (!has_cols(contdc, "contrast", "attrLevel")) {
    skipped("M04", "manipulation", "INFO", "contdc CSVs lack contrast")
  } else {
    got <- contdc %>% filter(!is.na(contrast)) %>%
      group_by(domain, attrLevel) %>%
      summarise(med = median(contrast), lo = min(contrast), .groups = "drop")
    check("M04", "manipulation", "INFO", TRUE,
          sprintf("median contrast by level: %s",
                  paste(sprintf("%s/L%s=%.3g", got$domain, got$attrLevel, got$med),
                        collapse = " ")),
          nrow(contdc))
  }

  # M05 -- more attributes should cost more time.
  out$M05 <- if (!has_cols(contdc, "rt", "attrLevel")) {
    skipped("M05", "manipulation", "CHECK", "contdc CSVs lack rt")
  } else {
    got <- contdc %>%
      filter(!timedOut, !is.na(rt)) %>%
      group_by(attrLevel) %>%
      summarise(mean_rt = mean(rt), k = n(), .groups = "drop") %>%
      arrange(attrLevel)
    monotone <- nrow(got) >= 2 && all(diff(got$mean_rt) > 0)
    check("M05", "manipulation", "CHECK", monotone,
          sprintf("mean RT by level: %s -- expected increasing%s",
                  paste(sprintf("L%s=%.2fs(n=%d)", got$attrLevel, got$mean_rt, got$k),
                        collapse = " "),
                  if (monotone) "" else " BUT IT IS NOT"),
          sum(got$k))
  }

  # M06 -- high competition should clear fewer bids.
  out$M06 <- if (!has_cols(auction, "bidAccepted", "competition")) {
    skipped("M06", "manipulation", "CHECK", "auction CSVs lack bidAccepted")
  } else {
    got <- auction %>% filter(!practice, !is.na(bidAccepted)) %>%
      group_by(competition) %>%
      summarise(cleared = mean(bidAccepted), k = n(), .groups = "drop")
    wide <- got %>% pivot_wider(names_from = competition,
                                values_from = c(cleared, k))
    ok <- !is.null(wide$cleared_high) && !is.null(wide$cleared_low) &&
      !is.na(wide$cleared_high) && !is.na(wide$cleared_low) &&
      wide$cleared_high < wide$cleared_low
    check("M06", "manipulation", "CHECK", ok,
          sprintf("clearance rate: %s -- expected high < low%s",
                  paste(sprintf("%s=%s(n=%d)", got$competition, pct(got$cleared), got$k),
                        collapse = " "),
                  if (isTRUE(ok)) "" else " BUT IT IS NOT"),
          sum(got$k))
  }

  # M07 -- the threshold itself should shift with competition.
  out$M07 <- if (!has_cols(auction, "threshold", "competition", "trueValue")) {
    skipped("M07", "manipulation", "CHECK", "auction CSVs lack threshold")
  } else {
    got <- auction %>%
      filter(!practice, !is.na(threshold), !is.na(trueValue), trueValue > 0) %>%
      group_by(domain, competition) %>%
      summarise(med_ratio = median(threshold / trueValue), k = n(), .groups = "drop")
    check("M07", "manipulation", "CHECK", nrow(got) > 0,
          sprintf("median threshold/value: %s",
                  paste(sprintf("%s/%s=%.3f(n=%d)", got$domain, got$competition,
                                got$med_ratio, got$k), collapse = " ")),
          sum(got$k))
  }

  # M08 -- the stochastic threshold exists to stop high competition from
  # making surplus negative by construction.
  out$M08 <- if (!has_cols(auction, "surplus", "competition")) {
    skipped("M08", "manipulation", "CHECK", "auction table lacks surplus")
  } else {
    got <- auction %>% filter(!is.na(surplus)) %>%
      group_by(domain, competition) %>%
      summarise(mean_surplus = mean(surplus), k = n(), .groups = "drop")
    if (nrow(got) == 0) {
      skipped("M08", "manipulation", "CHECK", "no cleared transactions yet")
    } else {
      # Flag only a cell that is both negative and well sampled. Cleared
      # high-competition trials are scarce per participant, so a small-n cell
      # goes negative on noise alone; this is a pooled-sample check.
      bad <- got %>% filter(mean_surplus < 0, k >= 20)
      check("M08", "manipulation", "CHECK", nrow(bad) == 0,
            sprintf("mean surplus on cleared trials: %s%s",
                    paste(sprintf("%s/%s=%.3g(n=%d)", got$domain, got$competition,
                                  got$mean_surplus, got$k), collapse = " "),
                    if (nrow(bad) == 0) ""
                    else " -- NEGATIVE cell: the threshold noise is not doing its job"),
            sum(got$k))
    }
  }

  # M09 -- BDM: a cleared bid transacts at the threshold, not at the bid.
  out$M09 <- if (!has_cols(auction, "pricePaid", "threshold", "bidAccepted")) {
    skipped("M09", "manipulation", "FAIL", "auction CSVs lack pricePaid/threshold")
  } else {
    cleared <- auction %>% filter(!is.na(bidAccepted), bidAccepted)
    mismatch <- cleared %>%
      filter(is.na(pricePaid) |
               abs(pricePaid - threshold) > 0.01 + 1e-6 * abs(threshold))
    leaked <- auction %>% filter(!is.na(bidAccepted), !bidAccepted, !is.na(pricePaid))
    check("M09", "manipulation", "FAIL",
          nrow(mismatch) == 0 && nrow(leaked) == 0,
          if (nrow(mismatch) == 0 && nrow(leaked) == 0)
            sprintf("all %d cleared trials paid the threshold; uncleared trials have no price",
                    nrow(cleared))
          else sprintf("%d cleared trials did not pay the threshold, %d uncleared trials carry a price (%s)",
                       nrow(mismatch), nrow(leaked),
                       name_offenders(c(mismatch$run_id, leaked$run_id))),
          nrow(cleared))
  }

  # M15 -- the acceptance rule runs in opposite directions by domain.
  out$M15 <- if (!has_cols(auction, "bid", "threshold", "bidAccepted", "domain")) {
    skipped("M15", "manipulation", "FAIL", "auction CSVs lack bid/threshold")
  } else {
    got <- auction %>%
      filter(!is.na(bid), !is.na(threshold), !is.na(bidAccepted)) %>%
      mutate(want = if_else(domain == "houses", bid >= threshold, bid <= threshold))
    # A bid can be withheld, so acceptance implies the rule but not conversely.
    bad <- got %>% filter(bidAccepted & !want)
    check("M15", "manipulation", "FAIL", nrow(bad) == 0,
          sprintf("houses clear on bid>=threshold, jobs on bid<=threshold (auction_task.m:689); %s",
                  if (nrow(bad) == 0) sprintf("all %d bids consistent", nrow(got))
                  else sprintf("INVERTED on %d trials (%s) -- a sign slip here flips the whole auction and still looks plausible",
                               nrow(bad), name_offenders(bad$run_id))),
          nrow(got))
  }

  # M10 -- bids should track value.
  out$M10 <- if (!has_cols(auction, "bid", "trueValue")) {
    skipped("M10", "manipulation", "CHECK", "auction CSVs lack bid/trueValue")
  } else {
    got <- auction %>% filter(!practice, !is.na(bid), !is.na(trueValue)) %>%
      group_by(run_id) %>%
      filter(n() >= 5, sd(bid) > 0, sd(trueValue) > 0) %>%
      summarise(rho = cor(bid, trueValue, method = "spearman"), k = n(),
                .groups = "drop")
    if (nrow(got) == 0) {
      skipped("M10", "manipulation", "CHECK",
              "too few bids with variance to rank-correlate")
    } else {
      bad <- got %>% filter(rho <= 0)
      check("M10", "manipulation", "CHECK", nrow(bad) == 0,
            sprintf("median within-run Spearman(bid, value) = %.2f over %d runs%s",
                    median(got$rho), nrow(got),
                    if (nrow(bad) == 0) ""
                    else sprintf("; non-positive in %s", name_offenders(bad$run_id))),
            nrow(got))
    }
  }

  # M11 -- the value marker is drawn on the scale and is expected to pull bids.
  out$M11 <- if (!has_cols(auction, "bid", "trueValue")) {
    skipped("M11", "manipulation", "INFO", "auction CSVs lack bid")
  } else {
    d <- auction %>% filter(!practice, !is.na(bid), !is.na(trueValue), trueValue > 0)
    check("M11", "manipulation", "INFO", TRUE,
          sprintf("median bid/value = %.3f, IQR %.3f-%.3f. cfg.display.showValueMarker=TRUE draws the advertised figure on the scale and is documented to compress bid variance.",
                  median(d$bid / d$trueValue),
                  quantile(d$bid / d$trueValue, 0.25),
                  quantile(d$bid / d$trueValue, 0.75)),
          nrow(d))
  }

  # M12 -- reversals should exist but stay well under chance.
  out$M12 <- if (is.null(reversals) || nrow(reversals) == 0) {
    skipped("M12", "manipulation", "CHECK",
            "no reversal-scorable pairs (needs a choice and both prices per pair)")
  } else {
    rate <- mean(reversals$reversal)
    check("M12", "manipulation", "CHECK",
          rate > 0 && rate < spec$qc$reversal_rate_max,
          sprintf("reversal rate %s over %d scorable pairs; expected above 0 and below %s",
                  pct(rate), nrow(reversals), pct(spec$qc$reversal_rate_max)),
          nrow(reversals))
  }

  # M13 -- the elicited anchor must be present and plausible for its domain.
  out$M13 <- if (!has_cols(auction, "anchor", "domain")) {
    skipped("M13", "manipulation", "CHECK", "auction CSVs lack anchor")
  } else {
    got <- auction %>% distinct(run_id, domain, anchor)
    bad <- got %>% filter(is.na(anchor) | anchor <= 0 |
                            (domain == "jobs" & (anchor < 5 | anchor > 500)) |
                            (domain == "houses" & (anchor < 20000 | anchor > 5e6)))
    check("M13", "manipulation", "CHECK", nrow(bad) == 0,
          sprintf("jobs anchor is an hourly wage, houses a budget; %s",
                  if (nrow(bad) == 0) sprintf("all %d runs plausible", nrow(got))
                  else sprintf("implausible: %s", name_offenders(
                    sprintf("%s/%s=%s", bad$run_id, bad$domain, bad$anchor)))),
          nrow(got))
  }

  # M14 -- value spread around the anchor, both domains fitToWindow.
  out$M14 <- if (!has_cols(auction, "trueValue", "anchor")) {
    skipped("M14", "manipulation", "INFO", "auction CSVs lack trueValue/anchor")
  } else {
    got <- auction %>% filter(!practice, !is.na(trueValue), !is.na(anchor), anchor > 0) %>%
      group_by(domain) %>%
      summarise(med = median(trueValue / anchor),
                p10 = quantile(trueValue / anchor, 0.1),
                p90 = quantile(trueValue / anchor, 0.9), .groups = "drop")
    check("M14", "manipulation", "INFO", TRUE,
          sprintf("value/anchor by domain: %s (window target [%.2f, %.2f], fitToWindow=TRUE both domains)",
                  paste(sprintf("%s med=%.2f p10=%.2f p90=%.2f", got$domain, got$med,
                                got$p10, got$p90), collapse = " "),
                  spec$sampling_spread[[1]], spec$sampling_spread[[2]]),
          nrow(auction))
  }

  bind_rows(out)
}

# ---- 5. response quality / engagement --------------------------------------

checks_quality <- function(auction, contdc, pref, timing, spec = design_spec()) {
  out <- list()

  # Q01 -- timeout rate per participant.
  out$Q01 <- if (!has_cols(contdc, "timedOut")) {
    skipped("Q01", "quality", "CHECK", "contdc CSVs lack timedOut")
  } else {
    got <- contdc %>% group_by(run_id) %>%
      summarise(rate = mean(timedOut, na.rm = TRUE), k = n(), .groups = "drop")
    bad <- got %>% filter(rate > spec$qc$timeout_rate_max)
    check("Q01", "quality", "CHECK", nrow(bad) == 0,
          sprintf("ceiling %s; worst observed %s%s", pct(spec$qc$timeout_rate_max),
                  pct(max(got$rate)),
                  if (nrow(bad) == 0) ""
                  else sprintf(" -- over: %s", name_offenders(
                    sprintf("%s=%s", bad$run_id, pct(bad$rate))))),
          nrow(got))
  }

  # Q02 -- implausibly fast responses.
  rt_tabs <- list(contdc = contdc, pref = pref)
  fast <- imap(rt_tabs, function(d, nm) {
    if (!has_cols(d, "rt")) return(NULL)
    d %>% filter(!is.na(rt)) %>%
      group_by(run_id) %>%
      summarise(share = mean(rt < spec$qc$rt_implausible_sec), k = n(),
                .groups = "drop") %>%
      mutate(tbl = nm)
  }) %>% compact() %>% bind_rows()
  out$Q02 <- if (nrow(fast) == 0) {
    skipped("Q02", "quality", "CHECK", "no tables with rt")
  } else {
    bad <- fast %>% filter(share > spec$qc$rt_implausible_max)
    check("Q02", "quality", "CHECK", nrow(bad) == 0,
          sprintf("RTs under %.2fs should be under %s of trials; worst %s%s",
                  spec$qc$rt_implausible_sec, pct(spec$qc$rt_implausible_max),
                  pct(max(fast$share)),
                  if (nrow(bad) == 0) ""
                  else sprintf(" -- over: %s", name_offenders(
                    sprintf("%s/%s=%s", bad$tbl, bad$run_id, pct(bad$share))))),
          sum(fast$k))
  }

  # Q03 -- a bid that never varies means the slider never moved.
  out$Q03 <- if (!has_cols(auction, "bid")) {
    skipped("Q03", "quality", "CHECK", "auction CSVs lack bid")
  } else {
    got <- auction %>% filter(!practice, !is.na(bid)) %>%
      group_by(run_id) %>%
      summarise(distinct_bids = n_distinct(bid), k = n(), .groups = "drop") %>%
      filter(k >= 5)
    if (nrow(got) == 0) {
      skipped("Q03", "quality", "CHECK", "too few bids placed to judge variance")
    } else {
      bad <- got %>% filter(distinct_bids <= 1)
      check("Q03", "quality", "CHECK", nrow(bad) == 0,
            if (nrow(bad) == 0) sprintf("every run with >=5 bids varies them (min %d distinct)",
                                        min(got$distinct_bids))
            else sprintf("constant bid: %s", name_offenders(bad$run_id)),
            nrow(got))
    }
  }

  # Q04 -- the rating scale must actually be used.
  out$Q04 <- if (!has_cols(pref, "rating")) {
    skipped("Q04", "quality", "CHECK", "pref CSVs lack rating")
  } else {
    got <- pref %>% filter(!is.na(rating)) %>%
      group_by(run_id) %>%
      summarise(spread = diff(range(rating)), distinct = n_distinct(rating),
                k = n(), .groups = "drop") %>%
      filter(k >= 10)
    if (nrow(got) == 0) {
      skipped("Q04", "quality", "CHECK", "no rating rows (jobs-only sample)")
    } else {
      bad <- got %>% filter(distinct < 5)
      check("Q04", "quality", "CHECK", nrow(bad) == 0,
            sprintf("VAS should take many values; min distinct per run %d%s",
                    min(got$distinct),
                    if (nrow(bad) == 0) ""
                    else sprintf(" -- flat: %s", name_offenders(
                      sprintf("%s=%d", bad$run_id, bad$distinct)))),
            nrow(got))
    }
  }

  # Q05 -- episode duration against the timeout.
  out$Q05 <- if (!has_cols(auction, "durationSec")) {
    skipped("Q05", "quality", "CHECK", "auction CSVs lack durationSec")
  } else {
    d <- auction %>% filter(!practice, !is.na(durationSec))
    at_cap <- mean(d$durationSec >= spec$auction_timeout_sec - 0.5)
    check("Q05", "quality", "CHECK", at_cap < 0.25,
          sprintf("%s of episodes ran to the %gs cap; median %.1fs",
                  pct(at_cap), spec$auction_timeout_sec, median(d$durationSec)),
          nrow(d))
  }

  # Q06 -- scale start positions should not be pinned.
  start_cols <- intersect(c("bidStartFrac", "startFrac"),
                          c(names(auction), names(contdc)))
  out$Q06 <- if (!length(start_cols)) {
    skipped("Q06", "quality", "CHECK",
            "no bidStartFrac/startFrac column (pre-schema CSVs)")
  } else {
    vals <- c(if ("bidStartFrac" %in% names(auction)) auction$bidStartFrac,
              if ("startFrac" %in% names(contdc)) contdc$startFrac)
    vals <- vals[!is.na(vals)]
    if (!length(vals)) {
      skipped("Q06", "quality", "CHECK", "start-fraction columns are all NA")
    } else {
      check("Q06", "quality", "CHECK", n_distinct(vals) > 1,
            sprintf("%d distinct start fractions over %d responses (median %.3f)",
                    n_distinct(vals), length(vals), median(vals)),
            length(vals))
    }
  }

  # Q07 -- section durations within a plausible band.
  out$Q07 <- if (!has_cols(timing, "seconds", "task")) {
    skipped("Q07", "quality", "CHECK", "no session timing CSVs")
  } else {
    got <- timing %>% group_by(participant, session, task) %>%
      summarise(minutes = sum(seconds, na.rm = TRUE) / 60, .groups = "drop")
    bad <- got %>% filter(minutes < 3 | minutes > 90)
    check("Q07", "quality", "CHECK", nrow(bad) == 0,
          sprintf("task totals should land between 3 and 90 min; observed %.1f-%.1f%s",
                  min(got$minutes), max(got$minutes),
                  if (nrow(bad) == 0) ""
                  else sprintf(" -- outside: %s", name_offenders(
                    sprintf("%s/%s=%.1fmin", bad$participant, bad$task, bad$minutes)))),
          nrow(got))
  }

  # Q08 -- an exhausted market means the search set ran dry.
  out$Q08 <- if (!has_cols(auction, "endReason")) {
    skipped("Q08", "quality", "CHECK", "auction CSVs lack endReason")
  } else {
    d <- auction %>% filter(!practice, !is.na(endReason))
    share <- mean(d$endReason == "exhausted")
    check("Q08", "quality", "CHECK", share < 0.20,
          sprintf("%s of episodes ended exhausted; %s",
                  pct(share),
                  paste(sprintf("%s=%d", names(table(d$endReason)),
                                as.integer(table(d$endReason))), collapse = " ")),
          nrow(d))
  }

  bind_rows(out)
}

# ---- 6. gaze quality -------------------------------------------------------
# Every check here needs the flat export from scripts/export_gaze_csv.m. With no
# export they all SKIP, naming the missing file -- that is the honest state, not
# a pass.

checks_gaze <- function(gaze = NULL, events = NULL, aoi = NULL, et_meta = NULL,
                        keys = NULL, spec = design_spec()) {
  out <- list()
  no_export <- paste("needs the flat gaze export: run scripts/combine_blocks.m then",
                     "scripts/export_gaze_csv.m, and point --data at that root")
  gaze_ok <- has_cols(gaze, "run_id", "trial", "phase")

  # alignBlockGaze labels samples with a trial number drawn from that block's
  # event log, so trial 1 exists in every block. Any per-trial grouping must
  # include the block or it silently spans the whole run.
  trial_key <- if (has_cols(gaze, "block")) c("run_id", "block", "trial")
               else c("run_id", "trial")

  # G01 -- a non-empty gaze table per run.
  out$G01 <- if (!gaze_ok) {
    skipped("G01", "gaze", "FAIL", no_export)
  } else if (is.null(keys)) {
    check("G01", "gaze", "FAIL", nrow(gaze) > 0,
          sprintf("%d samples over %d runs", nrow(gaze), n_distinct(gaze$run_id)),
          nrow(gaze))
  } else {
    want <- keys %>% distinct(run_id)
    missing <- anti_join(want, gaze %>% distinct(run_id), by = "run_id")
    check("G01", "gaze", "FAIL", nrow(missing) == 0,
          if (nrow(missing) == 0) sprintf("%d samples cover all %d runs",
                                          nrow(gaze), nrow(want))
          else sprintf("NO GAZE for: %s", name_offenders(missing$run_id)),
          nrow(gaze))
  }

  # G02 -- phase "unknown" means the clock sync failed for that block.
  out$G02 <- if (!gaze_ok) {
    skipped("G02", "gaze", "FAIL", no_export)
  } else {
    got <- gaze %>% group_by(run_id) %>%
      summarise(unknown = mean(phase == "unknown"), .groups = "drop")
    bad <- got %>% filter(unknown > 0)
    check("G02", "gaze", "FAIL", nrow(bad) == 0,
          if (nrow(bad) == 0) "no samples with phase=unknown; clock sync valid everywhere"
          else sprintf("CLOCK SYNC FAILED -- samples cannot be assigned to trials: %s",
                       name_offenders(sprintf("%s=%s", bad$run_id, pct(bad$unknown)))),
          nrow(gaze))
  }

  # G03 -- "outside" is expected at block edges but should stay small.
  out$G03 <- if (!gaze_ok) {
    skipped("G03", "gaze", "CHECK", no_export)
  } else {
    got <- gaze %>% group_by(run_id) %>%
      summarise(outside = mean(phase == "outside"), .groups = "drop")
    bad <- got %>% filter(outside > spec$qc$gaze_outside_max)
    check("G03", "gaze", "CHECK", nrow(bad) == 0,
          sprintf("ceiling %s; worst %s%s", pct(spec$qc$gaze_outside_max),
                  pct(max(got$outside)),
                  if (nrow(bad) == 0) ""
                  else sprintf(" -- over: %s", name_offenders(bad$run_id))),
          nrow(gaze))
  }

  # G04 -- the requested rate is never pushed to the tracker, only read back.
  out$G04 <- if (!has_cols(et_meta, "actualSampleRateHz")) {
    skipped("G04", "gaze", "FAIL",
            paste("needs eyeTracking metadata in the export;",
                  "cfg.et.sampleRateHz is requested but never set on the tracker",
                  "(config.m:220, setupEyeTracker.m:70), so a wrong rate is silent"))
  } else {
    bad <- et_meta %>% filter(is.na(actualSampleRateHz) |
                                abs(actualSampleRateHz - spec$et_sample_rate_hz) > 0.5)
    check("G04", "gaze", "FAIL", nrow(bad) == 0,
          sprintf("expected %g Hz; %s", spec$et_sample_rate_hz,
                  if (nrow(bad) == 0) "every run reports the requested rate"
                  else sprintf("WRONG RATE: %s", name_offenders(
                    sprintf("%s=%s", bad$run_id, bad$actualSampleRateHz)))),
          nrow(et_meta))
  }

  # G05 -- observed samples against duration x rate.
  out$G05 <- if (!gaze_ok || !has_cols(gaze, "ptbTime", "block")) {
    skipped("G05", "gaze", "CHECK", no_export)
  } else {
    rate <- spec$et_sample_rate_hz
    got <- gaze %>% filter(!is.na(ptbTime)) %>%
      group_by(run_id, block) %>%
      summarise(span = diff(range(ptbTime)), k = n(), .groups = "drop") %>%
      filter(span > 1) %>%
      mutate(ratio = k / (span * rate))
    if (nrow(got) == 0) {
      skipped("G05", "gaze", "CHECK", "no block spans long enough to judge")
    } else {
      bad <- got %>% filter(abs(ratio - 1) > spec$qc$gaze_rate_tol)
      check("G05", "gaze", "CHECK", nrow(bad) == 0,
            sprintf("observed/expected samples within %s; range %.2f-%.2f%s",
                    pct(spec$qc$gaze_rate_tol), min(got$ratio), max(got$ratio),
                    if (nrow(bad) == 0) ""
                    else sprintf(" -- off: %s", name_offenders(
                      sprintf("%s b%s=%.2f", bad$run_id, bad$block, bad$ratio)))),
            nrow(got))
    }
  }

  # G06 -- a trial with no samples is a trial with no data.
  out$G06 <- if (!gaze_ok) {
    skipped("G06", "gaze", "FAIL", no_export)
  } else {
    got <- gaze %>% filter(!is.na(trial)) %>%
      count(across(all_of(trial_key)), name = "k")
    empty <- got %>% filter(k == 0)
    check("G06", "gaze", "FAIL", nrow(empty) == 0,
          sprintf("%d trials carry samples, median %d per trial%s",
                  nrow(got), as.integer(median(got$k)),
                  if (nrow(empty) == 0) ""
                  else sprintf("; EMPTY: %s", name_offenders(empty$run_id))),
          nrow(got))
  }

  # G07 -- valid-sample fraction.
  out$G07 <- if (!has_cols(gaze, "gaze_validity")) {
    skipped("G07", "gaze", "CHECK", no_export)
  } else {
    got <- gaze %>% group_by(run_id) %>%
      summarise(valid = mean(as_lgl_flex(gaze_validity), na.rm = TRUE),
                .groups = "drop")
    bad <- got %>% filter(is.na(valid) | valid < spec$qc$gaze_valid_min)
    check("G07", "gaze", "CHECK", nrow(bad) == 0,
          sprintf("floor %s; observed %s-%s%s", pct(spec$qc$gaze_valid_min),
                  pct(min(got$valid)), pct(max(got$valid)),
                  if (nrow(bad) == 0) ""
                  else sprintf(" -- under: %s", name_offenders(
                    sprintf("%s=%s", bad$run_id, pct(bad$valid))))),
          nrow(gaze))
  }

  # G08 -- the largest sampling gap per trial, as tracking loss.
  out$G08 <- if (!gaze_ok || !has_cols(gaze, "ptbTime")) {
    skipped("G08", "gaze", "CHECK", no_export)
  } else {
    nominal <- 1 / spec$et_sample_rate_hz
    got <- gaze %>% filter(!is.na(ptbTime), !is.na(trial)) %>%
      arrange(across(all_of(c(trial_key, "ptbTime")))) %>%
      group_by(across(all_of(trial_key))) %>%
      filter(n() > 2) %>%
      summarise(max_gap = max(diff(ptbTime)), .groups = "drop")
    if (nrow(got) == 0) {
      skipped("G08", "gaze", "CHECK", "too few samples per trial to measure gaps")
    } else {
      # Ten nominal intervals of loss is ~0.17 s at 60 Hz.
      bad <- got %>% filter(max_gap > 10 * nominal)
      check("G08", "gaze", "CHECK", nrow(bad) / nrow(got) < 0.05,
            sprintf("median largest within-trial gap %.0f ms, worst %.0f ms; %s of trials lose more than %.0f ms",
                    1000 * median(got$max_gap), 1000 * max(got$max_gap),
                    pct(nrow(bad) / nrow(got)), 1000 * 10 * nominal),
            nrow(got))
    }
  }

  # G09 -- normalised gaze should lie on the display.
  out$G09 <- if (!has_cols(gaze, "gaze_x_norm", "gaze_y_norm")) {
    skipped("G09", "gaze", "CHECK", no_export)
  } else {
    d <- gaze %>% filter(!is.na(gaze_x_norm), !is.na(gaze_y_norm))
    off <- mean(d$gaze_x_norm < 0 | d$gaze_x_norm > 1 |
                  d$gaze_y_norm < 0 | d$gaze_y_norm > 1)
    check("G09", "gaze", "CHECK", off < 0.10,
          sprintf("%s of valid samples fall outside the display area", pct(off)),
          nrow(d))
  }

  # G10 -- drift-check offset is the only spatial-accuracy number on disk.
  out$G10 <- if (!has_cols(events, "event")) {
    skipped("G10", "gaze", "CHECK",
            paste("needs the event export (events/*_events.csv);",
                  "drift offset is the ONLY spatial-accuracy measure available,",
                  "because calibrate.m:56 discards the per-point residuals"))
  } else {
    dc <- events %>% filter(event == "drift_check")
    if (nrow(dc) == 0 || !"offsetDeg" %in% names(dc)) {
      skipped("G10", "gaze", "CHECK", "no drift_check events with offsetDeg")
    } else {
      d <- dc %>% filter(!is.na(offsetDeg))
      over <- mean(d$offsetDeg > spec$et_drift_tol_deg)
      recal <- if ("recalibrated" %in% names(d))
        sum(as_lgl_flex(d$recalibrated), na.rm = TRUE) else NA_integer_
      check("G10", "gaze", "CHECK", over < 0.20,
            sprintf("median offset %.2f deg, %s over the %.1f deg tolerance%s",
                    median(d$offsetDeg), pct(over), spec$et_drift_tol_deg,
                    if (is.na(recal)) "" else sprintf("; %d recalibrations", recal)),
            nrow(d))
    }
  }

  # G11 -- drift checks at the configured cadence.
  out$G11 <- if (!has_cols(events, "event")) {
    skipped("G11", "gaze", "CHECK", "needs the event export")
  } else {
    dc <- events %>% filter(event == "drift_check")
    if (nrow(dc) == 0) {
      skipped("G11", "gaze", "CHECK", "no drift_check events recorded")
    } else {
      got <- dc %>% count(run_id, name = "k")
      check("G11", "gaze", "CHECK", TRUE,
            sprintf("drift checks per run: %d-%d (contdc cadence is every %d trials)",
                    min(got$k), max(got$k), spec$contdc_drift_every),
            nrow(dc))
    }
  }

  # G12 -- pupil diameter present and not flat.
  out$G12 <- if (!has_cols(gaze, "pupil_diameter")) {
    skipped("G12", "gaze", "CHECK", no_export)
  } else {
    d <- gaze %>% filter(!is.na(pupil_diameter), pupil_diameter > 0)
    if (nrow(d) == 0) {
      skipped("G12", "gaze", "CHECK", "no positive pupil diameters recorded")
    } else {
      got <- d %>% group_by(run_id) %>%
        summarise(med = median(pupil_diameter), spread = sd(pupil_diameter),
                  .groups = "drop")
      bad <- got %>% filter(med < 1 | med > 9 | spread == 0)
      check("G12", "gaze", "CHECK", nrow(bad) == 0,
            sprintf("median diameter %.2f mm across runs; %s",
                    median(got$med),
                    if (nrow(bad) == 0) "all runs plausible and varying"
                    else sprintf("implausible or flat: %s", name_offenders(bad$run_id))),
            nrow(d))
    }
  }

  # G13 -- AOI separation verdicts.
  out$G13 <- if (!has_cols(aoi, "verdict")) {
    skipped("G13", "gaze", "CHECK",
            "needs the AOI export (aoi/*_aoi.csv); rects live only in the task .mat")
  } else {
    bad <- aoi %>% filter(str_detect(toupper(verdict), "TOO CLOSE"))
    marginal <- aoi %>% filter(str_detect(tolower(verdict), "marginal"))
    check("G13", "gaze", "CHECK", nrow(bad) == 0,
          sprintf("minAOI %.1f deg, minSep %.1f deg; %s",
                  spec$aoi_min_deg, spec$aoi_min_sep_deg,
                  if (nrow(bad) == 0) sprintf("no TOO CLOSE verdicts (%d marginal)",
                                              nrow(marginal))
                  else sprintf("TOO CLOSE: %s", name_offenders(
                    sprintf("%s/%s", bad$run_id, bad$aoiName)))),
          nrow(aoi))
  }

  # G14 -- AOI count should track the attribute level on a card.
  out$G14 <- if (!has_cols(aoi, "aoiName")) {
    skipped("G14", "gaze", "CHECK", "needs the AOI export")
  } else {
    got <- aoi %>% count(run_id, name = "k")
    check("G14", "gaze", "CHECK", all(got$k > 0),
          sprintf("%d AOIs over %d runs; attribute-AOI count per layout is checked against attrLevel in 20_stimulus_audit.R",
                  nrow(aoi), nrow(got)),
          nrow(aoi))
  }

  # G15 -- AOI coverage, explicitly NOT dwell time.
  out$G15 <- if (!gaze_ok || !has_cols(aoi, "aoiName")) {
    skipped("G15", "gaze", "INFO", no_export)
  } else {
    check("G15", "gaze", "INFO", TRUE,
          paste("AOI hit share is reported as COVERAGE only, not dwell time:",
                "contdc choice_onset/price_onset are logged before",
                "awaitFixationStart and the first stimulus flip return is",
                "discarded, so these onsets are not exact exposure times."),
          nrow(gaze))
  }

  # G16 -- calibration flag reaches disk for pref only.
  out$G16 <- if (!has_cols(et_meta, "calibrated")) {
    skipped("G16", "gaze", "CHECK",
            paste("et.calibrated is written only by preference_task.m:77;",
                  "auction_task.m:72-80 and continuous_DC_task.m:70-77 omit it"))
  } else {
    bad <- et_meta %>% filter(!as_lgl_flex(calibrated))
    check("G16", "gaze", "CHECK", nrow(bad) == 0,
          if (nrow(bad) == 0) sprintf("calibrated=TRUE on all %d runs that record it",
                                      nrow(et_meta))
          else sprintf("UNCALIBRATED: %s", name_offenders(bad$run_id)),
          nrow(et_meta))
  }

  # G17 -- artifact checksums.
  out$G17 <- skipped("G17", "gaze", "CHECK",
                     paste("per-artifact SHA-256 lives in the block receipts",
                           "(blockStore.m:131-153); verifying it is MATLAB-side work,",
                           "done by scripts/verify_block_checkpoints.m, not here"))

  bind_rows(out)
}

# ---- driver ----------------------------------------------------------------

#' Run every check and return one tidy table.
run_checks <- function(auction = NULL, contdc = NULL, pref = NULL, timing = NULL,
                       reversals = NULL, gaze = NULL, events = NULL, aoi = NULL,
                       et_meta = NULL, plan = NULL, stimuli_shown = NULL,
                       spec = design_spec()) {
  keys <- run_keys(auction, contdc, pref)
  bind_rows(
    checks_structural(auction, contdc, pref, timing, spec),
    checks_counterbalance(auction, contdc, pref, timing, spec),
    checks_stimuli(auction, contdc, pref, plan, stimuli_shown, spec),
    checks_manipulation(auction, contdc, reversals, spec),
    checks_quality(auction, contdc, pref, timing, spec),
    checks_gaze(gaze, events, aoi, et_meta, keys, spec)
  ) %>%
    mutate(section = factor(section, levels = c("structural", "counterbalance",
                                                "stimuli", "manipulation",
                                                "quality", "gaze"))) %>%
    arrange(section, id)
}

#' Counts by status, for the one-line verdict.
checks_summary <- function(checks) {
  tab <- table(factor(checks$status,
                      levels = c("FAIL", "CHECK", "PASS", "SKIP", "INFO")))
  as.list(tab)
}

#' The check table as report text.
format_checks <- function(checks) {
  s <- checks_summary(checks)
  verdict <- if (s$FAIL > 0) {
    sprintf("STOP: %d check(s) FAILED -- the study is not running as designed.",
            s$FAIL)
  } else if (s$CHECK > 0) {
    sprintf("%d check(s) want a human look; no hard failures.", s$CHECK)
  } else {
    "No failures and nothing flagged for review."
  }

  lines <- c(
    "CHECKS",
    sprintf("  %s", verdict),
    sprintf("  FAIL=%d CHECK=%d PASS=%d SKIP=%d INFO=%d",
            s$FAIL, s$CHECK, s$PASS, s$SKIP, s$INFO),
    ""
  )

  for (sec in levels(checks$section)) {
    rows <- checks %>% filter(section == sec)
    if (nrow(rows) == 0) next
    lines <- c(lines, sprintf("  [%s]", toupper(sec)))
    for (i in seq_len(nrow(rows))) {
      lines <- c(lines, sprintf("    %-5s %-5s %s",
                                rows$id[[i]], rows$status[[i]], rows$detail[[i]]))
    }
    lines <- c(lines, "")
  }

  paste(lines, collapse = "\n")
}
