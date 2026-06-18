#!/bin/bash --login
#SBATCH -J bwamem2.job
#SBATCH -o logs/bwa_align_%A_%a.out
#SBATCH -e logs/bwa_align_%A_%a.err
#SBATCH -p serial
#SBATCH -t 0-1
#SBATCH -a 1-144
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your@email

# Clean environment
module purge

# Load required modules
module load apps/bioinf
module load apps/gcc/bwa-mem2/2.2.1
module load apps/gcc/samtools/1.21

# Verify tools loaded correctly
if ! command -v bwa-mem2 &> /dev/null; then
    echo "ERROR: bwa-mem2 not found. Check module name with: module search bwa-mem2"
    exit 1
fi

if ! command -v samtools &> /dev/null; then
    echo "ERROR: samtools not found. Check module name with: module search samtools"
    exit 1
fi

echo "BWA-mem2 loaded successfully: $(bwa-mem2 version 2>&1 | head -1)"
echo "SAMtools loaded successfully: $(samtools --version | head -1)"

# --- ASSIGN SRA TO ARRAY ID---
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" SRA_list.txt)

echo "Running BWA-mem2 alignment for sample: $SAMPLE"

# check if bwa_out directory exists, if not create it
if [[ ! -d "bwa_out" ]]; then
    mkdir -p "bwa_out"    
fi

# --- USER INPUT ---
REFERENCE="reference_genome/GCF_018416015.2_ASM1841601v2_genomic.fna" # need to change species if needed - make sure to update indexing script too!
INDIR="trinity_out"
OUTDIR="bwa_out/${SAMPLE}"
# ------------------

# check if bwa_out/${SAMPLE} directory exists, if not create it
if [[ ! -d "$OUTDIR" ]]; then
    mkdir -p "$OUTDIR"    
fi

# Check reference genome and index exist
if [[ ! -f "$REFERENCE" ]]; then
    echo "ERROR: Reference genome not found at $REFERENCE"
    exit 1
fi

if [[ ! -f "${REFERENCE}.bwt.2bit.64" ]]; then
    echo "ERROR: Reference index not found!"
    echo "Please run the indexing script first: sbatch bwa_index.jobscript"
    exit 1
fi

# Check Trinity assembly exists
TRANSCRIPTS="$INDIR/${SAMPLE}_trinity.Trinity.fasta"
if [[ ! -f "$TRANSCRIPTS" ]]; then
    echo "ERROR: Trinity assembly not found at $TRANSCRIPTS"
    exit 1
fi

echo "Reference:   $REFERENCE"
echo "Transcripts: $TRANSCRIPTS"
echo "Output:      $OUTDIR"


# Align with BWA-mem2


bwa-mem2 mem \
    "$REFERENCE" \
    "$TRANSCRIPTS" \
    > "$OUTDIR/${SAMPLE}.sam"

if [[ ! -s "$OUTDIR/${SAMPLE}.sam" ]]; then
    echo "ERROR: SAM file is empty or was not created!"
    exit 1
fi

echo "Alignment complete! SAM size: $(ls -lh $OUTDIR/${SAMPLE}.sam | awk '{print $5}')"


# Convert SAM to BAM


samtools view \
    -bS "$OUTDIR/${SAMPLE}.sam" \
    -o "$OUTDIR/${SAMPLE}.bam"

if [[ ! -s "$OUTDIR/${SAMPLE}.bam" ]]; then
    echo "ERROR: BAM file is empty or was not created!"
    exit 1
fi

echo "Conversion complete! BAM size: $(ls -lh $OUTDIR/${SAMPLE}.bam | awk '{print $5}')"

# Sort BAM

samtools sort \
    "$OUTDIR/${SAMPLE}.bam" \
    -o "$OUTDIR/${SAMPLE}.sorted.bam"

if [[ ! -s "$OUTDIR/${SAMPLE}.sorted.bam" ]]; then
    echo "ERROR: Sorted BAM file is empty or was not created!"
    exit 1
fi

echo "Sorting complete! Sorted BAM size: $(ls -lh $OUTDIR/${SAMPLE}.sorted.bam | awk '{print $5}')"


# Index sorted BAM


samtools index \
    "$OUTDIR/${SAMPLE}.sorted.bam"

if [[ ! -f "$OUTDIR/${SAMPLE}.sorted.bam.bai" ]]; then
    echo "ERROR: BAM index file was not created!"
    exit 1
fi

echo "Indexing complete!"


# Extract unmapped contigs


# Extract unmapped reads into a BAM file
# -f 4 flag means: only keep reads where the unmapped flag (4) is set
samtools view \
    -f 4 \
    -b "$OUTDIR/${SAMPLE}.sorted.bam" \
    -o "$OUTDIR/${SAMPLE}.unmapped.bam"

if [[ ! -s "$OUTDIR/${SAMPLE}.unmapped.bam" ]]; then
    echo "WARNING: No unmapped contigs found or file is empty."
else
    echo "Unmapped BAM created! Size: $(ls -lh $OUTDIR/${SAMPLE}.unmapped.bam | awk '{print $5}')"

    # Convert unmapped BAM to FASTA for downstream analysis
    samtools fasta \
        "$OUTDIR/${SAMPLE}.unmapped.bam" \
        > "$OUTDIR/${SAMPLE}.unmapped.fasta"

    if [[ ! -s "$OUTDIR/${SAMPLE}.unmapped.fasta" ]]; then
        echo "WARNING: Unmapped FASTA file is empty!"
    else
        UNMAPPED_COUNT=$(grep -c ">" "$OUTDIR/${SAMPLE}.unmapped.fasta")
        echo "Unmapped contigs extracted: $UNMAPPED_COUNT"
        echo "Unmapped FASTA: $OUTDIR/${SAMPLE}.unmapped.fasta"
    fi
fi


# Remove intermediate SAM and unsorted BAM to save space

rm "$OUTDIR/${SAMPLE}.sam"
rm "$OUTDIR/${SAMPLE}.bam"


# Print alignment statistics

samtools flagstat "${OUTDIR}/${SAMPLE}.sorted.bam"

# Extract specific counts for summary
TOTAL_CONTIGS=$(samtools view -c "${OUTDIR}/${SAMPLE}.sorted.bam")
MAPPED_CONTIGS=$(samtools view -c -F 4 "${OUTDIR}/${SAMPLE}.sorted.bam")
UNMAPPED_CONTIGS=$(samtools view -c -f 4 "${OUTDIR}/${SAMPLE}.sorted.bam")


