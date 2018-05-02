#!/usr/bin/env Rscript

# Generate plots of aggregated filesystem data
# Christopher Harrison <ch12@sanger.ac.uk>

library(ggplot2,    warn.conflicts = FALSE)
library(dplyr,      warn.conflicts = FALSE)
library(xtable,     warn.conflicts = FALSE)
library(functional, warn.conflicts = FALSE)

## Utility Functions ###################################################

usage(error) {
  # Output error message, instructions and exit with non-zero status
  write(paste("Error:", error$message), stderr())
  write("Usage: render-assets.R DATA_FILE OUTPUT_DIR", stderr())
  quit(status = 1)
}

# Load aggregated data from file and annotate, appropriately
read.data <- Curry(read.delim, header = FALSE, col.names = c("fs", "orgk", "orgv", "type", "inodes", "size", "cost"))

## Text Formatting Functions ###########################################

#! FIXME This version of format.quantified works on vectorised input,
#! but it suffers from an order stability bug that makes it useless :(

#! format.quantified <- (function() {
#!   # Use a closure to define the default SI magnitude prefixes
#!   prefix.default <- data.frame(exponent = c(0,  1,   2,   3,   4,   5,   6),
#!                                prefix   = c("", "k", "M", "G", "T", "P", "E"))
#!
#!   is.prefix  <- function(x) { is.data.frame(x) && all(c("exponent", "prefix") %in% colnames(x)) }
#!   is.decimal <- function(x) { x != trunc(x) }
#!
#!   function(n, suffix = "", threshold = 0.8, base = 1000, prefix.alternative = NA, sep = "") {
#!     # Return n, quantified by order of magnitude (relative to base)
#!     # to one decimal place (or exactly, for non-quantified integers)
#!     # with an optional suffix for units
#!     prefix <- prefix.default
#!     if (is.prefix(prefix.alternative)) {
#!       prefix <- filter(prefix, !exponent %in% prefix.alternative$exponent) %>%
#!                 bind_rows(prefix.alternative)
#!     }
#!
#!     q <- data.frame(n = as.numeric(n), exponent = trunc(log(n, base = base))) %>%
#!          mutate(quantified = n / (base ^ exponent))
#!
#!     q.below <- filter(q, quantified <  base * threshold)
#!     q.above <- filter(q, quantified >= base * threshold) %>%
#!                mutate(exponent = exponent + 1, quantified = quantified / base)
#!
#!     Q <- bind_rows(q.below, q.above) %>%
#!          merge(prefix, by = "exponent", all.x = TRUE)
#!
#!     paste(
#!       ifelse(Q$exponent | is.decimal(Q$n), sprintf("%.1f", Q$quantified), Q$n),
#!       paste(Q$prefix, suffix, sep = ""),
#!       sep = sep)
#!   }
#! })()
#!
#! # Convenience wrappers
#! format.count <- Curry(format.quantified, prefix.alternative = data.frame(exponent = 3, prefix = "B"))
#! format.data <- Curry(format.quantified, base = 1024, suffix = "iB", sep = " ")

format.quantified <- function(n, base = 1000, prefix = c("", "k", "M", "G", "T", "P"), suffix = "", threshold = 0.8, sep = "") {
  # Return n, quantified by order of magnitude (relative to base,
  # defaulting to SI prefixes) to one decimal place (or exactly, for
  # non-quantified integers) with an optional suffix for units
  n <- as.numeric(n)
  base <- as.integer(base)
  exponent <- trunc(log(n, base = base))

  is.decimal <- n != trunc(n)

  # Move up to the next prefix multiplier if we're close enough
  # FIXME This condition only applies to the first element, but the
  # increment will be applied to everything
  # if (n / (base ^ (exponent + 1)) >= threshold) { exponent <- exponent + 1 }

  paste(
    ifelse(exponent | is.decimal, sprintf("%.1f", n / (base ^ exponent)), n),
    paste(prefix[exponent + 1], suffix, sep = ""),
    sep = sep)
}

# Convenience wrappers
format.count <- Curry(format.quantified, prefix = c("", "k", "M", "B", "T"))
format.data <- Curry(format.quantified, base = 1024, suffix = "iB", sep = " ")

format.money <- function(value, prefix = "", suffix = "", sep = "") {
  # Thousand separated to two decimal places, with optional prefix and
  # suffix for currency symbols
  paste(
    prefix,
    format(round(as.numeric(value), 2), nsmall = 2, big.mark = ","),
    suffix,
    sep = sep)
}

########################################################################

