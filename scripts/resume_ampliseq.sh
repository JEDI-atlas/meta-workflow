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


  INPUT_FILE=./output/fetchngs/${STUDY}/Group_${GROUP}/samplesheet/samplesheet.csv

  nextflow run nf-core/ampliseq -r 3.0.0 \
    -profile abims \
    -c input/param.config \
    -params-file ./input/${STUDY}/params_ampliseq_G${GROUP}.yaml \
    --input ${INPUT_FILE} \
    --outdir ./output/ampliseq/${STUDY}/Group_${GROUP} \
    -resume ${RUN_NAME}

    #if successful, delete tmp/resume_ampliseq.tsv corresponding line
    last_line=$(tail -n 1 .nextflow/history)
    status=$(echo "${last_line}" | cut -f4)

    if [[ $status == "OK" ]] && echo "$last_line" | grep -q "${RUN_NAME}"; then

      echo "ampliseq resumed run on the group ${GROUP} of the study ${STUDY} succeeded."
      sed -i "/${RUN_NAME}/d" ./tmp/resume_ampliseq.tsv
        
    elif [[ $status == "ERR" ]] && echo "$last_line" | grep -q "${RUN_NAME}"; then

      echo "ampliseq resumed run on the group ${GROUP} of the study ${STUDY} failed again."
      sed -i "/${RUN_NAME}/d" ./tmp/resume_ampliseq.tsv

      NEW_RUN_NAME=$(echo "${last_line}" | cut -f3)
      echo -e "${STUDY}\t${NEW_RUN_NAME}\t${GROUP}" >> tmp/resume_ampliseq.tsv

    else
      echo "Unexpected status of the pipeline ampliseq for the group ${GROUP} of the study ${STUDY}, run name ${RUN_NAME}."
      echo "Check tmp/resume_ampliseq.tsv file."

    fi

done < tmp/resume_ampliseq.tsv
