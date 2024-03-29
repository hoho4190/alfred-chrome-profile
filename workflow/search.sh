#!/bin/bash

readonly QUERY=$(tr '[A-Z]' '[a-z]' <<<"$1")
readonly DEFAULT_AVATAR_PATH="assets/avatar/default.png"
readonly AVATAR_INFO_PATH="assets/avatar/avatar-info.json"

get_profile_path() {
    local path="${1/#~/$HOME}"
    [[ "${path: -1}" != "/" ]] && path+="/"
    sed 's/\\ / /g' <<<"$path"
}

get_item() {
    local title
    local icon_path
    local arg

    local profile_name=$(jq -r '.profile_name' <<<"$1")
    local name=$(jq -r '.name' <<<"$1")
    local gaia_given_name=$(jq -r '.gaia_given_name' <<<"$1")
    local gaia_picture_file_name=$(jq -r '.gaia_picture_file_name' <<<"$1")
    local gaia_picture_url=$(jq -r '.gaia_picture_url' <<<"$1")
    local use_gaia_picture=$(jq -r '.use_gaia_picture' <<<"$1")
    local avatar_icon=$(jq -r '.avatar_icon' <<<"$1")

    # set title
    if [[ -z "$gaia_given_name" || "$name" == "$gaia_given_name" ]]; then
        title="$name"
    else
        title="$gaia_given_name ($name)"
    fi

    # set icon_path
    if [[ "$use_gaia_picture" == false || "$gaia_picture_url" == "null" ]]; then

        if [[ "$avatar_icon" == *"_26" ]]; then
            icon_path="$DEFAULT_AVATAR_PATH"
        else
            # https://github.com/chromium/chromium/blob/main/chrome/browser/profiles/profile_avatar_icon_util.cc#L414C35-L414C35
            avatar_icon=$(sed 's/chrome:\/\/theme\///g' <<<"$avatar_icon")
            avatar_name=$(
                jq -r --arg avatar_icon "$avatar_icon" \
                    '. | to_entries[] | select(.key == $avatar_icon) | .value' <"$AVATAR_INFO_PATH"
            )
            icon_path="${APP_SUP_PATH}Avatars/$avatar_name"

            [[ ! -f "$icon_path" ]] && icon_path="$DEFAULT_AVATAR_PATH"
        fi
    else
        icon_path="${APP_SUP_PATH}$profile_name/$gaia_picture_file_name"
    fi

    # set arg
    arg="${profile_name}"$'\n'"$title"

    jq --arg title "$title" --arg icon_path "$icon_path" --arg arg "$arg" \
        '. += { title: $title, icon: { path: $icon_path }, arg: $arg }' <<<"{}"
}

###########################
## MAIN

readonly APP_SUP_PATH=$(get_profile_path "$APP_SUPPORT_PATH")

profiles=$(
    jq --arg q "$QUERY" '.profile.info_cache | to_entries[] 
        | select((.value.gaia_given_name | ascii_downcase | contains($q)) or (.value.name | ascii_downcase | contains($q)))
        | {
            profile_name: .key,
            name: .value.name,
            gaia_given_name: .value.gaia_given_name,
            gaia_picture_file_name: .value.gaia_picture_file_name,
            gaia_picture_url: .value.last_downloaded_gaia_picture_url_with_size,
            use_gaia_picture: .value.use_gaia_picture,
            avatar_icon: .value.avatar_icon
        }' <"${APP_SUP_PATH}Local State"
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
