#!/usr/bin/Rscript

# GWASSER, an R script for simple gwassing.
# Copyright (C) 2016  Ben J. Ward
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Load libraries and install those required.

r = getOption("repos") # hard code the UK repo for CRAN
r["CRAN"] = "http://cran.uk.r-project.org"
options(repos = r)
rm(r)

# Installed package list.
inst <- installed.packages()[, 1]

# List of required packages.
reqs <- c("lme4", "argparse", "dplyr", "ggplot2", "lmerTest")

# Check each required package is installed.
for(req in reqs){
    if(!(req %in% inst)){
        warning(paste0("Detected that ", req, " is not installed. - INSTALLING"))
        install.packages(req)
    }
}

suppressMessages(library(lme4))
suppressMessages(library(argparse))
suppressMessages(library(dplyr))
suppressMessages(library(ggplot2))
suppressMessages(library(lmerTest))

# Load functions

printBanner <- function(){
  message("--------------------------------------------")
  message(" gwasseR: an R script for simple gwassing  ")
  message("--------------------------------------------")
  message("Adapted from the work of researchers at NIAB")
  message("Techniques here were used for MAGIC analysis of awning")
}

# Build the cmdline argument parser.
processArgs <- function(){
  parser <- ArgumentParser(description = "A simple program for simple GWAS-ing")

  parser$add_argument('--gFile',
                      dest = 'gfile',
                      type = "character",
                      nargs = 1,
                      required = TRUE,
                      help = "Genotype File")

  parser$add_argument('--pFile',
                      dest = 'pfile',
                      type = "character",
                      nargs = '+',
                      required = TRUE,
                      help = "Phenotype File")

  parser$add_argument('--mFile',
                      dest = 'map',
                      type = "character",
                      nargs= 1,
                      help = "Map File")

  parser$add_argument('--phenos',
                      dest = 'phenos',
                      type = "character",
                      nargs = '+',
                      required = TRUE,
                      help = "Phenotypes to associate with SNPs")

  parser$add_argument('--cov',
                      dest = 'covs',
                      type = "character",
                      nargs = '*',
                      help = 'Phenotypes to include as mixed effects')

  parser$add_argument('--outDir',
                      dest = 'outdir',
                      type = "character",
                      nargs = 1,
                      help = "Folder to store output in.",
                      default = getwd())

  parser$add_argument('--noPlots',
                      dest = 'noplots',
                      action = 'store_true',
                      help = "Skip making manhatten plot.")

  parser$add_argument('--saveInter',
                      dest = 'saveinter',
                      action = 'store_true',
                      help = "Whether or not to save intermediate files.")

  arguments <- parser$parse_args()

  return(arguments)
}

if(!interactive()) {
  args <- processArgs()
  if(!dir.exists(args$outdir)){
        message("Output directory is missing, creating directory...")
        dir.create(args$outdir, recursive = TRUE)
    }
  if (!args$noplots) {
    if (is.null(args$map)) {
      message("\n--mFile required to plot\n")
      quit()
    }
  }
}

# Print cmdline arguments out to user.
printArgs <- function(args){
  message("\nInput genotype file:\n  ",
          args$gfile, "\n")

  message("Input phenotype files:\n  ",
          paste(args$pfile, collapse = "\n\n  "), "\n")

  message("Directory for output files:\n ",
          args$outdir, "\n")

  message("Using Phenotypes:\n  ",
          paste(args$phenos, collapse = "\n  "), "\n")

  message("Using Map:\n ",
          args$map, "\n")

  message("Using mixed effects:\n  ",
          paste(args$covs, collapse = "\n  "), "\n")
}


# Parse Genotype file
# Each column is a SNP and each row is an individual.
parseGeno <- function(file){
  geno <- read.csv(file, header = TRUE)
  geno$ID <- as.character(geno$ID)
  for(i in 2:ncol(geno)){
    geno[, i] <- as.factor(geno[, i])
  }
  return(geno)
}

# Parse Phenotype file(s).
# Each row is an individual, each column is some phenotype measurement.
parsePheno <- function(files){
  phenos <- lapply(files, function(x) read.csv(x, header = TRUE))
  output <- Reduce(function(df1, df2){inner_join(df1, df2, by = "ID")}, phenos)
  output$ID <- as.character(output$ID)
  return(output)
}


parseMap <- function(file){
  table <- read.csv(file, header = TRUE)
  return(table)
}


writeOut <- function(table, filename){
  write.csv(table,
            file = filename,
            row.names = FALSE,
            quote = FALSE)
}


# Merge the genotype and phenotype data into one working table.
mergeGenoPheno <- function(pheno, geno){

  suppressWarnings(genoPheno <- inner_join(pheno, geno, by = "ID"))

  if(nrow(genoPheno) == 0){
    stop("Merged data file has no rows, are your ID's the same in all files?")
  }

  if(ncol(genoPheno) < 3){
    stop("Combined data file must have at least 3 columns: ID, Phenotype, and 1 SNP column")
  }

  if(!("ID" %in% colnames(genoPheno))){
    stop("There is no column called 'ID' in the data.")
  }

  namesNotID <- function(table, before = FALSE){
    cnames <- colnames(table)
    idcol <- which(cnames == "ID")
    if (before && idcol == 1) {
      out <- NULL
    } else if (before) {
      out <- cnames[1:(idcol - 1)]
    } else {
      out <- cnames[(idcol + 1):ncol(table)]
    }
    return(out)
  }

  phenoNames <- namesNotID(pheno)
  genoSNPNames <- namesNotID(geno)
  genoNotSNPNames <- namesNotID(geno, before = TRUE)

  genoPheno <- genoPheno[, c(phenoNames,
                             genoNotSNPNames,
                             "ID",
                             genoSNPNames)]

  return(list(data = genoPheno,
              IDcol = which(colnames(genoPheno) == "ID"),
              SNPS = genoSNPNames,
              phenos = c(phenoNames, genoNotSNPNames)))
}


