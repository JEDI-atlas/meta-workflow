#!/usr/bin/env bash



# Agregation of the ampliseq outputs of the studies and their groups all together
# For every category, one table for all the studies and their groups


########################################################
# ASVs sequences
########################################################

# Concatenate fasta and remove duplicate sequences
find ./output/ampliseq/*/*/dada2 -name "ASV_seqs.fasta" -exec awk '/^>/ {if (seen[$0]++) {f=0} else {f=1}} f' {} + \
  > output/agregated/ASV_seqs.fasta


########################################################
# ASV counts per sample
########################################################

#Rows are ASVs (long format table)
gzip -dc output/ampliseq/*/*/summary_tables/ampliseq.counts.tsv.gz | awk 'NR==1 || $0 != "asv_id\tsample\tcount"' \
    > output/agregated/all_projects_ampliseq.counts.tsv


########################################################
# Sample ID input
########################################################

find ./output/ampliseq/*/*/input -name "samplesheet.csv" -exec awk 'NR==1 || FNR!=1' {} + | \
  cut -f1 -d ',' | cut -d '"' -f2 \
  > output/agregated/input_samples.txt


########################################################
# Read counts per sample (summary stats)
########################################################

#Rows are samples
#Cutadapt and dada2 summary statistics in one table
find ./output/ampliseq/*/*/cutadapt -name "cutadapt_summary.tsv" -exec awk 'NR==1 || FNR!=1' {} + \
  > output/agregated/cutadapt_dada2_summary.tsv

find ./output/ampliseq/*/*/dada2 -name "DADA2_stats.tsv" -exec awk 'NR==1 || FNR!=1' {} + \
  >> output/agregated/cutadapt_dada2_summary.tsv


#Overall summary "how many reads per sample passed each pipeline step in which a loss can occur"
find ./output/ampliseq/*/* -name "overall_summary.tsv" -exec awk 'NR==1 || FNR!=1' {} + \
  > output/agregated/overall_summary.tsv



########################################################
# Metadata
########################################################

#Ampliseq input parameters
#Agregated outputs that don't have the same parameters for ampliseq (different quality bins)
#cat input/ampliseq/params_ampliseq.yaml > output/agregated/params_ampliseq.yaml

#Ampliseq version
ampliseq_version="v3.0.0"
#R version for scripts outside of ampliseq - change between users
R_version="v4.5.2"
#Python version used to retrieve metadata
python_version="v3.12"

#Metaworkflow information
COMMIT_HASH=$(git rev-parse HEAD) #last commit hash (possible to specify a branch)
VERSION=$(git describe --always --long | cut -d '-' -f1) #Shows the nearest tag, the number of commits since the tag, and the abbreviated commit hash.

echo "# Metaworkflow info" > output/agregated/metaworkflow_params.yaml
echo -e "\n#Versions\nmetaworkflow_version: ${VERSION}
git_commit_hash: ${COMMIT_HASH}
ampliseq_version: ${ampliseq_version}
R_version: ${R_version}
python_version: ${python_version}\n
#Parameters
#Export options:\nexport: ${export}
#File listing the projects to compute:\nadd_projects: \"${add_studies}\"" \
 >> output/agregated/metaworkflow_params.yaml
