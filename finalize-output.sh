#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source-path=SCRIPTDIR
. "$MY_DIR"/scripts/_utils.sh

: "${BUILD_CONFIG:=$1}"
: "${BUILD_CONFIG:=$MY_DIR/_config.sh}"

echo "sourcing build config from $(_term green)${BUILD_CONFIG}$(_term reset)"
# shellcheck source=_config.sh
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
    group "checksumming tarballs"

    local files=()
    for f in *.tar *.tar.*; do
        if [[ $f == "*.tar" || $f == "*.tar.*" ]]; then
            # path expansion produced no result
            continue
        fi

        echo "  - will checksum $f"
        files+=( "$f" )
    done

    sha256sum "${files[@]}" > SHA256SUMS &
    sha512sum "${files[@]}" > SHA512SUMS &
    wait

    endgroup
}

pack_sdk_feeds() {
    local feed_dir
    for feed_dir in "sdk-feed-stage"*; do
        pack_sdk_feed "$feed_dir"
    done
}

pack_sdk_feed() {
    local feed_dir="$1"

    group "packing SDK feed content: $feed_dir"

    local args=(
        # Reproducibility
        # see https://www.gnu.org/software/tar/manual/html_section/Reproducibility.html
        --sort=name
        --format=posix
        --pax-option='exthdr.name=%d/PaxHeaders/%f'
        --pax-option='delete=atime,delete=ctime'
        --clamp-mtime
        --mtime="$SOURCE_EPOCH"
        --numeric-owner
        --owner=0
        --group=0
        # but preserve file modes because we're not producing only plain-old data

        # no compression as majority of the content is already compressed
        -cvf "$feed_dir".tar
        "./$feed_dir"
    )
    LC_ALL=C tar "${args[@]}"

    # not strictly necessary because the upload-artifact action can filter out
    # the extra files, but it may be good to conserve disk space anyway
    rm -rf "./$feed_dir"

    endgroup
}

main() {
    init_source_epoch

    pushd "$OUT_DIR" > /dev/null || return

    if "$REPACK_TARBALLS"; then
        group "repacking tarballs with zstd"
        repack_tarballs
        endgroup
    else
        echo "skipping repacking of tarballs according to config"
        echo
    fi

    pack_sdk_feeds

    gen_checksums

    popd > /dev/null || return
}

main
