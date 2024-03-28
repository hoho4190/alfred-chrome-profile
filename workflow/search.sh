#!/bin/bash

readonly QUERY=$(tr '[A-Z]' '[a-z]' <<<"$1")
readonly CACHE_PATH="$alfred_workflow_cache"

get_profile_path() {
    local path="${1/#~/$HOME}"
    [[ "${path: -1}" != "/" ]] && path+="/"
    path=$(sed 's/\\ / /g' <<<"$path")
    echo "${path}Local State"
}

clean_up_cache_by_month() {
    if [[ ! -f "$CACHE_PATH/$1" ]]; then
        rm -rf "$CACHE_PATH"
        mkdir -p "$CACHE_PATH"
        touch "$CACHE_PATH/$1"
    fi
}

convert_icon_name() {
    echo $(echo "$1" | md5).png
}

save_icon() {
    local download_url="$1"
    local file_path="$2"

    if [[ ! -e "$file_path" ]]; then
        curl -s -o "$file_path" "$download_url"
    fi
}

get_item() {
    local title
    local icon_path
    local arg

    profile_name=$(jq -r '.profile_name' <<<"$1")
    name=$(jq -r '.name' <<<"$1")
    gaia_given_name=$(jq -r '.gaia_given_name' <<<"$1")
    icon_url=$(jq -r '.icon_url' <<<"$1")

    if [[ -z "$gaia_given_name" || "$name" == "$gaia_given_name" ]]; then
        title="$name"
    else
        title="$gaia_given_name ($name)"
    fi

    if [[ "$icon_url" == "null" ]]; then
        icon_path="assets/images/default.png"
    else
        icon_path="$CACHE_PATH/"$(convert_icon_name "$icon_url")
        save_icon "$icon_url" "$icon_path"
    fi

    arg="${profile_name}"$'\n'"$title"

    jq --arg title "$title" --arg icon_path "$icon_path" --arg arg "$arg" \
        '. += { title: $title, icon: { path: $icon_path }, arg: $arg }' <<<"{}"
}

###########################
## MAIN

readonly PROFILE_PATH=$(get_profile_path "$APP_SUPPORT_PATH")

# make cache directory
[[ -d "$CACHE_PATH" ]] || mkdir -p "$CACHE_PATH"

# clean up cached images every month
clean_up_cache_by_month $(date +"%m")

profiles=$(
    jq --arg q "$QUERY" '.profile.info_cache | to_entries[] 
        | select((.value.gaia_given_name | ascii_downcase | contains($q)) or (.value.name | ascii_downcase | contains($q)))
        | {
            profile_name: .key,
            name: .value.name,
            gaia_given_name: .value.gaia_given_name,
            icon_url: .value.last_downloaded_gaia_picture_url_with_size
        }' <"$PROFILE_PATH"
)

items="[]"
while read -r profile; do
    item=$(get_item "$profile")
    items=$(
        jq --argjson item "$item" '. += [$item]' <<<"$items"
    )
done < <(jq -c '.' <<<"$profiles")

cache=$(jq '. += {seconds: 10, loosereload: true}' <<<"{}")
echo -n "{\"cache\": $cache, \"items\": $items}"
