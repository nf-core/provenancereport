<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/nf-core-provenancereport_logo_dark.png">
    <img alt="nf-core/provenancereport" src="docs/images/nf-core-provenancereport_logo_light.png">
  </picture>
</h1>

[![Open in GitHub Codespaces](https://img.shields.io/badge/Open_In_GitHub_Codespaces-black?labelColor=grey&logo=github)](https://github.com/codespaces/new/nf-core/provenancereport)
[![GitHub Actions CI Status](https://github.com/nf-core/provenancereport/actions/workflows/nf-test.yml/badge.svg)](https://github.com/nf-core/provenancereport/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/nf-core/provenancereport/actions/workflows/linting.yml/badge.svg)](https://github.com/nf-core/provenancereport/actions/workflows/linting.yml)[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/provenancereport/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.10.4-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-4.0.2-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/4.0.2)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/nf-core/provenancereport)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23provenancereport-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/provenancereport)[![Follow on Bluesky](https://img.shields.io/badge/bluesky-%40nf__core-1185fe?labelColor=000000&logo=bluesky)](https://bsky.app/profile/nf-co.re)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

**nf-core/provenancereport** is a reporting pipeline that validates a samplesheet and renders reproducible Quarto reports. The samplesheet has two columns, `id` and `path`, where each row points to one input file. The pipeline stages all listed files into a single Quarto render and publishes the rendered report plus any generated artifacts.

### Requirements

- Nextflow `25.10.4` or later.
- A supported execution environment such as Docker, Singularity, Apptainer, or Conda. Docker or Singularity is recommended for reproducibility.
- Read access to the samplesheet and every file it references, plus write access to `--outdir`.
- For a custom `--notebook`, a configured report runtime containing Quarto and every language, package, and system dependency used by that notebook.

See the [usage requirements](docs/usage.md#requirements) for details.

The default workflow performs the following steps:

1. Validate and normalise the input samplesheet with `nf-schema`.
2. Resolve each `path` entry from the samplesheet as one input file.
3. Render one Quarto notebook with all listed files using the nf-core `quarto_notebook` module.
4. Calculate MD5 checksums for every samplesheet input and the rendered Quarto HTML using the nf-core `md5sum` module.
5. Run `REPORTENVIRONMENT` in the resolved Quarto runtime to collect the R session, Python version, and container or Conda environment details.
6. If `--document` is provided, publish the review or sign-off document with the pipeline results.
7. Generate a MultiQC audit report containing the input samplesheet, file checksums, published outputs, run configuration, software versions, and runtime information.
8. Generate BCO and Workflow Run RO-Crate provenance with the `nf-prov` plugin.
9. Publish the reports, artifacts, checksums, and standard Nextflow execution metadata.

![nf-core/provenancereport metro map](docs/images/provenancereport_metro.svg)

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/get_started/environment_setup/overview) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/get_started/run-your-first-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
id,path
counts,counts.tsv
metadata,metadata.tsv
```

Each row represents exactly one input file. The `id` value is included in `params$input_ids`, and `path` must point to a single file.

Now, you can run the pipeline using:

```bash
nextflow run nf-core/provenancereport \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

By default, the pipeline renders the bundled notebook in `assets/provenance_report.qmd`. To render your own custom Quarto notebook, provide `--notebook custom_report.qmd`.

Report inputs are staged into the Quarto render working directory by basename. Custom notebooks should read those staged filenames directly, for example `readxl::read_xlsx("counts.xlsx")`, and every file listed in the samplesheet must have a unique basename. See the usage documentation for details on designing custom reports.

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/running/run-pipelines#using-parameter-files).

For more details and further functionality, please refer to the [usage documentation](https://nf-co.re/provenancereport/usage) and the [parameter documentation](https://nf-co.re/provenancereport/parameters).

## Pipeline output

A successful run produces:

- `quartonotebook/*.html`: the rendered Quarto report, plus the source notebook and any report artifacts.
- `md5sum/provenancereport.md5`: checksums for every samplesheet input and the rendered report.
- `multiqc/multiqc_report.html`: an audit report covering inputs, checksums, outputs, parameters, software versions, and the report runtime.
- `pipeline_info/manifest_<timestamp>.bco.json` and `ro-crate-metadata_<timestamp>.json`: BCO and Workflow Run RO-Crate provenance.
- `pipeline_info/`: Nextflow execution reports, trace, DAG, parameters, and collected software versions.
- The original review or sign-off file at the results root when `--document` is provided.

For the complete directory layout and guidance on interpreting each file, see the [output documentation](https://nf-co.re/provenancereport/output).

## Credits

nf-core/provenancereport was originally written by Alexander Peltzer, Gregor Sturm, Julian Schwab.

We thank the following people for their extensive assistance in the development of this pipeline:

Antonia Saracco, Delfina Terradas, Anabella Trigila.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](docs/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#provenancereport` channel](https://nfcore.slack.com/channels/provenancereport) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use nf-core/provenancereport for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

Please cite the core reporting and provenance software used by the pipeline:

> **Quarto.**
>
> J.J. Allaire, Charles Teague, Carlos Scheidegger, Yihui Xie, Christophe Dervieux & Gordon Woodhull.
>
> _Computer software._ [https://quarto.org/](https://quarto.org/).

> **nf-prov: Nextflow plugin to render provenance reports for pipeline runs.**
>
> Nextflow.
>
> _Computer software_, version 1.7.0. [nextflow-io/nf-prov](https://github.com/nextflow-io/nf-prov/releases/tag/1.7.0).

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
