# ============================================
# CREATE SLEEP DATA FILES - PER ETHOSCOPE
# ============================================

source("analysis_config.r")

source_script("new_sleep_data_etho.r")

resolve_latest_rds <- function(output_dir, prebase = FALSE) {
  pattern <- if (prebase) "_all_ethoscopes_10sec_prebase\\.rds$" else "_all_ethoscopes_10sec\\.rds$"
  rds_files <- list.files(output_dir, pattern = pattern, full.names = TRUE)
  if (length(rds_files) == 0) return(NULL)
  rds_files[which.max(file.info(rds_files)$mtime)]
}

write_sleep_files <- function(run1, suffix = "") {
  ethoscope_names <- names(run1)
  for (eth_name in ethoscope_names) {
    cat("Processing", eth_name, suffix, "...\n", sep = "")

    eth_data <- as.data.frame(run1[[eth_name]])
    if (ncol(eth_data) == 0) {
      cat("  ⚠ No data (empty entry in RDS), skipping\n\n")
      next
    }
    eth_cols <- colnames(eth_data)
    time_data <- eth_data[, 1, drop = FALSE]

    focal_list <- list(time_data[, 1])
    focal_names <- c("Time")
    for (tube in FOCAL_TUBES) {
      col <- paste0("Ind", sprintf("%02d", tube))
      if (col %in% eth_cols) {
        focal_list[[length(focal_list) + 1]] <- eth_data[, col]
        focal_names <- c(focal_names, paste0("T", tube))
      }
    }

    yoked_list <- list(time_data[, 1])
    yoked_names <- c("Time")
    for (tube in YOKED_TUBES) {
      col <- paste0("Ind", sprintf("%02d", tube))
      if (col %in% eth_cols) {
        yoked_list[[length(yoked_list) + 1]] <- eth_data[, col]
        yoked_names <- c(yoked_names, paste0("T", tube))
      }
    }

    n_focal <- length(focal_names) - 1
    n_yoked <- length(yoked_names) - 1
    cat("  Focal tubes:", n_focal, "| Yoked tubes:", n_yoked, "\n")

    tag <- paste0("Sleep_", eth_name, suffix)

    if (n_focal > 0) {
      focal.df <- as.data.frame(do.call(cbind, focal_list))
      colnames(focal.df) <- focal_names
      focal.sleep <- newSleepDataEtho(data = focal.df, sleep.def = 5, bin = SLEEP_BIN_MIN, t.cycle = 24)
      tube_cols <- focal_names[-1]
      focal.sleep <- focal.sleep[, c("ZT", paste0("I", seq_along(tube_cols))), drop = FALSE]
      colnames(focal.sleep) <- c("ZT", tube_cols)
      write.table(focal.sleep, paste0(OUTPUT_DIR, tag, "_Focal.txt"),
                  quote = FALSE, row.names = FALSE, sep = "\t")
      cat("  ✓ Saved: ", tag, "_Focal.txt\n", sep = "")
    } else {
      cat("  ⚠ No focal tubes found, skipping focal\n")
    }

    if (n_yoked > 0) {
      yoked.df <- as.data.frame(do.call(cbind, yoked_list))
      colnames(yoked.df) <- yoked_names
      yoked.sleep <- newSleepDataEtho(data = yoked.df, sleep.def = 5, bin = SLEEP_BIN_MIN, t.cycle = 24)
      tube_cols <- yoked_names[-1]
      yoked.sleep <- yoked.sleep[, c("ZT", paste0("I", seq_along(tube_cols))), drop = FALSE]
      colnames(yoked.sleep) <- c("ZT", tube_cols)
      write.table(yoked.sleep, paste0(OUTPUT_DIR, tag, "_Yoked.txt"),
                  quote = FALSE, row.names = FALSE, sep = "\t")
      cat("  ✓ Saved: ", tag, "_Yoked.txt\n", sep = "")
    } else {
      cat("  ⚠ No yoked tubes found, skipping yoked\n")
    }

    cat("\n")
  }
}

FOCAL_TUBES <- c(1, 3, 5, 7, 9)
YOKED_TUBES <- c(12, 14, 16, 18, 20)

RDS_FILE <- resolve_latest_rds(OUTPUT_DIR)
if (is.null(RDS_FILE)) {
  stop("No 10sec RDS found in ", OUTPUT_DIR, ". Run ethoscope_10sec_bins.r first.")
}
cat("Using RDS:", RDS_FILE, "\n")
cat("Sleep bin size:", SLEEP_BIN_MIN, "min\n\n")

run1 <- readRDS(RDS_FILE)
cat("Ethoscopes found:", paste(names(run1), collapse = ", "), "\n\n")
write_sleep_files(run1)

RDS_PREBASE <- resolve_latest_rds(OUTPUT_DIR, prebase = TRUE)
if (!is.null(RDS_PREBASE)) {
  cat("Using pre-baseline RDS (plot only):", RDS_PREBASE, "\n\n")
  run1_prebase <- readRDS(RDS_PREBASE)
  write_sleep_files(run1_prebase, suffix = "_Plot")
}

writeLines(as.character(SLEEP_BIN_MIN), file.path(OUTPUT_DIR, ".sleep_bin_min"))
cat("Done! Files ready for plotting (", SLEEP_BIN_MIN, " min bins).\n", sep = "")
