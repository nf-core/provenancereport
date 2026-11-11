include { QUARTO_PREPARE  } from '../../../modules/local/quarto_prepare/main'
include { QUARTO_NOTEBOOK } from '../../../modules/nf-core/quarto/notebook/main'

workflow RENDER_QUARTO_WITH_PROVENANCE {

    take:
    ch_notebook
    ch_parameters
    ch_input_files
    ch_extensions

    main:
    QUARTO_PREPARE (
        ch_notebook
    )

    QUARTO_NOTEBOOK (
        QUARTO_PREPARE.out.notebook,
        ch_parameters,
        ch_input_files,
        ch_extensions,
    )

    emit:
    html                = QUARTO_NOTEBOOK.out.html
    source_notebook     = QUARTO_PREPARE.out.source_notebook
    notebook            = QUARTO_NOTEBOOK.out.notebook
    params_yaml         = QUARTO_NOTEBOOK.out.params_yaml
    artifacts           = QUARTO_NOTEBOOK.out.artifacts
    extensions          = QUARTO_NOTEBOOK.out.extensions
    runtime_environment = QUARTO_NOTEBOOK.out.runtime_environment
    versions            = QUARTO_NOTEBOOK.out.versions
    versions_quarto     = QUARTO_NOTEBOOK.out.versions_quarto
    versions_papermill  = QUARTO_NOTEBOOK.out.versions_papermill
}
