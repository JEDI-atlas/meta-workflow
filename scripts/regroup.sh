#!/usr/bin/env bash

############################################################################################
# When a study has groups, the groups outputs are regrouped.
#
# For all the studies, the following tables  are placed in output/<STUDY>:
#
# traceability.tsv: bioproject(s), study ID, link(s) to manuscript(s)
# ASV_seqs.fasta: ASVs description
# ampliseq.counts.tsv: ASVs counts per sample
# input_samples.txt: sample ID input
# overall_summary.tsv: sample quality metric and
#   "how many reads per sample passed each pipeline step in which a loss can occur" (cutadapt and dada2 steps)
# params_ampliseq_G<i>.yaml: ampliseq parameters - as many files as groups because they can have different parameters
# metaworkflow_params.yaml: metadata metaworkflow: version (ID commit github), param metaworkflow
#
# Taxonomy tables, done with consensus_taxo.R:
# consensus_taxo.tsv
# domain_conflicts.tsv
#
#
# Agregated consensus taxonomy is also created by consensus_taxo.R in this script, see agregate_outputs.sh
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

    [ ! -d "output/${study}" ] && mkdir output/${study}

    OUT="./output/${study}"

    # Traceability
    grep ${study} ./input/studies_traceability.tsv > ${OUT}/traceability.tsv

    nb_group=$(ls input/${study}/samplesheet* | wc -l)

    if [[ $nb_group -gt 1 ]]; then

        # ASVs sequences
        find ./output/ampliseq/${study}/*/dada2 -name "ASV_seqs.fasta" -exec awk '/^>/ {if (seen[$0]++) {f=0} else {f=1}} f' {} + \
            > ${OUT}/ASV_seqs.fasta

        # ASV counts per sample - rows are ASVs (long format table)
        gzip -dc ./output/ampliseq/${study}/*/summary_tables/ampliseq.counts.tsv.gz | awk 'NR==1 || $0 != "asv_id\tsample\tcount"' \
            > ${OUT}/ampliseq.counts.tsv

        # Input sample IDs
        find ./output/ampliseq/${study}/*/input -name "samplesheet.csv" -exec awk -F',' '
            NR==1 || FNR!=1 {gsub(/^"|"$/, "", $1); print $1}' {} + \
            > ${OUT}/input_samples.txt

        # Overall summary "how many reads per sample passed each pipeline step in which a loss can occur"            
        find "./output/ampliseq/${study}" -mindepth 2 -name "overall_summary.tsv" -exec awk 'NR==1 || FNR!=1' {} + \
            > tmp/${study}_overall_summary.tsv

        # Sample quality metric
        quality_file="tmp/${study}_fastqc_per_sequence_quality_scores_plot.tsv"
        find ./output/ampliseq/${study}/*/multiqc/multiqc_data -name "fastqc_per_sequence_quality_scores_plot.txt" \
            -exec awk 'NR==1 || FNR!=1' {} + \
            > $quality_file
        
        
        for ((i = 1; i <= nb_group; i++)); do

            # Ampliseq parameters
            cp ./input/${study}/params_ampliseq_G${i}.yaml ${OUT}/params_ampliseq_G${i}.yaml

            # Check input and output for differences
            nb_input=$(wc -l input/${study}/samplesheet_G${i}.tsv)
            nb_output=$(( $(wc -l output/ampliseq/${study}/Group_${i}/overall_summary.tsv) - 1))

            if [[ $nb_input != $nb_output ]]; then
                echo "The study ${study} group ${i} has ${nb_input} samples as input"
                echo "and ${nb_output} samples in the output. Check manually for differences or errors."
            fi

        done


    elif [[ $nb_group -eq 1 ]]; then

        # ASVs sequences
        mv ./output/ampliseq/${study}/Group_1/dada2/ASV_seqs.fasta ${OUT}/ASV_seqs.fasta

        # ASV counts per sample
        mv ./output/ampliseq/${study}/Group_1/summary_tables/ampliseq.counts.tsv.gz ${OUT}/ampliseq.counts.tsv
        
        # Input sample IDs
        awk -F',' 'NR==1 || FNR!=1 {gsub(/^"|"$/, "", $1); print $1}
            ' ./output/ampliseq/${study}/Group_1/input/samplesheet.csv  \
            > ${OUT}/input_samples.txt

        # Overall summary
        mv ./output/ampliseq/${study}/Group_1/overall_summary.tsv tmp/${study}_overall_summary.tsv

        # Ampliseq parameters
        cp ./input/${study}/params_ampliseq_G1.yaml ${OUT}/params_ampliseq.yaml


        # Check input and output for differences
        nb_input=$(wc -l input/${study}/samplesheet_G1.tsv)
        nb_output=$(( $(wc -l "output/ampliseq/${study}/Group_1/overall_summary.tsv") - 1))

        if [[ $nb_input != $nb_output ]]; then
            echo "The study ${study} has ${nb_input} samples as input"
            echo "and ${nb_output} samples in the output. Check manually for differences or errors."
        fi

        # Sample quality metric
        quality_file="output/ampliseq/${study}/Group_1/multiqc/multiqc_data/fastqc_per_sequence_quality_scores_plot.txt"

    fi


    # Meta-workflow parameters
    cp ./output/metaworkflow_params.yaml ${OUT}/metaworkflow_params.yaml


    # Sample quality metric - most frequently observed Phred quality across bases (mean for reads 1 and 2)
    awk 'NR == 1 {print "most_freq_mean_phred_score"
        next
        }
        NR % 2 == 0 {
            max_count_even = -1
            save_score_even = 0
            for (i = 2; i <= NF; i += 2) {
                score = $i;
                count = $(i+1);
                gsub(/[(),]/, "", score);
                gsub(/[(),]/, "", count);
                if (count + 0 > max_count_even) {
                    max_count_even = count + 0
                    save_score_even = score + 0
                }
            }
        }
        NR % 2 == 1 {
            max_count_odd = -1
            save_score_odd = 0
            for (i = 2; i <= NF; i += 2) {
                score = $i;
                count = $(i+1);
                gsub(/[(),]/, "", score);
                gsub(/[(),]/, "", count);
                if (count + 0 > max_count_odd) {
                    max_count_odd = count + 0
                    save_score_odd = score + 0
                }
            }            
            print (save_score_even + save_score_odd) / 2
        }' $quality_file | paste <(cut -f1 tmp/${study}_overall_summary.tsv) \
            - <(cut -f2- tmp/${study}_overall_summary.tsv) \
            > ${OUT}/overall_summary.tsv

done < $1


# Consensus taxonomy per study

if [ $export == "none" ]; then
  echo 'No generation and export of R formatted taxonomy tables. The default option for -e is "none".'

elif [[ $export == "both" || $export == "consensus" || $export == "conflicts" ]]; then

    [ ! -d "output/agregated" ] && mkdir output/agregated

    echo "R formatted taxonomy tables exported for all the studies."

    module load r/4.5.2

    sbatch \
        #--mem 20GB \
        --wrap="Rscript scripts/consensus_taxo.R $export"

else

  echo "${export} is an invalid argument for option -e. Use one of "consensus", "conflicts" or "both". Default is "none"."

fi


# Clean
rm tmp/*_fastqc_per_sequence_quality_scores_plot.tsv
rm tmp/*_overall_summary.tsv
