#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./patch_ftnn_deb.sh <input.deb> [output.deb]

Examples:
  ./patch_ftnn_deb.sh FTNN_desktop.deb
  ./patch_ftnn_deb.sh FTNN_desktop.deb FTNN_patched.deb
EOF
}

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing required command: $cmd" >&2
        exit 1
    fi
}

replace_once() {
    local text="$1"
    local old="$2"
    local new="$3"

    if [[ "$text" != *"$old"* ]]; then
        echo "expected preinst snippet not found: $old" >&2
        exit 1
    fi

    printf '%s' "${text/"$old"/"$new"}"
}

patch_preinst() {
    local preinst="$1"
    local text
    local old
    local new

    if [[ ! -f "$preinst" ]]; then
        echo "preinst not found: $preinst" >&2
        exit 1
    fi

    if grep -q 'Non-Ubuntu system detected' "$preinst"; then
        echo "preinst already patched"
        return 0
    fi

    text="$(<"$preinst")"

    old=$'. /etc/lsb-release\n        os_version=$DISTRIB_RELEASE'
    new=$'. /etc/lsb-release\n        os_id=$(echo "${DISTRIB_ID:-unknown}" | tr \'[:upper:]\' \'[:lower:]\')\n        os_version=$DISTRIB_RELEASE'
    text="$(replace_once "$text" "$old" "$new")"

    old=$'. /etc/os-release\n        os_version=$VERSION_ID'
    new=$'. /etc/os-release\n        os_id=$(echo "${ID:-unknown}" | tr \'[:upper:]\' \'[:lower:]\')\n        os_version=$VERSION_ID'
    text="$(replace_once "$text" "$old" "$new")"

    old=$'    else\n        Log "ERROR" "Unable to determine OS version."\n        exit 1\n    fi\n'
    new=$'    else\n        Log "ERROR" "Unable to determine OS version."\n        exit 1\n    fi\n\n    os_id=${os_id:-unknown}\n    os_version=${os_version:-0}\n'
    text="$(replace_once "$text" "$old" "$new")"

    old='if [ $os_version_num -lt 1804 ]; then'
    new='if [ "$os_id" = "ubuntu" ] && [ $os_version_num -lt 1804 ]; then'
    text="$(replace_once "$text" "$old" "$new")"

    old='    Log "INFO" "OS version check passed. Current version: $os_version"'
    new=$'    if [ "$os_id" = "ubuntu" ]; then\n        Log "INFO" "OS version check passed. Current Ubuntu version: $os_version"\n    else\n        Log "INFO" "Non-Ubuntu system detected ($os_id $os_version). Skipping Ubuntu 18.04 minimum version check."\n    fi'
    text="$(replace_once "$text" "$old" "$new")"

    if [[ "$text" != *'Non-Ubuntu system detected'* ]]; then
        echo "patch verification failed" >&2
        exit 1
    fi

    printf '%s' "$text" >"$preinst"

    if ! grep -q 'Non-Ubuntu system detected' "$preinst"; then
        echo "failed to patch preinst" >&2
        exit 1
    fi
}

main() {
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        usage
        exit 1
    fi

    require_cmd dpkg-deb

    local input_deb="$1"
    local output_deb="${2:-}"
    local input_abs
    local output_abs
    local base_name
    local temp_dir=""
    local control_dir
    local data_dir
    local repack_dir

    if [[ ! -f "$input_deb" ]]; then
        echo "input .deb not found: $input_deb" >&2
        exit 1
    fi

    input_abs="$(realpath "$input_deb")"
    base_name="$(basename "$input_abs" .deb)"

    if [[ -z "$output_deb" ]]; then
        output_abs="$(dirname "$input_abs")/${base_name}_patched.deb"
    else
        mkdir -p "$(dirname "$output_deb")"
        output_abs="$(realpath -m "$output_deb")"
    fi

    temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ftnn-deb-patch.XXXXXX")"
    trap '[[ -n "${temp_dir:-}" ]] && rm -rf "$temp_dir"' EXIT

    control_dir="$temp_dir/control"
    data_dir="$temp_dir/data"
    repack_dir="$temp_dir/repack"

    mkdir -p "$control_dir" "$data_dir" "$repack_dir/DEBIAN"

    echo "Extracting control files from: $input_abs"
    dpkg-deb -e "$input_abs" "$control_dir"

    echo "Patching Ubuntu distro check in preinst"
    patch_preinst "$control_dir/preinst"

    echo "Extracting package payload"
    dpkg-deb -x "$input_abs" "$data_dir"

    cp -a "$control_dir/." "$repack_dir/DEBIAN/"
    cp -a "$data_dir/." "$repack_dir/"

    rm -f "$output_abs"
    echo "Building patched package: $output_abs"
    dpkg-deb --root-owner-group -b "$repack_dir" "$output_abs" >/dev/null

    echo "Done"
    echo "$output_abs"
}

main "$@"
