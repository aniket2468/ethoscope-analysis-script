#!/usr/bin/env Rscript
# Main entry point — run from the project root (Ethoscope folder).

if (!dir.exists("analysis_scripts")) {
  stop("Run from the project root, where analysis_scripts/ and ethoscope_data/ live.\n",
       "  Example:  Rscript run_ethoscope_analysis.r")
}

scripts <- normalizePath("analysis_scripts", winslash = "/")

cat("\n╔══════════════════════════════════════════════════════╗\n")
cat("║         Ethoscope sleep analysis pipeline            ║\n")
cat("╚══════════════════════════════════════════════════════╝\n\n")

source(file.path(scripts, "install_dependencies.r"), local = TRUE)
if (length(missing_packages()) > 0L) install_if_missing()

source(file.path(scripts, "prompt_pipeline_settings.r"), local = TRUE)
prompt_pipeline_settings()
source(file.path(scripts, "analysis_config.r"), local = FALSE)

cat("Project:  ", PROJECT_ROOT, "\n")
cat("Data:     ", ETHOSCOPE_DATA_DIR, "\n")
cat("Output:   ", OUTPUT_DIR, "\n")
cat("Crop:     ", if (do_crop) "yes" else "no (uncropped)", "\n")
cat("Bin size: ", SLEEP_BIN_MIN, "min\n\n")

if (!dir.exists(ETHOSCOPE_DATA_DIR)) {
  stop("Missing ethoscope_data/ folder. See README.md for setup.")
}
dbs <- Sys.glob(file.path(ETHOSCOPE_DATA_DIR, "results", "*", "ETHOSCOPE_*", "*", "*.db"))
if (length(dbs) == 0L) {
  stop("No .db files in ethoscope_data/results/. Copy your Ethoscope results there first.")
}
cat("Found", length(dbs), ".db file(s). Starting pipeline...\n\n")

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

source(file.path(scripts, "run_analysis_pipeline.r"), local = TRUE)
run_pipeline_steps()

cat("\n✓ Done. Outputs in:\n  ", OUTPUT_DIR, "\n\n")
