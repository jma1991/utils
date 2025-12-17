  df <- results[[n]][["table"]]
  
  df$status <- "ns"
  
  df$status[df$logFC > 0 & df$FDR < 0.05] <- "up"
  
  df$status[df$logFC < 0 & df$FDR < 0.05] <- "down"
  
  ggplot(df, aes(logFC, -log10(FDR), colour = status)) + 
    geom_point(alpha = 0.5, show.legend = FALSE) +
    scale_colour_manual(values = c("up" = "#FF7777", "ns" = "lightgrey", "down" = "#7DA8E6")) + 
    geom_vline(xintercept = c(-log2(1.5), log(1.5)), linetype = "dashed") + 
    geom_hline(yintercept = -log10(0.05), linetype = "dashed") +
    geom_text_repel(
      aes(
        label = ifelse(
          status != "ns" &
          ave(FDR, status, FUN = function(x) rank(x)) <= 5,
          name,
          ""
        )
      ),
      color = "#000000",
      min.segment.length = 0,
      show.legend = FALSE,
      max.overlaps = Inf
    ) +
    labs(
      x = expression(Log[2]~fold~change),
      y = expression(-Log[10]~italic(P)~adjusted),
      title = "Differential expression analysis",
      subtitle = gsub("_", " ", n),
      caption = "Significant genes: FDR < 0.05 & |FC| > 1.5"
    ) + 
    theme_classic()
  
