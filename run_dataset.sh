#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat << EOF
Usage: $(basename "$0") DATASET [OPTIONS] [-- SNAKEMAKE_ARGS...]

Run the Snakemake workflow locally.

Arguments:
  DATASET       Path to dataset directory containing config/config.yml

Options:
  --dry-run     Run Snakemake with --dry-run
  -h, --help    Show this help message

Examples:
  bash $(basename "$0") dataset_example
  bash $(basename "$0") /path/to/dataset -- --cores 8 --rerun-incomplete
  bash $(basename "$0") dataset_example --dry-run
EOF
    exit 0
}

if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

DATASET="$1"
shift  # Remove the first argument (DATASET) from the argument list

SNAKEMAKE_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            SNAKEMAKE_ARGS+=(--dry-run)
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
            SNAKEMAKE_ARGS+=("$1")
            shift
            ;;
    esac
done

WORKFLOW_DIR="$(realpath workflow)"
RUN_DIR="$(realpath "$DATASET")"

cd "$RUN_DIR"

snakemake \
  -s "$WORKFLOW_DIR/Snakefile" \
  --configfile config/config.yml \
  "${SNAKEMAKE_ARGS[@]}"
