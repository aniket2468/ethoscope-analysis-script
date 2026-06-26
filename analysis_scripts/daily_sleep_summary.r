source("analysis_config.r")
source("exclude_pairs.r")

library(data.table)

SLEEP_BIN_MIN <- read_applied_bin(OUTPUT_DIR)
BINS_PER_DAY  <- (24 * 60) / SLEEP_BIN_MIN
cat("Sleep bin size:", SLEEP_BIN_MIN, "min (", BINS_PER_DAY, " bins/day)\n\n", sep = "")

FOCAL_BY_PAIR <- c("T1", "T3", "T5", "T7", "T9")
YOKED_BY_PAIR <- c("T12", "T14", "T16", "T18", "T20")

detect_ethoscopes <- function(output_dir) {
  focal_files <- list.files(output_dir, pattern = "^Sleep_(Eth\\d+)_Focal\\.txt$")
  if (length(focal_files) == 0) {
    stop("No Sleep_*_Focal.txt files in ", output_dir,
         ". Run create_sleep_files.r first.")
  }
  eth <- sub("^Sleep_(Eth\\d+)_Focal\\.txt$", "\\1", focal_files)
  eth[order(as.integer(sub("Eth", "", eth)))]
}

get_day_sleep <- function(vals, day) {
  start <- (day - 1) * BINS_PER_DAY + 1
  end   <- day * BINS_PER_DAY
  if (start > length(vals)) return(NA_real_)
  end <- min(end, length(vals))
  round(sum(vals[start:end], na.rm = TRUE), 1)
}

ETHOSCOPES <- detect_ethoscopes(OUTPUT_DIR)
cat("Detected ethoscopes:", paste(ETHOSCOPES, collapse = ", "), "\n")
if (apply_exclusions()) cat("Exclusions:", describe_exclusions(), "\n")

all_results <- list()

for (eth in ETHOSCOPES) {
  focal <- fread(file.path(OUTPUT_DIR, paste0("Sleep_", eth, "_Focal.txt")))
  yoked <- fread(file.path(OUTPUT_DIR, paste0("Sleep_", eth, "_Yoked.txt")))

  for (pair in 1:5) {
    if (apply_exclusions() && !pair_is_included(eth, pair)) next
    fcol <- FOCAL_BY_PAIR[pair]
    ycol <- YOKED_BY_PAIR[pair]
    if (!(fcol %in% names(focal)) || !(ycol %in% names(yoked))) next

    fvals <- focal[[fcol]]
    yvals <- yoked[[ycol]]

    all_results[[length(all_results) + 1]] <- data.table(
      ethoscope = eth, type = "Focal", pair = pair, tube = fcol,
      base = get_day_sleep(fvals, 1), sd = get_day_sleep(fvals, 2),
      rec1 = get_day_sleep(fvals, 3), rec2 = get_day_sleep(fvals, 4),
      rec3 = get_day_sleep(fvals, 5), rec4 = get_day_sleep(fvals, 6)
    )
    all_results[[length(all_results) + 1]] <- data.table(
      ethoscope = eth, type = "Yoked", pair = pair, tube = ycol,
      base = get_day_sleep(yvals, 1), sd = get_day_sleep(yvals, 2),
      rec1 = get_day_sleep(yvals, 3), rec2 = get_day_sleep(yvals, 4),
      rec3 = get_day_sleep(yvals, 5), rec4 = get_day_sleep(yvals, 6)
    )
  }
}

if (length(all_results) == 0) stop("No pair data found — check Sleep_* files in ", OUTPUT_DIR)

results <- rbindlist(all_results)
periods <- c("base", "sd", "rec1", "rec2", "rec3", "rec4")

summary_rows <- lapply(periods, function(period) {
  focal_avg <- round(mean(results[type == "Focal", get(period)], na.rm = TRUE), 1)
  yoked_avg <- round(mean(results[type == "Yoked", get(period)], na.rm = TRUE), 1)
  data.table(Period = period, Focal_Avg = focal_avg, Yoked_Avg = yoked_avg,
             Diff = round(focal_avg - yoked_avg, 1))
})
summary <- rbindlist(summary_rows)

out_file <- file.path(OUTPUT_DIR, paste0(
  "daily_sleep_summary", SUMMARY_CROP_TAG, FILTER_TAG(), "_",
  format(Sys.Date(), "%d_%b"), "_", SLEEP_BIN_MIN, "min.txt"
))

con <- file(out_file, open = "wt")
writeLines(sprintf("Daily Sleep Summary — %s", format(Sys.Date(), "%d %b %Y")), con)
writeLines(sprintf("Ethoscopes: %s", paste(ETHOSCOPES, collapse = ", ")), con)
writeLines(sprintf("Sleep bin size: %d min", SLEEP_BIN_MIN), con)
if (apply_exclusions()) {
  writeLines(sprintf("Exclusions: %s", describe_exclusions()), con)
}
writeLines(sprintf("Pairs included: Focal = %d | Yoked = %d",
                   nrow(results[type == "Focal"]), nrow(results[type == "Yoked"])), con)
writeLines("", con)
writeLines("Period\tFocal_Avg\tYoked_Avg\tDiff", con)
for (i in seq_len(nrow(summary))) {
  writeLines(sprintf("%s\t%s\t%s\t%s",
                     summary$Period[i], summary$Focal_Avg[i],
                     summary$Yoked_Avg[i], summary$Diff[i]), con)
}
close(con)

cat("\nSummary:\n")
print(summary)
cat(sprintf("\n✓ Saved: %s\n", out_file))
