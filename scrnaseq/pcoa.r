###########################################################################
# Principal Coordinate Analysis of Simulated Cell Type Proportions
#
# This script simulates single-cell assignments of cell types across a set
# of samples, aggregates these assignments into a cell-type-by-sample
# abundance matrix, converts abundances to per-sample proportions, and
# computes Bray–Curtis dissimilarities between samples. A Principal
# Coordinate Analysis (PCoA) is then performed to project samples into a
# low-dimensional space. Finally, the first two PCoA axes are plotted
# using base R to visualize similarity patterns among samples.
#
# Dependencies: vegan
###########################################################################

set.seed(1701)

# Parameters
num_samples <- 50
num_cells   <- 2000

sample_ids  <- paste0("S", seq_len(num_samples))
cell_types  <- c("Tcell", "Bcell", "NK", "Mono", "DC", "Neutro")

# Simulated data
cell_data <- data.frame(
  sample_id = sample(sample_ids, num_cells, replace = TRUE),
  cell_type = sample(cell_types, num_cells, replace = TRUE),
  stringsAsFactors = FALSE
)

# Abundance matrix (cell_type × sample_id)
abundance_matrix <- table(cell_data$cell_type, cell_data$sample_id)

# Convert to proportional abundances per sample
proportion_matrix <- sweep(
  abundance_matrix,
  MARGIN = 2,
  STATS  = colSums(abundance_matrix),
  FUN    = "/"
)

# Bray–Curtis distances between samples
bray_distances <- vegan::vegdist(t(proportion_matrix), method = "bray")

# Principal Coordinate Analysis
pcoa_result <- vegan::wcmdscale(bray_distances, eig = TRUE)

# Extract coordinates
coords <- pcoa_result$points

# Base R scatter plot
plot(
  coords[, "Dim1"], coords[, "Dim2"],
  xlab = "PCoA 1",
  ylab = "PCoA 2",
  main = "Principal Coordinate Analysis of Cell Type Proportions",
  pch = 19
)
