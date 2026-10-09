process QUARTO_PREPARE {
    tag "${meta.id}"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/28/28717ccd9ce22dbfc219f3db088d5a1fc2ca1f575b5c65621218596dcdbaac95/data'
        : 'community.wave.seqera.io/library/jupyter_matplotlib_papermill_quarto_r-rmarkdown:6d15193ce3dfc665'}"

    input:
    tuple val(meta), path(notebook)

    output:
    tuple val(meta), path("prepared_${notebook.name}")                    , emit: notebook
    tuple val("${task.process}"), val('python'), eval('python --version | sed "s/^Python //"'), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('pyyaml'), eval('python -c "import yaml; print(yaml.__version__)"'), emit: versions_pyyaml, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    prepare_quarto_notebook.py \
        --input "${notebook}" \
        --output "prepared_${notebook.name}"
    """

    stub:
    """
    cp "${notebook}" "prepared_${notebook.name}"
    """
}
