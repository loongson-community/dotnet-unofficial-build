#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$MY_DIR"/scripts/_utils.sh

: "${BUILD_CONFIG:=$1}"
: "${BUILD_CONFIG:=$MY_DIR/_config.sh}"

echo "sourcing build config from $(_term green)${BUILD_CONFIG}$(_term reset)"
. "$BUILD_CONFIG"
echo

: "${OUT_DIR:?OUT_DIR must be set}"
: "${REPACK_TARBALLS:=true}"

_GZIP_CMD=gzip
if command -v pigz > /dev/null; then
    _GZIP_CMD=pigz
fi

# operates in CWD
repack_tarballs() {
    local f
    local bare_name
    local orig_size
    local repacked_size
    local results=()
    for f in *.tar.gz; do
        case "$f" in
        Private.SourceBuilt.Artifacts.*.tar.gz)
            # these have to stay in tar.gz format to meet dotnet source build
            # expectations.
            # see prep-source-build.sh in dotnet/dotnet
            echo "not repacking $f"
            continue
            ;;
        "*.tar.gz")
            # path expansion produced no result
            return 0
            ;;
        esac


        bare_name="${f%.gz}"
        orig_size="$(stat -c "%s" "$f")"
        "$_GZIP_CMD" -d "$f"
        zstd -19 --rsyncable --rm -T0 "$bare_name"
        repacked_size="$(stat -c "%s" "${bare_name}.zst")"
        results+=( "$f: $orig_size -> $repacked_size bytes" )
    done

    local result
    for result in "${results[@]}"; do
        echo "$result"
    done
}

# operates in CWD
gen_checksums() {
    local f
    for f in *.tar.*; do
        if [[ $f == "*.tar.*" ]]; then
            # path expansion produced no result
            return 0
        fi

        echo "  - $f"
        sha256sum "$f" > "$f".sha256 &
        sha512sum "$f" > "$f".sha512 &
        wait
    done
}

main() {
    pushd "$OUT_DIR" > /dev/null

    if "$REPACK_TARBALLS"; then
        group "repacking tarballs with zstd"
        repack_tarballs
        endgroup
    else
        echo "skipping repacking of tarballs according to config"
        echo
    fi

    group "checksumming tarballs"
    gen_checksums
    endgroup

    popd > /dev/null
}

main
