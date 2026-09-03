/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap                } from 'plugin/nf-schema'
include { QUARTONOTEBOOK                  } from '../modules/nf-core/quartonotebook/main'
include { REPORTENVIRONMENT               } from '../modules/local/reportenvironment/main'
include { STAGE_FILE                      } from '../modules/local/stage_file/main'
include { MD5SUM                          } from '../modules/nf-core/md5sum/main'
include { MULTIQC                         } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMultiqc            } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML          } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText          } from '../subworkflows/local/utils_nfcore_provenancereport_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PROVENANCEREPORT {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    outdir

    main:

    def ch_versions = channel.empty()
    def report_notebook = file(params.notebook ?: "${projectDir}/assets/provenance_report.qmd", checkIfExists: true)
    ch_document_file = params.document ? file(params.document) : channel.empty()

    ch_quarto_input = ch_samplesheet
        .collect(flat: false)
        .multiMap { rows ->
            def input_ids = rows.collect { meta, _input_file -> meta.id }
            def input_files = rows.collect { _meta, input_file -> input_file }
            def input_file_names = input_files.collect { input_file -> input_file.getName() }
            def report_meta = [
                id: report_notebook.baseName,
                report_file_name: report_notebook.baseName,
                input_ids: input_ids.join(','),
                input_files: input_file_names.join(','),
                input_file_count: input_file_names.size(),
            ]
            notebook:
            [
                report_meta,
                report_notebook,
            ]

            parameters:
            [
                input_dir: './',
                input_filename: input_file_names[0],
            ]

            input_files:
            input_files

            extensions:
            []
        }

    QUARTONOTEBOOK (
        ch_quarto_input.notebook,
        ch_quarto_input.parameters,
        ch_quarto_input.input_files,
        ch_quarto_input.extensions,
    )

    REPORTENVIRONMENT (
        QUARTONOTEBOOK.out.runtime_environment
    )

    //
    // Calculate checksums for every samplesheet input and the rendered report
    //
    def ch_checksum_files = ch_samplesheet
        .map { _meta, input_file -> input_file }
        .mix(QUARTONOTEBOOK.out.html.map { _meta, report_file -> report_file })
        .collect()
        .map { files -> [[ id: 'provenancereport' ], files] }

    MD5SUM (
        ch_checksum_files,
        false,
    )

    //
    // Collate and save software versions
    //
    def quartonotebook_versions = QUARTONOTEBOOK.out.versions_quarto
        .mix(QUARTONOTEBOOK.out.versions_papermill)
        .map { process, tool, version ->
            def trimmed_version = version?.toString()?.trim()
            // Optional tools may emit an empty eval value; omit them instead of reporting a blank version.
            trimmed_version
                ? [ process.tokenize(':')[-1], "  ${tool}: ${trimmed_version}" ]
                : null
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions)
        .mix(quartonotebook_versions)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'provenancereport_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    def ch_multiqc_files = channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        channel.value(file(params.input, checkIfExists: true)).collectFile(name: 'samplesheet.csv')
    )

    def ch_file_checksums = MD5SUM.out.checksum
        .map { _meta, checksum_file ->
            def checksum_rows = checksum_file.text.readLines()
                .findAll { line -> line.trim() }
                .collect { line ->
                    def checksum_fields = line.trim().split(/\s+/, 2)
                    "${checksum_fields[1]}\t${checksum_fields[0]}"
                }
                .sort()
            (["file\tmd5"] + checksum_rows).join('\n')
        }
        .collectFile(
            name: 'file_checksums_mqc.tsv',
            newLine: true,
        )
    ch_multiqc_files = ch_multiqc_files.mix(ch_file_checksums)

    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: 'nextflow_schema.json')
    ch_summary_params.get('Core Nextflow options')?.remove('container')
    def workflow_summary = paramsSummaryMultiqc(ch_summary_params)
        .readLines()
        .findAll { line -> !line.startsWith('description:') && !line.startsWith('section_href:') }
        .join('\n')
    ch_multiqc_files = ch_multiqc_files.mix(
        channel.value(workflow_summary).collectFile(name: 'workflow_summary_mqc.yaml')
    )

    def ch_methods_description = channel.value(
        methodsDescriptionText(file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true))
    )
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true)
    )

    ch_multiqc_files = ch_multiqc_files.mix(
        REPORTENVIRONMENT.out.multiqc_table,
        REPORTENVIRONMENT.out.multiqc_r_session
    )

    def ch_pipeline_outputs_rows = QUARTONOTEBOOK.out.html
        .map { _meta, report ->
            [
                file: report.getName(),
                output_path: "quartonotebook/${report.getName()}",
            ]
        }
    if (params.document) {
        ch_pipeline_outputs_rows = ch_pipeline_outputs_rows.mix(
            channel.value(
                [
                    file: ch_document_file.getName(),
                    output_path: ch_document_file.getName(),
                ]
            )
        )
    }
    def ch_pipeline_outputs = ch_pipeline_outputs_rows
        .collect()
        .map { rows ->
            (['file\toutput_path'] + rows.collect { row -> "${row.file}\t${row.output_path}" }).join('\n')
        }
        .collectFile(name: 'pipeline_outputs_mqc.tsv', newLine: true)
    ch_multiqc_files = ch_multiqc_files.mix(ch_pipeline_outputs)

    MULTIQC (
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [ id: 'provenancereport' ],
                files,
                file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                file("${projectDir}/assets/nf-core-provenancereport_logo_light.png", checkIfExists: true),
                [],
                [],
            ]
        }
    )

    STAGE_FILE (ch_document_file)

    emit:
    versions       = ch_versions                                        // channel: [ path(versions.yml) ]
    reports        = QUARTONOTEBOOK.out.html                            // channel: [ val(meta), path(html) ]
    multiqc_report = MULTIQC.out.report.map { _meta, report -> report } // channel: path(multiqc_report.html)
    document       = STAGE_FILE.out.staged_file
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
