#!/bin/bash

main() {
    local builder_image_tag="$1"

    local args=(
        --rm
        --platform linux/amd64
        -v $(realpath ../aspnetcore):/aspnetcore
        -v $(realpath ../runtime):/runtime
        -v $(realpath ../sdk):/sdk
        -v $(pwd):/work
        -ti
        "$builder_image_tag"
        /bin/bash
    )

    exec docker run "${args[@]}"
}

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <builder-image-tag>" >&2
    exit 1
fi

main "$@"