prepResults <- function(df, start){
  snprange <- start:ncol(df)
  fvalues <- numeric(length = length(snprange))
  names(fvalues) <- colnames(df)[snprange]
  fvalues[1:length(fvalues)] <- NA
  return(fvalues)
}

getFVals <- function(model){
    return(anova(model)[1, 4])
}

getPVals <- function(model){
    UseMethod("getPVals", model)
}

getPVals.lm <- function(model){
    return(-log(anova(model)[1, 5]))
}

getPVals.merModLmerTest <- function(model){
    return(-log(coef(summary(model))[2, 5]))
}

snpAssociation <- function(df, phenotype, covs, start){

  fvalues <- prepResults(df, start)
  pvalues <- prepResults(df, start)

  # The basic formular for a linear model should be 'response ~ explanatory variables'.
  baseFormula <- paste0(phenotype, " ~ ")

  # The basic modelling function in R is 'lm'
  modelfun <- lm

  # If there are mixed effects to be taken account of, the function lmer needs to
  # be used instead, and the formula adapted.
  if(length(covs) > 0){
    baseFormula <- paste0(baseFormula,
                          paste0("(1|", covs, ")", collapse = " + "))
    modelfun <- lmer
  }

  for(i in names(fvalues)){
    modelFormula <- as.formula(paste0(baseFormula, " + ", i))
    mod <- modelfun(modelFormula, data = df)
    fred <- try(getFVals(mod))
    pred <- try(getPVals(mod))
    if(class(fred) != "try-error"){
      fvalues[i] <- fred
    }
    if(class(pred) != "try-error"){
      pvalues[i] <- pred
    }
  }

  return(list(fvalues, pvalues))
}


# Run program. Put in a conditional so this file can be sourced for it's functions.
# For example if you were in an R Studio session and wanted to use the above functions,
# you would not really want the below to run.
if(!interactive()){

    printBanner()

    args <- processArgs()

    printArgs(args)

    message("------------------------")
    message("Start Analysis:\n")

    message("Now reading genotype file...")
    genotypes <- parseGeno(args$gfile)

    message("Now reading phenotype files...")
    phenotypes <- parsePheno(args$pfile)

    if(args$saveinter){
      message("Writing merged phenotypes to file...")
      writeOut(phenotypes, paste0(args$outdir, "/combinedPhenotypes.phe"))
    }

    message("Merging genotype and phenotype files...")
    combined <- mergeGenoPheno(phenotypes, genotypes)

    if(args$saveinter){
      message("Writing combined data to file...")
      writeOut(combined$data, paste0(args$outdir, "/combinedData.csv"))
    }

    rm(genotypes, phenotypes)

    if (!args$noplots) {
      message("Now reading map file...")
      map <- parseMap(args$map)
    }

    for(pheno in args$phenos){

      message(paste0("Starting association of SNPs for phenotype: ", pheno))

      results <- snpAssociation(df = combined$data,
                               phenotype = pheno,
                               covs = args$covs,
                               start = combined$IDcol + 1)
      output <- data.frame(ID = names(results[[1]]), fvalues = results[[1]], minlogp = results[[2]])

      message("Writing full raw output data to file...")
      writeOut(output, file = paste0(args$outdir,
                                      paste0("/SNPAssociation-Full-",
                                             pheno,
                                             ".csv")))

      if(!args$noplots){

        # The map should not contain any ID's not in the output, and the output
        # should not contain any ID's not in the map.
        map <- map[map$ID %in% output$ID, ]
        output <- output[output$ID %in% map$ID, ]

        suppressWarnings(plotTab <- inner_join(output, map, by = "ID"))

        if(nrow(plotTab) != nrow(map)){
          warning("The number of rows following merge of map and p values is less. Are some markers not mapped or named inconsistently?")
        }
        if(nrow(plotTab) == 0){
          error("The number of rows following merge of map and p values is 0. This should not happen.")
        }

        plotTab <- arrange(plotTab, Chr, cM)

        plotTab$X <- 1:nrow(plotTab)
        plotTab$Chr <- as.factor(plotTab$Chr)

        writeOut(plotTab, file = paste0(args$outdir,
                                        paste0("/PlottingTable-",
                                               pheno,
                                               ".csv")))

        c25 <- c("dodgerblue2", "#E31A1C",
                 "green4", "#6A3D9A", "#FF7F00",
                 "black", "gold1", "skyblue2", "#FB9A99",
                 "palegreen2", "#CAB2D6", "#FDBF6F", "gray70", "khaki2",
                 "maroon", "orchid1", "deeppink1", "blue1", "steelblue4",
                 "darkturquoise", "green1", "yellow4", "yellow3",
                 "darkorange4", "brown")

        graphic <- ggplot(plotTab, aes(x = X, y = minlogp, colour = Chr)) +
            geom_point() + scale_colour_manual(values = c25) + xlab("SNP") +
            ylab("- log(P)")

        ggsave(filename = paste0(args$outdir,
                                 paste0("/AssociationPlot-", pheno, ".png")),
               plot = graphic,
               width = 10,
               height = 7,
               units = "in")

      }

    }

    message("gwasseR is finished!")

    q("no")

}
