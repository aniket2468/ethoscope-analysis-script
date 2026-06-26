# Project paths — auto-detected from project root or analysis_scripts/

if (file.exists("analysis_config.r")) {
  SCRIPTS_DIR  <- normalizePath(getwd(), winslash = "/")
  PROJECT_ROOT <- normalizePath("..", winslash = "/")
} else if (dir.exists("analysis_scripts")) {
  PROJECT_ROOT <- normalizePath(getwd(), winslash = "/")
  SCRIPTS_DIR  <- normalizePath("analysis_scripts", winslash = "/")
} else {
  stop("Run from the project root:  Rscript run_ethoscope_analysis.r")
}

OUTPUT_DIR         <- paste0(normalizePath(file.path(PROJECT_ROOT, "analysis_output"), winslash = "/"), "/")
ETHOSCOPE_DATA_DIR <- normalizePath(file.path(PROJECT_ROOT, "ethoscope_data"), winslash = "/")

DEFAULT_DO_CROP <- FALSE
DEFAULT_PLOT_PRE_BASELINE <- FALSE
DEFAULT_SLEEP_BIN_MIN <- 60

ALLOWED_SLEEP_BINS <- c(5, 30, 60)

crop_env <- Sys.getenv("ETHOSCOPE_DO_CROP", unset = "")
prebase_env <- Sys.getenv("ETHOSCOPE_PLOT_PRE_BASELINE", unset = "")
bin_env  <- Sys.getenv("ETHOSCOPE_SLEEP_BIN_MIN", unset = "")

if (nzchar(crop_env)) {
  do_crop <- identical(toupper(crop_env), "TRUE")
} else {
  do_crop <- DEFAULT_DO_CROP
}

if (nzchar(prebase_env)) {
  plot_pre_baseline <- identical(toupper(prebase_env), "TRUE")
} else {
  plot_pre_baseline <- DEFAULT_PLOT_PRE_BASELINE
}
if (!isTRUE(do_crop)) plot_pre_baseline <- FALSE

if (nzchar(bin_env)) {
  SLEEP_BIN_MIN <- as.integer(bin_env)
} else {
  SLEEP_BIN_MIN <- DEFAULT_SLEEP_BIN_MIN
}

if (!SLEEP_BIN_MIN %in% ALLOWED_SLEEP_BINS) {
  stop("SLEEP_BIN_MIN must be one of ", paste(ALLOWED_SLEEP_BINS, collapse = ", "))
}

BIN_HOURS    <- SLEEP_BIN_MIN / 60
BINS_PER_DAY <- (24 * 60) / SLEEP_BIN_MIN
SUMMARY_CROP_TAG <- if (!isTRUE(do_crop)) "_uncropped" else ""
CROP_TAG <- if (!isTRUE(do_crop)) {
  "_uncropped"
} else if (isTRUE(plot_pre_baseline)) {
  "_prebase"
} else {
  ""
}

read_plot_pre_baseline <- function(output_dir) {
  if (!isTRUE(do_crop)) return(FALSE)
  prebase_env <- Sys.getenv("ETHOSCOPE_PLOT_PRE_BASELINE", unset = "")
  if (nzchar(prebase_env)) return(identical(toupper(prebase_env), "TRUE"))
  marker <- file.path(output_dir, ".plot_pre_baseline")
  if (file.exists(marker)) return(identical(readLines(marker, n = 1L), "TRUE"))
  FALSE
}

read_sd_anchors <- function(output_dir) {
  path <- file.path(output_dir, ".sd_anchors.rds")
  if (!file.exists(path)) return(NULL)
  readRDS(path)
}

sleep_row_to_days <- function(row_num, bin_min, anchor, file_start_t = NULL) {
  bin_sec <- bin_min * 60
  baseline_t <- anchor$baseline_start_unix - anchor$exp_start_unix
  start_t <- if (is.null(file_start_t)) baseline_t else file_start_t
  bin_mid_t <- start_t + (row_num - 0.5) * bin_sec
  (bin_mid_t - baseline_t) / 86400
}

# Plot at bin start so day boundaries (0, 1, 2…) align with vertical guides
sleep_row_to_days_plot <- function(row_num, bin_min, anchor, file_start_t = NULL) {
  bin_sec <- bin_min * 60
  baseline_t <- anchor$baseline_start_unix - anchor$exp_start_unix
  start_t <- if (is.null(file_start_t)) baseline_t else file_start_t
  bin_start_t <- start_t + (row_num - 1) * bin_sec
  (bin_start_t - baseline_t) / 86400
}

sleep_bin_days <- function(n_bins, bin_min, anchor, file_start_t = NULL) {
  sleep_row_to_days(seq_len(n_bins), bin_min, anchor, file_start_t)
}

anchor_file_start_t <- function(anchor, for_plot = FALSE) {
  if (isTRUE(for_plot) && !is.null(anchor$prebase_start_t)) {
    return(anchor$prebase_start_t)
  }
  anchor$baseline_start_t
}

get_period_sleep <- function(vals, period_index, bin_days) {
  idx <- which(!is.na(bin_days) & bin_days >= period_index & bin_days < period_index + 1)
  if (length(idx) == 0) return(NA_real_)
  round(sum(vals[idx], na.rm = TRUE), 1)
}

read_applied_bin <- function(output_dir) {
  bin_env <- Sys.getenv("ETHOSCOPE_SLEEP_BIN_MIN", unset = "")
  if (nzchar(bin_env)) {
    bin <- as.integer(bin_env)
    if (bin %in% ALLOWED_SLEEP_BINS) return(bin)
  }
  marker <- file.path(output_dir, ".sleep_bin_min")
  if (file.exists(marker)) {
    bin <- as.integer(readLines(marker, n = 1L))
    if (!bin %in% ALLOWED_SLEEP_BINS) stop("Invalid .sleep_bin_min in ", output_dir)
    return(bin)
  }
  SLEEP_BIN_MIN
}

source_script <- function(filename) {
  source(file.path(SCRIPTS_DIR, filename), local = parent.frame())
}

run_r_script <- function(script_name) {
  rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(SCRIPTS_DIR)
  status <- system2(rscript, script_name)
  if (!identical(status, 0L)) {
    stop(script_name, " failed (exit code ", status, ").")
  }
  invisible(status)
}
