newSleepDataEtho <- function(data, sleep.def = 5, bin = 60, t.cycle = 24) {
  
  data <- as.data.frame(data)
  pre.raw <- data[, -c(1), drop = FALSE]
  
  # Filter out all-NA columns
  valid_cols <- colSums(is.na(pre.raw)) != nrow(pre.raw)
  if (sum(valid_cols) == 0) {
    stop("No valid data columns found (all are NA)")
  }
  raw <- pre.raw[, valid_cols, drop = FALSE]
  
  raw <- as.data.frame(raw)
  raw[raw < 1] <- -1
  raw[raw >= 1] <- 1
  raw[raw == -1] <- 0
  
  for (i in seq_len(ncol(raw))) {
    x <- raw[, i]
    y <- rle(x)
    d_y <- as.data.frame(unclass(y))
    d_y$end <- cumsum(d_y$lengths)
    d_y$start <- d_y$end - d_y$lengths + 1
    
    dd_y <- subset(d_y, d_y$values == 0 & d_y$lengths >= (sleep.def * 6))
    
    if(length(dd_y[,1]) == 0) {
      x = 0
    } else {
      for (j in 1:length(dd_y[,1])) {
        x[dd_y[j,"start"]:dd_y[j,"end"]] = -1
      }
    }
    
    x[x > -1] = 0
    x[x == -1] = 1
    raw[,i] <- x
  }
  
  s_per_day <- (60/bin)*t.cycle

  binned_full_run.sleep <- (nrow(raw)/(1440*6))*s_per_day
  n_ind <- ncol(raw)
  sleep <- matrix(NA, nrow = binned_full_run.sleep, ncol = n_ind)
  index.sleep <- seq(1, nrow(raw), by = bin*6)

  for (i in seq_along(index.sleep)) {
    end_idx <- min(index.sleep[i] + (bin * 6) - 1, nrow(raw))
    for (j in seq_len(ncol(raw))) {
      x <- raw[index.sleep[i]:end_idx, j]
      if (all(is.na(x))) {
        sleep[i, j] <- NA
      } else {
        sleep[i, j] <- (sum(x, na.rm = TRUE) * 10) / 60
      }
    }
  }

  has_data <- rowSums(!is.na(sleep)) > 0
  if (any(has_data)) {
    sleep <- sleep[seq_len(max(which(has_data))), , drop = FALSE]
  } else {
    sleep <- sleep[0, , drop = FALSE]
  }

  column.names <- paste0("I", seq_len(ncol(sleep)))
  colnames(sleep) <- column.names

  t <- seq((bin/60), t.cycle, by = (bin/60))
  n_bins <- nrow(sleep)
  zt <- as.data.frame(rep(t, length.out = n_bins))
  colnames(zt) <- c("ZT")
  
  output <- cbind(zt,sleep)
  return(output)
}
