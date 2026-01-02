## Principal Component Analysis (PCA) of Bulk RNA-seq Data
##
## This script performs PCA on log-normalized counts from bulk RNA-seq
## experiments using either DESeq2 (DESeqTransform) or edgeR (DGEList)
## objects.
##
## Dependencies: DESeq2, edgeR

## Generic function for PCA computation with S3 method dispatch
calculatePCA <- function(obj, ntop=500) {
    UseMethod("calculatePCA")
}

## S3 method for DESeqTransform objects
calculatePCA.DESeqTransform <- function(obj, ntop=500) {
    ## Extract transformed counts from DESeqTransform object
    countsMatrix <- DESeq2::assay(obj)
    metadata <- as.data.frame(SummarizedExperiment::colData(obj))
    sampleNames <- rownames(metadata)

    ## Delegate to shared PCA computation
    .calculatePCA(countsMatrix, metadata, sampleNames, ntop)
}

## S3 method for DGEList objects
calculatePCA.DGEList <- function(obj, ntop=500) {
    ## Compute log-CPM from DGEList object
    countsMatrix <- edgeR::cpm(obj, log=TRUE, prior.count=2)
    metadata <- obj$samples
    sampleNames <- rownames(metadata)

    ## Delegate to shared PCA computation
    .calculatePCA(countsMatrix, metadata, sampleNames, ntop)
}

## Default method for unsupported object types
calculatePCA.default <- function(obj, ntop=500) {
    stop("Input must be either a DESeqTransform (DESeq2) or ",
         "DGEList (edgeR) object.")
}


## Internal shared PCA computation logic
.calculatePCA <- function(countsMatrix, metadata, sampleNames, ntop) {
    ## Variance-based gene filtering
    geneVariance <- apply(countsMatrix, 1, var)

    ## Select top N most variable genes
    ntop <- min(ntop, nrow(countsMatrix))
    topGenes <- order(geneVariance, decreasing=TRUE)[seq_len(ntop)]
    countsFiltered <- countsMatrix[topGenes, ]

    ## Perform PCA on transposed matrix (samples as rows, genes as
    ## columns)
    pcaResult <- stats::prcomp(t(countsFiltered), center=TRUE,
                               scale.=FALSE)

    ## Extract PCA coordinates
    pcaCoords <- as.data.frame(pcaResult$x[, 1:2])
    pcaCoords$sample <- sampleNames

    ## Calculate variance explained
    varianceExplained <- (pcaResult$sdev ^ 2) /
        sum(pcaResult$sdev ^ 2)

    ## Integrate sample metadata with PCA coordinates
    metadata$sample <- rownames(metadata)
    pcaData <- merge(pcaCoords, metadata, by="sample", all.x=TRUE)

    ## Return results as a list
    list(pcaData=pcaData, varianceExplained=varianceExplained)

}
