#' Scale an assay matrix by row
#'
#' This function centers each row by its mean and scales it by an
#' estimate of the row-wise standard deviation. Missing values are
#' ignored when computing means and variances.
#'
#' @param x A numeric matrix-like object (rows = features, columns = samples)
#' @return A numeric matrix with centered and scaled rows
scaleAssay <- function(x) {

  # Ensure input is a matrix
  x <- as.matrix(x)

  # Number of samples (columns)
  n_samples <- ncol(x)

  # Row-wise means, ignoring NA values
  row_means <- rowMeans(x, na.rm = TRUE)

  # Initial degrees of freedom (n - 1)
  df <- n_samples - 1L

  # Identify missing values
  is_na <- is.na(x)

  # Convert logical matrix to integer (TRUE = 1, FALSE = 0)
  # for efficient row-wise summation
  mode(is_na) <- "integer"

  # Adjust degrees of freedom for missing values
  df <- df - rowSums(is_na)

  # Prevent division by zero
  df[df == 0L] <- 1L

  # Center rows by subtracting the row mean
  x <- x - row_means

  # Row-wise variance estimate (ignoring NA values)
  row_var <- rowSums(x^2L, na.rm = TRUE) / df

  # Scale rows by standard deviation
  # A small constant (0.01) is added for numerical stability
  x <- x / sqrt(row_var + 0.01)

  return(x)
}
