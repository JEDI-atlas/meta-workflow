# Make consensus taxonomy from dada2 assignation with pr2 and silva reference databases ----

############################################################################################
############################################################################################
# This script is part of the jedi meta-workflow, it generates and exports taxonomic tables.
# Usage: Rscript scripts/consensus_taxo.R -e <export_option>
#
# Input:
# Reads in the output of ampliseq/dada2
#
# Outputs:
# Its outputs are given for each study, regrouping its eventual groups, in output/regrouped/taxonomy
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
  


#Export tables to output/regrouped/taxonomy

if (export=="consensus" | export=="both"){
  walk2(.x=pr2_silva_consensus,
        .y=studies_names,
        .f= ~ write_tsv(.x,
                        file=str_c("output/regrouped/taxonomy/", .y,
                                   "_pr2_silva_consensus.tsv"), append=FALSE)
        )
} else if (export=="conflicts" | export=="both"){
  
  ## Get conflict info on the domain level
  domain_conflicts_per_projects <- map(pr2_silva_consensus, domain_conflict)
  
  walk2(.x=domain_conflicts_per_projects,
        .y=studies_names,
        .f= ~ write_tsv(.x,
                        file=str_c("output/regrouped/taxonomy/", .y,
                                   "_domain_conflicts.tsv"), append=FALSE)
        )
} 



##### Agregate taxonomy - one table for all the studies ----
############################################################################################
# The following code part generates and exports one agregated consensus taxonomy table.
# It only runs if "consensus" or "both" were chosen as export option for main.sh
#
# Input:
# pr2_silva_consensus list of tables from consensus_taxo.R script
#
# Output:
# One agregated consensus taxonomic table
#
#Columns of the final table:
#ASV_ID: all the ASV IDs, written only once
#Studies: column listing all the studies where the ASV is found
#consensus_taxo: consensus of all consensus_dada2_taxonomy for the ASV (shortest)
#consensus_conf: consensus of all consensus_dada2_confidence for the ASV (smallest)
#consensus_db: reference database used for the consensus_dada2_taxonomy kept (silva or pr2)
#
############################################################################################

# When an ASV has different taxonomies in different studies, we keep the shortest one.
# We expect small differences bc they are due to non exact reproducibility in dada2

if (export=="consensus" | export=="both"){
  
  # Transform the list of tables in one big table (with repetition)
  binded_tables <- bind_rows(pr2_silva_consensus, .id="Studies") |> 
    select(ASV_ID, Studies, consensus_dada2_taxonomy, consensus_dada2_confidence, consensus_db) |>
    group_by(ASV_ID) |> 
    mutate(Studies = str_c(Studies, collapse="-")) |> 
    ungroup()
  
  
  # Vector of all duplicated ASVs
  dup <- unique(binded_tables$ASV_ID[duplicated(binded_tables$ASV_ID)])
  
  # Add columns of booleans
  #  duplicate: indicates whether the ASV is present in more than one project (TRUE) or unique to a project (FALSE)
  #  same_consensus_taxo: FALSE if difference between the pr2 and silva consensus taxo of the same ASV
  #  same_consensus_confidence: FALSE if difference between pr2 and silva consensus confidence of the same ASV
  
  binded_tables <- binded_tables |>
    mutate(duplicate = ifelse(ASV_ID %in% dup, "TRUE", "FALSE" )) |>
    mutate(same_consensus_taxo = n_distinct(
      ASV_ID, consensus_dada2_taxonomy) == 1, .by = "ASV_ID") |> 
    mutate(same_consensus_confidence = n_distinct(
      ASV_ID, consensus_dada2_confidence) == 1, .by = "ASV_ID") |> 
    distinct()
  
  
  # Different consensus taxonomies, keep the shortest one ---
  taxo_conflicts_solved <- binded_tables |> 
    filter(same_consensus_taxo=="FALSE") |> 
    mutate(nb_NA = str_count(consensus_dada2_taxonomy, "NA")) |> 
    group_by(ASV_ID) |> 
    slice_max(nb_NA, with_ties = FALSE) |> 
    select(! nb_NA)
  
  # Same consensus taxo but different confidences, keep the smallest confidence ----
  confidence_conflicts_solved <- binded_tables |> 
    filter(same_consensus_taxo=="TRUE" & same_consensus_confidence=="FALSE") |> 
    group_by(ASV_ID) |> 
    slice_min(consensus_dada2_confidence)
  
  
  duplicate_without_conflict <- binded_tables |> 
    filter(duplicate=="TRUE" & same_consensus_taxo=="TRUE" & same_consensus_confidence=="TRUE")
  
  not_duplicated <- filter(binded_tables, duplicate=="FALSE")
  
  # Taxonomy table with the consensus taxonomy for all the projects
  agregated_consensus_taxonomy <- rbind(not_duplicated, confidence_conflicts_solved,
                                   taxo_conflicts_solved, duplicate_without_conflict) |> 
    select(ASV_ID, Studies, consensus_dada2_taxonomy, 
           consensus_dada2_confidence, consensus_db)
  
  
  ## Export agregated consensus taxonomy table ----
  write_tsv(agregated_consensus_taxonomy,
            file="output/agregated/agregated_consensus_taxonomy.tsv",
            append=FALSE)

}
