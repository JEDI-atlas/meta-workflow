#!/usr/bin/env bash

############################################################################################
# Aggregation of the regrouped outputs of all the studies together.
#
# Tables created in output/final_files/aggregated:
#
# counts.tsv: ASVs counts per sample
# sequences.fasta: ASVs sequences
# input_samples.txt: sample ID input
# overall_summary.tsv: sample quality metric and "how many reads per sample passed each pipeline step in which a loss can occur" (cutadapt and dada2 steps)
# metaworkflow_params.yaml: metadata meta-workflow (versions)
# traceability.tsv: bioproject(s), study ID, link(s) to manuscript(s)
# 
# Taxonomy table
# taxonomy.tsv: consensus for duplicated ASVs and between pr2 and silva, see README for more information
# (already exported by consensus_taxo.R in regroup.sh)
############################################################################################

out_dir="./output/final_files/aggregated"

########################################################
# ASVs sequences
########################################################

# Concatenate fasta and remove duplicate sequences
find ./output/final_files/per_study/*/ASV_seqs.fasta -exec awk '/^>/ {if (seen[$0]++) {f=0} else {f=1}} f' {} + \
  > ${out_dir}/sequences.fasta


########################################################
# ASV counts per sample
########################################################

#Rows are ASVs (long format table)
find ./output/final_files/per_study/*/ampliseq.counts.tsv -exec awk 'NR==1 || $0 != "asv_id\tsample\tcount"' {} + \
  > ${out_dir}/counts.tsv


########################################################
# Sample ID input
########################################################

find ./output/final_files/per_study/*/input_samples.txt \
  -exec awk 'NR==1 || FNR!=1 {gsub(/^"|"$/, "", $1); print $1}' {} + \
  > ${out_dir}/input_samples.txt


########################################################
# Overall summary "how many reads per sample passed each pipeline step in which a loss can occur"
########################################################

find ./output/final_files/per_study/*/overall_summary.tsv -exec awk 'NR==1 || FNR!=1' {} + \
  > ${out_dir}/overall_summary.tsv


########################################################
# Meta-workflow parameters
########################################################
cp ./output/metaworkflow_params.yaml ${out_dir}/metaworkflow_params.yaml


########################################################
# Traceability - bioproject(s), study ID, link(s) to manuscript(s)
########################################################
cp ./input/studies_traceability.tsv ${out_dir}/traceability.tsv
