process REPORTENVIRONMENT {
    tag 'report runtime environment'
    label 'process_single'

    input:
    val report_container

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
    Container engine\t${workflow.containerEngine ?: 'None'}
    Container\t${report_container ?: 'Not configured'}
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
