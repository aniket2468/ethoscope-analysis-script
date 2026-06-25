# ============================================================
# Stage 2 — edit this file after reviewing the Stage 1 actogram
# ============================================================
#
# Only list ethoscopes where you want to DROP pairs.
# Names must match Stage 1 (see actogram or Sleep_EthXXX_Focal.txt files).
# Ethoscopes not listed here keep all pairs.
#
# Pair → tubes (focal / yoked):
#   1 → T1  / T12     2 → T3  / T14     3 → T5  / T16
#   4 → T7  / T18     5 → T9  / T20
#
# Example:
#   EXCLUDE_PAIRS <- list(
#     Eth007 = c(2, 4),
#     Eth012 = c(1)
#   )
#
# Then run:  Rscript run_ethoscope_analysis_stage2.r

EXCLUDE_PAIRS <- list(
  Eth006 = c(1)
)

FILTER_TAG <- function() {
  if (!identical(Sys.getenv("ETHOSCOPE_APPLY_EXCLUSIONS"), "1")) return("")
  if (any(lengths(EXCLUDE_PAIRS) > 0L)) "_filtered" else ""
}

apply_exclusions <- function() {
  identical(Sys.getenv("ETHOSCOPE_APPLY_EXCLUSIONS"), "1")
}

pair_is_included <- function(eth, pair, exclude_list = EXCLUDE_PAIRS) {
  !(eth %in% names(exclude_list) && pair %in% exclude_list[[eth]])
}

describe_exclusions <- function(exclude_list = EXCLUDE_PAIRS) {
  active <- exclude_list[lengths(exclude_list) > 0L]
  if (length(active) == 0L) {
    return("No pairs excluded (all pairs included).")
  }
  paste(
    vapply(names(active), function(eth) {
      sprintf("%s → drop pair %s", eth, paste(active[[eth]], collapse = ", "))
    }, character(1)),
    collapse = "\n  "
  )
}

detect_ethoscopes <- function(output_dir) {
  focal_files <- list.files(output_dir, pattern = "^Sleep_(Eth\\d+)_Focal\\.txt$")
  if (length(focal_files) == 0L) return(character())
  eth <- sub("^Sleep_(Eth\\d+)_Focal\\.txt$", "\\1", focal_files)
  eth[order(as.integer(sub("Eth", "", eth)))]
}
