format_deseq2_results <- function(dds, res, sample_names_A, sample_name_B) {

    # Convert DESeq2 results object to a data frame
    res_df <- as.data.frame(res)

    # Compute linear fold change from log2FoldChange
    res_df$foldChange <- 2 ^ res_df$log2FoldChange

    # Rename columns for readability
    res_df <- dplyr::rename(res_df, PValue = pvalue, FDR = padj)

    # Replace missing FDR values (NA) with 1
    res_df$FDR[is.na(res_df$FDR)] <- 1

    # Compute additional adjusted p-values using Hochberg correction
    res_df$PAdj <- p.adjust(res_df$PValue, method = "hochberg")

    # Initialize baseMeanA and baseMeanB placeholders
    res_df$baseMeanA <- 1
    res_df$baseMeanB <- 1

    # Retrieve normalized counts from DESeq2
    norm_counts <- counts(dds, normalized = TRUE)

    # Round normalized counts to one decimal place
    norm_counts <- round(norm_counts, 1)

    # Combine DESeq2 results with normalized counts
    combined_df <- dplyr::bind_cols(res_df, norm_counts)

    # Sort rows by FDR (ascending order)
    combined_df <- dplyr::arrange(combined_df, FDR)

    # Calculate cumulative expected false positives
    combined_df$falsePos <- 1:nrow(combined_df) * combined_df$FDR

    # Identify sample names for each experimental group
    sample_names_A <- sample_names[df$group == groups[[1]]]
    sample_names_B <- sample_names[df$group == groups[[2]]]

    # Compute mean normalized counts for each condition
    combined_df$baseMeanA <- rowMeans(combined_df[, sample_names_A])
    combined_df$baseMeanB <- rowMeans(combined_df[, sample_names_B])

    # Round numerical columns for readability
    combined_df$foldChange      <- round(combined_df$foldChange, 3)
    combined_df$log2FoldChange  <- round(combined_df$log2FoldChange, 1)
    combined_df$baseMean        <- round(combined_df$baseMean, 1)
    combined_df$baseMeanA       <- round(combined_df$baseMeanA, 1)
    combined_df$baseMeanB       <- round(combined_df$baseMeanB, 1)
    combined_df$lfcSE           <- round(combined_df$lfcSE, 2)
    combined_df$stat            <- round(combined_df$stat, 2)
    combined_df$FDR             <- round(combined_df$FDR, 4)
    combined_df$falsePos        <- round(combined_df$falsePos, 0)

    # Define a clear and logical column order
    reordered_cols <- c(
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
        sample_names_A,
        sample_names_B
    )

    # Reorder columns for final output
    formatted_results <- combined_df[, reordered_cols]

    # Return formatted DESeq2 results table
    return(formatted_results)
}
