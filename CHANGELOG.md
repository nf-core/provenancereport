# nf-core/provenancereport: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0dev - [date]

Initial release of nf-core/provenancereport, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- [#26](https://github.com/nf-core/provenancereport/issues/26) - Attach documentation to pipeline run.
- [#8](https://github.com/nf-core/provenancereport/issues/8) - Add a MultiQC execution report with run configuration and report-runtime environment metadata.
- [#23](https://github.com/nf-core/provenancereport/pull/23) - Add MD5 checksums for all samplesheet inputs and the rendered Quarto report to the MultiQC execution report.
- [#18](https://github.com/nf-core/provenancereport/pull/18) - Document the required Quarto report `params`and input names in samplesheet.
- [#16](https://github.com/nf-core/provenancereport/pull/16) - Add a test case with a user-provided quarto input with an external RDS file and user-provided custom container.
- [#15](https://github.com/nf-core/provenancereport/pull/15) - First draft implementation of provenancereport pipeline.
- [#19](https://github.com/nf-core/provenancereport/pull/19) - Integrate nf-prov and metadata capture.
- [#29](https://github.com/nf-core/provenancereport/pull/29) - List QUARTONOTEBOOK html report in seqera.

### `Fixed`

### `Dependencies`

### `Deprecated`
