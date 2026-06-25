#!/usr/bin/env Rscript

PIPELINE_SCRIPTS <- c(
  "extract_ethoscope_data.r",
  "ethoscope_10sec_bins.r",
  "create_sleep_files.r",
  "plot_wavy_actogram.r",
  "daily_sleep_summary.r"
)

run_pipeline_steps <- function() {
  for (i in seq_along(PIPELINE_SCRIPTS)) {
    script <- PIPELINE_SCRIPTS[i]
    cat(sprintf("\n[%d/%d] Running %s\n", i, length(PIPELINE_SCRIPTS), script))
    cat(strrep("=", 50), "\n\n")
    run_r_script(script)
  }
  cat("\n", strrep("=", 50), "\n✓ Pipeline complete.\n", sep = "")
}

if (sys.nframe() == 0L) {
  script_dir <- if (file.exists("analysis_config.r")) {
    normalizePath(getwd(), winslash = "/")
  } else if (dir.exists("analysis_scripts")) {
    normalizePath("analysis_scripts", winslash = "/")
  } else {
    stop("Run from the project root or analysis_scripts/ folder.")
  }

  cat("=== Ethoscope analysis pipeline ===\n")
  source(file.path(script_dir, "prompt_pipeline_settings.r"), local = TRUE)
  prompt_pipeline_settings()
  source(file.path(script_dir, "analysis_config.r"), local = TRUE)
  cat(sprintf("Config: do_crop = %s | SLEEP_BIN_MIN = %d min\n\n", do_crop, SLEEP_BIN_MIN))
  run_pipeline_steps()
}
