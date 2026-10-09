# nf-core/provenancereport: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0 - 2026-10-01

Initial release of nf-core/provenancereport, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- Validate and normalise samplesheets containing one or more report input files.
- Render a bundled or user-provided Quarto notebook in a reproducible container or Conda environment.
- Capture package versions loaded by R/knitr or Python/Jupyter notebooks, while preserving an explicitly generated `versions.csv` as the authoritative record.
- Publish the rendered HTML report, source notebook, and report-generated artifacts.
- Index the rendered report and prepared notebook outputs so they are included in Workflow Run RO-Crate provenance.
- Generate MD5 checksums for all report inputs and the rendered report.
- Capture the report runtime environment, including container or Conda details, R session information, and the Python version.
- Generate a MultiQC audit report containing inputs, outputs, checksums, parameters, software versions, and runtime metadata.
- Publish an optional review or sign-off document alongside the pipeline results.
- Generate BioCompute Object and Workflow Run RO-Crate provenance records with `nf-prov`.
- Publish standard Nextflow execution reports and expose the rendered report and MultiQC report in Seqera Platform.
