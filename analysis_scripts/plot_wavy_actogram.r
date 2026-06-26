source("analysis_config.r")
source("exclude_pairs.r")

library(data.table)
library(ggplot2)

SLEEP_BIN_MIN <- read_applied_bin(OUTPUT_DIR)
BIN_HOURS     <- SLEEP_BIN_MIN / 60
BINS_PER_DAY  <- (24 * 60) / SLEEP_BIN_MIN
plot_pre_baseline <- read_plot_pre_baseline(OUTPUT_DIR)
sd_anchors <- read_sd_anchors(OUTPUT_DIR)
use_anchored_time <- isTRUE(do_crop) && !is.null(sd_anchors)
cat("Sleep bin size:", SLEEP_BIN_MIN, "min\n")
if (plot_pre_baseline) cat("Pre-baseline actogram: days -1 to 0 (SD-anchored timeline)\n")
if (use_anchored_time) cat("Timeline anchored to baseline (day 0) and SD start (day 1)\n")
cat("\n")

detect_ethoscopes <- function(output_dir) {
  focal_files <- list.files(output_dir, pattern = "^Sleep_(Eth\\d+)_Focal\\.txt$")
  if (length(focal_files) == 0) {
    stop("No Sleep_*_Focal.txt files in ", output_dir,
         ". Run create_sleep_files.r first.")
  }
  eth <- sub("^Sleep_(Eth\\d+)_Focal\\.txt$", "\\1", focal_files)
  eth[order(as.integer(sub("Eth", "", eth)))]
}

ETHOSCOPES <- detect_ethoscopes(OUTPUT_DIR)
cat("Detected ethoscopes:", paste(ETHOSCOPES, collapse = ", "), "\n")
if (apply_exclusions()) cat("Exclusions:", describe_exclusions(), "\n")
cat("\n")

# 3. Yoking pairs.
PAIRS <- data.frame(
  pair       = c(1,  2,  3,  4,  5),
  focal_tube = c(1,  3,  5,  7,  9),   # RED   solid — focal
  yoked_tube = c(12, 14, 16, 18, 20)   # BLUE  dashed — yoked
)

# 4. Which pair numbers to include in the plot.
#    Use "all" to include every pair found, or a numeric vector e.g. c(1, 2).
PLOT_PAIRS <- "all"

# Line colours and legend text
FOCAL_COLOR <- "#E41A1C"            # red
YOKED_COLOR <- "#377EB8"            # blue
FOCAL_LABEL <- "Focal (Deprived)"
YOKED_LABEL <- "Yoked (Control)"

SKIP_ROWS <- 0

MAX_DAYS <- 6

OUTPUT_FILE <- paste0("Paired_Actogram", CROP_TAG, FILTER_TAG(), "_", format(Sys.Date(), "%d_%b"), "_", SLEEP_BIN_MIN, "min.pdf")

# Height scaling factor (e.g. 0.7 means sleep peak takes up 70% of the spacing between baseline rows, preventing overlap)
WAVE_SCALE <- 0.7

# PDF height: fixed inches per actogram row (so few rows = short page, not tall rows)
ROW_HEIGHT_IN <- 0.6
HEIGHT_EXTRA_IN <- 2   # title, legend, margins
PLOT_WIDTH_IN   <- if (SLEEP_BIN_MIN == 5) 48 else 16

# ============================================================
# LOAD DATA — No edits needed below this line
# ============================================================

cat("Loading data...\n\n")
all_data <- list()

