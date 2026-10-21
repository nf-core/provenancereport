#!/usr/bin/env bash

collect_r_session_info() {
    if command -v Rscript >/dev/null 2>&1; then
        Rscript -e 'sessionInfo()' > r_session_info.txt 2>/dev/null || printf 'Not available\n' > r_session_info.txt
    else
        printf 'Not available\n' > r_session_info.txt
    fi
}

collect_python_version() {
    if command -v python >/dev/null 2>&1; then
        python --version > python_version.txt 2>&1 || printf 'Not available\n' > python_version.txt
    elif command -v python3 >/dev/null 2>&1; then
        python3 --version > python_version.txt 2>&1 || printf 'Not available\n' > python_version.txt
    else
        printf 'Not available\n' > python_version.txt
    fi
}

write_runtime_environment_table() {
    local python_version
    python_version=\$(tr '\t\r\n' '   ' < python_version.txt | sed 's/[[:space:]]*\$//')

    cat <<-END_MQC > runtime_environment_mqc.tsv
field\tvalue
Process\t${task.process}
Runtime source process\t${runtime_process}
Runtime backend\t${runtime_backend}
Runtime reference\t${runtime_reference ?: 'Not configured'}
Container engine\t${workflow.containerEngine ?: 'None'}
Python\t\${python_version}
END_MQC
}

write_r_session_info_section() {
    cat <<-END_MQC > r_session_info_mqc.yaml
id: 'nf-core-provenancereport-r-session-info'
description: 'Full R sessionInfo() output from the report rendering environment.'
section_name: 'R sessionInfo()'
plot_type: 'html'
data: |
  <pre style="white-space: pre-wrap; overflow-x: auto; max-height: 32rem;">
END_MQC

    sed \
        -e 's/&/\\&amp;/g' \
        -e 's/</\\&lt;/g' \
        -e 's/>/\\&gt;/g' \
        -e 's/^/  /' \
        r_session_info.txt >> r_session_info_mqc.yaml

    printf '  </pre>\n' >> r_session_info_mqc.yaml
}

collect_r_session_info
collect_python_version
write_runtime_environment_table
write_r_session_info_section
