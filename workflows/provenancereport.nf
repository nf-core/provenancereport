/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap                } from 'plugin/nf-schema'
include { RENDER_QUARTO_WITH_PROVENANCE    } from '../subworkflows/local/render_quarto_with_provenance/main'
include { REPORTENVIRONMENT               } from '../modules/local/reportenvironment/main'
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
    ch_input       // channel: input samplesheet file
    ch_notebook    // channel: Quarto notebook file
    ch_document    // channel: optional supporting document
    outdir

    main:

    ch_multiqc_reports = channel.empty()

    ch_quarto_input = ch_samplesheet
        .collect(flat: false)
        .map { rows -> [rows] }
        .combine(ch_notebook)
        .multiMap { rows, report_notebook ->
            def input_ids = rows.collect { meta, _input_file -> meta.id }
            def input_files = rows.collect { _meta, input_file -> input_file }
            def input_file_names = input_files.collect { input_file -> input_file.getName() }
            def duplicate_input_file_names = input_file_names
                .countBy { input_file_name -> input_file_name }
                .findAll { _input_file_name, count -> count > 1 }
                .keySet()
                .sort()
            if (duplicate_input_file_names) {
                error "Input files must have unique basenames because they are staged into the same directory. Duplicate basenames: ${duplicate_input_file_names.join(', ')}"
            }
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

    RENDER_QUARTO_WITH_PROVENANCE (
        ch_quarto_input.notebook,
        ch_quarto_input.parameters,
        ch_quarto_input.input_files,
        ch_quarto_input.extensions,
    )

    REPORTENVIRONMENT (
        RENDER_QUARTO_WITH_PROVENANCE.out.runtime_environment
    )

    //
    // Calculate checksums for every samplesheet input, the rendered report, and the optional document
    //
    def ch_checksum_files = ch_samplesheet
        .map { _meta, input_file -> input_file }
        .mix(RENDER_QUARTO_WITH_PROVENANCE.out.html.map { _meta, report_file -> report_file })
        .mix(ch_document)
        .collect()
        .map { files -> [[ id: 'provenancereport' ], files] }

    MD5SUM (
        ch_checksum_files,
        false,
    )

    //
    // Collate and save software versions
    //
    def ch_versions = channel.topic('versions')
        .distinct()
        .flatMap { entry ->
            if (entry instanceof Path) {
                def version_data = new org.yaml.snakeyaml.Yaml().load(entry)
                return version_data instanceof Map
                    ? version_data.collectMany { process, versions ->
                        versions instanceof Map
                            ? versions.collect { tool, version -> [ process, tool, version ] }
                            : []
                    }
                    : []
            }
            [ entry ]
        }
        .map { process, tool, version ->
            def trimmed_version = version?.toString()?.trim()
            def process_name = process.toString()
            def yaml_version = trimmed_version?.replace('\\', '\\\\')?.replace('"', '\\"')
            trimmed_version
                ? [ process_name[process_name.lastIndexOf(':')+1..-1], "  ${tool}: \"${yaml_version}\"" ]
                : null
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }
        .collectFile(
            name: 'versions.yml',
            sort: true,
            newLine: true
        )

    // MultiQC consumes the collected versions, so its own version is added to the final file afterwards.
    def ch_versions_for_multiqc = softwareVersionsToYAML(ch_versions)
        .collectFile(
            name: 'nf_core_'  +  'provenancereport_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    def ch_multiqc_files = channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_versions_for_multiqc)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_input.collectFile(name: 'samplesheet.csv')
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

    def ch_pipeline_outputs_rows = RENDER_QUARTO_WITH_PROVENANCE.out.html
        .map { _meta, report ->
            [
                file: report.getName(),
                output_path: "quartonotebook/${report.getName()}",
            ]
        }
    ch_pipeline_outputs_rows = ch_pipeline_outputs_rows.mix(
        ch_document.map { document_file ->
            [
                file: document_file.getName(),
                output_path: document_file.getName(),
            ]
        }
    )
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

    def multiqc_versions_string = MULTIQC.out.versions
        .map { process, tool, version ->
            def yaml_version = version.toString().replace('\\', '\\\\').replace('"', '\\"')
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: \"${yaml_version}\"" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = ch_versions_for_multiqc
        .map { versions_file -> versions_file.text.trim() }
        .mix(multiqc_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'provenancereport_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    ch_multiqc_reports = ch_multiqc_reports
            .mix(MULTIQC.out.report.map { _meta, report -> report })
            .mix(MULTIQC.out.data.map   { _meta, data   -> data   })
            .mix(MULTIQC.out.plots.map  { _meta, plots  -> plots  })

    // Workflow outputs only publish files materialized in the work directory.
    def ch_publishable_document = ch_document.collectFile()

    emit:
    versions       = ch_collated_versions                                // channel: [ path(versions.yml) ]
    multiqc_report = ch_multiqc_reports
    document       = ch_publishable_document
    reports        = RENDER_QUARTO_WITH_PROVENANCE.out.html.map      { _meta, html     -> html     }
    notebook       = RENDER_QUARTO_WITH_PROVENANCE.out.notebook.map  { _meta, qmd      -> qmd      }
    artifacts      = RENDER_QUARTO_WITH_PROVENANCE.out.artifacts.map { _meta, artifact -> artifact } // channel: [ val(meta), path(artifacts/*) ]
    md5sum         = MD5SUM.out.checksum.map          { _meta, checksum -> checksum }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