for (eth in ETHOSCOPES) {
  sleep_suffix <- if (plot_pre_baseline &&
      file.exists(paste0(OUTPUT_DIR, "Sleep_", eth, "_Plot_Focal.txt"))) {
    "_Plot"
  } else {
    ""
  }
  focal_path <- paste0(OUTPUT_DIR, "Sleep_", eth, sleep_suffix, "_Focal.txt")
  yoked_path <- paste0(OUTPUT_DIR, "Sleep_", eth, sleep_suffix, "_Yoked.txt")

  if (!file.exists(focal_path) || !file.exists(yoked_path)) {
    cat("  ⚠ Skipping", eth, "— file(s) not found\n")
    next
  }

  focal <- fread(focal_path)
  yoked <- fread(yoked_path)

  focal_cols <- grep("^T[0-9]+$", names(focal), value = TRUE)
  yoked_cols <- grep("^T[0-9]+$", names(yoked), value = TRUE)

  if (length(focal_cols) == 0 && length(yoked_cols) == 0) {
    cat("  ⚠ Skipping", eth, "— no tube columns found\n")
    next
  }

  focal <- focal[, c("ZT", focal_cols), with = FALSE]
  yoked <- yoked[, c("ZT", yoked_cols), with = FALSE]

  focal_long <- melt(focal, id.vars = "ZT", variable.name = "tube_col", value.name = "sleep_min")
  focal_long[, `:=`(condition = "Focal", tube = as.integer(gsub("T", "", tube_col)))]

  yoked_long <- melt(yoked, id.vars = "ZT", variable.name = "tube_col", value.name = "sleep_min")
  yoked_long[, `:=`(condition = "Yoked", tube = as.integer(gsub("T", "", tube_col)))]

  dt_eth <- rbindlist(list(focal_long, yoked_long))
  dt_eth <- dt_eth[!is.na(sleep_min)]
  dt_eth[, ethoscope := eth]

  dt_eth[, row_num := seq_len(.N), by = .(tube, condition)]
  dt_eth[condition == "Focal", pair := PAIRS$pair[match(tube, PAIRS$focal_tube)]]
  dt_eth[condition == "Yoked", pair := PAIRS$pair[match(tube, PAIRS$yoked_tube)]]
  dt_eth <- dt_eth[!is.na(pair)]

  if (!identical(tolower(as.character(PLOT_PAIRS)), "all")) {
    dt_eth <- dt_eth[pair %in% as.integer(PLOT_PAIRS)]
  }

  if (apply_exclusions()) {
    dt_eth <- dt_eth[sapply(dt_eth$pair, function(p) pair_is_included(eth, p))]
  }

  if (nrow(dt_eth) == 0) {
    cat("  ⚠ Skipping", eth, "— no matching pairs found\n")
    next
  }

  found_focal <- sort(unique(dt_eth[condition == "Focal", tube]))
  found_yoked <- sort(unique(dt_eth[condition == "Yoked", tube]))
  cat(sprintf("  ✓ %-10s  focal: %-12s  yoked: %s\n",
              eth,
              paste0("T", found_focal, collapse = ", "),
              paste0("T", found_yoked, collapse = ", ")))

  all_data[[eth]] <- dt_eth
}

if (length(all_data) == 0) stop("No data loaded — check ETHOSCOPES and OUTPUT_DIR.")

dt <- rbindlist(all_data)

# ============================================================
# APPLY ROW SKIP
# ============================================================

dt <- dt[row_num > SKIP_ROWS]
dt[, row_num := row_num - SKIP_ROWS]

# ============================================================
# AUTO-DETECT DURATION FROM ALL LOADED FILES
# ============================================================

bin_hours <- BIN_HOURS
bin_mins  <- SLEEP_BIN_MIN

individual_max_rows <- dt[, .(max_row = max(row_num)), by = .(ethoscope, tube, condition)]

x_min <- if (plot_pre_baseline) -1 else 0

if (!is.null(MAX_DAYS)) {
  max_days <- MAX_DAYS
  if (use_anchored_time) {
    cat(sprintf("\nUsing fixed duration: %.2f days from baseline (day 0)\n", max_days))
  } else {
    max_row <- MAX_DAYS * 24 / bin_hours
    max_days <- MAX_DAYS
    cat(sprintf("\nUsing fixed duration: %.1f h (%.2f days)\n", max_row * bin_hours, max_days))
  }
} else {
  max_row  <- as.numeric(quantile(individual_max_rows$max_row, 0.95))
  max_days <- (max_row - 1) * bin_hours / 24
  cat(sprintf("\nAuto-detected recording duration: %.1f h (%.2f days)\n", max_row * bin_hours, max_days))
}

# Filter to duration — timeline from SD metadata when cropped
if (use_anchored_time) {
  dt[, days := NA_real_]
  for (eth in unique(dt$ethoscope)) {
    if (!eth %in% names(sd_anchors)) {
      dt[ethoscope == eth, days := (row_num - 1) * bin_hours / 24]
      next
    }
    for_plot <- isTRUE(plot_pre_baseline) &&
      file.exists(paste0(OUTPUT_DIR, "Sleep_", eth, "_Plot_Focal.txt"))
    file_start_t <- anchor_file_start_t(sd_anchors[[eth]], for_plot = for_plot)
    dt[ethoscope == eth, days := sleep_row_to_days_plot(
      row_num, SLEEP_BIN_MIN, sd_anchors[[eth]], file_start_t
    )]
  }
  dt <- dt[!is.na(days) & days >= x_min & days <= max_days + BIN_HOURS / 24]
} else {
  dt <- dt[row_num <= max_row]
  dt[, days := (row_num - 1) * bin_hours / 24]
}

dt[, sleep_norm := sleep_min / bin_mins]

# ============================================================
# BUILD PLOT ROW ORDER
# ============================================================

