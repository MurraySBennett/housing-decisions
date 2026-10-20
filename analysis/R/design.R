# design.R -- the design constants, and the assignments they predict.
#
# THIS FILE IS A MIRROR OF MATLAB, AND MIRRORS DRIFT.
#
# Every constant below is duplicated from +utils/config.m or a task file, and
# every function reproduces a MATLAB counterbalancing rule. Nothing reads the
# MATLAB at run time -- parsing config.m is more fragile than the drift it would
# protect against -- so a changed constant on the MATLAB side is a deliberate
# one-file edit here. The provenance column in design_spec() is what makes that
# edit findable: grep the MATLAB path, not the number.
#
# The check that this file has not drifted is the data itself. If MATLAB starts
# writing 30 auction trials and this says 24, checks.R reports a FAIL on real
# data -- which is the correct outcome, because one of the two is wrong and a
# human has to say which.

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
})

#' Design constants, with the MATLAB source of each.
#'
#' Flat on purpose: one lookup, `design_spec()$auction_n_trials`, and one table
#' to print in the report so the expectations are visible rather than implied.
design_spec <- function() {
  list(
    # ---- session structure ------------------------------------------------
    tasks                = c("auction", "contdc", "pref"),  # +utils/batteryPlan.m:25-29
    session_num          = 1L,                              # +utils/batteryPlan.m:11-15
    domains              = c("jobs", "houses"),             # +utils/batteryPlan.m:17
    n_task_orders        = 6L,                              # +utils/batteryPlan.m:48-50

    # ---- auction ----------------------------------------------------------
    auction_n_trials     = 24L,   # cfg.auction.nTrials, +utils/config.m:171
    auction_n_blocks     = 4L,    # cfg.auction.nBlocks, +utils/config.m:171-174
    auction_n_options    = 12L,   # cfg.auction.nOptionsPerTrial, +utils/config.m:171-174
    auction_n_attrs      = 6L,    # fixed at 6 attributes, experiment/README.md "Design knobs"
    auction_n_practice   = 1L,    # auction_task.m:252-262
    auction_timeout_sec  = 90,    # cfg.auction.trialTimeoutSec, +utils/config.m
    auction_min_after_retire = 6L,# cfg.auction.minOptionsAfterRetire, auction_task.m:374-379
    competition_levels   = c("low", "high"),                # +utils/trialPlan.m
    end_reasons          = c("accepted", "timeout", "exhausted"),

    # ---- continuous / discrete choice -------------------------------------
    attr_levels          = c(2L, 4L, 6L),  # cfg.attrLevels, +utils/config.m
    contdc_n_pairs       = c(jobs = 20L, houses = 20L),  # cfg.contdc.nPairs, +utils/config.m:202-203
    contdc_task_types    = c("choice", "price"),
    contdc_n_blocks      = 6L,    # 3 levels x 2 task types, continuous_DC_task.m:478-484
    contdc_drift_every   = 2L,    # cfg.contdc.driftEvery, +utils/config.m:212

    # ---- preference -------------------------------------------------------
    pref_n_rating_houses = 60L,   # N_RATING, preference_task.m:9
    pref_n_pwc_houses    = 160L,  # N_PWC_HOUSES, preference_task.m:10
    pref_n_pwc_jobs      = 160L,  # N_PWC_JOBS, preference_task.m:11
    pref_areas           = c("extPic", "kitPic", "bedPic",
                             "bathPic", "livPic", "outPic"),  # AREA_QUOTAS, preference_task.m:17-24
    pref_area_quota      = 10L,   # AREA_QUOTAS, preference_task.m:17-24

    # ---- sampling window --------------------------------------------------
    sampling_spread      = c(0.6, 1.6),  # cfg.sampling.spread, +utils/config.m:152-167
    sampling_min_n       = 12L,          # cfg.sampling.minN, +utils/config.m:152-167
    fit_to_window        = c(jobs = TRUE, houses = TRUE),  # +utils/config.m:152-167

    # ---- eye tracking -----------------------------------------------------
    et_sample_rate_hz    = 60,    # cfg.et.sampleRateHz, +utils/config.m:220
    et_drift_tol_deg     = 1.5,   # cfg.et.driftTolDeg, +utils/config.m:222
    aoi_min_deg          = 1.5,   # geom.minAOIDeg, +utils/geom.m:28-34
    aoi_min_sep_deg      = 2.0,   # geom.minSepDeg, +utils/geom.m:28-34

    # ---- QC thresholds ----------------------------------------------------
    # Not mirrored from MATLAB -- chosen here, and the only numbers in this file
    # that are a judgement call rather than a duplicated constant.
    qc = list(
      rt_implausible_sec   = 0.25,  # faster than this is not a decision
      rt_implausible_max   = 0.02,  # at most 2% of trials may be that fast
      timeout_rate_max     = 0.10,
      side_bias_max        = 0.70,  # |p(left) - 0.5| beyond this is a strategy
      gaze_valid_min       = 0.75,  # per-run valid-sample fraction floor
      gaze_outside_max     = 0.15,
      gaze_rate_tol        = 0.15,  # |observed / expected - 1| per block
      exposure_tol         = 2L,    # slack on the near-uniform exposure band
      reversal_rate_max    = 0.50
    )
  )
}

# ---- Predicted assignments -------------------------------------------------
# Each mirrors one MATLAB rule. These are the whole point of the counterbalance
# section: every assignment is a deterministic function of the participant
# number, so "was this participant run correctly" is a comparison, not a guess.

