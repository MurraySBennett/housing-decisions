# plots.R -- descriptive figures, one per manipulation; no models, no inference.
# Colour: palette slots 1-3 only; colourblind separation clears the floor for three.

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(scales)
})

PAL <- c("#2a78d6", "#eb6834", "#1baf7a")   # blue, orange, aqua
INK_PRIMARY   <- "#1a1a19"
INK_SECONDARY <- "#5c5b54"
GRID          <- "#e4e3dd"

theme_hw <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      text             = element_text(colour = INK_PRIMARY),
      plot.title       = element_text(face = "bold", size = base_size * 1.15,
                                      margin = margin(b = 2)),
      plot.subtitle    = element_text(colour = INK_SECONDARY, size = base_size * 0.9,
                                      margin = margin(b = 10)),
      plot.caption     = element_text(colour = INK_SECONDARY, size = base_size * 0.8,
                                      hjust = 0, margin = margin(t = 10)),
      axis.title       = element_text(colour = INK_SECONDARY, size = base_size * 0.9),
      axis.text        = element_text(colour = INK_SECONDARY, size = base_size * 0.85),
      panel.grid.major = element_line(colour = GRID, linewidth = 0.3),
      panel.grid.minor = element_blank(),
      panel.spacing    = unit(1.1, "lines"),
      strip.text       = element_text(colour = INK_PRIMARY, face = "bold",
                                      size = base_size * 0.9),
      legend.position  = "top",
      legend.title     = element_text(colour = INK_SECONDARY, size = base_size * 0.85),
      legend.text      = element_text(size = base_size * 0.85),
      legend.key.size  = unit(0.8, "lines"),
      plot.title.position = "plot",
      plot.caption.position = "plot"
    )
}

COMP_COLS <- c(low = PAL[1], high = PAL[2])

# Separate colour/fill helpers: an unused scale makes ggplot warn.
scale_competition_colour <- function()
  scale_colour_manual(values = COMP_COLS, name = "Competition", drop = FALSE)

scale_competition_fill <- function()
  scale_fill_manual(values = COMP_COLS, name = "Competition", drop = FALSE)

# ---- Design coverage ------------------------------------------------------
plot_design_coverage <- function(auction, contdc) {
  parts <- list()

  if (!is.null(auction)) {
    d <- auction %>% filter(!practice) %>% count(domain, competition, .drop = FALSE)
    parts$auction <- ggplot(d, aes(competition, n, fill = competition)) +
      geom_col(width = 0.6) +
      geom_text(aes(label = n), vjust = -0.4, size = 3.2, colour = INK_SECONDARY) +
      facet_wrap(~ domain) +
      scale_competition_fill() +
      scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
      labs(title = "Auction: trials per competition level",
           subtitle = "Real search episodes; practice excluded",
           x = NULL, y = "trials") +
      theme_hw() + theme(legend.position = "none")
  }

  if (!is.null(contdc)) {
    d <- contdc %>% count(domain, attrLevel, taskType, .drop = FALSE)
    parts$contdc <- ggplot(d, aes(attrLevel, n, fill = taskType)) +
      geom_col(position = position_dodge(width = 0.72), width = 0.62) +
      facet_wrap(~ domain) +
      scale_fill_manual(values = c(choice = PAL[1], price = PAL[3]),
                        name = "Block type", drop = FALSE) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
      labs(title = "Continuous / DC: rows per attribute level",
           subtitle = "A choice block and a pricing block at each level; pricing has two rows per pair",
           x = "attributes shown", y = "rows") +
      theme_hw()
  }

  parts
}

# ---- Auction --------------------------------------------------------------

plot_bid_vs_value <- function(auction) {
  d <- auction %>% filter(!practice, !is.na(bid), !is.na(trueValue))
  if (nrow(d) == 0) return(NULL)

  ggplot(d, aes(trueValue, bid, colour = competition)) +
    geom_abline(slope = 1, intercept = 0, linewidth = 0.4,
                colour = INK_SECONDARY, linetype = "22") +
    geom_point(size = 2.2, alpha = 0.85) +
    facet_wrap(~ domain, scales = "free") +
    scale_competition_colour() +
    scale_x_continuous(labels = label_number(big.mark = ",")) +
    scale_y_continuous(labels = label_number(big.mark = ",")) +
    labs(title = "Bid against the item's true value",
         subtitle = "Dashed line is bid = value. Houses: bidding to buy. Jobs: asking a wage.",
         x = "true value", y = "bid",
         caption = "BDM clearing means a cleared bid transacts at the market threshold, not at the bid.") +
    theme_hw()
}

