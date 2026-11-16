#!/usr/bin/env bash

#SBATCH --partition long
#SBATCH --cpus-per-task 1
#SBATCH --mem 5GB
#SBATCH --output run_fetchngs.out

export TMPDIR="/shared/scratch/jedi_meta/"

module load nextflow/26.04.4
module load singularity

i=2
study="LABO23-1"
RUN_NAME="friendly_mccarthy"

nextflow run nf-core/fetchngs -r 1.13.0 \
    -profile abims \
    -c input/param.config \
    -params-file ./input/params_fetchngs.yaml \
    --input ./input/${study}/samplesheet_G${i}.tsv \
    --outdir ./output/fetchngs/${study}/Group_${i} \
    -resume ${RUN_NAME}

i=1
study="LANG22-1"
RUN_NAME="chaotic_panini"

nextflow run nf-core/fetchngs -r 1.13.0 \
    -profile abims \
    -c input/param.config \
    -params-file ./input/params_fetchngs.yaml \
    --input ./input/${study}/samplesheet_G${i}.tsv \
    --outdir ./output/fetchngs/${study}/Group_${i} \
    -resume ${RUN_NAME}

