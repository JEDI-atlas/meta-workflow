#!/usr/bin/env bash

############################################################
# Help                                                     
############################################################
Help() {
  # Display Help
  echo "Help for the pipeline running fetchngs and ampliseq"
  echo "options:"
  echo "-h     Print this Help."
  echo -e "-a  Path to a file listing (one per line) the samplesheets you want to analyse.
                Samplesheets must be named project_id with extension .csv .tsv or .txt
                Example: project_id1.csv\nproject_id2.tsv
                If there are samplesheets for other projects, they will be ignored \neven if their outputs have been deleted from the working directory.
                Can be used when you have already successfully ran ampliseq on some projects and deleted their outputs
                than added some samplesheet for projects you also want to run (without running the other ones again)."
  echo "-e    Chose whether to export pr2, silva and consensus taxonomies (pr2_silva_consensus.tsv) and domain conflicts
              (domain_conflicts) tables (one per project). Either joined, conflicts or both. Default is none."
}


############################################################
# Usage function
############################################################
usage() {
  echo "Usage: $0 -a <tmp/add_new_projects.txt> -e <joined;conflicts;both> [-h for help]"
}


#########
#Options#
#########

#Default values
export="none"
add_projects="tmp/studies_list.txt"

while getopts ":ha:e:" OPTION
do
  case $OPTION in
  h)
    Help
    usage
    exit 0
    ;;
  a) #Added studies list to run only these
    add_projects=$OPTARG
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

export add_projects="$add_projects"
export export="$export"



########################################################
# Gets the list of all studies, if none given
########################################################

if [ $add_projects != "tmp/studies_list.txt" ] ; then

  if [ -f $add_projects ]; then

    echo "Running fetchngs only for the project(s) listed in the file ${add_projects}:"
    cat ${add_projects}

  else

    echo "$add_projects file doesn't exist"
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

  if [[ $nb_group -gt 1 ]]; then 

    for ((i = 1; i <= nb_group; i++)); do
      awk -v gr="$i" -F '\t' '
        $14 ~ gr { print $4 }' "input/${study}/ena_run_metadata_group.tsv" > "input/${study}/samplesheet_G${i}.tsv"
    done 

  elif [[ $nb_group -eq 1 ]]; then

    awk 'NR>1 {print $4}' "input/${study}/ena_run_metadata_group.tsv" > "input/${study}/samplesheet.tsv"

  fi

done < $add_projects



########################################################
#Run nf-core-fetchngs
########################################################

sbatch scripts/run_fetchngs.sh ${add_projects}


########################################################
# Run ampliseq
########################################################

sbatch scripts/run_ampliseq.sh ${add_projects}

#Re-run ampliseq with option -resume for projects that had en error 
FILE=tmp/ampliseq_projectsTOresume.tsv

if [[ -f "$FILE" &&  $(wc -l < "$FILE") -gt 0 ]]; then
  sbatch scripts/resume_ampliseq.sh 
fi

########################################################
# Agregate ampliseq outputs per projects
########################################################
[ ! -d "output/agregated" ] && mkdir output/agregated

sbatch scripts/agregate_ampliseq_outputs.sh
