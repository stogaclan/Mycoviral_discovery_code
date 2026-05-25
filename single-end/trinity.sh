#!/bin/bash --login
#SBATCH -J trinity
#SBATCH -o logs/trinity_%A_%a.out
#SBATCH -e logs/trinity_%A_%a.err
#SBATCH -p multicore
#SBATCH -n 4
#SBATCH -t 0-3
#SBATCH -a 1-144%24
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=stefano.togatorop@postgrad.manchester.ac.uk

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
# ------------------

# check if outdir exists, if not create it
if [[ ! -d "$OUTDIR" ]]; then
    mkdir -p "$OUTDIR"    
fi

# Check input file exists (single paired-end file)
PAIRED_READS="$INDIR/${SAMPLE}.paired.fastq.gz"

if [[ ! -f "$PAIRED_READS" ]]; then
    echo "ERROR: Paired reads file not found: $PAIRED_READS"
    exit 1
fi

# Remove old output if it exists (Trinity fails if directory exists)
if [[ -d "$OUTDIR/${SAMPLE}/" ]]; then
    echo "Warning: Output directory for the sample already exists, removing..."
    rm -rf "$OUTDIR/${SAMPLE}/"
fi

mkdir -p "$OUTDIR/${SAMPLE}_trinity/"

echo "Running Trinity for $SAMPLE..."
echo "Input paired reads: $PAIRED_READS"
echo "Output:            $OUTDIR/${SAMPLE}_trinity/Trinity.fasta"
echo "Threads:           $SLURM_NTASKS"
echo "Memory:            $MAX_MEMORY"

# Run Trinity via Singularity/Apptainer (single file mode)
apptainer exec -B /scratch,/mnt $TRINITY_SIF Trinity \
    --seqType fq \
    --single "$PAIRED_READS" \
    --CPU "$SLURM_NTASKS" \
    --max_memory "$MAX_MEMORY" \
    --output "$OUTDIR/${SAMPLE}_trinity/"

# check if Trinity ran successfully
if [[ ! -f "$OUTDIR/${SAMPLE}_trinity.Trinity.fasta" ]]; then
    echo "ERROR: Trinity assembly not found at $OUTDIR/${SAMPLE}_trinity.Trinity.fasta"
    exit 1
fi

echo "$SAMPLE Trinity assembly completed successfully!"