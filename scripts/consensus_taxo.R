# Make consensus taxonomy from pr2 and silva results

############################################################################################
############################################################################################
# This script is part of the jedi meta-workflow, it generates and exports taxonomic tables.
# Usage: Rscript scripts/consensus_taxo.R -e <export_option>
#
# Input:
# Reads in the output of ampliseq/dada2
#
# Outputs:
# Its outputs are given for each study, regrouping its eventual groups, in output/out_per_project/taxonomy
#
# Consensus
# <STUDY>_pr2_silva_consensus.tsv:
# dada2 assignated taxonomy: with pr2, silva and a consensus (either pr2 and silva depending on the ASV)
# The consensus confidence refers to the most precise taxonomic level kept
# rows: ASVs, columns, pr2, silva and consensus taxonomies and confidences, consensus database
#
# Domain conflicts
# <STUDY>_domain_conflicts.tsv
# the conflicts on the domain level: ASVs for which pr2 and silva led to different assignation with dada2
# rows: ASVs, columns: pr2 domain, silva domain (and the associated full taxonomy)
#
#
# The export option (-e) allows to chose which tables will be exported
# The arguments are either "consensus" (consensus table), "conflicts" (domain conflicts table) or "both" (both tables).
# Default is "none" (the script doesn't run).
############################################################################################
############################################################################################


#Generate the tables only if relevant export option

# Export option ----
args <- commandArgs(trailingOnly = TRUE)
export <- args[1] #to export tables with pr2, silva and consensus taxo and/or domain conflicts tables


# Libraries and functions ----  
library(tidyverse)
library(stringmagic)
library(stringr)

source("scripts/functions_taxo.R")
  


## Read files ----
studies_list <- readLines("tmp/studies_list.txt")
  
taxo_files_pr2 <- list.files(path="output/ampliseq", pattern="ASV_tax.pr2", recursive=TRUE, full.names=TRUE)
taxo_files_silva <- list.files(path="output/ampliseq", pattern="ASV_tax.silva", recursive=TRUE, full.names=TRUE)
  
studies_names <- str_remove_all(taxo_files_pr2, "^output/ampliseq/|/dada2.+") |> 
  str_replace("/Group_", "_G")
  
pr2_taxonomic_tables <- taxo_files_pr2 |>  
  set_names(str_c("pr2_", studies_names)) |> 
  map(read_tsv)
  
silva_taxonomic_tables <- taxo_files_silva |>  
  set_names(str_c("silva_", studies_names)) |> 
  map(read_tsv)
  


## Make consensus taxnomy ----
  
# Formatted tables for each projects for silva and pr2
pr2_taxonomic_tables <- map(pr2_taxonomic_tables, format_taxo_table_pr2)
silva_taxonomic_tables <- map(silva_taxonomic_tables, format_taxo_table_silva)
  
  
# Table with both pr2 and silva complete taxonomies
pr2_silva_consensus <-  map2(.x= pr2_taxonomic_tables, 
                             .y= silva_taxonomic_tables,
                             .f= ~ full_join(.x, .y, by="ASV_ID")) |>
                        set_names(studies_names)
  
# Add the consensus taxonomy on the joined taxonomic tables
pr2_silva_consensus2 <- map(pr2_silva_consensus, .f=make_consensus_taxo)

# Agregate the groups of the studies to have one file per study
# Extract the studies names with their group multiplicity and row-bind the groups
prefixes <- sub("_G\\d+$", "", names(pr2_silva_consensus))
pr2_silva_consensus <- split(pr2_silva_consensus, prefixes) |> 
  map(bind_rows)
  


#Export tables to output/out_per_project/taxonomy

if (export=="consensus" | export=="both"){
  walk2(.x=pr2_silva_consensus,
        .y=studies_names,
        .f= ~ write_tsv(.x,
                        file=str_c("output/out_per_project/taxonomy/", .y,
                                   "_pr2_silva_consensus.tsv"), append=FALSE)
        )
} else if (export=="conflicts" | export=="both"){
  
  ## Get conflict info on the domain level
  domain_conflicts_per_projects <- map(pr2_silva_consensus, domain_conflict)
  
  walk2(.x=domain_conflicts_per_projects,
        .y=studies_names,
        .f= ~ write_tsv(.x,
                        file=str_c("output/out_per_project/taxonomy/", .y,
                                   "_domain_conflicts.tsv"), append=FALSE)
        )
} 
