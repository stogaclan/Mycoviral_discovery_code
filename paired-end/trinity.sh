#!/bin/bash --login
#SBATCH -J trinity
#SBATCH -o logs/trinity_%j.out
#SBATCH -e logs/trinity_%j.err
#SBATCH -p multicore
#SBATCH -n 16
#SBATCH -t 0-2
#SBATCH -a 1-6
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your@email

# Clean environment
module purge

# Load required modules
module load apps/singularity/trinity/2.15.2

# Verify container exists
if [[ ! -f "$TRINITY_SIF" ]]; then
    echo "ERROR: Trinity container not found at $TRINITY_SIF"
    exit 1
fi

echo "Trinity container found: $TRINITY_SIF"

# Fix locale warnings
export LC_ALL=C
export LANG=C

echo "Trinity version: $(apptainer exec -B /scratch,/mnt $TRINITY_SIF Trinity --version)"

# --- ASSIGN SRA TO ARRAY ID---
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" SRA_list.txt)

echo "Running Trinity for sample: $SAMPLE"

# --- USER INPUT ---
INDIR="trimmomatic_out"           # Directory containing trimmed paired .fastq.gz files
OUTDIR="trinity_out"              # Base output directory (NOT including sample name)
MAX_MEMORY="16G"                  # Maximum memory for Trinity


# check if outdir exists, if not create it
if [[ ! -d "$OUTDIR" ]]; then
    mkdir -p "$OUTDIR"    
fi

# Check input files exist
R1="$INDIR/${SAMPLE}_1_paired.fastq.gz"
R2="$INDIR/${SAMPLE}_2_paired.fastq.gz"

if [[ ! -f "$R1" ]]; then
    echo "ERROR: R1 file not found: $R1"
    exit 1
fi

if [[ ! -f "$R2" ]]; then
    echo "ERROR: R2 file not found: $R2"
    exit 1
fi


# Remove old output if it exists (Trinity fails if directory exists)
if [[ -d "$OUTDIR/${SAMPLE}_trinity/" ]]; then
    echo "Warning: Output directory already exists, removing..."
    rm -rf "$OUTDIR/${SAMPLE}_trinity/"
fi

mkdir -p "$OUTDIR/${SAMPLE}_trinity/"

echo "Running Trinity for $SAMPLE..."
echo "Input R1:  $R1"
echo "Input R2:  $R2"
echo "Output:    $OUTDIR/${SAMPLE}_trinity/Trinity.fasta"
echo "Threads:   $SLURM_NTASKS"
echo "Memory:    $MAX_MEMORY"

# Run Trinity via Singularity/Apptainer
apptainer exec -B /scratch,/mnt $TRINITY_SIF Trinity \
    --seqType fq \
    --left "$R1" \
    --right "$R2" \
    --SS_lib_type RF \
    --CPU "$SLURM_NTASKS" \
    --max_memory "$MAX_MEMORY" \
    --output "$OUTDIR/${SAMPLE}_trinity/"

# check if Trinity ran successfully
if [[ ! -f "$OUTDIR/${SAMPLE}_trinity.Trinity.fasta" ]]; then
    echo "ERROR: Trinity assembly not found at $OUTDIR/${SAMPLE}_trinity.Trinity.fasta"
    exit 1
fi  

echo "Trinity assembly completed successfully for $SAMPLE. Output located at $OUTDIR/${SAMPLE}_trinity/Trinity.fasta"

