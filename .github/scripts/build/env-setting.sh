#!/bin/bash

is_release=false

if [[ $GITHUB_EVENT_NAME == 'push' && $GITHUB_REF_NAME == "main" ]]; then
    release_branch=$(
        gh api \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            /repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA/pulls \
            -q '.[0].head.ref'
    )

    if [[ $release_branch == "release/v"* ]]; then
        is_release=true
        echo "RELEASE_BRANCH=$release_branch" >>"$GITHUB_ENV"
        echo "RELEASE_TAG=$(sed 's/release\///' <<<$release_branch)" >>"$GITHUB_ENV"
        echo "RELEASE_VERSION=$(sed 's/release\/v//' <<<$release_branch)" >>"$GITHUB_ENV"
    fi
fi

echo "IS_RELEASE=$is_release" >>"$GITHUB_ENV"
