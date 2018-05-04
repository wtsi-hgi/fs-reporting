#!/usr/bin/env Rscript

# Render report assets given aggregated filesystem data
# Christopher Harrison <ch12@sanger.ac.uk>

library(ggplot2,    warn.conflicts = FALSE)
library(dplyr,      warn.conflicts = FALSE)
library(xtable,     warn.conflicts = FALSE)
library(functional, warn.conflicts = FALSE)
library(templates,  warn.conflicts = FALSE)

## Utility Functions ###################################################

usage <- function(error) {
  # Output error message, instructions and exit with non-zero status
  write(paste("Error:", error$message), stderr())
  write("Usage: render-assets.R DATA_FILE OUTPUT_DIR [AGGREGATION_DATE]", stderr())
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
  #! FIXME This condition only applies to the first element, but the
  #! increment will be applied to everything
  #! if (n / (base ^ (exponent + 1)) >= threshold) { exponent <- exponent + 1 }

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

## Plotting Function ###################################################

plot.render <- function(data) {
  # Create sunburst plot for the supplied data frame
  lvl0 <- data.frame(orgv = "root", cost = NA, level = as.factor(0), fill = NA, alpha = NA)

  lvl1 <- filter(data, type == "all") %>%
          mutate(level = as.factor(1), fill = orgv, alpha = type) %>%
          select(orgv, cost, level, fill, alpha)

  lvl2 <- filter(data, type != "all") %>%
          mutate(level = as.factor(2), fill = orgv, alpha = type) %>%
          select(orgv = type, cost, level, fill, alpha)

  bind_rows(lvl0, lvl1, lvl2) %>% arrange(fill, orgv) %>%
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
}

## LaTeX Template Functions ############################################

# TODO

## Entrypoint ##########################################################

main <- function(argv) {
  if (length(argv) < 2) { stop("Invalid arguments") }
  data <- read.data(argv[1])
  output <- normalizePath(argv[2])

  # Get aggregation date (expects GNU date)
  if (length(argv) == 2) { argv <- c(argv, "now") }
  data.date <- system(paste("gdate -d '", argv[3], "' '+{%d}{%m}{%Y}'", sep = ""), intern = TRUE)

  org.values <- c("group", "user", "pi")
  filename.template <- tmpl("{{ dir }}/{{ fs }}-{{ orgk }}.{{ ext }}")

  for (i_fs in unique(data$fs)) {
    for (i_orgk in org.values) {
      write(paste("Creating ", i_orgk," assets for ", i_fs, "...", sep=""), stderr())

      # Get data subset for filesystem and organisational type
      filtered <- filter(data, fs == i_fs, orgk == i_orgk)

      # Mark the top 10 records by overall cost
      orgv.top10 <- filter(filtered, type == "all") %>% top_n(10, cost)
      filtered <- mutate(filtered, in.top10 = orgv %in% orgv.top10$orgv)

      # Summarise everything not in the top 10
      orgv.rest <- paste("Every", ifelse(i_orgk == "group", "thing", "one"), " Else", sep = "")
      filtered.rest <- filter(filtered, in.top10 == FALSE) %>%
                       group_by(fs, orgk, type, in.top10) %>%
                       summarise(inodes = sum(inodes), size = sum(size), cost = sum(cost)) %>%
                       mutate(orgv = orgv.rest)

      # For the plots, we want the top 10 records and the summary of
      # everything else, regardless of organisational type
      filtered.plot <- filter(filtered, in.top10 == TRUE) %>%
                       bind_rows(filtered.rest)

      # For the table, we want the full PI data, but the top 10 and
      # summary for users and groups, then the raw data munged into a
      # human-friendly format
      # NOTE filter won't let me use an ifelse expression :(
      if (i_orgk == "pi") {
        filtered.table <- filtered
      } else {
        filtered.table <- filtered.plot
      }
      filtered.table <- filter(filtered.table, type == "all") %>%
                        mutate(latex.begin = "", latex.end = "")

      # More specific formatting
      if (i_orgk != "pi") {
        # "Everyone/thing Else" row is italicised
        filtered.table.top10 <- filter(filtered.table, in.top10 == TRUE)
        filtered.table.rest <- filter(filtered.table, in.top10 == FALSE) %>%
                               mutate(latex.begin = "\\textit{", latex.end = "}")

        if (i_orgk == "group") {
          # Sanitise group names
          filtered.table.top10 <- mutate(filtered.table.top10, orgv = paste("\\texttt{", sanitize(orgv), "}", sep = ""))
        }

        filtered.table <- bind_rows(filtered.table.top10, filtered.table.rest)
      }

      # Create a total line
      filtered.table.total <- group_by(filtered.table, fs, orgk) %>%
                              summarise(inodes = sum(inodes), size = sum(size), cost = sum(cost)) %>%
                              mutate(orgv = "Total", latex.begin = "\\textbf{", latex.end = "}")

      # Sort by cost, append total line and apply LaTeX formatting
      filtered.table <- arrange(filtered.table, desc(cost)) %>%
                        bind_rows(filtered.table.total) %>%
                        mutate(orgv     = paste(latex.begin, orgv, latex.end, sep = ""),
                               h_inodes = paste(latex.begin, format.count(inodes), latex.end, sep = ""),
                               h_size   = paste(latex.begin, format.data(size), latex.end, sep = ""),
                               h_cost   = paste(latex.begin, format.money(cost, prefix = "\\pounds"), latex.end, sep = "")) %>%
                        select("\\textbf{Identity}" = orgv,
                               "\\textbf{inodes}"   = h_inodes,
                               "\\textbf{Size}"     = h_size,
                               "\\textbf{Cost}"     = h_cost)

      # Export assets
      asset.filename = Curry(tmplUpdate, filename.template, dir = output, fs = i_fs, orgk = i_orgk)

      suppressMessages(ggsave(asset.filename(ext = "pdf"),
                       plot = plot.render(filtered.plot),
                       device = "pdf"))

      print(xtable(filtered.table, align = "llrrr"),
            include.rownames = FALSE,
            type = "latex",
            sanitize.text.function = as.is,
            hline.after = c(-1, 0, nrow(filtered.table) - 1),
            file = asset.filename(ext = "tex"))
    }
  }
}

tryCatch(
  suppressWarnings(main(commandArgs(trailingOnly = TRUE))),
  error = usage)
