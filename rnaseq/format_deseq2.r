#' Format DESeq2 differential-expression results
#'
#' @param dds A fitted `DESeqDataSet`.
#' @param result A `DESeqResults` object produced from `dds`.
#' @param group A named factor with exactly two observed levels. Names must
#'   match the samples in `dds`; level order defines groups A and B.
#' @param annotations An optional row-named data frame of gene annotations.
#'
#' @return A data frame containing statistics, group means, annotations, and
#'   normalized counts, ordered by raw p-value.
format_deseq2 <- function(dds, result, group, annotations = NULL) {
  validate_ids <- function(ids, label) {
    if (
      is.null(ids) ||
      anyNA(ids) ||
      any(ids == "") ||
      anyDuplicated(ids)
    ) {
      stop(label, " must be non-missing, non-empty, and unique.",
           call. = FALSE)
    }
  }

  if (!inherits(dds, "DESeqDataSet")) {
    stop("`dds` must be a DESeqDataSet.", call. = FALSE)
  }
  if (!inherits(result, "DESeqResults")) {
    stop("`result` must be a DESeqResults object.", call. = FALSE)
  }

  normalized_counts <- as.matrix(DESeq2::counts(dds, normalized = TRUE))
  sample_names <- colnames(normalized_counts)
  validate_ids(sample_names, "`dds` sample names")

  if (
    !is.factor(group) ||
    length(group) != length(sample_names) ||
    anyNA(group) ||
    nlevels(group) != 2L ||
    any(tabulate(group, nbins = nlevels(group)) == 0L)
  ) {
    stop(
      "`group` must be a factor with exactly two observed levels and one ",
      "non-missing value per sample.",
      call. = FALSE
    )
  }
  group_names <- names(group)
  validate_ids(group_names, "`group` names")
  if (!setequal(group_names, sample_names)) {
    stop("`group` names must exactly match `dds` sample names.", call. = FALSE)
  }
  group <- group[sample_names]

  result_data <- as.data.frame(result)
  required_columns <- c(
    "baseMean",
    "log2FoldChange",
    "lfcSE",
    "stat",
    "pvalue",
    "padj"
  )
  missing_columns <- setdiff(required_columns, names(result_data))
  if (length(missing_columns) > 0L) {
    stop(
      "`result` is missing required columns: ",
      paste(missing_columns, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  result_ids <- rownames(result_data)
  count_ids <- rownames(normalized_counts)
  validate_ids(result_ids, "`result`")
  validate_ids(count_ids, "`dds` counts")
  if (!setequal(result_ids, count_ids)) {
    stop("`result` and `dds` must contain exactly the same gene IDs.",
         call. = FALSE)
  }
  normalized_counts <- normalized_counts[result_ids, , drop = FALSE]

  if (is.null(annotations)) {
    annotations <- data.frame(row.names = result_ids)
  } else {
    if (!is.data.frame(annotations)) {
      stop("`annotations` must be a data frame.", call. = FALSE)
    }
    annotation_ids <- rownames(annotations)
    validate_ids(annotation_ids, "`annotations`")
    if (!setequal(annotation_ids, result_ids)) {
      stop(
        "`annotations` and `result` must contain exactly the same gene IDs.",
        call. = FALSE
      )
    }
    annotations <- annotations[result_ids, , drop = FALSE]
  }

  group_levels <- levels(group)
  sample_names_a <- sample_names[group == group_levels[[1L]]]
  sample_names_b <- sample_names[group == group_levels[[2L]]]
  output_columns <- c(
    "name",
    names(annotations),
    "baseMean",
    "baseMeanA",
    "baseMeanB",
    "foldChange",
    "log2FoldChange",
    "lfcSE",
    "stat",
    "PValue",
    "PAdj",
    "FDR",
    "falsePos",
    sample_names_a,
    sample_names_b
  )
  if (
    anyNA(output_columns) ||
    any(output_columns == "") ||
    anyDuplicated(output_columns)
  ) {
    stop(
      "Annotation or sample names collide with required output columns.",
      call. = FALSE
    )
  }

  statistics <- data.frame(
    baseMean = result_data$baseMean,
    baseMeanA = rowMeans(normalized_counts[, sample_names_a, drop = FALSE]),
    baseMeanB = rowMeans(normalized_counts[, sample_names_b, drop = FALSE]),
    foldChange = 2 ^ result_data$log2FoldChange,
    log2FoldChange = result_data$log2FoldChange,
    lfcSE = result_data$lfcSE,
    stat = result_data$stat,
    PValue = result_data$pvalue,
    PAdj = stats::p.adjust(result_data$pvalue, method = "hochberg"),
    FDR = result_data$padj,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  statistics$falsePos <- NA_real_

  row_order <- order(
    statistics$PValue,
    -statistics$foldChange,
    na.last = TRUE
  )
  false_positives <- seq_len(nrow(statistics)) * statistics$FDR[row_order]

  formatted <- cbind(
    data.frame(name = result_ids, stringsAsFactors = FALSE),
    annotations,
    statistics,
    as.data.frame(normalized_counts, check.names = FALSE)
  )
  formatted <- formatted[row_order, output_columns, drop = FALSE]
  formatted$falsePos <- false_positives
  rownames(formatted) <- NULL
  formatted
}
