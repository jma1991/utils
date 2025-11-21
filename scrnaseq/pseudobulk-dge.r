bulk <- aggregateAcrossCells(sce, id = colData(sce)[, c("celltype", "sample")])

keep <- bulk$ncells >= 10

bulk <- bulk[, keep]

splitByCol <- function(x, f) {
  f <- as.factor(f)
  by.levels <- split(seq_along(f), f)
  for (i in seq_along(by.levels)) {
    by.levels[[i]] <- x[, by.levels[[i]], drop = FALSE]
  }
  by.levels
}

bulk <- splitByCol(bulk, bulk$celltype)

labels <- names(bulk)

results <- lapply(labels, pseudoBulkDGE)

pseudoBulkDGE <- function(sce) {

  y <- DGEList(counts(sce), samples = colData(sce))

  keep <- filterByExpr(y, group = sce$tomato)

  y <- y[keep, ]

  y <- calcNormFactors(y)

  design <- model.matrix(~ factor(pool) + factor(tomato), y$samples)

  y <- estimateDisp(y, design)

  fit <- glmQLFit(y, design, robust = TRUE)

  res <- glmQLFTest(fit, coef = ncol(design))

}