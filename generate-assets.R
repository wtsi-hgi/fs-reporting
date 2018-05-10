#!/usr/bin/env Rscript

# Render report assets given aggregated filesystem data
# Christopher Harrison <ch12@sanger.ac.uk>

library(ggplot2,    warn.conflicts = FALSE)
library(dplyr,      warn.conflicts = FALSE)
library(xtable,     warn.conflicts = FALSE)
library(functional, warn.conflicts = FALSE)

## Utility Functions ###################################################

write.stderr <- Curry(write, file = stderr())

usage <- function(error) {
  # Output error message, instructions and exit with non-zero status
  write.stderr(paste("Error:", error$message))
  write.stderr("Usage: generate-assets.R DATA_FILE OUTPUT_DIR [AGGREGATION_DATE]")
  quit(status = 1)
}

# Load aggregated data from file and annotate, appropriately
read.data <- Curry(read.delim, header = FALSE, col.names = c("fs", "orgk", "orgv", "type", "inodes", "size", "cost"))

## Text Formatting Functions ###########################################

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
    theme_minimal(base_family = "Palatino")
}

## LaTeX Source ########################################################

# FIXME? This is kind of horrible, but at least we don't have yet
# another dependency on, say, Jinja2.

# Preamble and start of document environment template
latex.header <- Curry(sprintf, "
\\documentclass[a4paper]{article}

\\usepackage{graphicx}
\\usepackage{datetime}
\\usepackage{fancyhdr}
\\usepackage{parskip}
\\usepackage{mathpazo}
\\usepackage{eulervm}
\\usepackage[T1]{fontenc}

\\setlength{\\parindent}{0cm}
\\linespread{1.05}
\\renewcommand{\\arraystretch}{1.05}

\\newdate{dataDate}%s

\\setlength{\\headheight}{15pt}
\\pagestyle{fancy}
\\fancyhf{}
\\lhead{\\large\\textsc{Human Genetics Programme Filesystem Usage}}
\\fancyfoot[L]{\\leftmark}
\\fancyfoot[R]{\\rightmark}

\\begin{document}")

# Appendix and end of document environment string
latex.footer <- "
  \\newpage
  \\appendix
  \\section{Cost Calculation}

  Total data cost is calculated using the following formula, over the
  appropriate set of files on filesystem $F$:

  \\begin{displaymath}
    R_F \\sum_{f \\in F} S_f (t_0 - t_f)
  \\end{displaymath}

  \\begin{tabbing}
    Where, \\= $R_F$ \\= $=$ \\= Filesystem cost rate (GBP$\\cdot$TiB$^{-1}\\cdot$year$^{-1}$); \\\\
           \\> $S_f$ \\> $=$ \\> File size (TiB); \\\\
           \\> $t_0$ \\> $=$ \\> Aggregation time (\\displaydate{dataDate}); \\\\
           \\> $t_f$ \\> $=$ \\> File \\texttt{ctime}. \\\\
  \\end{tabbing}

  Each file's \\texttt{ctime} (change time) is used as a proxy for when
  it came into existence on its respective filesystem, as it is not
  likely to change during the file's lifetime. However, as such, the
  total cost represents a lower bound.
\\end{document}"

# Section function
latex.section <- (function() {
  titles <- list(
    "lustre"    = "Lustre",
    "irods"     = "iRODS",
    "nfs"       = "NFS",
    "warehouse" = "Warehouse")

  # We don't use templates here, because it has a bug with templates
  # enclosed within curly braces
  function(fs) { sprintf("\\section{%s}", titles[[fs]]) }
})()

latex.subsection <- (function() {
  titles <- list(
    "pi"    = "By Principal Investigator",
    "group" = "By Group",
    "user"  = "By User")

  import.template <- Curry(sprintf, "%s-%s.%s")

  function(fs, orgk, new.page = FALSE) {
    asset.filename <- Curry(import.template, fs, orgk)

    paste(
      sprintf("%s\\subsection{%s}", ifelse(new.page, "\\newpage\n", ""), titles[[orgk]]),
      "",
      sprintf("\\input{%s}", asset.filename("tex")),
      "",
      "\\begin{center}",
      sprintf("\\includegraphics[width=0.9\\linewidth]{%s}", asset.filename("pdf")),
      "\\end{center}",
      "",
      sep = "\n")
  }
})()

## Entrypoint ##########################################################

main <- function(argv) {
  if (length(argv) < 2) { stop("Invalid arguments") }
  data <- read.data(argv[1])
  output <- normalizePath(argv[2])

  # Get aggregation date (expects GNU date)
  if (length(argv) == 2) { argv <- c(argv, "now") }
  data.date <- system(paste("date -d '", argv[3], "' '+{%d}{%m}{%Y}'", sep = ""), intern = TRUE)

  org.values <- c("pi", "group", "user")

  report.filename <- sprintf("%s/report.tex", output)
  asset.template <- Curry(sprintf, "%s/%s-%s.%s")

  write(latex.header(data.date), report.filename)
  write.report <- Curry(write, file = report.filename, append = TRUE)
  new.page <- FALSE

  for (i_fs in unique(data$fs)) {
    write.report(latex.section(i_fs))

    for (i_orgk in org.values) {
      write.stderr(paste("Creating ", i_orgk," assets for ", i_fs, "...", sep=""))

      # Get data subset for filesystem and organisational type
      filtered <- filter(data, fs == i_fs, orgk == i_orgk)

      if (nrow(filtered) == 0) {
        # Skip writing output for empty datasets
        break
      }

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
      asset.filename = Curry(asset.template, output, i_fs, i_orgk)

      suppressMessages(
        ggsave(asset.filename("pdf"),
               plot = plot.render(filtered.plot),
               device = "pdf"))

      print(xtable(filtered.table, align = "llrrr"),
            include.rownames = FALSE,
            type = "latex",
            sanitize.text.function = as.is,
            hline.after = c(-1, 0, nrow(filtered.table) - 1),
            file = asset.filename("tex"))

      # Write output into report
      write.report(latex.subsection(i_fs, i_orgk, new.page))
      new.page <- TRUE
    }
  }

  write.report(latex.footer)
  write.stderr("All done :)")
}

tryCatch(
  suppressWarnings(main(commandArgs(trailingOnly = TRUE))),
  error = usage)
