# nf-core/provenancereport: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/provenancereport/usage](https://nf-co.re/provenancereport/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

`nf-core/provenancereport` validates a samplesheet and renders one Quarto HTML report using all files listed in the samplesheet. The pipeline does not perform biological analysis itself. Instead, it provides a reproducible Nextflow wrapper around a user-supplied or bundled Quarto notebook so that input file paths, workflow versions, and execution metadata are captured consistently.

The default report notebook is `assets/provenance_report.qmd`. You can replace it by passing `--notebook path/to/report.qmd`. In practice, this can be any Quarto notebook that can run non-interactively inside the container or Conda environment configured for `QUARTONOTEBOOK` and read the files listed in the samplesheet.

## Samplesheet input

Create a samplesheet with the files you would like to make available to the report. It must be a comma-separated file with a header row and the columns shown below.

```bash
--input '[path to samplesheet file]'
```

```csv title="samplesheet.csv"
id,path
counts,counts.tsv
metadata,metadata.tsv
```

| Column | Description                                                                                                                                       |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`   | Unique input identifier. It must be a valid parameter name: start with a letter or underscore and contain only letters, numbers, and underscores. |
| `path` | Path or URL to exactly one input file. Comma-separated values are not allowed.                                                                    |

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

## Designing a custom Quarto report

Custom reports should be written to read files from the Quarto task working directory, not from their original source locations. The samplesheet `path` values may point to local files, URLs, or object storage paths, but Nextflow stages each file into the render task using the file basename.

Custom Quarto reports must include a `params` section in the YAML front matter. These defaults define the parameter structure that the `QUARTONOTEBOOK` module will populate at render time:

```yaml
params:
  meta: NULL
  input_dir: ./
  input_filename: NULL
  artifact_dir: NULL
  cpus: 1
  input_ids: NULL
  input_files: NULL
  input_file_count: 0
```

For example, this samplesheet:

```csv title="samplesheet.csv"
id,path
expression,input/expression_sample.xlsx
metadata,s3://example-bucket/project/metadata.tsv
```

makes these files available beside the Quarto notebook during rendering:

```text
expression_sample.xlsx
metadata.tsv
```

The report should therefore read:

```r
expression <- readxl::read_xlsx("expression_sample.xlsx")
metadata <- readr::read_tsv("metadata.tsv")
```

and should not read from the original samplesheet locations:

```r
# Do not do this inside the report
readxl::read_xlsx("input/expression_sample.xlsx")
readr::read_tsv("s3://example-bucket/project/metadata.tsv")
```

Because parent directories are stripped during staging, every file listed in the samplesheet must have a unique basename. This is valid:

```csv title="samplesheet.csv"
id,path
expression_xlsx,input/expression_sample.xlsx
expression_csv,input/expression_sample.csv
```

Currently this is not valid for the current staging layout because both rows would be staged as `expression.xlsx`:

```csv title="samplesheet.csv"
id,path
cohort_a,cohort_a/input/expression.xlsx
cohort_b,cohort_b/input/expression.xlsx
```

## Review document input

Use `--document` to attach a review or sign-off file to the run, for example a completed checklist, SOP, approval form, or other traceability record:

```bash
--document '[path to review document]'
```

When set, the pipeline stages this file into the results and adds it to the "Pipeline Outputs" table in the MultiQC report so the run records which review document was supplied. This parameter is optional and does not affect Quarto rendering itself.

## How the pipeline works

The main workflow performs eight steps:

1. `PIPELINE_INITIALISATION` validates `--input` with the `nf-schema` plugin and resolves each `path` entry as a single file.
2. The workflow selects the notebook using `--notebook`, or the bundled `assets/provenance_report.qmd` if `--notebook` is unset.
3. `QUARTONOTEBOOK` renders one Quarto HTML report using all samplesheet rows. The process receives `[meta, notebook]`, a parameter map, and the actual input files as a plain path channel. Its official eval outputs provide versions for software present in its runtime environment; empty version values are discarded.
4. `MD5SUM` calculates MD5 checksums for every samplesheet input and for the rendered Quarto HTML report.
5. `REPORTENVIRONMENT` receives the resolved `QUARTONOTEBOOK` runtime metadata and inherits the matching container image or Conda environment when one is configured. It captures the runtime backend, runtime reference, activated Conda path when available, `R sessionInfo()`, and Python version. Missing R or Python installations are reported as unavailable without failing the run.
6. If `--document` is set, the workflow stages the supplied review file into the published results via `STAGE_FILE`.
7. `MULTIQC` collates the input samplesheet, file checksums, pipeline outputs, workflow parameters, software versions, runtime-environment information, and Nextflow execution profile.
8. The workflow publishes the Quarto and MultiQC reports, report artifacts, checksums, the optional review document, and standard pipeline metadata under `pipeline_info/`.

The notebook receives these useful parameters:

| Parameter               | Description                                                                                                          |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `params$meta`           | Metadata map for the report, including `id`, `report_file_name`, `input_ids`, `input_files`, and `input_file_count`. |
| `params$input_dir`      | Working directory containing the staged input files. Defaults to `./`.                                               |
| `params$input_filename` | Staged filename for the first samplesheet row, provided for compatibility with simple Quarto notebook templates.     |
| `params$artifact_dir`   | Directory where the notebook should write images, tables, and other artifacts to be published by the pipeline.       |
| `params$cpus`           | CPUs allocated to the Quarto render task.                                                                            |

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/provenancereport --input ./samplesheet.csv --outdir ./results  -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

When a custom notebook requires a different runtime, configure `QUARTONOTEBOOK` with a normal Nextflow process selector. For a container runtime:

```groovy title="custom-container.config"
process {
    withName: '.*:QUARTONOTEBOOK' {
        container = 'quay.io/your-org/quarto-report:latest'
    }
}
```

```bash
nextflow run nf-core/provenancereport \
    --input ./samplesheet.csv \
    --notebook ./custom_report.qmd \
    --document ./review-signoff.pdf \
    --outdir ./results \
    -profile docker \
    -c custom-container.config
