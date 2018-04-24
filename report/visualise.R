#!/usr/bin/env Rscript

# Generate plots of aggregated filesystem data
# Christopher Harrison <ch12@sanger.ac.uk>

library(ggplot2, warn.conflicts=FALSE)
library(dplyr, warn.conflicts=FALSE)

usage <- function() {
  write("Usage: visualise.R DATA_FILE OUTPUT_DIR", stderr())
}

load_data <- function(path) {
  # Load aggregated data from file and annotate, appropriately
  data <- read.delim(path, header=FALSE,
                     col.names=c("fs", "orgk", "orgv", "type", "inodes", "size", "cost"))
  return(data)
}

create_plot <- function(data) {
  # Create sunburst plot for the supplied data frame

  # FIXME This is just the summary data, not split by file type in a
  # multiple-level sunburst plot
  data.all <- data[data$type == "all",]
  plot <- ggplot(data.all, aes(y=data.all$cost)) +
          geom_bar(aes(x=data.all$orgk, fill=data.all$orgv), stat="identity") +
          coord_polar(theta="y")

  return(plot)
}

main <- function(argv) {
  if (length(argv) != 2) {
    usage()
    quit(status=1)
  }

  data <- load_data(argv[1])
  output <- normalizePath(argv[2])

  org_types <- c("group", "user", "pi")
  file_types <- c("all", "cram", "bam", "index", "compressed", "uncompressed", "checkpoint", "log", "temp", "other")

  for (fs in unique(data$fs)) {
    for (orgk in org_types) {
      write(paste("Creating ", orgk," plot for ", fs, "...", sep=""), stderr())

      # Get data subset for plotting
      filtered <- data[data$fs == fs & data$orgk == orgk,]
      if (orgk != "pi") {
        # We only care about the top 10 users and groups by cost
        filtered.all <- filtered[filtered$type == "all",]
        filtered.all.top10 <- top_n(filtered.all, 10, filtered.all$cost)
        filtered <- filtered[filtered$orgv %in% filtered.all.top10$orgv,]
      }

      # Generate plot and save to disk
      plot <- create_plot(filtered)
      file <- paste(output, "/", fs, "-", orgk, ".pdf", sep="")
      ggsave(file, plot=plot, device="pdf")
    }
  }
}

main(commandArgs(trailingOnly=TRUE))
