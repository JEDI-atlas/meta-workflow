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

  nextflow run nf-core/ampliseq -r 3.1.0 \
    -profile abims \
    -c input/param.config \
    -params-file ./input/${STUDY}/params_ampliseq_G1.yaml \
    --input ./output/fetchngs/${STUDY}/samplesheet/samplesheet.csv \
    --outdir ./output/ampliseq/${STUDY} \
    -resume ${RUN_NAME}

    #if successful, delete tmp/resume_ampliseq.tsv corresponding line
    last_line=$(tail -n 1 .nextflow/history)
    status=$(echo "${last_line}" | cut -f4)

    if [[ $status == "OK" ]] && echo "$last_line" | grep -q "${STUDY}"; then

      RUN_NAME=$(echo "${last_line}" | cut -f3)
      echo "ampliseq resumed run on the study ${STUDY} succeeded."
      sed -i "/${RUN_NAME}/d" ./tmp/resume_ampliseq.tsv

    fi

done < tmp/resume_ampliseq.tsv

