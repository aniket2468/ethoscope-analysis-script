# Ask for crop + bin size; stores choices in environment variables.

stdin_is_tty <- function() {
  if (.Platform$OS.type == "windows") {
    return(TRUE)
  }
  identical(suppressWarnings(system("test -t 0", ignore.stdout = TRUE)), 0L)
}

ask <- function(prompt) {
  cat(prompt)
  flush.console()
  if (stdin_is_tty()) {
    return(readLines(file("stdin"), n = 1L))
  }
  if (file.exists("/dev/tty")) {
    con <- tryCatch(file("/dev/tty", "r"), error = function(e) NULL)
    if (!is.null(con)) {
      cat(prompt, file = "/dev/tty")
      on.exit(close(con), add = TRUE)
      return(readLines(con, n = 1L))
    }
  }
  readLines(file("stdin"), n = 1L)
}

prompt_pipeline_settings <- function(force = FALSE) {
  if (!force &&
      nzchar(Sys.getenv("ETHOSCOPE_DO_CROP")) &&
      nzchar(Sys.getenv("ETHOSCOPE_SLEEP_BIN_MIN"))) {
    return(invisible(TRUE))
  }

  cat("\n=== Pipeline settings ===\n\n")

  crop_ans <- trimws(paste(ask("Crop to 24h before sleep deprivation? (y/N): "), collapse = ""))
  do_crop <- grepl("^[Yy]", crop_ans)

  cat("\nSleep bin size:\n  1 = 5 min\n  2 = 30 min\n  3 = 60 min\n")
  bin_ans <- trimws(paste(ask("Enter 1, 2, or 3 (default 3): "), collapse = ""))
  sleep_bin <- if (!nzchar(bin_ans)) 60L else c(5L, 30L, 60L)[as.integer(bin_ans)]
  if (is.na(sleep_bin)) stop("Invalid choice — enter 1, 2, or 3.")

  Sys.setenv(
    ETHOSCOPE_DO_CROP = if (do_crop) "TRUE" else "FALSE",
    ETHOSCOPE_SLEEP_BIN_MIN = as.character(sleep_bin)
  )

  cat(sprintf(
    "\n→ crop: %s | bin: %d min\n\n",
    if (do_crop) "yes" else "no",
    sleep_bin
  ))
  invisible(TRUE)
}
