#!/usr/bin/env bash

#SBATCH --partition long
#SBATCH --cpus-per-task 1
#SBATCH --mem 5GB
#SBATCH --output run_fetchngs.out

export TMPDIR="/shared/scratch/jedi_meta/"

module load nextflow/26.04.4
module load singularity


while IFS=$'\t' read -r -a LINE; do

    STUDY=${LINE[0]}
    RUN_NAME=${LINE[1]}
    GROUP=${LINE[2]}

    nb_group=$(ls input/${STUDY}/samplesheet* | wc -l)
    
    nextflow run nf-core/fetchngs -r 1.13.0 \
        -profile abims \
        -c input/param.config \
        -params-file ./input/params_fetchngs.yaml \
        --input ./input/${STUDY}/samplesheet_G${GROUP}.tsv \
        --outdir ./output/fetchngs/${STUDY}/Group_${GROUP} \
        -resume ${RUN_NAME}


    #if successful, delete tmp/resume_fetchngs.tsv corresponding line, else update RUN_NAME

    last_line=$(tail -n 1 .nextflow/history)
    status=$(echo "${last_line}" | cut -f4)

    if [[ $status == "OK" ]] && echo "$last_line" | grep -q "${RUN_NAME}"; then
            
        echo "fetchngs resumed run on the study ${STUDY} and group ${GROUP} succeeded."
        sed -i "/${RUN_NAME}/d" ./tmp/resume_fetchngs.tsv
    
    elif [[ $status == "ERR" ]] && echo "$last_line" | grep -q "${RUN_NAME}"; then
         
        echo "fetchngs resumed run on the study ${STUDY} and group ${GROUP} failed again."
        sed -i "/${RUN_NAME}/d" ./tmp/resume_fetchngs.tsv #remove line then replace with the new run name

        NEW_RUN_NAME=$(echo "${last_line}" | cut -f3)
        echo -e "${STUDY}\t${NEW_RUN_NAME}\t${GROUP}" >> tmp/resume_fetchngs.tsv
    
    else
        echo "Unexpected status of the pipeline fetchngs for the group ${i} of the study ${STUDY}, run name ${RUN_NAME}."
        echo "Check tmp/resume_ampliseq.tsv file."

    fi

done < tmp/resume_fetchngs.tsv
