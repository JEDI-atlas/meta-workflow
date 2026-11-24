# jedi_meta-workflow

    This workflow helps analysing a large volume of metabarcoding data from different published studies.  

For this first version, the DNA must be amplified with the universal primers (5'-GTGYCAGCMGCCGCGGTAA-3' and 926R (5'-CCGYCAATTYMTTTRAGTTT-3') [(Parada, Needham, & Fuhrman, 2016)](https://pubmed.ncbi.nlm.nih.gov/26271760/), targeting the V4-V5 region of the small subunit rRNA gene and which allows the amplification of 16S rRNA (_Bacteria, Archaea_) as well as 18S rRNA (_Eukaryota_).



## Core steps

1. [nf-core fetchngs pipeline](https://nf-co.re/fetchngs/1.13.0/docs/usage)  
    - downloads fastq from public databases (ENA, ...)  
    - makes appropriate input for ampliseq  
2. [nf-core ampliseq pipeline](https://nf-co.re/ampliseq/3.0.0/)  
    - Sequencing quality control (FastQC)
    - cutadapt (primer removal)  
    - DADA2 (Divisive Amplicon Denoising Algorithm 2):
        - Amplicon Sequence Variants (ASVs) inferring  
        - Taxonomical classification (reference databases: pr2 and silva)  
3. Produces a formatted, reproducible archive for each study  


## Usage

sbatch main.sh -a <add_new_studies.txt> -e <consensus;conflicts;both> [-h for help]  

**Examples:**
sbatch main.sh -a "tmp/add_new_studies.txt" -e both  
sbatch main.sh -e both  


## Inputs  

The input of this workflow corresponds to the output of the linked [metadata workflow](https://github.com/li0ni0/jedi_metadata).  

The inputs must be organized in different studies, which can correspond to one or more publicly available bio-projects, and are given a unique identifier.  


To place in the folder input:  
- **params_fetchngs.yaml**: file with parameters for fetchngs    
- **studies_traceability.tsv**: columns data accession (bioprojects IDs), study ID and link to the paper  
- **param.config** (optionnal, personnalized configuration file for nextflow)  

For each study, in **input/<study_id>**:  
- **ena_run_metadata.tsv** 
- **ena_sample_metadata.tsv** (optional)
- **params_ampliseq_Gi.yaml** (as many files as there are groups, i being the group number)
- **samplesheet_Gi.tsv** (idem)


## Outputs  

The following tables are saved in the folder output/<STUDY>, with information for every run of the study (no more groups) as well as in the folder output/agregated, where they regroup all the runs of all the studies together.  

- **traceability.tsv**:  
    copy of input/studies_traceability.tsv

- **input_samples.txt**:
    sample IDs given as input for the study  

- **ASV_seqs.fasta**:   
    Contains the ASVs IDs and sequences of all the projects   

- [**ampliseq_counts.tsv**](https://nf-co.re/ampliseq/3.1.0/docs/output/#summary-tables):   
    "ASV counts in long format (asv_id, sample, count), zero-count rows dropped. Sourced from DADA2’s raw output, before clustering and any post-processing filters below"   

- [**overall_summary.tsv**](https://nf-co.re/ampliseq/3.1.0/docs/output/#pipeline-information):  
    most_freq_mean_phred_score: 
    Mean sample quality metric: most frequently observed Phred quality across bases (mean for reads 1 and 2) 
    other columns:
    "how many reads per sample passed each pipeline step in which a loss can occur" (see nf-core ampliseq doc)

- **params_ampliseq_G<i>.yaml**:  
    ampliseq parameters, with as many files as groups because they can have different parameters

- **metaworkflow_params.yaml**:
    metadata of the meta-workflow; version (tag + ID commit github), options used

- **consensus_taxo.R**:
    - <pr2/silva>_dada2_taxonomy: taxonomy assigned by dada2 assignTaxonomy() based on the database PR2 (resp. SILVA)
    - <pr2/silva>_dada2_confidence: confidence of the last taxonomic rank assigned by dada2, using PR2 (resp. SILVA)  
    - <pr2/silva>_dada2_allConfidences: the confidences of all the assigned taxonomic ranks, using PR2 (resp. SILVA)  
    - consensus_dada2_taxonomy: the taxonomy assigned with either PR2 or SILVA. See consensus rules below  
    - consensus_confidence: confidence of the last taxonomic rank of the consensus taxonomy  
    - consensus_db: "pr2", "silva" or "-" depending on the consensus taxonomy chosen  

  Rules of consensus taxonomy:  
    pr2 is consensus when the ASV is assigned to _Eukaryota_  
    silva is consensus for _Bacteria_ and _Archaea_  
    silva _Mitochondria_ are assigned _Eukaryota:mito_  (consensus_db: "-")
    silva _Chloroplast_  are assigned _conflict_  (consensus_db: "-")


- **domain_conflicts.tsv**:  
Lists the ASVs for which PR2 and SILVA led to different domain assignation with dada2.
    - ASV_ID                         
    - pr2_dada2_taxonomy_domain 	
    - silva_dada2_taxonomy_domain 	
    - pr2_dada2_taxonomy
    - silva_dada2_taxonomy


In output/agregated, the same tables as listed above are found, except consensus_taxo.tsv and domain_conflicts.tsv.  
Instead:  

- **agregated_consensus_taxo.tsv**:  
    Consensus taxonomy table for one study. The columns are:  
    ASV_ID 
    Projects: column listing all the projects where the ASV is found  
    consensus_taxo: consensus of all the consensus taxonomy for the ASV (shortest)  
    consensus_conf: consensus of all the consensus confidences for the ASV (smallest)  
    consensus_db: corresponding to the consensus taxonomy kept (silva or pr2)  
 
    When an ASV is present in more than one bio-project, there can be (small) differences in dada2 taxonomic assignation between projects due to "[an element of randomness in the naive Bayesian classifier method that comes from selecting the subsamples of the sequence over which boot strapping assignment is performed"](https://github.com/benjjneb/dada2/issues/1115) and which isn't fixed by setting a seed.  
    Thus, when the taxonomies differ, the shortest one (i.e. with the fewest number of taxonomic level assigned) is kept as consensus over the projects.  
    When the taxonomies are identical but the confidences differ, the smallest confidence value is kept.  
    



## Options

**-h**  to print the help  
**-a**  Path to a file listing the samplesheets you want to analyse (one per line).  
    Samplesheets must be named ID_PROJECT.csv with extension .csv .tsv or .txt  
        Example:  
        ID_PROJECT1.csv  
        ID_PROJECT2.tsv  
        ...    
    If there are some other projects samplesheets, they will be ignored, even if their outputs have been deleted from the working directory.  
    Can be used when you have already successfully ran ampliseq on some projects and deleted their outputs than added some samplesheet for projects you also  want to run (without running the other ones again).
**-e**   Can take the values joined, conflicts or both. Default is none.  
         "joined" to export the tables with pr2, silva and consensus taxonomies (pr2_silva_consensus.tsv)  
         "conflicts" to export the tables listing domain conflicts (domain_conflicts.tsv)  
         "both" to export taxonomy and conflicts  
         One table per project.   




## References

### nf-core  

**The nf-core framework for community-curated bioinformatics pipelines.**  
Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.  
Nat Biotechnol. 2020 Feb 13. doi: 10.1038/s41587-020-0439-x.  

### nf-core fetchngs   
doi: 10.5281/zenodo.5070524  


### nf-core ampliseq  
doi: 10.5281/zenodo.1493841  

**Interpretations of Environmental Microbial Community Studies Are Biased by the Selected 16S rRNA (Gene) Amplicon Sequencing Pipeline**  
Daniel Straub, Nia Blackwell, Adrian Langarica-Fuentes, Alexander Peltzer, Sven Nahnsen, Sara Kleindienst  
Frontiers in Microbiology 2020, 11:2652 doi: 10.3389/fmicb.2020.550420.  

**The nf-core framework for community-curated bioinformatics pipelines.**  
Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.  
Nat Biotechnol. 2020 Feb 13. doi: 10.1038/s41587-020-0439-x.  

## Universal primers
Parada AE, Needham DM, Fuhrman JA. Every base matters: assessing small subunit rRNA primers for marine microbiomes with mock communities, time series and global field samples. Environ Microbiol. 2016 May;18(5):1403-14. doi: 10.1111/1462-2920.13023. Epub 2015 Oct 14. PMID: 26271760.