plot_auction_outcomes <- function(auction) {
  d <- auction %>%
    filter(!practice, !is.na(endReason)) %>%
    count(domain, competition, endReason, .drop = FALSE) %>%
    group_by(domain, competition) %>%
    mutate(prop = ifelse(sum(n) == 0, NA_real_, n / sum(n))) %>%
    ungroup() %>%
    filter(!is.na(prop))
  if (nrow(d) == 0) return(NULL)

  ggplot(d, aes(endReason, prop, fill = competition)) +
    geom_col(position = position_dodge(width = 0.75), width = 0.64) +
    facet_wrap(~ domain) +
    scale_competition_fill() +
    scale_y_continuous(labels = percent_format(accuracy = 1),
                       limits = c(0, 1), expand = expansion(mult = c(0, 0.05))) +
    labs(title = "How each search episode ended",
         subtitle = "High competition should clear fewer bids -- the threshold is stochastic, so it shifts the odds rather than forbidding a win",
         x = NULL, y = "share of episodes") +
    theme_hw()
}

plot_search_effort <- function(auction) {
  d <- auction %>%
    filter(!practice) %>%
    tidyr::pivot_longer(c(nPresented, nRejected, durationSec),
                        names_to = "measure", values_to = "value") %>%
    filter(!is.na(value)) %>%
    mutate(measure = recode(measure,
                            nPresented  = "options seen",
                            nRejected   = "options rejected",
                            durationSec = "episode duration (s)"),
           measure = factor(measure, levels = c("options seen", "options rejected",
                                                "episode duration (s)")))
  if (nrow(d) == 0) return(NULL)

  ggplot(d, aes(competition, value, colour = competition)) +
    geom_boxplot(outlier.shape = NA, width = 0.45, linewidth = 0.5, fill = NA) +
    geom_jitter(width = 0.13, height = 0, size = 1.6, alpha = 0.6) +
    facet_grid(measure ~ domain, scales = "free_y", switch = "y") +
    scale_competition_colour() +
    labs(title = "Search effort per episode",
         subtitle = "Each point is one search episode",
         x = NULL, y = NULL) +
    theme_hw() +
    theme(legend.position = "none", strip.placement = "outside")
}

plot_surplus <- function(auction) {
  d <- auction %>% filter(!practice, !is.na(surplus))
  if (nrow(d) == 0) return(NULL)

  ggplot(d, aes(competition, surplus, colour = competition)) +
    geom_hline(yintercept = 0, linewidth = 0.4, colour = INK_SECONDARY) +
    geom_jitter(width = 0.14, height = 0, size = 2.1, alpha = 0.8) +
    stat_summary(fun = mean, geom = "point", shape = 95, size = 14,
                 colour = INK_PRIMARY) +
    facet_wrap(~ domain, scales = "free_y") +
    scale_competition_colour() +
    scale_y_continuous(labels = label_number(big.mark = ",")) +
    labs(title = "Surplus on cleared transactions",
         subtitle = "Value minus price paid (houses), price received minus value (jobs). Black bar is the mean.",
         x = NULL, y = "surplus",
         caption = "Thresholds carry noise on purpose: without it, high competition makes surplus negative by construction.") +
    theme_hw() + theme(legend.position = "none")
}

# ---- Continuous / discrete choice -----------------------------------------

