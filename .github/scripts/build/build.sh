#!/bin/bash

readonly OUTPUT_PATH="outputs"
readonly WORKFLOW_PATH="workflow"
readonly PLIST_FILE="$WORKFLOW_PATH/info.plist"

get_value() {
    local key=$1
    local is_key=false
    local value=
    while IFS= read -r line; do
        if [[ $line == [[:space:]]"<key>$key</key>" ]]; then
            is_key=true
        elif [[ $is_key == true && $line == [[:space:]]"<string>"* ]]; then
            value=$(sed -e "s/<string>//" -e "s/<\/string>//" <<<"$line")
            break
        fi
    done <$PLIST_FILE

    echo $value
}

update_version() {
    if [[ "$OSTYPE" =~ ^darwin ]]; then
        sed -i "" "s/{{VERSION}}/$version/" $PLIST_FILE
    else
        sed -i "s/{{VERSION}}/$version/" $PLIST_FILE
    fi
}

create_alfredworkflow() {
    rm -rf "$OUTPUT_PATH"
    mkdir -p "$OUTPUT_PATH"

    cd "$WORKFLOW_PATH" && zip -rq "../$1" .
}

###########################
## MAIN

[[ -z $RELEASE_VERSION ]] && version="dev" || version=$RELEASE_VERSION

# update to release version
update_version
if [[ $? -ne 0 ]]; then
    echo "Failed to update version."
    exit 1
fi

# create .alfredworkflow file
name=$(get_value "name" | tr ' ' '-' | tr '[A-Z]' '[a-z]')-
if [[ $version == "dev" ]]; then
    name+="$version"
else
    name+="v$version"
fi
file_name="$OUTPUT_PATH/$name.alfredworkflow"

create_alfredworkflow $file_name
if [[ $? -ne 0 ]]; then
    echo "Failed to create .alfredworkflow"
    exit 1
fi

echo "OUTPUT_PATH=$OUTPUT_PATH" >>"$GITHUB_OUTPUT"
