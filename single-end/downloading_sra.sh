#!/bin/bash --login
#SBATCH -J sra_download
#SBATCH -o logs/sra_download_%A_%a.out
#SBATCH -e logs/sra_download_%A_%a.err
#SBATCH -p serial
#SBATCH -t 1-0
#SBATCH -a 1-14
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=stefano.togatorop@postgrad.manchester.ac.uk

# Clean environment
module purge

# Load required modules
module load apps/bioinf
module load apps/binapps/sra/3.0.0
module load tools/gcc/pigz/2.5

# check if tools loaded correctly
if ! command -v prefetch &> /dev/null; then
    echo "ERROR: prefetch not found. Check module name with: module search sra"
    exit 1
fi
echo "SRA tools loaded successfully: $(prefetch --version)"

if ! command -v pigz &> /dev/null; then
    echo "ERROR: pigz not found. Check module name with: module search pigz"
    exit 1
fi

echo "pigz loaded successfully: $(pigz --version)"

# --- JOB ARRAY --- 
# Read sample name from SRA_list.txt
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" SRA_list.txt)
# -----------------

# check if sample name is read 
if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: Sample name not found for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID. Check SRA_list.txt"
    exit 1
fi

# --- USER INPUT ---
OUTDIR="SRA_data"         # Output directory
# ------------------

# check if output directory exists, if not create it
if [[ ! -d "$OUTDIR" ]]; then
    mkdir -p "$OUTDIR"    
fi

echo "Downloading $SAMPLE..."

# download .sra file
prefetch "$SAMPLE"

# conver to FASTQ (single-end)
fasterq-dump "$SAMPLE" \
    --outdir "$OUTDIR" \
    --progress

# Compress the FASTQ file using pigz (parallel gzip)
pigz "${OUTDIR}/${SAMPLE}.fastq"

# remove the prefetched .sra file to save space
rm -rf "$SAMPLE"

# check if files were created successfully
if [[ ! -f "${OUTDIR}/${SAMPLE}.fastq.gz" ]]; then
    echo "ERROR: Failed to create ${OUTDIR}/${SAMPLE}.fastq.gz"
    exit 1
fi

echo "${SAMPLE} download and compressed successfully!"