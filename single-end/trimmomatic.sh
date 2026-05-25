#!/bin/bash --login
#SBATCH -J trimmomatic
#SBATCH -o logs/trimmomatic_%A_%a.out    # %A = array job ID, %a = task ID
#SBATCH -e logs/trimmomatic_%A_%a.err
#SBATCH -p serial                   
#SBATCH -t 0-1
#SBATCH --array=1-67
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=stefano.togatorop@postgrad.manchester.ac.uk

# Clean environment
module purge

# Load required modules
module load apps/binapps/trimmomatic/0.39

# Verify tool loaded correctly
if ! command -v trimmomatic &> /dev/null; then
    echo "ERROR: trimmomatic not found. Check module name with: module search trimmomatic"
    exit 1
fi

echo "Trimmomatic loaded successfully: $(trimmomatic -version)"
echo "Array task $SLURM_ARRAY_TASK_ID running with $SLURM_NTASKS threads"

# --- JOB ARRAY --- 
# Read sample name from SRA_list.txt
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" SRA_list.txt)
# -----------------

# Check that we got a sample name
if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: Could not read sample name from line $SLURM_ARRAY_TASK_ID of SRA_list.txt"
    exit 1
fi

# --- USER INPUT ---
INDIR="SRA_data"                  # Directory containing raw .fastq.gz files
OUTDIR="trimmomatic_out"          # Output directory for trimmed files
ADAPTERS="TruSeq3-SE.fa"        
LEADING=20                        # Remove leading bases below Phred quality 20
TRAILING=20                       # Remove trailing bases below Phred quality 20
SLIDINGWINDOW="5:20"              # Sliding window: window size 5, quality threshold 20
MINLEN=50                         # Minimum read length after trimming
# ------------------

# Check input directory exists
if [[ ! -d "$INDIR" ]]; then
    echo "ERROR: Input directory '$INDIR' not found."
    exit 1
fi

# Find the Trimmomatic adapters directory using the module environment variable
ADAPTER_DIR="$TRIMMOMATICSHARE/adapters"
if [[ ! -f "$ADAPTER_DIR/$ADAPTERS" ]]; then
    echo "ERROR: Adapter file not found at $ADAPTER_DIR/$ADAPTERS"
    echo "Available adapters:"
    ls "$ADAPTER_DIR"
    exit 1
fi

echo "Using adapter file: $ADAPTER_DIR/$ADAPTERS"

# check if outdir exists, if not create it
if [[ ! -d "$OUTDIR" ]]; then
    mkdir -p "$OUTDIR"
fi


READ="$INDIR/${SAMPLE}.fastq.gz"
# Check read file exists
if [[ ! -f "$READ" ]]; then
    echo "ERROR: Read file not found: $READ"
    exit 1
fi

echo "Trimming $SAMPLE..."

trimmomatic SE \
    -phred33 \
    "$READ" \
    "$OUTDIR/${SAMPLE}.paired.fastq.gz" \
    ILLUMINACLIP:"$ADAPTER_DIR/$ADAPTERS":2:30:10 \
    LEADING:$LEADING \
    TRAILING:$TRAILING \
    SLIDINGWINDOW:$SLIDINGWINDOW \
    MINLEN:$MINLEN

# Check if Trimmomatic succeeded
if [[ $? -eq 0 ]]; then
    echo "$SAMPLE trimming complete! Results saved to $OUTDIR"
else
    echo "ERROR: Trimmomatic failed for $SAMPLE"
    exit 1
fi