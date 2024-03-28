#!/bin/bash

if [[ $# -ne 1 || -z $1 ]]; then
    echo "Usage: TEMPLATE_NAME"
    exit 1
elif [[ -z $BRANCH_NAME ]]; then
    echo "BRANCH_NAME is null"
    exit 1
elif [[ -z $CUR_VERSION ]]; then
    echo "BRANCH_NAME is null"
    exit 1
fi

readonly TEMPLATE_PATH=".github/ISSUE_TEMPLATE/$1"

get_tags() {
    gh release list --exclude-drafts --json tagName | jq \
        --arg d "v$CUR_VERSION" \
        '. += [{ "tagName": $d }] 
            | map(.tagName) 
            | sort 
            | reverse'
}

###########################
## MAIN

tags=$(get_tags) yq -iP \
    '(.body[] | select(.id == "version") | .attributes.options)
        = env(tags)' "$TEMPLATE_PATH"

# remove (strip) all comments
yq -iP '... comments=""' "$TEMPLATE_PATH"

# add comments
echo -e "\n# Updated by $BRANCH_NAME\n# $(date -u)" >>"$TEMPLATE_PATH"
