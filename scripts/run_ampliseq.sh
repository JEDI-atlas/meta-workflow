#!/usr/bin/env bash

#SBATCH --partition long
#SBATCH --cpus-per-task 1
#SBATCH --mem 5GB
#SBATCH --output run_ampliseq.out

export TMPDIR="/shared/scratch/jedi_meta/"

module load nextflow/26.04.4
module load singularity

[ ! -d "output/ampliseq" ] && mkdir output/ampliseq

#Check that fetchngs samplesheet output was created and is not empty for each project
#Better than not empty, check if
#nb_line(output/fetchngs/${project}/samplesheet/samplesheet.csv) -1 == nb_line(input/fetchngs/samplesheet/${project}.csv)
#If yes, run ampliseq

while IFS= read -r study; do

  INPUT_FILE=./output/fetchngs/${study}/samplesheet/samplesheet.csv

  if [[ -f "$INPUT_FILE" &&  $(wc -l < "$INPUT_FILE") -gt 1 ]]; then

    echo "$INPUT_FILE exists and is not empty."

    DIR=output/ampliseq/${study}

    if [ -d "$DIR" ]; then

      echo "$DIR already exists. Not running ampliseq for the study ${study}."

    else

      echo "$DIR directory does not exist. Running ampliseq for the study ${study} or for its groups if applicable."
      
      nb_group=$(ls input/${study}/samplesheet* | wc -l)

      if [[ $nb_group -gt 1 ]]; then

        for ((i = 1; i <= nb_group; i++)); do

          nextflow run nf-core/ampliseq -r 3.0.0 \
            -profile abims \
            -c input/param.config \
            -params-file ./input/${study}/params_ampliseq_G${i}.yaml \
            --input ${INPUT_FILE} \
            --outdir ./output/ampliseq/${study}/Group_${i}

        done

      elif [[ $nb_group -eq 1 ]]; then

        nextflow run nf-core/ampliseq -r 3.0.0 \
          -profile abims \
          -c input/param.config \
          -params-file ./input/${study}/params_ampliseq_G1.yaml \
          --input ${INPUT_FILE} \
          --outdir ./output/ampliseq/${study}
          
      fi

    fi

    # Error check and generation of a resume samplesheet 

    last_line=$(tail -n 1 .nextflow/history)
    status=$(echo "${last_line}" | cut -f4)

    if [[ $status == "ERR" ]] && echo "$last_line" | grep -q "${study}"; then

      RUN_NAME=$(echo "${last_line}" | cut -f3)

      echo "ampliseq run on the study ${study} failed. It will be resumed -resume ${RUN_NAME} (run name)."
      echo -e "${study}\t${RUN_NAME}" >> tmp/resume_ampliseq.tsv

    fi

  else

    echo "$INPUT_FILE does not exist or is empty. Run fetchngs for ${study} first."

  fi

done < $1


# Display failed run in run_ampliseq.out

if [[ -f "tmp/resume_ampliseq.tsv" &&  $(wc -l < "tmp/resume_ampliseq.tsv") -gt 0 ]]; then

  echo "The file tmp/resume_ampliseq.tsv was created."
  echo "It lists the project(s) for which an error occurred when running ampliseq and their associated run name."
  cat tmp/resume_ampliseq.tsv

fi
