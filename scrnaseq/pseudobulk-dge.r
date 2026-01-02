###########################################################################
# Pseudobulk Differential Expression Workflow
#
# This script converts single-cell data into pseudobulk profiles, then runs
# an edgeR quasi-likelihood (QL) pipeline to test for differential expression
# by the "tomato" condition while adjusting for sample pooling. Each step is
# documented inline to clarify intent and assumptions.
###########################################################################

# Aggregate counts per cell type and sample into pseudobulk profiles
bulk <- aggregateAcrossCells(sce, id = colData(sce)[, c("celltype", "sample")])

# Retain pseudobulk samples with sufficient cells to stabilize estimates
keep <- bulk$ncells >= 10
bulk <- bulk[, keep]

# Split a SummarizedExperiment/SingleCellExperiment into a list by column factor
splitByCol <- function(x, f) {
  f <- as.factor(f)
  by.levels <- split(seq_along(f), f)
  for (i in seq_along(by.levels)) {
    # Preserve both assay data and column metadata for each subset
    by.levels[[i]] <- x[, by.levels[[i]], drop = FALSE]
  }
  by.levels
}

# Create a list of pseudobulk objects, one per cell type
bulk <- splitByCol(bulk, bulk$celltype)
labels <- names(bulk)

# Run differential expression per cell type (function defined below)
results <- lapply(labels, pseudoBulkDGE)

# edgeR QL pipeline for one pseudobulked cell type
pseudoBulkDGE <- function(sce) {

  # Build DGEList with counts and accompanying sample metadata
  y <- DGEList(counts(sce), samples = colData(sce))

  # Filter lowly expressed genes using the experimental group (tomato)
  keep <- filterByExpr(y, group = sce$tomato)
  y <- y[keep, ]

  # TMM normalization
  y <- calcNormFactors(y)

  # Design matrix: adjust for pooling, test tomato effect
  design <- model.matrix(~ factor(pool) + factor(tomato), y$samples)

  # Estimate dispersion and fit QL GLM
  y <- estimateDisp(y, design)
  fit <- glmQLFit(y, design, robust = TRUE)

  # Test the tomato coefficient (last column of design)
  res <- glmQLFTest(fit, coef = ncol(design))

}