# Installs R packages required by the analysis pipeline.
# Run manually once if needed:  Rscript install_dependencies.r

REQUIRED_PACKAGES <- c(
  "data.table",
  "ggplot2",
  "RSQLite",
  "stringr",
  "scopr",
  "sleepr"
)

missing_packages <- function(packages = REQUIRED_PACKAGES) {
  packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
}

install_if_missing <- function(packages = REQUIRED_PACKAGES, repos = "https://cloud.r-project.org") {
  missing <- missing_packages(packages)
  if (length(missing) == 0L) {
    return(invisible(TRUE))
  }

  cat("Installing missing packages:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, repos = repos, dependencies = TRUE)
  still_missing <- missing_packages(missing)
  if (length(still_missing) > 0L) {
    stop(
      "Could not install: ", paste(still_missing, collapse = ", "),
      "\nTry in R: install.packages(c('scopr', 'sleepr'))"
    )
  }
  cat("✓ Package installation complete.\n")
  invisible(TRUE)
}

# Auto-install only when this file is run directly (not when sourced)
if (sys.nframe() == 0L) {
  install_if_missing()
}
