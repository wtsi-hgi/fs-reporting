#!/usr/bin/env Rscript

# Generate plots of aggregated filesystem data
# Christopher Harrison <ch12@sanger.ac.uk>

library(ggplot2, warn.conflicts = FALSE)
library(dplyr, warn.conflicts = FALSE)

usage <- function() {
  write("Usage: visualise.R DATA_FILE OUTPUT_DIR", stderr())
}

load_data <- function(path) {
  # Load aggregated data from file and annotate, appropriately
  data <- read.delim(path, header = FALSE,
                     col.names = c("fs", "orgk", "orgv", "type", "inodes", "size", "cost"))
  return(data)
}

create_plot <- function(data) {
  # Create sunburst plot for the supplied data frame
  lvl0 <- data.frame(orgv = as.factor("root"), cost = NA, level = as.factor(0), fill = NA)

  lvl1 <- data %>%
          filter(type == "all") %>%
          mutate(orgv = as.factor(orgv), level = as.factor(1), fill = orgv) %>%
          select(orgv, cost, level, fill)

  lvl2 <- data %>%
          filter(type != "all") %>%
          mutate(type = as.factor(type), level = as.factor(2), fill = orgv) %>%
          select(orgv = type, cost, level, fill)

  plot <- bind_rows(lvl0, lvl1, lvl2) %>%
          arrange(fill, orgv) %>%
          ggplot(aes(x = level, y = cost, fill = fill, alpha = level)) +
          geom_col(color = "white", size = 0.2, position = position_stack()) +
          scale_alpha_manual(values = c("0" = 1, "1" = 1, "2" = 0.8), guide = FALSE) +
          scale_x_discrete(breaks = NULL) +
          scale_y_continuous(breaks = NULL) +
          labs(x = NULL, y = NULL, fill = NULL) +
          coord_polar(theta = "y") +
          theme_minimal()

  return(plot)
}

main <- function(argv) {
  if (length(argv) != 2) {
    usage()
    quit(status = 1)
  }

  data <- load_data(argv[1])
  output <- normalizePath(argv[2])

  org_types <- c("group", "user", "pi")

  for (i_fs in unique(data$fs)) {
    for (i_orgk in org_types) {
      write(paste("Creating ", i_orgk," plot for ", i_fs, "...", sep=""), stderr())

      # Get data subset for plotting
      filtered <- data %>% filter(fs == i_fs, orgk == i_orgk)
      if (i_orgk != "pi") {
        # We only care about the top 10 users and groups by cost
        filtered.top10 <- filtered %>% filter(type == "all") %>% top_n(10, cost)
        filtered <- filtered %>% filter(orgv %in% filtered.top10$orgv)
      }

      # Generate plot and save to disk
      plot <- create_plot(filtered)
      file <- paste(output, "/", i_fs, "-", i_orgk, ".pdf", sep="")
      ggsave(file, plot = plot, device = "pdf")
    }
  }
}

main(commandArgs(trailingOnly = TRUE))
