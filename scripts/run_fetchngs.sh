#!/usr/bin/env bash

#SBATCH --partition long
#SBATCH --cpus-per-task 1
#SBATCH --mem 5GB
#SBATCH --output run_fetchngs.out

export TMPDIR="/shared/scratch/jedi_meta/"

module load nextflow/26.04.4
module load singularity


# Run for all the studies in the input folder or for the studies listed in -a (option of main.sh) if applicable

[ ! -d "output/fetchngs" ] && mkdir output/fetchngs


while IFS= read -r STUDY; do

  DIR="output/fetchngs/${STUDY}"

  if [ -d "$DIR" ]; then

    echo "$DIR already exists."

  else

    echo "$DIR directory does not exist. Running fetchngs for the study ${STUDY} or for its groups if applicable."

    nb_group=$(ls input/${STUDY}/samplesheet* | wc -l)
    
    if [[ $nb_group -gt 1 ]]; then #at least 2 groups

    for ((i = 1; i <= nb_group; i++)); do

      nextflow run nf-core/fetchngs -r 1.13.0 \
        -profile abims \
        -c input/param.config \
        -params-file ./input/params_fetchngs.yaml \
        --input ./input/${STUDY}/samplesheet_G${i}.tsv \
        --outdir ./output/fetchngs/${STUDY}/Group_${i}

      # Error check

      last_line=$(tail -n 1 .nextflow/history)
      status=$(echo "${last_line}" | cut -f4)

      if [[ $status == "ERR" ]] && echo "$last_line" | grep -q "${STUDY}"; then

        RUN_NAME=$(echo "${last_line}" | cut -f3)
        echo "fetchngs run on the project ${STUDY} failed. Correct the script and run again with -resume ${RUN_NAME} (run name)."
        echo -e "${STUDY}\t${RUN_NAME}\t${i}" >> tmp/resume_fetchngs.tsv

      fi

    done

    else #when there is only one group (i.e. one seq tech for the whole study)

      nextflow run nf-core/fetchngs -r 1.13.0 \
        -profile abims \
        -c input/param.config \
        -params-file ./input/params_fetchngs.yaml \
        --input ./input/${STUDY}/samplesheet.tsv \
        --outdir ./output/fetchngs/${STUDY}

      # Error check

      last_line=$(tail -n 1 .nextflow/history)
      status=$(echo "${last_line}" | cut -f4)

      if [[ $status == "ERR" ]] && echo "$last_line" | grep -q "${STUDY}"; then

        RUN_NAME=$(echo "${last_line}" | cut -f3)
        echo "fetchngs run on the project ${STUDY} failed. Correct the script and run again with -resume ${RUN_NAME} (run name)."
        echo -e "${STUDY}\t${RUN_NAME}\t0" >> tmp/resume_fetchngs.tsv

      fi

    fi

  fi

done < $1

