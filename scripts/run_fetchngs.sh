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


while IFS= read -r study; do

  DIR="output/fetchngs/${study}"

  if [ -d "$DIR" ]; then

    echo "$DIR already exists."

  else

    echo "$DIR directory does not exist. Running fetchngs for the study ${study} or for its groups if applicable."

    nb_group=$(ls input/${study}/samplesheet* | wc -l)

    for ((i = 1; i <= nb_group; i++)); do

      nextflow run nf-core/fetchngs -r 1.13.0 \
        -profile abims \
        -c input/param.config \
        -params-file ./input/params_fetchngs.yaml \
        --input ./input/${study}/samplesheet_G${i}.tsv \
        --outdir ./output/fetchngs/${study}/Group_${i}

      # Error check

      last_line=$(tail -n 1 .nextflow/history)
      status=$(echo "${last_line}" | cut -f4)

      if [[ $status == "ERR" ]] && echo "$last_line" | grep -q "${study}"; then

        RUN_NAME=$(echo "${last_line}" | cut -f3)
        echo -e "${study}\t${RUN_NAME}\t${i}" >> tmp/resume_fetchngs.tsv
        echo "Fetchngs run on the study ${study} group ${i} failed. It was added to tmp/resume_fetchngs.tsv."
        echo "Check fetchngs pipeline report and correct issues if relevant."
        echo "Fetchngs run for $[study} will be resumed with -resume ${RUN_NAME} (run name) when running the workflow again."
        
      fi

    done

  fi

done < $1
