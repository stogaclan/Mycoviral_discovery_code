# Searching for Mycoviral Sequences in fungal transcriptomic dataset
The scripts in this repository are made to run sequentially shown in Steps below, with the aim of searching for mycoviral sequences in a list of fungal transcriptomic datasets. The scripts are suited to run using the Slurm job scheduling system in a High Performance Computer cluster, see https://slurm.schedmd.com/documentation.html for more documentation about using Slurm. In this case the HPC that was used was The University of Manchester's Computational Shared Facility 3 (CSF3). 
## Notes
1. Scripts were made to run in a directory, for example a directory representing a single BioProject. The scripts will create output directories of all the steps in the pipeline in that same directory. Something like this: 
```text
PRJNA11029          # the working directory 
├── SRA_list.txt    # list of SRA accession IDs 
├── sra_download.sh # job script
├── fastqc.sh       # job script
├── SRA_data/       # sra_download.sh output directory
├── fastqc_out/     # fastqc.sh output directory
└── logs/           # all the job logs will be here (stdout & stderr)
```
2. Create list of SRA accessions IDs in a text file called "SRA_list.txt", this will be used to download the data (sra_download.sh). It should be in the same directory as the scripts. The formatting should be something like: 

SRR029811<br>
SRR029812<br>
SRR029813<br>
SRR029814<br>
... 

3. Paired-end or Single-end data? Scripts of steps 1-4 are different depending on library layout. 

4. Make sure to download the appropriate fungal reference genome and change the path to the file accordingly in the step 5 script (bwamem2.sh). Also ensure that it has been indexed by bwa-mem2. See (https://github.com/bwa-mem2/bwa-mem2). 

5. The BLAST nr database would need to be downloaded first, if you're using  CSF3, it is already downloaded and can be accessed in `$NCBI_BLAST_DIR/nr`, when `apps/binapps/blast@2.17.0` module is loaded (accessed on 02/03/2026). The custom viral database used in step 6 need to be created using `blastdbcmd` (more info: https://www.ncbi.nlm.nih.gov/books/NBK569853/), the path to the database should be changed in the `---USER INPUT---` section of the code of "blastx.sh". 

6. Modules used in the scripts is based on the available modules on the CSF3 during the creation of the scripts. You can request for databases to be downloaded or softwares to be installed via the CSF3 help section (https://ri.itservices.manchester.ac.uk/csf3/overview/help/). You can also use miniforge to install softwares you want, information is found here if you are using https://ri.itservices.manchester.ac.uk/csf3/software/applications/conda/.   

7. Make note of job array as it will be different in every run. See here: https://ri.itservices.manchester.ac.uk/csf4/batch/job-arrays/

8. Use rsync to transfer files between your local storage and HPC. 


## Steps 
### 1. Downloading the raw sequencing data. (downloading_sra.sh)
- This will download all the raw data in a compressed FASTA format. 
### 2. Quality control. (fastqc.sh)
- View the html files produced by fastqc. 

### 3. Trimming and adapter removal. (trimmomatic.sh)
- Edit the parameters in `---USER INPUT---` section of the code depending on what you want. 
### 4. De novo assembly. (trinity.sh)
### 5. Aligning contigs to the host genome. (bwamem2.sh)
- Look at 4 in Notes above. 
### 6. BLASTx search of unmapped contigs to a viral protein database. (blastx.sh)
- Before running this step, make a list of SRA accession IDs called "SRA_list_blastx.txt" that represents datasets that have unmapped contigs that will be searched against the viral database, as some may not have any. 
### 7. Filtering of unwanted viral sequences and translation of putative mycoviral contigs to protein sequences. (transdecoder.sh)
- This sets a minimum of 100 amino acids for the predicted protein sequence, which can be changed in the code in `---USER INPUT---`.
### 8. BLASTp search of putative mycoviral protein sequences to the nr protein database (blastp.sh)
- Before running this step, make a list of SRA accession IDs called "SRA_list_blastp.txt" that represents datasets that have protein sequences made from step 7. 