```

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/running/run-pipelines#configuring-pipelines), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run nf-core/provenancereport -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: "./samplesheet.csv"
outdir: "./results/"
notebook: "./custom_report.qmd"
document: "./review-signoff.pdf"
```

The `notebook` and `document` entries are optional. If `notebook` is omitted, the bundled `assets/provenance_report.qmd` notebook is used. If `document` is omitted, no review document is staged and the corresponding MultiQC section is not added.

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/provenancereport
```

### Reproducibility

It is a good idea to specify the pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/provenancereport releases page](https://github.com/nf-core/provenancereport/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future.

To further assist in reproducibility, you can use share and reuse [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen)

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> [!IMPORTANT]
> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to check if your system is supported, please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer environment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://charliecloud.io/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow ` 24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the pipeline steps, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher resources request (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#set-max-resources) and [customise process resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#customize-process-resources) section of the nf-core website.

### Custom Report Runtimes

In some cases, you may wish to change the container or Conda environment used by `QUARTONOTEBOOK`. This is especially relevant for `nf-core/provenancereport`, because a custom Quarto notebook may require additional R, Python, Julia, system, or Quarto extension dependencies that are not available in the default runtime.

You can provide any Quarto notebook with `--notebook`, as long as the runtime configured for `QUARTONOTEBOOK` contains Quarto plus all packages required by that notebook. Override the process runtime in a Nextflow config file. For a container runtime:

```groovy title="custom-container.config"
process {
    withName: '.*:QUARTONOTEBOOK' {
        container = 'quay.io/your-org/quarto-report:latest'
    }
}
```

For a Conda runtime:

```groovy title="custom-conda.config"
process {
    withName: '.*:QUARTONOTEBOOK' {
        conda = '/path/to/report-env.yml'
        container = null
    }
}
```

Then run the pipeline with both your execution profile and the custom config:

```bash
nextflow run nf-core/provenancereport \
    -profile docker \
    -c custom-container.config \
    --input samplesheet.csv \
    --notebook report.qmd \
    --outdir results
```

`REPORTENVIRONMENT` inherits the resolved `QUARTONOTEBOOK` container or Conda environment when possible. With no managed runtime, the runtime-environment table reports `Not configured`.

For more general guidance, see the [updating tool versions](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#update-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#modifying-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
