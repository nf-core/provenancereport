#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/provenancereport
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/provenancereport
    Website: https://nf-co.re/provenancereport
    Slack  : https://nfcore.slack.com/channels/provenancereport
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PROVENANCEREPORT  } from './workflows/provenancereport'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_provenancereport_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_provenancereport_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_PROVENANCEREPORT {

    take:
    samplesheet // channel: samplesheet read in from --input
    input       // channel: input samplesheet file
    notebook    // channel: Quarto notebook file
    document    // channel: optional supporting document

    main:

    //
    // WORKFLOW: Run pipeline
    //
    PROVENANCEREPORT (
        samplesheet,
        input,
        notebook,
        document,
        params.outdir,
    )

    emit:
    multiqc_report = PROVENANCEREPORT.out.multiqc_report
    reports        = PROVENANCEREPORT.out.reports
    notebook       = PROVENANCEREPORT.out.notebook
    artifacts      = PROVENANCEREPORT.out.artifacts
    md5sum         = PROVENANCEREPORT.out.md5sum
    document       = PROVENANCEREPORT.out.document
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.notebook,
        params.document,
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_PROVENANCEREPORT (
        PIPELINE_INITIALISATION.out.samplesheet,
        PIPELINE_INITIALISATION.out.input,
        PIPELINE_INITIALISATION.out.notebook,
        PIPELINE_INITIALISATION.out.document,
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        NFCORE_PROVENANCEREPORT.out.multiqc_report,
    )

    publish:
    reports        = NFCORE_PROVENANCEREPORT.out.reports
    notebook       = NFCORE_PROVENANCEREPORT.out.notebook
    artifacts      = NFCORE_PROVENANCEREPORT.out.artifacts
    multiqc_report = NFCORE_PROVENANCEREPORT.out.multiqc_report
    md5sum         = NFCORE_PROVENANCEREPORT.out.md5sum
    document       = NFCORE_PROVENANCEREPORT.out.document
}

output {
    reports {
        path 'quartonotebook'
        mode params.publish_dir_mode
    }
    notebook {
        path 'quartonotebook'
        mode params.publish_dir_mode
    }
    artifacts {
        path 'quartonotebook'
        mode params.publish_dir_mode
        index {
            path 'artifacts.csv'
        }
    }
    multiqc_report {
        path 'multiqc'
        mode params.publish_dir_mode
        index {
            path 'multiqc_report.csv'
        }
    }
    md5sum {
        path 'md5sum'
        mode params.publish_dir_mode
    }
    document{
        mode params.publish_dir_mode
        index {
            path 'document.csv'
        }
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
