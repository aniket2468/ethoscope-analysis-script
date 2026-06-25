# ============================================
# CREATE SLEEP DATA FILES - PER ETHOSCOPE
# ============================================

source("analysis_config.r")

source_script("new_sleep_data_etho.r")

resolve_latest_rds <- function(output_dir) {
  rds_files <- list.files(output_dir, pattern = "_all_ethoscopes_10sec\\.rds$", full.names = TRUE)
  if (length(rds_files) == 0) {
    stop("No 10sec RDS found in ", output_dir,
         ". Run ethoscope_10sec_bins.r first.")
  }
  rds_files[which.max(file.info(rds_files)$mtime)]
}

RDS_FILE <- resolve_latest_rds(OUTPUT_DIR)
cat("Using RDS:", RDS_FILE, "\n")
cat("Sleep bin size:", SLEEP_BIN_MIN, "min\n\n")

FOCAL_TUBES <- c(1, 3, 5, 7, 9)
YOKED_TUBES <- c(12, 14, 16, 18, 20)

# Load data
run1 <- readRDS(RDS_FILE)
ethoscope_names <- names(run1)

cat("Ethoscopes found:", paste(ethoscope_names, collapse = ", "), "\n\n")

# Process each ethoscope separately
for (eth_name in ethoscope_names) {
  cat("Processing", eth_name, "...\n")
  
  eth_data <- as.data.frame(run1[[eth_name]])
  if (ncol(eth_data) == 0) {
    cat("  ⚠ No data (empty entry in RDS), skipping\n\n")
    next
  }
  eth_cols <- colnames(eth_data)
  time_data <- eth_data[, 1, drop = FALSE]
  
  # Extract focal tubes
  focal_list <- list(time_data[,1])
  focal_names <- c("Time")
  for (tube in FOCAL_TUBES) {
    col <- paste0("Ind", sprintf("%02d", tube))
    if (col %in% eth_cols) {
      focal_list[[length(focal_list) + 1]] <- eth_data[, col]
      focal_names <- c(focal_names, paste0("T", tube))
    }
  }
  
  # Extract yoked tubes
  yoked_list <- list(time_data[,1])
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
  
  if (n_focal == 0) {
    cat("  ⚠ No focal tubes found, skipping focal\n")
  } else {
    focal.df <- as.data.frame(do.call(cbind, focal_list))
    colnames(focal.df) <- focal_names
    focal.sleep <- newSleepDataEtho(data = focal.df, sleep.def = 5, bin = SLEEP_BIN_MIN, t.cycle = 24)
    tube_cols <- focal_names[-1]
    focal.sleep <- focal.sleep[, c("ZT", paste0("I", seq_along(tube_cols))), drop = FALSE]
    colnames(focal.sleep) <- c("ZT", tube_cols)
    write.table(focal.sleep, paste0(OUTPUT_DIR, "Sleep_", eth_name, "_Focal.txt"), 
                quote = FALSE, row.names = FALSE, sep = "\t")
    cat("  ✓ Saved: Sleep_", eth_name, "_Focal.txt\n", sep = "")
  }
  
  if (n_yoked == 0) {
    cat("  ⚠ No yoked tubes found, skipping yoked\n")
  } else {
    yoked.df <- as.data.frame(do.call(cbind, yoked_list))
    colnames(yoked.df) <- yoked_names
    yoked.sleep <- newSleepDataEtho(data = yoked.df, sleep.def = 5, bin = SLEEP_BIN_MIN, t.cycle = 24)
    tube_cols <- yoked_names[-1]
    yoked.sleep <- yoked.sleep[, c("ZT", paste0("I", seq_along(tube_cols))), drop = FALSE]
    colnames(yoked.sleep) <- c("ZT", tube_cols)
    write.table(yoked.sleep, paste0(OUTPUT_DIR, "Sleep_", eth_name, "_Yoked.txt"), 
                quote = FALSE, row.names = FALSE, sep = "\t")
    cat("  ✓ Saved: Sleep_", eth_name, "_Yoked.txt\n", sep = "")
  }
  
  cat("\n")
}

writeLines(as.character(SLEEP_BIN_MIN), file.path(OUTPUT_DIR, ".sleep_bin_min"))
cat("Done! Files ready for plotting (", SLEEP_BIN_MIN, " min bins).\n", sep = "")
