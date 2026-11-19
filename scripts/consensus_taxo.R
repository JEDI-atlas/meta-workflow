# Make consensus taxonomy from pr2 and silva results

# This script is part of the jedi meta-workflow
# Usage: Rscript scripts/consensus_taxo.R $export

# The export option allows to chose which tables will be exported
# Either "consensus", "conflicts" or "both"

# Outputs:
# Its outputs are given for each study, in output/out_per_project/taxonomy

# <STUDY>_pr2_silva_consensus.tsv:
# Table with the taxonomy assigned by dada2 using the reference databases pr2 and silva
# as well as a consensus taxonomy (either pr2 or silva, depending on the ASVs)

# Domain conflicts
# <STUDY>_domain_conflicts.tsv
# Table listing the ASVs for which pr2 and silva gave different domains
# along with pr2 and silva associated domains and full taxonomies



# next dev step

#Generate the tables only if relevant export option







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
# lines are ASV_ID and columns are pr2 and silva taxonomies and confidences
pr2_silva_consensus <-  map2(.x= pr2_taxonomic_tables, 
                             .y= silva_taxonomic_tables,
                             .f= ~ full_join(.x, .y, by="ASV_ID")) |>
                        set_names(studies_names)

# Add the consensus taxonomy on the joined taxonomic tables
#We now have pr2, silva and consensus (confidence consensus only for the most precise taxonomic level kept)
pr2_silva_consensus <- map(pr2_silva_consensus, .f=make_consensus_taxo)


# Agregate the groups of the studies to have one file per study
# Extract the studies names with their group multiplicity name and row-bind the groups
prefixes <- sub("_G\\d+$", "", names(pr2_silva_consensus))
pr2_silva_consensus <- split(pr2_silva_consensus, prefixes) |> 
  map(bind_rows)



## Get conflict info on the domain level ----
domain_names <- str_replace(names(pr2_taxonomic_tables), "pr2", "domain_conflicts")
domain_conflicts_per_projects <- map(pr2_silva_consensus, domain_conflict) |> 
  set_names(domain_names)




# Optionnal export ----
#Bash boolean variables to chose what to export

args <- commandArgs(trailingOnly = TRUE)
export <- args[1] #to export tables with pr2, silva and consensus taxo and/or domain conflicts tables

#Export tables to output/per_project/taxonomy

if (export=="consensus"){
  walk2(.x=pr2_silva_consensus,
        .y=studies_names,
        .f= ~ write_tsv(.x,
                        file=str_c("output/out_per_project/taxonomy/", .y,
                                   "_pr2_silva_consensus.tsv"), append=FALSE)
  )
} else if (export=="conflicts"){
  walk2(.x=domain_conflicts_per_projects,
        .y=studies_names,
        .f= ~ write_tsv(.x,
                        file=str_c("output/out_per_project/taxonomy/", .y,
                                   "_domain_conflicts.tsv"), append=FALSE))
} else if (export=="both"){
  walk2(.x=pr2_silva_consensus,
        .y=studies_names,
        .f= ~ write_tsv(.x,
                        file=str_c("output/out_per_project/taxonomy/", .y,
                                   "_pr2_silva_consensus.tsv"), append=FALSE))
  
  walk2(.x=domain_conflicts_per_projects,
        .y=studies_names,
        .f= ~ write_tsv(.x,
                        file=str_c("output/out_per_project/taxonomy/", .y,
                                   "_domain_conflicts.tsv"), append=FALSE))
} else{
  print(export)
  print('Invalid string given for -e argument. Use one of "consensus", "conflicts" or "both".')
}