#' Assigned domain. Odd IDs jobs, even IDs houses.
#' Mirrors +utils/batteryPlan.m:17.
expected_domain <- function(participant) {
  ifelse(as.integer(participant) %% 2L == 1L, "jobs", "houses")
}

#' The six task orders, in MATLAB's `sortrows(perms(1:3))` order.
#'
#' sortrows() pins the list so perms()' own row order is an implementation
#' detail (+utils/batteryPlan.m:44-50); sorted permutations of 1:3 are plain
#' lexicographic, which is what this reproduces.
task_order_table <- function(tasks = design_spec()$tasks) {
  perms_lex <- list(c(1, 2, 3), c(1, 3, 2), c(2, 1, 3),
                    c(2, 3, 1), c(3, 1, 2), c(3, 2, 1))
  lapply(perms_lex, function(ix) tasks[ix])
}

#' Task order for one participant: slot `mod(ceil(p/2) - 1, 6) + 1`.
#' Mirrors +utils/batteryPlan.m:32-50. Parity picks the DOMAIN; ceil(p/2) the order.
expected_task_order <- function(participant, tasks = design_spec()$tasks) {
  slot <- (ceiling(as.integer(participant) / 2L) - 1L) %% 6L + 1L
  task_order_table(tasks)[[slot]]
}

expected_task_order_slot <- function(participant) {
  (ceiling(as.integer(participant) / 2L) - 1L) %% 6L + 1L
}

#' Auction competition level per trial: ABBA over blocks, start level by parity.
#'
#' Mirrors +utils/trialPlan.m:42-59 exactly, including the index arithmetic:
#'   which = 1 + mod(floor((b-1)/2) + (b-1) + startsHigh, 2)
#' which walks A B B A over four blocks. ABBA rather than ABAB is deliberate --
#' it puts both levels at the same mean serial position, so competition is
#' orthogonal to fatigue and practice within a participant (trialPlan.m:52-53).
expected_competition_sequence <- function(participant,
                                          n_trials = design_spec()$auction_n_trials,
                                          n_blocks = design_spec()$auction_n_blocks,
                                          levels = design_spec()$competition_levels) {
  per_block <- n_trials %/% n_blocks
  starts_high <- as.integer(as.integer(participant) %% 2L == 1L)
  which_level <- vapply(seq_len(n_blocks), function(b) {
    1L + ((b - 1L) %/% 2L + (b - 1L) + starts_high) %% 2L
  }, integer(1))
  rep(levels[which_level], each = per_block)
}

#' Which competition level block 1 uses. Odd participants start high.
#' Mirrors +utils/trialPlan.m:42-47.
expected_start_competition <- function(participant,
                                       levels = design_spec()$competition_levels) {
  expected_competition_sequence(participant, levels = levels)[[1]]
}

#' contdc task-type order: even participants get choice first.
#' Mirrors continuous_DC_task.m:471-476 (buildBlocks).
expected_contdc_type_order <- function(participant) {
  if (as.integer(participant) %% 2L == 0L) c("choice", "price") else c("price", "choice")
}

#' Expected contdc rows for one block, by task type. Vectorised over both args.
#' choice = one row per pair; price = two rows per pair, both options priced
#' separately (continuous_DC_task.m:349).
expected_contdc_rows <- function(task_type, domain, spec = design_spec()) {
  np <- unname(spec$contdc_n_pairs[as.character(domain)])
  as.integer(ifelse(as.character(task_type) == "choice", np, 2L * np))
}

#' Expected pref row counts for a domain.
expected_pref_rows <- function(domain, spec = design_spec()) {
  if (identical(domain, "houses")) {
    c(rating = spec$pref_n_rating_houses, pwc = spec$pref_n_pwc_houses)
  } else {
    c(rating = 0L, pwc = spec$pref_n_pwc_jobs)
  }
}

#' The provenance table, printed into the integrity report so the expectations
#' this pipeline enforces are visible rather than implicit.
design_provenance <- function() {
  spec <- design_spec()
  tribble(
    ~constant,                  ~value,                                      ~source,
    "tasks per session",        paste(spec$tasks, collapse = ", "),          "+utils/batteryPlan.m:25-29",
    "domain assignment",        "odd=jobs, even=houses",                     "+utils/batteryPlan.m:17",
    "task-order slot",          "mod(ceil(p/2)-1,6)+1 of sortrows(perms(1:3))", "+utils/batteryPlan.m:32-50",
    "auction trials",           as.character(spec$auction_n_trials),         "+utils/config.m:171",
    "auction blocks",           paste0(spec$auction_n_blocks, " (ABBA)"),    "+utils/trialPlan.m:49-59",
    "auction start level",      "odd=high, even=low",                        "+utils/trialPlan.m:42-47",
    "auction options/trial",    as.character(spec$auction_n_options),        "+utils/config.m:171-174",
    "attribute levels",         paste(spec$attr_levels, collapse = "/"),     "+utils/config.m (cfg.attrLevels)",
    "contdc pairs/level",       as.character(spec$contdc_n_pairs[["houses"]]), "+utils/config.m:202-203",
    "contdc type order",        "even=choice first",                         "continuous_DC_task.m:471-476",
    "pref houses",              paste0(spec$pref_n_rating_houses, " rating + ",
                                       spec$pref_n_pwc_houses, " pwc"),      "preference_task.m:9-10",
    "pref jobs",                paste0(spec$pref_n_pwc_jobs, " pwc"),        "preference_task.m:11",
    "gaze sample rate",         paste0(spec$et_sample_rate_hz, " Hz"),       "+utils/config.m:220",
    "drift tolerance",          paste0(spec$et_drift_tol_deg, " deg"),       "+utils/config.m:222"
  )
}
