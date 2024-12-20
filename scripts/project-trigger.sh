#!/bin/bash


json_file="../projects/projects.json"
gh_token=$GH_TOKEN
git_ref="main"
workflow_organization_name="cncf-tags"
workflow_project_name="green-reviews-tooling"
workflow_dispatcher_file_name="benchmark-pipeline.yaml"

if [ -z "$gh_token" ]; then
    echo "GH_TOKEN not set"
    exit 20
fi

jq -c '.projects[]' "$json_file" | while read -r project; do
    proj_name=$(echo "$project" | jq -r '.name')
    proj_organization=$(echo "$project" | jq -r '.organization')
    proj_benchmark_manifest_url=$(echo "$project" | jq -r '.benchmark.k8s_manifest_url')
    proj_benchmark_duration_mins=$(echo "$project" | jq -r '.benchmark.duration_mins')
    configs=$(echo "$project" | jq -r '.configs')

    echo "Project Name: $proj_name"
    echo "Organization: $proj_organization"
    echo "Benchmark Manifest URL: $proj_benchmark_manifest_url"
    echo "Benchmark Duration (Minutes): $proj_benchmark_duration_mins"
    echo "Configs: $configs"

    release_url="https://api.github.com/repos/${proj_organization}/${proj_name}/releases/latest"
    
    
    response=$(curl --fail-with-body -sSL -X GET $release_url)
    status_code=$?
    if [ $status_code -ne 0 ]; then
        echo "fetching latest release for ${proj_name} from ${release_url}. Status code: $status_code"
        echo "curl Response: $response"
        continue
    fi

    latest_proj_version=$(echo "$response" | jq -r '.tag_name')
    if [ -z "$latest_proj_version" ]; then
        echo "could not find the latest version for ${proj_name}"
        continue
    fi

    echo "latest version: $latest_proj_version"

    if [ "$configs" == "null" ]; then
        echo "$proj_name has no configs triggering pipeline once"
        workflow_dispatch=$(curl --fail-with-body -sSL -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $gh_token" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/repos/$workflow_organization_name/$workflow_project_name/actions/workflows/$workflow_dispatcher_file_name/dispatches" \
            -d "{\"ref\":\"${git_ref}\",\"inputs\":{\"cncf_project\":\"${proj_name}\",\"benchmark_job_url\":\"${proj_benchmark_manifest_url}\",\"benchmark_job_duration_mins\":\"${proj_benchmark_duration_mins}\",\"version\":\"${latest_proj_version}\"}}")

        status_code=$?
        if [ $status_code -ne 0 ]; then
            echo "dispatching workflow for [proj: ${proj_name}, ver: $latest_proj_version] Status code: $status_code"
            echo "curl response: $workflow_dispatch"
            continue
        fi

        echo "workflow_call event [proj: $proj_name, ver: $latest_proj_version]=> OK"
    else
        echo "$proj_name has configs triggering pipeline once per config"
        for config in $(echo "$configs" | jq -r '.[]'); do
            workflow_dispatch=$(curl --fail-with-body -sSL -X POST \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer $gh_token" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/repos/$workflow_organization_name/$workflow_project_name/actions/workflows/$workflow_dispatcher_file_name/dispatches" \
                -d "{\"ref\":\"${git_ref}\",\"inputs\":{\"cncf_project\":\"${proj_name}\",\"benchmark_job_url\":\"${proj_benchmark_manifest_url}\",\"benchmark_job_duration_mins\":\"${proj_benchmark_duration_mins}\",\"config\":\"${config}\",\"version\":\"${latest_proj_version}\"}}")

            status_code=$?
            if [ $status_code -ne 0 ]; then
                echo "dispatching workflow for [proj: ${proj_name}, config: $config, ver: $latest_proj_version] Status code: $status_code"
                echo "curl response: $workflow_dispatch"
                continue
            fi

            echo "workflow_call event [proj: $proj_name, config: $config, ver: $latest_proj_version]=> OK"
        done
    fi
done