active_combos <- unique(dt[, .(ethoscope, pair)])
active_combos[, eth_order := match(ethoscope, ETHOSCOPES)]
setorder(active_combos, eth_order, -pair)
active_combos[, eth_order := NULL]
active_combos[, row_label := paste0(ethoscope, " Pair ", pair)]
active_combos[, row_idx := seq_len(.N)]

row_order <- active_combos$row_label
dt[, row_label := factor(paste0(ethoscope, " Pair ", pair), levels = row_order)]
dt[, y_pos     := as.numeric(row_label)]

n_rows <- length(row_order)
cat("Total pairs plotted:", n_rows, "\n")

# ============================================================
# ETHOSCOPE GROUP LABELS (dynamically placed)
# ============================================================

eth_label_dt <- active_combos[, .(mid_y = mean(seq_len(.N) + min(which(row_order %in% paste0(ethoscope, " Pair ", pair))) - 1)),
                               by = ethoscope]
eth_label_dt[, mid_y := sapply(ethoscope, function(e) {
  rows_for_eth <- which(active_combos$ethoscope == e)
  mean(rows_for_eth)
})]
eth_label_dt[, label := ethoscope]

# ============================================================
# X-AXIS BREAKS — scaled to actual duration
# ============================================================

x_max <- ceiling(max_days * 4) / 4   # round up to nearest 0.25 day

x_break_interval <- if (max_days <= 1.5) 0.25 else if (max_days <= 4) 0.5 else 1.0
x_breaks <- seq(x_min, x_max, by = x_break_interval)

# Left-margin x position for ethoscope labels
label_x <- x_min - (x_max - x_min) * 0.15

# ============================================================
# BUILD PLOT
# ============================================================

# Pre-compute dynamic ethoscope label annotations
eth_annotations <- lapply(seq_len(nrow(eth_label_dt)), function(i) {
  annotate("text",
           x        = label_x,
           y        = eth_label_dt$mid_y[i],
           label    = eth_label_dt$label[i],
           fontface = "bold",
           size     = 4,
           hjust    = 1)
})

p <- ggplot(dt, aes(
    x     = days,
    y     = y_pos + sleep_norm * WAVE_SCALE,
    group = interaction(row_label, condition)
  )) +

  geom_line(aes(linetype = condition, color = condition), linewidth = 0.5) +
  geom_hline(yintercept = seq_len(n_rows), color = "gray85", linewidth = 0.3) +

  eth_annotations +

  scale_linetype_manual(
    values = c("Focal" = "solid",   "Yoked" = "dashed"),
    name   = NULL,
    labels = c("Focal" = FOCAL_LABEL, "Yoked" = YOKED_LABEL)
  ) +
  scale_color_manual(
    values = c("Focal" = FOCAL_COLOR, "Yoked" = YOKED_COLOR),
    name   = NULL,
    labels = c("Focal" = FOCAL_LABEL, "Yoked" = YOKED_LABEL)
  ) +
  scale_y_continuous(
    breaks = seq_len(n_rows),
    labels = row_order,
    expand = c(0.02, 0.02)
  ) +
  scale_x_continuous(
    breaks = x_breaks,
    labels = x_breaks
  ) +

  labs(
    title    = "Sleep Actogram: Focal vs Yoked Pairs",
    subtitle = sprintf(
      "Solid = %s  |  Dashed = %s  |  Upward = Sleeping  |  %d-min bins%s",
      FOCAL_LABEL, YOKED_LABEL, SLEEP_BIN_MIN,
      if (plot_pre_baseline) "  |  Day 0 = baseline, day 1 = SD start" else ""
    ),
    x = "Days",
    y = NULL
  ) +

  theme_minimal(base_size = 13) +
  theme(
    axis.text.y        = element_text(size = 10, face = "bold"),
    axis.text.x        = element_text(size = 11),
    axis.title         = element_text(size = 13, face = "bold"),
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_line(color = "gray85", linewidth = 0.4),
    legend.position    = "top",
    plot.title         = element_text(hjust = 0.5, face = "bold", size = 17),
    plot.subtitle      = element_text(hjust = 0.5, size = 11, color = "gray40"),
    plot.margin        = margin(10, 10, 10, 120)
  ) +
  coord_cartesian(xlim = c(x_min, x_max), clip = "off")

# ============================================================
# SAVE
# ============================================================

plot_height <- n_rows * ROW_HEIGHT_IN + HEIGHT_EXTRA_IN
out_path    <- paste0(OUTPUT_DIR, OUTPUT_FILE)
ggsave(out_path, p, width = PLOT_WIDTH_IN, height = plot_height, limitsize = FALSE)

cat(sprintf("\n✓ Saved: %s  (%.0f rows × %.0f × %.1f inches)\n",
            out_path, n_rows, PLOT_WIDTH_IN, plot_height))
