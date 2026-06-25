source("analysis_config.r")

library(scopr)
library(data.table)
library(sleepr)
library(RSQLite)

output_dir <- OUTPUT_DIR

all_dbs <- Sys.glob(file.path(ETHOSCOPE_DATA_DIR, "results/*/ETHOSCOPE_*/*/*.db"))

if (length(all_dbs) == 0) stop("No .db files found in ethoscope_data/results/")

db_info <- data.table(
  db_path = all_dbs,
  machine_name = sub(".*/(ETHOSCOPE_\\d+)/.*", "\\1", all_dbs),
  folder_date = sub(".*/(\\d{4}-\\d{2}-\\d{2}_\\d{2}-\\d{2}-\\d{2})/.*", "\\1", all_dbs)
)
# Keep most recent run per ethoscope
setorder(db_info, machine_name, -folder_date)
db_info <- db_info[, .SD[1], by = machine_name]

cat("=== Ethoscopes found ===\n")
for (i in 1:nrow(db_info)) {
  cat(sprintf("  %s  |  %s\n", db_info$machine_name[i], basename(db_info$db_path[i])))
}
cat("\n")

# ============================================================
# PROCESS EACH ETHOSCOPE
# ============================================================

all_data <- list()

for (i in 1:nrow(db_info)) {
  eth_name <- db_info$machine_name[i]
  db_path  <- db_info$db_path[i]
  eth_date <- sub("_.*", "", db_info$folder_date[i])
  eth_num  <- sub("ETHOSCOPE_0*", "", eth_name)

  cat(sprintf("\n────────── %s ──────────\n", eth_name))

  metadata <- data.table(
    machine_name = eth_name,
    date = eth_date,
    region_id = 1:20
  )

  tryCatch({
    metadata <- link_ethoscope_metadata(metadata, result_dir = file.path(ETHOSCOPE_DATA_DIR, "results/"))
  }, error = function(e) {
    cat("  ⚠ Failed to link metadata:", conditionMessage(e), "\n")
    return(NULL)
  })
  if (is.null(metadata) || nrow(metadata) == 0) next

  # Fix is_inferred TEXT→INTEGER if needed
  con <- dbConnect(SQLite(), db_path)
  roi_tables <- grep("^ROI_\\d+$", dbListTables(con), value = TRUE)

  for (tbl in roi_tables) {
    col_info <- dbGetQuery(con, paste0("PRAGMA table_info(", tbl, ")"))
    if ("is_inferred" %in% col_info$name && col_info$type[col_info$name == "is_inferred"] == "TEXT") {
      cat("  Fixing is_inferred in", tbl, "...\n")
      col_defs <- sapply(1:nrow(col_info), function(j) {
        ctype <- ifelse(col_info$name[j] == "is_inferred", "INTEGER", col_info$type[j])
        pk <- ifelse(col_info$pk[j] == 1, " PRIMARY KEY", "")
        paste0(col_info$name[j], " ", ctype, pk)
      })
      new_tbl <- paste0(tbl, "_fix")
      dbExecute(con, paste0("CREATE TABLE ", new_tbl, " (", paste(col_defs, collapse = ", "), ")"))
      dbExecute(con, paste0("INSERT INTO ", new_tbl, " SELECT * FROM ", tbl))
      dbExecute(con, paste0("DROP TABLE ", tbl))
      dbExecute(con, paste0("ALTER TABLE ", new_tbl, " RENAME TO ", tbl))
    }
  }

  # Auto-detect available ROIs
  roi_tables <- grep("^ROI_\\d+$", dbListTables(con), value = TRUE)
  dbDisconnect(con)
  available_rois <- sort(as.integer(sub("ROI_", "", roi_tables)))
  metadata <- metadata[region_id %in% available_rois]
  cat("  Available ROIs:", paste(available_rois, collapse = ", "), "\n")

  # Load with sleep annotation
  cat("  Loading data + sleep annotation...\n")
  dt <- tryCatch({
    load_ethoscope(metadata, FUN = sleepr::sleep_annotation, verbose = FALSE)
  }, error = function(e) {
    cat("  ⚠ load_ethoscope failed:", conditionMessage(e), "\n")
    return(NULL)
  })

  if (is.null(dt) || nrow(dt) == 0) {
    cat("  ⚠ No data returned. Skipping.\n")
    next
  }

  if (do_crop) {
    # Trim: keep only data from 24h before SD start
    con <- dbConnect(SQLite(), db_path)
    selected_opts <- dbGetQuery(con, "SELECT value FROM METADATA WHERE field='selected_options'")$value[1]
    exp_start_unix <- as.numeric(dbGetQuery(con, "SELECT value FROM METADATA WHERE field='date_time'")$value[1])
    dbDisconnect(con)

    date_range_part <- sub(".*date_range", "", selected_opts)
    sd_start_str <- regmatches(date_range_part, regexpr("\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}", date_range_part))

    if (length(sd_start_str) > 0) {
      sd_start_unix <- as.numeric(as.POSIXct(sd_start_str, format = "%Y-%m-%d %H:%M:%S"))
      cutoff_t <- (sd_start_unix - (24 * 3600)) - exp_start_unix
      nrow_before <- nrow(dt)
      dt <- dt[t >= cutoff_t]
      cat(sprintf("  ✓ Trimmed: SD start %s | Rows: %d → %d\n", sd_start_str, nrow_before, nrow(dt)))
    } else {
      cat("  ⚠ No date_range in metadata. No trim applied.\n")
    }
  } else {
    cat("  ✓ Cropping disabled — keeping full recording.\n")
  }

  # Save individual file
  ind_file <- paste0(output_dir, "ethoscope_", eth_num, ".txt")
  write.table(dt, file = ind_file, sep = "\t", row.names = FALSE, quote = FALSE)
  cat(sprintf("  ✓ Saved: %s (%d rows, %d individuals)\n", ind_file, nrow(dt), length(unique(dt$id))))

  all_data[[eth_name]] <- dt
}

# ============================================================
# MERGE AND SAVE
# ============================================================

if (length(all_data) > 0) {
  merged <- rbindlist(all_data)
  merged_file <- paste0(output_dir, "all_ethoscopes_merged.txt")
  write.table(merged, file = merged_file, sep = "\t", row.names = FALSE, quote = FALSE)

  cat("\n══════════════════════════════════════\n")
  cat(sprintf("✓ Merged: %s\n", merged_file))
  cat(sprintf("  Total rows: %d | Individuals: %d | Ethoscopes: %d\n",
      nrow(merged), length(unique(merged$id)), length(all_data)))
  cat("══════════════════════════════════════\n")
} else {
  cat("\n⚠ No data from any ethoscope. Nothing to merge.\n")
}