#!/bin/bash
CMD="tofu init && tofu providers lock -platform=linux_amd64"
dirs=("bloom_dev" "bloom_dev_deployer_permission_set_policy" "bloom_genai" "bloom_genai_deployer_permission_set_policy" "bloom_prod" "bloom_prod_deployer_permission_set_policy" )

for directory in "${dirs[@]}"; do
    echo "processing $directory"
    pushd $directory
    eval "$CMD"
    popd
done