#!/usr/bin/env bash

############################################################################################
# When a study has groups, their outputs are previously regrouped in  in output/ampliseq/${study}/regrouped
#
# Agregation of the regrouped outputs of all the studies together
# For every category, one table for all the studies
#
# ASVs counts per sample
# overall summary: "how many reads per sample passed each pipeline step in which a loss can occur" (cutadapt and dada2 steps)
# asv description (ASV_seqs.fasta)
# taxo optional
# sample ID input
# ampliseq parameters - as many files (.yaml) as their are groups because they can have different parameters
# metadata metaworkflow: version (ID commit github), param metaworkflow
# taxonomy done with consensus_taxo.R (see regroup.sh)
############################################################################################



########################################################
# ASVs sequences
########################################################

# Concatenate fasta and remove duplicate sequences
find ./output/ampliseq/*/regrouped/ASV_seqs.fasta -exec awk '/^>/ {if (seen[$0]++) {f=0} else {f=1}} f' {} + \
  > ./output/agregated/ASV_seqs.fasta


########################################################
# ASV counts per sample
########################################################

#Rows are ASVs (long format table)
find ./output/ampliseq/*/regrouped/ampliseq.counts.tsv.gz -exec gzip -dc {} + | \
  awk 'NR==1 || $0 != "asv_id\tsample\tcount"' \
  > ./output/agregated/ampliseq.counts.tsv


########################################################
# Sample ID input
########################################################

find ./output/ampliseq/*/regrouped/input_samples.txt \
  -exec awk 'NR==1 || FNR!=1 {gsub(/^"|"$/, "", $1); print $1}' {} + \
  > ./output/agregated/input_samples.txt


########################################################
# Overall summary "how many reads per sample passed each pipeline step in which a loss can occur"
########################################################

find ./output/ampliseq/*/regrouped/ -name "overall_summary.tsv" -exec awk 'NR==1 || FNR!=1' {} + \
  > ./output/agregated/overall_summary.tsv


########################################################
# Agregated consensus taxonomy
########################################################

# done in consensus_taxo.r

if [[ $export == "consensus" || $export == "both" ]]; then

  echo "You used -e "consensus" or -e "both", the table of agregated consensus taxonomy for all the studies will be created."

else
  echo "Use -e "consensus" (or -e "both") to have the table of agregated consensus taxonomy for all the studies."

fi


########################################################
# Meta-workflow parameters
########################################################
cp ./output/metaworkflow_params.yaml ./output/agregated/metaworkflow_params.yaml


########################################################
# Traceability - bioproject(s), study ID, link(s) to manuscript(s)
########################################################
cp ./input/studies_traceability.tsv ./output/agregated/traceability.tsv
