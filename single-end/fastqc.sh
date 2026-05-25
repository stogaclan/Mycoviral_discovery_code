#!/bin/bash --login
#SBATCH -J fastqc
#SBATCH -o logs/fastqc_%A_%a.out    # %A = array job ID, %a = task ID
#SBATCH -e logs/fastqc_%A_%a.err
#SBATCH -p serial                   # 1 core per task
#SBATCH -t 0-1
#SBATCH --array=1-67
#SBATCH --mail-type=END,FAIL        
#SBATCH --mail-user=stefano.togatorop@postgrad.manchester.ac.uk

# Clean environment
module purge

# Load required modules
module load apps/binapps/fastqc/0.12.1

# Verify tool loaded correctly
if ! command -v fastqc &> /dev/null; then
    echo "ERROR: fastqc not found. Check module name with: module search fastqc"
    exit 1
fi

echo "FastQC loaded successfully: $(fastqc --version)"

# --- JOB ARRAY --- 
# Read sample name from SRA_list.txt
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" SRA_list.txt)
# -----------------

# --- USER INPUT ---
INDIR="SRA_data"           # Directory containing .fastq.gz files
OUTDIR="fastqc_out"        # Output directory for FastQC reports
# ------------------

# Check that we got a sample name
if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: Could not read sample name from line $SLURM_ARRAY_TASK_ID of SRA_list.txt"
    exit 1
fi


# check if outdir exists, if not create it
if [[ ! -d "$OUTDIR" ]]; then   
    mkdir -p "$OUTDIR"    
fi  

echo "Running FastQC for $SAMPLE..."

# Run FastQC on sample file
# Note: removed --threads since we only have 1 core in serial partition
fastqc \
    "${INDIR}/${SAMPLE}.fastq.gz" \
    --outdir "$OUTDIR"

# Check if FastQC succeeded
if [[ $? -eq 0 ]]; then
    echo "FastQC complete for $SAMPLE! Results saved to $OUTDIR"
else
    echo "ERROR: FastQC failed for $SAMPLE"
    exit 1
fi

