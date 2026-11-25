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

  nb_group=$(ls input/${study}/samplesheet* | wc -l)
  
  for ((i = 1; i <= nb_group; i++)); do

    INPUT_FILE=./output/fetchngs/${study}/Group_${i}/samplesheet/samplesheet.csv

    if [[ -f "$INPUT_FILE" &&  $(wc -l < "$INPUT_FILE") -gt 1 ]]; then

      echo "$INPUT_FILE exists and is not empty."
      OUTDIR=./output/ampliseq/${study}/Group_${i}

      if [ -d "$OUTDIR" ]; then
        echo -e "$OUTDIR already exists. Not running ampliseq for the study ${study} group ${i}.\n"

      else
        echo "$OUTDIR directory does not exist. Running ampliseq for the study ${study} group ${i}."

        nextflow run nf-core/ampliseq -r 3.0.0 \
          -profile abims \
          -c ./input/param.config \
          -params-file ./input/${study}/params_ampliseq_G${i}.yaml \
          --input ${INPUT_FILE} \
          --outdir ${OUTDIR}


        # Error check and generation of a resume samplesheet for ampliseq
          
        last_line=$(tail -n 1 .nextflow/history)
        status=$(echo "${last_line}" | cut -f4)

        if [[ $status == "ERR" ]] && echo "$last_line" | grep -q "${study}"; then

          RUN_NAME=$(echo "${last_line}" | cut -f3)
          echo "ampliseq run on the group ${i} of the study ${study} failed. It will be resumed -resume ${RUN_NAME} (run name)."
          echo -e "${study}\t${RUN_NAME}\t${i}" >> tmp/resume_ampliseq.tsv

        fi

      fi

    else
      echo "$INPUT_FILE does not exist or is empty. Run fetchngs for ${study} first."

    fi

  done

done < $1


# Display failed run in run_ampliseq.out

if [[ -f "tmp/resume_ampliseq.tsv" &&  $(wc -l < "tmp/resume_ampliseq.tsv") -gt 0 ]]; then

  echo "The file tmp/resume_ampliseq.tsv was created. It lists the studies groups for which an error occurred when running ampliseq and their associated run name."
  echo "It contains the following line(s):"
  cat tmp/resume_ampliseq.tsv

fi