plot_contdc_rt <- function(contdc) {
  d <- contdc %>% filter(!timedOut, !is.na(rt))
  if (nrow(d) == 0) return(NULL)

  ggplot(d, aes(attrLevel, rt, colour = taskType)) +
    geom_jitter(position = position_jitterdodge(jitter.width = 0.12,
                                                dodge.width = 0.6),
                size = 1.7, alpha = 0.6) +
    stat_summary(fun = mean, geom = "point", size = 3.2, shape = 18,
                 position = position_dodge(width = 0.6)) +
    facet_wrap(~ domain) +
    scale_colour_manual(values = c(choice = PAL[1], price = PAL[3]),
                        name = "Block type", drop = FALSE) +
    labs(title = "Response time by attribute load",
         subtitle = "More attributes should cost more time. Diamonds are means; timed-out trials excluded.",
         x = "attributes shown", y = "RT (s)") +
    theme_hw()
}

plot_choice_share <- function(contdc) {
  d <- contdc %>%
    filter(taskType == "choice", !timedOut, !is.na(choseMoney)) %>%
    group_by(domain, attrLevel) %>%
    summarise(p = mean(choseMoney), n = dplyr::n(), .groups = "drop")
  if (nrow(d) == 0) return(NULL)

  ggplot(d, aes(attrLevel, p)) +
    geom_hline(yintercept = 0.5, linewidth = 0.4, colour = INK_SECONDARY,
               linetype = "22") +
    geom_col(width = 0.55, fill = PAL[1]) +
    geom_text(aes(label = sprintf("%.0f%%\nn=%d", 100 * p, n)),
              vjust = -0.25, size = 3, colour = INK_SECONDARY, lineheight = 0.95) +
    facet_wrap(~ domain) +
    scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 1.15),
                       breaks = seq(0, 1, 0.25), expand = expansion(mult = c(0, 0))) +
    labs(title = "Share of choices going to the money-favouring option",
         subtitle = "Dashed line is indifference. One series, so the title names it and no legend is needed.",
         x = "attributes shown", y = "share of choices") +
    theme_hw()
}

plot_price_by_option <- function(contdc) {
  d <- contdc %>%
    filter(taskType == "price", !is.na(price), !is.na(isMoneyOption)) %>%
    mutate(option = factor(ifelse(isMoneyOption, "money-favouring", "quality-favouring"),
                           levels = c("money-favouring", "quality-favouring")))
  if (nrow(d) == 0) return(NULL)

  ggplot(d, aes(attrLevel, price, colour = option)) +
    geom_jitter(position = position_jitterdodge(jitter.width = 0.12,
                                                dodge.width = 0.6),
                size = 1.8, alpha = 0.65) +
    stat_summary(fun = mean, geom = "point", size = 3.2, shape = 18,
                 position = position_dodge(width = 0.6)) +
    facet_wrap(~ domain, scales = "free_y") +
    scale_colour_manual(values = c("money-favouring" = PAL[1],
                                   "quality-favouring" = PAL[2]),
                        name = "Option", drop = FALSE) +
    scale_y_continuous(labels = label_number(big.mark = ",")) +
    labs(title = "Price assigned to each option in a pair",
         subtitle = "Both options in every pair are priced separately; the pair is the same one that was chosen between",
         x = "attributes shown", y = "price") +
    theme_hw()
}

plot_reversals <- function(rev) {
  if (is.null(rev) || nrow(rev) == 0) return(NULL)

  d <- rev %>%
    group_by(domain, attrLevel) %>%
    summarise(p = mean(reversal), n = dplyr::n(), .groups = "drop")

  ggplot(d, aes(attrLevel, p)) +
    geom_col(width = 0.55, fill = PAL[2]) +
    geom_text(aes(label = sprintf("%.0f%%\nn=%d", 100 * p, n)),
              vjust = -0.25, size = 3, colour = INK_SECONDARY, lineheight = 0.95) +
    facet_wrap(~ domain) +
    # Free y: reversal rates sit well below 50%; a 0-100% axis would squash the bars.
    scale_y_continuous(labels = percent_format(accuracy = 1),
                       expand = expansion(mult = c(0, 0.22))) +
    labs(title = "Preference reversals by attribute load",
         subtitle = "Chose one option but priced the other higher. Recomputed here from the CSV alone.",
         x = "attributes shown", y = "share of scorable pairs",
         caption = "n is scorable pairs, not trials: a pair needs a non-timed-out choice and both of its prices.") +
    theme_hw()
}
