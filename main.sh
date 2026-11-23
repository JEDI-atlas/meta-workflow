#!/usr/bin/env bash

############################################################
# Help                                                     
############################################################
Help() {
  # Display Help
  echo "Help for the pipeline running fetchngs and ampliseq"
  echo -e "Options:\n"
  echo -e "-h        Print this Help.\n"
  echo -e "-a        Path to a file listing the studies you want to analyse (one per line).
          The study ID needs to include a dash '-', 'AZER-1' for instance.
          If there are other studies, they will be ignored
          even if their outputs have been deleted from the working directory but not their input.
          Can be used when you have already successfully ran the workflow/ampliseq on some studies and deleted their outputs
          than added some studies you also want to run (without running the other ones again).\n"
  echo -e "-e       Chose whether to export pr2, silva and consensus taxonomies (pr2_silva_consensus.tsv) and domain conflicts
        (domain_conflicts) tables (one per group and studies??). Either joined, conflicts or both. Default is none.\n"
}


############################################################
# Usage function
############################################################
usage() {
  echo "Usage: $0 -a <tmp/add_new_projects.txt> -e <consensus;conflicts;both> [-h for help]"
}


#########
#Options#
#########

#Default values
export="none"
add_studies="tmp/studies_list.txt"

while getopts ":ha:e:" OPTION
do
  case $OPTION in
  h)
    Help
    Usage
    exit 0
    ;;
  a) #Added studies list to run only these
    add_studies=$OPTARG
    ;;
  e) #Export taxonomy and/or domain conflicts tables
    export=$OPTARG
    ;;
  \?)
    echo "Invalid option: -$OPTARG"
    usage
    exit 1
    ;;
  :)
  	echo "Option -$OPTARG requires an argument."
    usage
    exit 1
    ;;
  esac
done


#Preparation
[ ! -d "tmp" ] && mkdir tmp
[ ! -d "output" ] && mkdir output

export add_studies="$add_studies"
export export="$export"



########################################################
# Gets the list of all studies, if none given
########################################################

if [ $add_studies != "tmp/studies_list.txt" ] ; then

  if [ -f $add_studies ]; then

    echo "Running fetchngs only for the project(s) listed in the file ${add_studies}:"
    cat ${add_studies}

  else

    echo "$add_studies file doesn't exist"
    exit 0

  fi

else
  
  echo "Running fetchngs for every study that has (at least one) samplesheet in input/<STUDY>"
  ls input | grep "-" | sort > tmp/studies_list.txt #need to have a dash "-" in the names of the studies
  echo "The file tmp/studies_list.txt was created."

fi


########################################################
# Make the input samplesheets of the jedi workflow - one per group inside each study
########################################################

while IFS= read -r study; do

  nb_group=$(ls input/${study}/params_ampliseq_*.yaml | wc -l)

  for ((i = 1; i <= nb_group; i++)); do
    awk -v gr="$i" -F '\t' '
    $14 ~ gr { print $4 }' "input/${study}/ena_run_metadata_group.tsv" > "input/${study}/samplesheet_G${i}.tsv"
  done 

done < $add_studies



########################################################
#Run nf-core-fetchngs
########################################################

sbatch scripts/run_fetchngs.sh ${add_studies}

#Re-run fetchngs with option -resume for projects that had en error 
FILE=tmp/resume_fetchngs.tsv

if [[ -f "$FILE" &&  $(wc -l < "$FILE") -gt 0 ]]; then
  sbatch scripts/resume_fetchngs.sh 
fi

########################################################
# Run nf-core ampliseq
########################################################

JOBIDAMPLISEQ=$(sbatch --parsable scripts/run_ampliseq.sh ${add_studies})

#Re-run ampliseq with option -resume for projects that had en error 
FILE=tmp/resume_ampliseq.tsv

if [[ -f "$FILE" &&  $(wc -l < "$FILE") -gt 0 ]]; then
  JOBIDresumeAMPLISEQ=$(sbatch --parsable scripts/resume_ampliseq.sh)
fi


########################################################
# Regroup the (eventual) groups of the studies
########################################################

JOBIDregroup=$(sbatch --parsable --dependency="afterok:$JOBIDAMPLISEQ?afterok:$JOBIDresumeAMPLISEQ" scripts/regroup.sh ${add_studies})


########################################################
# Agregate ampliseq outputs per studies
########################################################

[ ! -d "output/agregated" ] && mkdir output/agregated

sbatch --dependency=afterok:$JOBIDregroup scripts/agregate_outputs.sh
