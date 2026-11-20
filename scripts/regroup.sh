#!/usr/bin/env bash

############################################################################################
# When a study has groups, regroup their outputs in output/ampliseq/${study}/regrouped
#
# One table per study for:
#
# ASVs counts per sample
# overall summary: "how many reads per sample passed each pipeline step in which a loss can occur" (cutadapt and dada2 steps)
# asv description (ASV_seqs.fasta)
# taxo optional
# sample ID input
# ampliseq parameters - as many files (.yaml) as their are groups because they can have different parameters
# metadata metaworkflow: version (ID commit github), param metaworkflow
# taxonomy done with consensus_taxo.R
#
############################################################################################


# Meta-workflow metadata

if [ ! -f "output/metaworkflow_params.yaml" ]; then

    #nf-core pipelines versions
    fetchngs_version="v1.13.0"
    ampliseq_version="v3.0.0"

    #meta-workflow information
    COMMIT_HASH=$(git rev-parse HEAD) #last commit hash (possible to specify a branch)
    VERSION=$(git describe --always --long | cut -d '-' -f1) #Shows the nearest tag, the number of commits since the tag, and the abbreviated commit hash.

    echo "# Metaworkflow info" \
        > output/agregated/metaworkflow_params.yaml
    echo -e "\n#Versions\nmetaworkflow_version: ${VERSION}
    git_commit_hash: ${COMMIT_HASH}
    fetchngs_version: ${fetchngs_version}
    ampliseq_version: ${ampliseq_version}\n
    #Options
    #Export option:\nexport: ${export}
    #File listing the projects to compute:\nadd_projects: \"${add_studies}\"" \
        >> output/metaworkflow_params.yaml

fi


while IFS= read -r study; do

    [ ! -d "output/ampliseq/${study}/regrouped" ] && mkdir output/ampliseq/${study}/regrouped

    nb_group=$(ls input/${study}/samplesheet* | wc -l)

    if [[ $nb_group -gt 1 ]]; then

        # ASVs sequences
        find ./output/ampliseq/${study}/*/dada2 -name "ASV_seqs.fasta" -exec awk '/^>/ {if (seen[$0]++) {f=0} else {f=1}} f' {} + \
            > ./output/ampliseq/${study}/regrouped/ASV_seqs.fasta

        # ASV counts per sample - rows are ASVs (long format table)
        gzip -dc ./output/ampliseq/${study}/*/summary_tables/ampliseq.counts.tsv.gz | awk 'NR==1 || $0 != "asv_id\tsample\tcount"' \
            > ./output/ampliseq/${study}/regrouped/ampliseq.counts.tsv

        # Input sample IDs
        find ./output/ampliseq/${study}/*/input -name "samplesheet.csv" -exec awk -F',' '
            NR==1 || FNR!=1 {gsub(/^"|"$/, "", $1); print $1}' {} + \
            > ./output/ampliseq/${study}/regrouped/input_samples.txt

        # Overall summary "how many reads per sample passed each pipeline step in which a loss can occur"
        find ./output/ampliseq/${study}/* -name "overall_summary.tsv" -exec awk 'NR==1 || FNR!=1' {} + \
            > ./output/ampliseq/${study}/regrouped/overall_summary.tsv

        # Ampliseq parameters
        for ((i = 1; i <= nb_group; i++)); do
            cp ./input/${study}/params_ampliseq_G${i}.yaml ./output/ampliseq/${study}/regrouped/params_ampliseq_G${i}.yaml
        done

        # Meta-workflow parameters
        cp output/metaworkflow_params.yaml ./output/ampliseq/${study}/regrouped/metaworkflow_params.yaml

    elif [[ $nb_group -eq 1 ]]; then

        # ASVs sequences
        mv ./output/ampliseq/${study}/Group_1/dada2/ASV_seqs.fasta ./output/ampliseq/${study}/regrouped/ASV_seqs.fasta

        # ASV counts per sample
        mv ./output/ampliseq/${study}/Group_1/summary_tables/ampliseq.counts.tsv.gz ./output/ampliseq/${study}/regrouped/ampliseq.counts.tsv
        
        # Input sample IDs
        awk -F',' 'NR==1 || FNR!=1 {gsub(/^"|"$/, "", $1); print $1}
            ' ./output/ampliseq/${study}/Group_1/input/samplesheet.csv  \
            > ./output/ampliseq/${study}/regrouped/input_samples.txt

        # Overall summary
        mv ./output/ampliseq/${study}/Group_1/overall_summary.tsv ./output/ampliseq/${study}/regrouped/overall_summary.tsv

        # Ampliseq parameters
        cp ./input/${study}/params_ampliseq_G1.yaml ./output/ampliseq/${study}/regrouped/params_ampliseq.yaml

        # Meta-workflow parameters
        cp output/metaworkflow_params.yaml ./output/ampliseq/${study}/regrouped/metaworkflow_params.yaml

    fi

done < $1


# Consensus taxonomy per study

if [ $export == "none" ]; then
  echo 'No generation and export of R formatted taxonomy tables. The default option for -e is "none".'

elif [[ $export == "both" || $export == "consensus" || $export == "conflicts" ]]; then

  [ ! -d "output/regrouped/taxonomy" ] && mkdir output/regrouped/taxonomy

  echo "R formatted taxonomy tables exported for all the studies."

  module load r/4.5.2

  sbatch \
    #--mem 20GB \
    --wrap="Rscript scripts/consensus_taxo.R $export"

else

  echo "${export} is an invalid argument for option -e. Use one of "consensus", "conflicts" or "both". Default is "none"."

fi

