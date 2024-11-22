# this file is meant to be sourced

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_IMAGE_TAG_PREFIX="ghcr.io/loongson-community"

builder_image_tag() {
    local timestamp="$1"
    echo "${_IMAGE_TAG_PREFIX}/dotnet-unofficial-build-builder:${timestamp}"
}

rootfs_image_tag() {
    local arcade_commit="${1:0:12}"
    local timestamp="$2"
    local libc_kind="$3"

    local libc_suffix=""
    case "$libc_kind" in
    musl)
        libc_suffix="-musl"
        ;;
    esac

    echo "${_IMAGE_TAG_PREFIX}/dotnet-unofficial-build-rootfs:${arcade_commit}-${timestamp}${libc_suffix}"
}

#
# CLI output helpers
#

if [[ -z $TERM || $TERM == dumb ]]; then
    TERM=ansi
fi
export TERM

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

ensure_git_safety() {
    [[ -n $CI ]] || return 0
    [[ -O "$REPO_ROOT" ]] && return 0

    group "telling Git to consider the repo as safe"
    git config --global --add safe.directory "$REPO_ROOT"
    endgroup
}

get_commit_time() {
  TZ=UTC0 git log -1 \
    --format='tformat:%cd' \
    --date='format:%Y-%m-%dT%H:%M:%SZ' \
    "$@"
}

init_source_epoch() {
    if [[ -n $SOURCE_EPOCH ]]; then
        echo "source epoch is explicitly set"
    else
        echo "deriving source epoch from dotnet-unofficial-build repository HEAD"
        export SOURCE_EPOCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && get_commit_time)"
    fi

    echo_kv SOURCE_EPOCH "$SOURCE_EPOCH"
}
