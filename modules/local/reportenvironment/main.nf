process REPORTENVIRONMENT {
    tag 'report runtime environment'
    label 'process_single'
    container {
        try {
            runtime_backend != 'conda' && runtime_backend != 'none' && runtime_reference != 'Not configured' ? runtime_reference : null
        } catch (MissingPropertyException _ignored) {
            // `nextflow inspect` evaluates directives before process inputs are bound.
            null
        }
    }
    conda {
        try {
            runtime_backend == 'conda' && runtime_reference != 'Not configured' ? runtime_reference : null
        } catch (MissingPropertyException _ignored) {
            // `nextflow inspect` evaluates directives before process inputs are bound.
            null
        }
    }

    input:
    tuple val(runtime_process), val(runtime_backend), val(runtime_reference)

    output:
    path "runtime_environment_mqc.tsv", emit: multiqc_table
    path "r_session_info_mqc.yaml", emit: multiqc_r_session

    script:
    template 'reportenvironment.sh'

    stub:
    """
    cat <<-END_MQC > runtime_environment_mqc.tsv
    field\tvalue
    Process\t${task.process}
    Runtime source process\t${runtime_process}
    Runtime backend\t${runtime_backend}
    Runtime reference\t${runtime_reference ?: 'Not configured'}
    Container engine\t${workflow.containerEngine ?: 'None'}
    Python\tNot available
    END_MQC

    cat <<-END_MQC > r_session_info_mqc.yaml
    id: 'nf-core-provenancereport-r-session-info'
    description: 'Full R sessionInfo() output from the report rendering environment.'
    section_name: 'R sessionInfo()'
    plot_type: 'html'
    data: |
      <pre style="white-space: pre-wrap; overflow-x: auto; max-height: 32rem;">
      Not available
      </pre>
    END_MQC
    """
}
