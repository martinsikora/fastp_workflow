#!/usr/bin/env bash

set -euo pipefail

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") DATASET [OPTIONS]

Submit Snakemake workflow to SLURM with automatic resource management.

Arguments:
  DATASET       Path to dataset directory containing config/config.yml

Options:
  -j, --jobs N          Maximum number of jobs to run in parallel (default: 100)
  -p, --partition NAME  SLURM partition to use (default: general)
  -t, --time TIME       Max walltime per job (default: 4:00:00)
  -m, --mem MB          Default memory per job in MB (default: 8000)
  --dry-run            Show what would be done without submitting jobs
  --unlock             Unlock working directory
  --                   Pass remaining args directly to Snakemake
  -h, --help           Show this help message

Example:
  bash $(basename "$0") cgg/018
  bash $(basename "$0") cgg/100 --jobs 50 --partition highmem

  # For testing without submitting:
  bash $(basename "$0") cgg/018 --dry-run
  bash $(basename "$0") cgg/018 -- --rerun-incomplete --keep-going

EOF
    exit 0
}

# Default parameters
MAX_JOBS=100
PARTITION="general"
MAX_TIME="4:00:00"
DEFAULT_MEM=8000
SNAKEMAKE_ARGS=()
UNLOCK=""

# Parse command line arguments
if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

DATASET="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        -j|--jobs)
            MAX_JOBS="$2"
            shift 2
            ;;
        -p|--partition)
            PARTITION="$2"
            shift 2
            ;;
        -t|--time)
            MAX_TIME="$2"
            shift 2
            ;;
        -m|--mem)
            DEFAULT_MEM="$2"
            shift 2
            ;;
        --dry-run)
            SNAKEMAKE_ARGS+=(--dry-run)
            shift
            ;;
        --unlock)
            UNLOCK="--unlock"
            shift
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                SNAKEMAKE_ARGS+=("$1")
                shift
            done
            ;;
        *)
            if [[ "$1" == -* ]]; then
                SNAKEMAKE_ARGS+=("$1")
                if [[ $# -ge 2 ]] && [[ "$2" != -* ]]; then
                    SNAKEMAKE_ARGS+=("$2")
                    shift 2
                else
                    shift
                fi
            else
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
            fi
            ;;
    esac
done

# Get the directory where this script is located
if [[ -n "${SLURM_SUBMIT_DIR:-}" ]]; then
    SCRIPT_DIR="$SLURM_SUBMIT_DIR"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Setup paths - workflow is relative to script location
WORKFLOW_DIR="$SCRIPT_DIR/workflow"
RUN_DIR="$(realpath $DATASET)"

# Change to the run directory
cd "$RUN_DIR"

echo "=========================================="
echo "Snakemake SLURM Submission"
echo "=========================================="
echo "Dataset:       $RUN_DIR"
echo "Max jobs:      $MAX_JOBS"
echo "Partition:     $PARTITION"
echo "Default time:  $MAX_TIME"
echo "Default mem:   ${DEFAULT_MEM}M"
echo "=========================================="

# Run unlock if requested
if [[ -n "$UNLOCK" ]]; then
    echo "Unlocking working directory..."
    snakemake \
      -s "$WORKFLOW_DIR/Snakefile" \
      --configfile config/config.yml \
      --unlock
    echo "Directory unlocked."
    exit 0
fi

# Convert time format (HH:MM:SS to minutes for runtime parameter)
RUNTIME_MIN=$(echo "$MAX_TIME" | awk -F: '{ print ($1 * 60) + $2 }')

# Run Snakemake with SLURM executor (Snakemake 9+)
snakemake \
  -s "$WORKFLOW_DIR/Snakefile" \
  --configfile config/config.yml \
  --executor slurm \
  --jobs ${MAX_JOBS} \
  --default-resources slurm_partition=${PARTITION} mem_mb=${DEFAULT_MEM} runtime=${RUNTIME_MIN} \
  --retries 2 \
  --latency-wait 60 \
  --printshellcmds \
  "${SNAKEMAKE_ARGS[@]}"

echo "=========================================="
echo "Workflow submission complete!"
echo "Monitor jobs with: squeue -u \$USER"
echo "Workflow logs: $RUN_DIR/logs/"
echo "=========================================="
