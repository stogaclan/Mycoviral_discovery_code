#!/bin/bash --login
#SBATCH -J transdecoder_pipeline
#SBATCH -o logs/transdecoder_%j.out
#SBATCH -e logs/transdecoder_%j.err
#SBATCH -p multicore
#SBATCH -n 4
#SBATCH -t 0-4
#SBATCH --array=1-6
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=stefano.togatorop@postgrad.manchester.ac.uk

module purge
module load apps/gcc/transdecoder/5.5.0
module load apps/gcc/samtools/1.21

# check if TransDecoder loaded correctly
if ! command -v TransDecoder.LongOrfs &> /dev/null; then
    echo "ERROR: TransDecoder not found. Check module name with: module search TransDecoder"
    exit 1
fi

# chek if samtools loaded correctly
if ! command -v samtools &> /dev/null; then
    echo "ERROR: samtools not found. Check module name with: module search samtools"
    exit 1
fi

# --- ASSIGN SRA TO ARRAY ID---
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" SRA_list.txt)

# get fasta of the sample's from bwa_out
TRANSCRIPTS="bwa_out/${SAMPLE}/${SAMPLE}.unmapped.fasta"

# filtering blastx results for viral hits
BLAST_RESULTS="blastx_out/${SAMPLE}/${SAMPLE}.blastx.remote.tsv"

# check if viral_contigs directory exists, if not create it
if [[ ! -d "viral_contigs" ]]; then
    mkdir viral_contigs
fi


# removing hits to bacteriophages 
grep -v -i -E "retrovirus|retrotransposon|phage|Caudoviricetes" $BLAST_RESULTS | \
    awk -F'\t' '$11 < 1e-10' | \
    cut -f1 | sort -u > "viral_contigs/${SAMPLE}_viral_contigs.txt"  

samtools faidx -r "viral_contigs/${SAMPLE}_viral_contigs.txt" $TRANSCRIPTS -o "viral_contigs/${SAMPLE}_viral_contigs.fasta"

contig_fasta="viral_contigs/${SAMPLE}_viral_contigs.fasta"

# count how many contigs after filtering 
CONTIG_COUNT=$(grep -c ">" "$contig_fasta")
echo "Sample: $SAMPLE - Viral contigs after filtering: $CONTIG_COUNT"


# check if transdecoder_out directory exists, if not create it
if [[ ! -d "transdecoder_out" ]]; then
    mkdir transdecoder_out
fi


# TransDecoder 
TransDecoder.LongOrfs -t ${contig_fasta} -m 100
TransDecoder.Predict -t ${contig_fasta} --no_refine_starts

mkdir transdecoder_out/${SAMPLE}

FILE=${SAMPLE}_viral_contigs.fasta

# moving the files to transdecoder_out
mv ${FILE}.transdecoder_dir* \
	${FILE}.transdecoder.pep ${FILE}.transdecoder.cds \
	${FILE}.transdecoder.gff3 ${FILE}.transdecoder.bed \
	transdecoder_out/${SAMPLE}/ 

rm -rf pipeliner.* 