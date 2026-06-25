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
DEFAULT_SLEEP_BIN_MIN <- 60

ALLOWED_SLEEP_BINS <- c(5, 30, 60)

crop_env <- Sys.getenv("ETHOSCOPE_DO_CROP", unset = "")
bin_env  <- Sys.getenv("ETHOSCOPE_SLEEP_BIN_MIN", unset = "")

if (nzchar(crop_env)) {
  do_crop <- identical(toupper(crop_env), "TRUE")
} else {
  do_crop <- DEFAULT_DO_CROP
}

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
CROP_TAG     <- if (isTRUE(do_crop)) "" else "_uncropped"

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
