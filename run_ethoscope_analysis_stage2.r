#!/usr/bin/env Rscript
# Stage 2 — edit analysis_scripts/exclude_pairs.r first, then run from project root.

if (!dir.exists("analysis_scripts")) {
  stop(
    "Run from the project root (same folder as run_ethoscope_analysis.r).\n",
    "  Example:  Rscript run_ethoscope_analysis_stage2.r"
  )
}

source(file.path(normalizePath("analysis_scripts", winslash = "/"), "run_stage2_filtered.r"))