create_plot <- function(data) {
  # Create sunburst plot for the supplied data frame
  lvl0 <- data.frame(orgv = as.factor("root"), cost = NA, level = as.factor(0), fill = NA, alpha = NA)

  lvl1 <- data %>%
          filter(type == "all") %>%
          mutate(orgv = as.factor(orgv), type = as.factor(type), level = as.factor(1), fill = orgv, alpha = type) %>%
          select(orgv, cost, level, fill, alpha)

  lvl2 <- data %>%
          filter(type != "all") %>%
          mutate(orgv = as.factor(orgv), type = as.factor(type), level = as.factor(2), fill = orgv, alpha = type) %>%
          select(orgv = type, cost, level, fill, alpha)

  plot <- bind_rows(lvl0, lvl1, lvl2) %>%
          arrange(fill, orgv) %>%
          ggplot(aes(x = level, y = cost, fill = fill, alpha = alpha)) +
          geom_col(color = "white", width = 0.999, size = 0.2, position = position_stack()) +
          scale_alpha_manual(values = c("all"          = 1,
                                        "bam"          = 0.75,
                                        "checkpoint"   = 0.6875,
                                        "compressed"   = 0.625,
                                        "cram"         = 0.5625,
                                        "index"        = 0.5,
                                        "log"          = 0.4375,
                                        "other"        = 0.375,
                                        "temp"         = 0.3125,
                                        "uncompressed" = 0.25)) +
          scale_x_discrete(breaks = NULL) +
          scale_y_continuous(breaks = NULL) +
          labs(x = NULL, y = NULL, fill = NULL, alpha = NULL) +
          coord_polar(theta = "y") +
          theme_minimal()

  return(plot)
}

main <- function(argv) {
  if (length(argv) != 2) {
    stop("Invalid arguments")
  }

  data <- read.data(argv[1])
  output <- normalizePath(argv[2])

  org_types <- c("group", "user", "pi")

  for (i_fs in unique(data$fs)) {
    for (i_orgk in org_types) {
      write(paste("Creating ", i_orgk," assets for ", i_fs, "...", sep=""), stderr())

      # Get data subset for plotting
      filtered <- data %>% filter(fs == i_fs, orgk == i_orgk)

      # Create exportable data frame
      exportable <- filtered %>%
                    filter(type == "all") %>%
                    mutate(rank = 1)

      if (i_orgk != "pi") {
        # We only care about the top 10 users and groups by cost
        filtered.top10 <- filtered %>% filter(type == "all") %>% top_n(10, cost)
        filtered <- filtered %>% filter(orgv %in% filtered.top10$orgv)

        # Summarise everything besides the top 10
        exportable.ranked <- exportable %>%
                             mutate(rank = ifelse(rank(desc(cost)) <= 10, 1, 2))
        exportable.top    <- exportable.ranked %>% filter(rank == 1)
        exportable.bottom <- exportable.ranked %>% filter(rank == 2) %>%
                             group_by(fs, orgk, type, rank) %>%
                             summarise(inodes = sum(inodes), size = sum(size), cost = sum(cost)) %>%
                             mutate(orgv = paste("\\hline\\textit{Every", ifelse(i_orgk == "user", "one", "thing"), " Else}", sep = ""))

        if (i_orgk == "group") {
          # Sanitise group names
          exportable.top <- exportable.top %>% mutate(orgv = paste("\\texttt{", sanitize(orgv), "}", sep = ""))
        }

        exportable <- bind_rows(exportable.top, exportable.bottom)
      }

      output.prefix <- paste(output, "/", i_fs, "-", i_orgk, ".", sep="")

      # Generate plot and save to disk
      plot <- create_plot(filtered)
      plot.file <- paste(output.prefix, "pdf", sep="")
      suppressMessages(ggsave(plot.file, plot = plot, device = "pdf"))

      # Generate exportable data frame and save to disk
      export <- xtable(exportable %>%
                       arrange(rank, desc(cost)) %>%
                       mutate(h_inodes = format.count(inodes),
                              h_size   = format.data(size),
                              h_cost   = format.money(cost, prefix = "\\pounds")) %>%
                       select("Identity" = orgv, "inodes" = h_inodes, "Size" = h_size, "Cost" = h_cost),
                       align = "llrrr")
      export.file <- paste(output.prefix, "tex", sep="")
      print(export, include.rownames = FALSE, type = "latex", sanitize.text.function = as.is, file = export.file)
    }
  }
}

tryCatch(
  suppressWarnings(main(commandArgs(trailingOnly = TRUE))),
  error = usage)
