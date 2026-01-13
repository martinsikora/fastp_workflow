# fastp_workflow

Snakemake pipeline for trimming FASTQ reads with `fastp`. It supports both
single-end and paired-end data, produces trimmed/merged FASTQs, and emits HTML
and JSON reports per sample.

## Repository layout

- `workflow/Snakefile` - main Snakemake workflow
- `workflow/resources/adapterList.fa` - adapter sequences for fastp
- `dataset_example/config/config.yml` - example configuration
- `dataset_example/config/units.tsv` - example sample sheet
- `run_dataset.sh` - run locally
- `run_dataset_slurm.sh` - submit to SLURM

## Requirements

- `snakemake` (9+ recommended)
- `fastp`
- Python with `pandas`

## Configuration

Create a dataset directory with a `config/` folder that contains:

- `config/config.yml`
- `config/units.tsv`

An example dataset lives at `dataset_example/`.

Example `config/config.yml`:

```yaml
out_dir: fastp
units: config/units.tsv
fastp:
  min_l: 25
  min_overlap: 11
  adapters: "{workflow.basedir}/workflow/resources/adapterList.fa"
```

`config/units.tsv` columns:

- `unit_id`: sample or subject ID (used in output directory names)
- `unit_prefix`: unique sample/run prefix
- `fq1`: path to read 1 FASTQ
- `fq2`: path to read 2 FASTQ (leave empty for single-end)

Example:

| unit_id | unit_prefix | fq1 | fq2 |
| --- | --- | --- | --- |
| SAMPLE01 | SAMPLE01_L001 | /data/fastq/SAMPLE01_L001_R1.fastq.gz | /data/fastq/SAMPLE01_L001_R2.fastq.gz |
| SAMPLE02 | SAMPLE02_L001 | /data/fastq/SAMPLE02_L001_R1.fastq.gz | |

## Run locally

From the repo root:

```bash
bash run_dataset.sh /path/to/dataset
bash run_dataset.sh dataset_example
```

You can pass extra Snakemake args after the dataset path:

```bash
bash run_dataset.sh /path/to/dataset -- --cores 8 --rerun-incomplete
```

## Run on SLURM

```bash
bash run_dataset_slurm.sh /path/to/dataset --jobs 50 --partition general
bash run_dataset_slurm.sh dataset_example --dry-run
```

See full options:

```bash
bash run_dataset_slurm.sh --help
```

## Outputs

For each `unit_id`, outputs are written under `${out_dir}/${unit_id}/`:

- `fastq/` - trimmed FASTQs and merged reads
- `report/` - `fastp` HTML and JSON reports
- `log/` - `fastp` logs

Example output structure:

```text
${out_dir}/
├── SAMPLE01/
│   ├── fastq/
│   │   ├── SAMPLE01_L001.fastp.R1.fq.gz
│   │   ├── SAMPLE01_L001.fastp.R2.fq.gz
│   │   └── SAMPLE01_L001.fastp.coll.fq.gz
│   ├── log/
│   │   └── SAMPLE01_L001.fastp.log
│   └── report/
│       ├── SAMPLE01_L001.fastp.html
│       └── SAMPLE01_L001.fastp.json
└── SAMPLE02/
    ├── fastq/
    │   ├── SAMPLE02_L001.fastp.R1.fq.gz
    │   ├── SAMPLE02_L001.fastp.R2.fq.gz
    │   └── SAMPLE02_L001.fastp.coll.fq.gz
    ├── log/
    │   └── SAMPLE02_L001.fastp.log
    └── report/
        ├── SAMPLE02_L001.fastp.html
        └── SAMPLE02_L001.fastp.json
```

Single-end runs write the merged FASTQ to `*.fastp.coll.fq.gz` and touch empty
paired-end output files for compatibility.
