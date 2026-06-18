#!/bin/bash --login
#SBATCH -J blastx_local
#SBATCH -o logs/blastx_local_%A_%a.out
#SBATCH -e logs/blastx_local_%A_%a.err
#SBATCH -p multicore
#SBATCH -n 8
#SBATCH --mem=32G
#SBATCH -t 0-3
#SBATCH -a 1-6
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your@email

# Clean environment
module purge

# Load BLAST module
module load apps/binapps/blast@2.17.0

# Verify tool loaded correctly
if ! command -v blastx &> /dev/null; then
    echo "ERROR: BLAST not found."
    exit 1
fi

echo "BLAST loaded: $(blastx -version 2>&1 | head -1)"


# --- ASSIGN SRA TO ARRAY ID---
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" SRA_list_blastx.txt)


echo "Running local BLASTx for sample: $SAMPLE"

# check if sample was read correctly
if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: No sample name read from SRA_list_blastx.txt."
    exit 1
fi

# --- USER INPUT ---
QUERY="bwa_out/${SAMPLE}/${SAMPLE}.unmapped.fasta"   # Unmapped Trinity contigs
OUTDIR="blastx_out_local/${SAMPLE}"                        # Output directory
EVALUE="1e-10"                                       # E-value threshold
MAX_HITS=5                                           # Maximum hits per query
BLASTDB="$HOME/viral_database/viral_nr"                  # Set BLAST database path environment variable
# ------------------

# Check query file exists
if [[ ! -f "$QUERY" ]]; then
    echo "ERROR: Query file not found at $QUERY"
    exit 1
fi

# check if outdir exists, if not create it
if [[ ! -d "$OUTDIR" ]]; then
    mkdir -p "$OUTDIR"
fi

# Count query sequences
QUERY_COUNT=$(grep -c ">" "$QUERY")


# Local BLASTx with viral database

echo "Starting local BLASTx against NCBI nr with viruses database..."
echo "Start time: $(date)"

blastx \
    -query "$QUERY" \
    -db "$BLASTDB" \
    -evalue "$EVALUE" \
    -num_threads "$SLURM_NTASKS" \
    -max_target_seqs "$MAX_HITS" \
    -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" \
    -out $OUTDIR/${SAMPLE}.blastx.local.tsv

EXIT_CODE=$?

# Check if search succeeded
if [[ $EXIT_CODE -ne 0 ]]; then
    echo "ERROR: Local BLASTx failed!"
    exit 1
fi

# Check output was created
if [[ ! -s "$OUTDIR/${SAMPLE}.blastx.local.tsv" ]]; then
    echo "WARNING: BLASTx output is empty - no viral hits found!"
    exit 0
fi

VIRAL_HITS=$(wc -l < "$OUTDIR/${SAMPLE}.blastx.local.tsv")
echo "Local BLASTx complete! Viral hits: $VIRAL_HITS"

CONTIGS_WITH_HITS=$(cut -f1 "$OUTDIR/${SAMPLE}.blastx.local.tsv" | sort -u | wc -l)

echo "Local BLASTx Summary for $SAMPLE"
echo "Total query contigs:         $QUERY_COUNT"
echo "Contigs with viral hits:     $CONTIGS_WITH_HITS"
echo "Total viral hits:            $VIRAL_HITS"