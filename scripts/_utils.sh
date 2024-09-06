# this file is meant to be sourced

_IMAGE_TAG_PREFIX="ghcr.io/loongson-community"

builder_image_tag() {
    local timestamp="$1"
    echo "${_IMAGE_TAG_PREFIX}/dotnet-unofficial-build-builder:${timestamp}"
}

rootfs_image_tag() {
    local arcade_commit="${1:0:12}"
    local timestamp="$2"
    echo "${_IMAGE_TAG_PREFIX}/dotnet-unofficial-build-rootfs:${arcade_commit}-${timestamp}"
}

#
# CLI output helpers
#

declare -A _TERM_SEQ_MAP=(
    ["reset"]="$(tput sgr0)"
    ["bold"]="$(tput bold)"
    ["gray"]="$(tput setaf 0)"
    ["red"]="$(tput setaf 1)"
    ["green"]="$(tput setaf 2)"
    ["yellow"]="$(tput setaf 3)"
    ["blue"]="$(tput setaf 4)"
    ["magenta"]="$(tput setaf 5)"
    ["cyan"]="$(tput setaf 6)"
    ["white"]="$(tput setaf 7)"
)

_term() {
    for key in "$@"; do
        printf "%s" "${_TERM_SEQ_MAP[$key]}"
    done
}

# usage: group <group name>
group() {
    local prefix=
    [[ -n $GITHUB_ACTIONS ]] && prefix="::group::"

    printf "${prefix}$(_term bold green)%s$(_term reset)\n" "$1"
}

# usage: endgroup
endgroup() {
    if [[ -n $GITHUB_ACTIONS ]]; then
        echo "::endgroup::"
    fi
    echo
}

# usage: echo_kv <k> <v>
echo_kv() {
    local k="$1"
    shift

    echo "$(_term yellow)${k}: $(_term cyan)$@$(_term reset)"
}
