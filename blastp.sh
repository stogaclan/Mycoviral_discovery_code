#!/bin/bash --login
#SBATCH -J blastp_local
#SBATCH -o logs/blastp_local_%A_%a.out
#SBATCH -e logs/blastp_local_%A_%a.err
#SBATCH -p multicore
#SBATCH -n 8
#SBATCH -t 0-3
#SBATCH -a 1-1
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=stefano.togatorop@postgrad.manchester.ac.uk

# Clean environment
module purge    

# Load BLAST module
module load apps/binapps/blast@2.17.0

# Verify tool loaded correctly
if ! command -v blastp &> /dev/null; then
    echo "ERROR: BLAST not found."
    exit 1  
fi

echo "BLAST loaded: $(blastp -version 2>&1 | head -1)"

# --- ASSIGN SRA TO ARRAY ID---
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" SRA_list_blastp.txt)

echo "Running local BLASTp for sample: $SAMPLE"


# --- USER INPUT ---
ORFs="transdecoder_out/${SAMPLE}/${SAMPLE}_viral_contigs.fasta.transdecoder.pep"   # ORFs from TransDecoder
OUTDIR="blastp_local_out"                        # Output directory
EVALUE="1e-10"                                       # E-value threshold
MAX_HITS=5                                           # Maximum hits per query
DB="$NCBI_BLAST_DIR/nr"                                              # BLAST database 

# Check if query file exists, if not exit without error (no ORFs to blast, too small) 
if [[ ! -f "$ORFs" ]]; then
    echo "WARNING: No ORF file found for $SAMPLE at $ORFs. Skipping BLASTp for this sample."
    exit 0  
fi


# check if outdir exists, if not create it
if [[ ! -d "$OUTDIR" ]]; then
    mkdir -p "$OUTDIR"
fi

# running blastp locally against nr database 
blastp \
    -query ${ORFs} \
    -db ${DB} \
    -evalue ${EVALUE} \
    -max_target_seqs ${MAX_HITS} \
    -num_threads $SLURM_NTASKS \
    -outfmt "6 qseqid sseqid pident length evalue bitscore stitle" \
    -out ${OUTDIR}/${SAMPLE}.blastp.nr.tsv
