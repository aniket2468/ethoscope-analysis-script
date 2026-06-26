#!/usr/bin/env Rscript

script_dir <- if (file.exists("analysis_config.r")) {
  normalizePath(getwd(), winslash = "/")
} else if (dir.exists("analysis_scripts")) {
  normalizePath("analysis_scripts", winslash = "/")
} else {
  stop("Run from the project root or analysis_scripts/ folder.")
}

cat("\n=== Stage 2: filtered actogram + daily sleep summary ===\n\n")

source(file.path(script_dir, "prompt_pipeline_settings.r"), local = TRUE)
prompt_pipeline_settings(force = TRUE)

source(file.path(script_dir, "analysis_config.r"), local = TRUE)
source(file.path(script_dir, "exclude_pairs.r"), local = TRUE)

if (!dir.exists(OUTPUT_DIR)) {
  stop("No analysis_output/ — run Stage 1 first (run_ethoscope_analysis.r).")
}
if (!file.exists(file.path(OUTPUT_DIR, ".sleep_bin_min"))) {
  stop("Stage 1 outputs missing — run the full pipeline first.")
}

cat("Settings: crop =", if (do_crop) "yes" else "no",
    "| pre-baseline plot =", if (plot_pre_baseline) "yes" else "no",
    "| bin =", SLEEP_BIN_MIN, "min\n\n")

eth_in_run <- detect_ethoscopes(OUTPUT_DIR)
if (length(eth_in_run) > 0L) {
  cat("Ethoscopes:", paste(eth_in_run, collapse = ", "), "\n\n")
}

cat("Exclusions:\n  ", describe_exclusions(), "\n\n", sep = "")

Sys.setenv(ETHOSCOPE_APPLY_EXCLUSIONS = "1")

stored_bin <- as.integer(readLines(file.path(OUTPUT_DIR, ".sleep_bin_min"), n = 1L))
if (stored_bin != SLEEP_BIN_MIN) {
  cat("Regenerating Sleep_* files for", SLEEP_BIN_MIN, "min bins...\n\n")
  run_r_script("create_sleep_files.r")
}

for (i in seq_along(c("plot_wavy_actogram.r", "daily_sleep_summary.r"))) {
  script <- c("plot_wavy_actogram.r", "daily_sleep_summary.r")[i]
  cat(sprintf("[%d/2] %s\n", i, script), strrep("-", 50), "\n\n", sep = "")
  run_r_script(script)
  cat("\n")
}

cat("✓ Stage 2 complete.\n\n")
