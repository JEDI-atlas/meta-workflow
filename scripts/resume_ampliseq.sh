#!/usr/bin/env bash

#SBATCH --partition long
#SBATCH --cpus-per-task 1
#SBATCH --mem 5GB
#SBATCH --output resume_ampliseq.out

export TMPDIR="/shared/scratch/jedi_meta/"

module load nextflow/26.04.4
module load singularity


while IFS=$'\t' read -r -a LINE; do

  STUDY=${LINE[0]}
  RUN_NAME=${LINE[1]}
  GROUP=${LINE[2]}

  nb_group=$(ls input/${STUDY}/samplesheet* | wc -l)
    
  if [[ $nb_group -gt 1 ]]; then #at least 2 groups

    for ((i = 1; i <= nb_group; i++)); do

      INPUT_FILE=./output/fetchngs/${STUDY}/Group_${i}/samplesheet/samplesheet.csv

      nextflow run nf-core/ampliseq -r 3.0.0 \
        -profile abims \
        -c input/param.config \
        -params-file ./input/${STUDY}/params_ampliseq_G${i}.yaml \
        --input ${INPUT_FILE} \
        --outdir ./output/ampliseq/${STUDY}/Group_${i} \
        -resume ${RUN_NAME}

        #if successful, delete tmp/resume_ampliseq.tsv corresponding line
        last_line=$(tail -n 1 .nextflow/history)
        status=$(echo "${last_line}" | cut -f4)

        if [[ $status == "OK" ]] && echo "$last_line" | grep -q "${RUN_NAME}"; then

          echo "ampliseq resumed run on the group ${i} of the study ${STUDY} succeeded."
          sed -i "/${RUN_NAME}/d" ./tmp/resume_ampliseq.tsv
        
        elif [[ $status == "ERR" ]] && echo "$last_line" | grep -q "${RUN_NAME}"; then

          echo "ampliseq resumed run on the group ${i} of the study ${STUDY} failed again."
          sed -i "/${RUN_NAME}/d" ./tmp/resume_ampliseq.tsv

          NEW_RUN_NAME=$(echo "${last_line}" | cut -f3)
          echo -e "${STUDY}\t${NEW_RUN_NAME}\t${i}" >> tmp/resume_ampliseq.tsv

        else
          echo "Unexpected status of the pipeline ampliseq for the group ${i} of the study ${STUDY}, run name ${RUN_NAME}."
          echo "Check tmp/resume_ampliseq.tsv file."

        fi

    done

  # Only one group for the study
  elif [[ $nb_group -eq 1 ]]; then

    INPUT_FILE=./output/fetchngs/${STUDY}/samplesheet/samplesheet.csv

    nextflow run nf-core/ampliseq -r 3.0.0 \
      -profile abims \
      -c input/param.config \
      -params-file ./input/${STUDY}/params_ampliseq_G1.yaml \
      --input ${INPUT_FILE} \
      --outdir ./output/ampliseq/${STUDY} \
      -resume ${RUN_NAME}

      #if successful, delete tmp/resume_ampliseq.tsv corresponding line
      last_line=$(tail -n 1 .nextflow/history)
      status=$(echo "${last_line}" | cut -f4)

      if [[ $status == "OK" ]] && echo "$last_line" | grep -q "${RUN_NAME}"; then

        echo "ampliseq resumed run on the study ${STUDY} succeeded."
        sed -i "/${RUN_NAME}/d" ./tmp/resume_ampliseq.tsv
        
      elif [[ $status == "ERR" ]] && echo "$last_line" | grep -q "${RUN_NAME}"; then

        echo "ampliseq resumed run for the study ${STUDY} failed again."
        sed -i "/${RUN_NAME}/d" ./tmp/resume_ampliseq.tsv

        NEW_RUN_NAME=$(echo "${last_line}" | cut -f3)
        echo -e "${STUDY}\t${NEW_RUN_NAME}\t0" >> tmp/resume_ampliseq.tsv #add this line to resume on the resumed run next time the pipeline is launched

      else
        echo "Unexpected status of the pipeline ampliseq for the study ${STUDY}, run name ${RUN_NAME}."
        echo "Check tmp/resume_ampliseq.tsv file."

      fi

  fi

done < tmp/resume_ampliseq.tsv
