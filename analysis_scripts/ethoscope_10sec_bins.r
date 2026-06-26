source("analysis_config.r")

df <- read.delim(file.path(OUTPUT_DIR, "all_ethoscopes_merged.txt"), header = TRUE)

datSortBin <- function (input, n.days, cat.names = c("Control", "Experimental"), ethoscope.id, mins.trim) {
  library(stringr)
  
  dat <- list()
  
  for.df <- list()
  
  for (i in 1:length(ethoscope.id)) {
  txt <- paste(ethoscope.id[i], sep = "")
  for.df[[i]] <- input[str_detect(string = input$id, pattern = txt, negate = FALSE),]
}
  
  for (i in 1:length(for.df)) {
    df <- for.df[[i]]
    
    t = as.data.frame(table(df$id))
    tt = subset(t, Freq != 0)
    etho.names <- as.vector(tt[,1])
    
    n.time = n.days*((24*60*60)/10)
    # output.bin = 10/60
    
    ethoscope <- list()
    
    for (j in 1:length(etho.names)) {
      ethoscope[[j]] <- subset(df, id == etho.names[j], select = c("t","max_velocity"))
    }
    
    
    dat.etho <- matrix(NA, nrow = 1440*6*(n.days+10), ncol = length(ethoscope))
        
    for (ii in 1:length(ethoscope)) {
        rows_to_trim <- mins.trim[i] * 6   # i = current ethoscope index (outer loop)
        if (rows_to_trim >= nrow(ethoscope[[ii]])) {
            warning(paste("Skipping individual", ii, "- not enough data after trimming"))
            next
        }
        trimmed.dat <- ethoscope[[ii]][-c(1:rows_to_trim),]
        dat.etho[1:nrow(trimmed.dat), ii] <- trimmed.dat[,"max_velocity"]
    }
    
    eth.names <- strsplit(etho.names, split = "|", fixed = T)
  
  col.names.etho <- c()
  for (kk in 1:length(dat.etho[1,])) {
    col.names.etho[kk] <- paste("Ind", eth.names[[kk]][2], sep = "")
  }
  
  colnames(dat.etho) <- col.names.etho
  
  out.time <- as.matrix(seq(10, (length(dat.etho[,1])*10), by = 10))
  colnames(out.time) <- c("Time since start (sec)")
    
  dat[[i]] <- cbind(out.time, dat.etho)
    
  }
  names(dat) <- cat.names
  return(dat)
  
  
}

# Auto-detect ethoscopes from results folder
results_dirs <- list.dirs(file.path(ETHOSCOPE_DATA_DIR, "results"), recursive = FALSE)
machine_id_folders <- basename(results_dirs)

cat_names <- c()
eth_ids   <- c()

for (mid in machine_id_folders) {
  eth_folder <- list.dirs(file.path(ETHOSCOPE_DATA_DIR, "results", mid), recursive = FALSE)
  eth_folder <- basename(eth_folder[grepl("^ETHOSCOPE_", basename(eth_folder))])
  if (length(eth_folder) == 0) next
  
  eth_num <- sub("ETHOSCOPE_0*", "", eth_folder[1])
  eth_id  <- substr(mid, 1, 6)
  
  # Check this ethoscope has data in the merged file
  if (any(grepl(eth_id, df$id))) {
    cat_names <- c(cat_names, paste0("Eth", sprintf("%03d", as.integer(eth_num))))
    eth_ids   <- c(eth_ids, eth_id)
  }
}

# Sort by ethoscope number
ord <- order(cat_names)
cat_names <- cat_names[ord]
eth_ids   <- eth_ids[ord]

cat("Detected ethoscopes:\n")
for (k in seq_along(cat_names)) {
  cat(sprintf("  %s -> id: %s\n", cat_names[k], eth_ids[k]))
}

df.sorted <- datSortBin(input = df, n.days = 6,
                        cat.names = cat_names,
                        ethoscope.id = eth_ids,
                        mins.trim = rep(0, length(eth_ids)))

output_dir <- OUTPUT_DIR
out_rds    <- paste0(output_dir, format(Sys.Date(), "%d_%b"), "_all_ethoscopes_10sec.rds")

saveRDS(df.sorted, out_rds)
cat(sprintf("\n✓ Saved: %s\n", out_rds))

prebase_merged <- file.path(OUTPUT_DIR, "all_ethoscopes_merged_prebase.txt")
if (file.exists(prebase_merged)) {
  cat("\nProcessing pre-baseline data (plot only)...\n")
  df.prebase <- read.delim(prebase_merged, header = TRUE)
  df.sorted.prebase <- datSortBin(
    input = df.prebase, n.days = 6,
    cat.names = cat_names, ethoscope.id = eth_ids,
    mins.trim = rep(0, length(eth_ids))
  )
  out_rds_prebase <- paste0(output_dir, format(Sys.Date(), "%d_%b"), "_all_ethoscopes_10sec_prebase.rds")
  saveRDS(df.sorted.prebase, out_rds_prebase)
  cat(sprintf("✓ Saved: %s\n", out_rds_prebase))
}
