#!/usr/bin/env bash
# =============================================================================
# run_tests_with_openjceplus.sh
#
# For each Java test file (from a .txt list or supplied inline via -f):
#   1. Scan for Sun security provider string literals.
#   2. Replace them with "OpenJCEPlus".
#   3. Run the test sequentially with jtreg.
#   4. Restore the original file unconditionally (pass or fail).
#
# Usage:
#   ./scripts/run_tests_with_openjceplus.sh [OPTIONS]
#
# Options:
#   -t, --txt     <path>             Path to a .txt file whose first column
#                                    contains test paths (one per non-comment
#                                    line).  Lines starting with '#' or blank
#                                    lines are skipped.
#                                    Format per line:
#                                      <test/path/File.java> [<url> <platform>]
#   -f, --files   <file1,file2,...>  Comma-separated list of test file paths
#                                    (relative to OPENJDK_DIR/test/jdk).
#                                    Used alone or combined with -t.
#   -j, --jtreg   <path>             Path to the jtreg binary  [auto-detect]
#   -d, --jdk     <path>             Path to the JDK under test [auto-detect]
#   -o, --openjdk <path>             Root of the openjdk-jdk source tree
#                                    [default: openjdk/openjdk-jdk]
#   -r, --results <path>             Directory to write JTR results
#                                    [default: /tmp/jtreg_results]
#   -h, --help                       Show this help and exit
#
# Sun → OpenJCEPlus provider mapping (string literal replacements):
#   "SunJCE"     → "OpenJCEPlus"
#   "SunJSSE"    → "OpenJCEPlus"
#   "SunRsaSign" → "OpenJCEPlus"
#   "SunEC"      → "OpenJCEPlus"
#   "SUN"        → "OpenJCEPlus"   (exact string literal, not a word boundary)
#
# Exit codes:
#   0  All tests passed
#   1  One or more tests failed (originals already restored)
#   2  Script invocation error
# =============================================================================

set -euo pipefail

# ── colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[PASS]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()     { echo -e "${RED}[FAIL]${RESET}  $*" >&2; }
section() { echo -e "\n${BOLD}────────────────────────────────────────${RESET}"; \
            echo -e "${BOLD} $*${RESET}"; \
            echo -e "${BOLD}────────────────────────────────────────${RESET}"; }

# ── defaults ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FILES_INPUT=""
TXT_FILE=""
JTREG_BIN=""
JDK_HOME="${JAVA_HOME:-}"
OPENJDK_DIR="${REPO_ROOT}/openjdk/openjdk-jdk"
RESULTS_DIR="/tmp/jtreg_results"

# Sun provider → OpenJCEPlus mapping
# Each entry: "PATTERN@REPLACEMENT" — both include the surrounding double-quotes
# so that only exact provider-name string literals are replaced.
declare -a PROVIDER_MAPPINGS=(
    '"SunJSSE"@"OpenJCEPlus"'
    '"SunRsaSign"@"OpenJCEPlus"'
    '"SunEC"@"OpenJCEPlus"'
    '"SunJCE"@"OpenJCEPlus"'
    '"SUN"@"OpenJCEPlus"'
)

# ── argument parsing ──────────────────────────────────────────────────────────
usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \?//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--txt)     TXT_FILE="$2";      shift 2 ;;
        -f|--files)   FILES_INPUT="$2";   shift 2 ;;
        -j|--jtreg)   JTREG_BIN="$2";    shift 2 ;;
        -d|--jdk)     JDK_HOME="$2";      shift 2 ;;
        -o|--openjdk) OPENJDK_DIR="$2";   shift 2 ;;
        -r|--results) RESULTS_DIR="$2";   shift 2 ;;
        -h|--help)    usage ;;
        *) err "Unknown option: $1"; exit 2 ;;
    esac
done

if [[ -z "${FILES_INPUT}" && -z "${TXT_FILE}" ]]; then
    err "No test files specified. Use -t tests.txt and/or -f file1.java,file2.java"
    exit 2
fi

# ── load test names from .txt file ───────────────────────────────────────────
# The .txt format (ProblemList style) has one test per line:
#   <test/path/File.java>  <issue-url>  <platform>
# Lines beginning with '#' or empty lines are ignored.
# Only the first whitespace-delimited token (the test path) is used.
if [[ -n "${TXT_FILE}" ]]; then
    if [[ ! -f "${TXT_FILE}" ]]; then
        err "txt file not found: ${TXT_FILE}"
        exit 2
    fi
    info "Reading test names from: ${TXT_FILE}"
    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip blank lines and comments
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
        # Extract the first token (test path)
        token=$(awk '{print $1}' <<< "${line}")
        [[ -z "${token}" ]] && continue
        # Append to FILES_INPUT (comma-separated)
        if [[ -z "${FILES_INPUT}" ]]; then
            FILES_INPUT="${token}"
        else
            FILES_INPUT="${FILES_INPUT},${token}"
        fi
    done < "${TXT_FILE}"
    info "Loaded $(echo "${FILES_INPUT}" | tr ',' '\n' | wc -l | tr -d ' ') test(s) from txt file."
fi

# ── auto-detect jtreg ─────────────────────────────────────────────────────────
if [[ -z "${JTREG_BIN}" ]]; then
    # Common locations used in this project
    for candidate in \
        "${REPO_ROOT}/TKG/tools/jtreg/bin/jtreg" \
        "${HOME}/jtreg/bin/jtreg" \
        "$(command -v jtreg 2>/dev/null || true)"; do
        if [[ -x "${candidate}" ]]; then
            JTREG_BIN="${candidate}"
            break
        fi
    done
fi

if [[ -z "${JTREG_BIN}" || ! -x "${JTREG_BIN}" ]]; then
    err "jtreg not found. Use -j /path/to/jtreg or add it to PATH."
    exit 2
fi

# ── auto-detect JDK ──────────────────────────────────────────────────────────
if [[ -z "${JDK_HOME}" ]]; then
    JDK_HOME="$(dirname "$(dirname "$(command -v java)")")"
fi

if [[ -z "${JDK_HOME}" || ! -x "${JDK_HOME}/bin/java" ]]; then
    err "JDK not found. Set JAVA_HOME or use -d /path/to/jdk."
    exit 2
fi

# ── resolve test directory ────────────────────────────────────────────────────
JDK_VERSION=$("${JDK_HOME}/bin/java" -version 2>&1 | awk -F '"' '/version/{print $2}' | cut -d. -f1)
if [[ "${JDK_VERSION}" == "1" ]]; then
    TEST_BASE="${OPENJDK_DIR}/jdk/test"
else
    TEST_BASE="${OPENJDK_DIR}/test/jdk"
fi

# ── split file list ───────────────────────────────────────────────────────────
IFS=',' read -ra TEST_FILES <<< "${FILES_INPUT}"

# ── tracking arrays ───────────────────────────────────────────────────────────
declare -a PASSED=()
declare -a FAILED=()
declare -a MODIFIED_FILES=()

mkdir -p "${RESULTS_DIR}"

# ── portable in-place sed (handles both GNU and BSD/macOS sed) ────────────────
sed_inplace() {
    local expr="$1" file="$2"
    if sed --version 2>/dev/null | grep -q GNU; then
        sed -i "${expr}" "${file}"
    else
        sed -i '' "${expr}" "${file}"
    fi
}

# ── helper: replace Sun providers in one file ─────────────────────────────────
replace_providers() {
    local file="$1"
    local changed=0

    for mapping in "${PROVIDER_MAPPINGS[@]}"; do
        local pattern="${mapping%%@*}"
        local replacement="${mapping##*@}"
        if grep -qF "${pattern}" "${file}"; then
            # Take the backup only once — before the very first modification.
            if [[ ${changed} -eq 0 ]]; then
                cp "${file}" "${file}.bak"
            fi
            sed_inplace "s/${pattern}/${replacement}/g" "${file}"
            info "  Replaced ${pattern} → ${replacement}"
            changed=1
        fi
    done

    return $((1 - changed))   # returns 0 if at least one change was made
}

# ── helper: restore original file ────────────────────────────────────────────
restore_file() {
    local file="$1"
    if [[ -f "${file}.bak" ]]; then
        mv "${file}.bak" "${file}"
        info "  Restored: ${file}"
    fi
}

# ── main loop ─────────────────────────────────────────────────────────────────
section "Starting sequential test run  (${#TEST_FILES[@]} file(s))"
info "jtreg   : ${JTREG_BIN}"
info "JDK     : ${JDK_HOME}"
info "TestBase: ${TEST_BASE}"
info "Results : ${RESULTS_DIR}"

overall_exit=0

for rel_path in "${TEST_FILES[@]}"; do
    rel_path="${rel_path// /}"          # trim whitespace
    full_path="${TEST_BASE}/${rel_path}"

    section "Processing: ${rel_path}"

    # ── 1. Validate file exists ───────────────────────────────────────────────
    if [[ ! -f "${full_path}" ]]; then
        err "File not found: ${full_path}"
        FAILED+=("${rel_path} [file not found]")
        overall_exit=1
        continue
    fi

    # ── 2. Check for Sun providers ───────────────────────────────────────────
    info "Scanning for Sun provider references..."
    sun_hits=$(grep -nE '"SunJCE"|"SunJSSE"|"SunRsaSign"|"SunEC"|(\bSUN\b)' "${full_path}" || true)

    if [[ -z "${sun_hits}" ]]; then
        warn "No Sun provider references found — running test unmodified."
        modified=false
    else
        info "Found Sun provider references:"
        while IFS= read -r line; do
            info "  ${line}"
        done <<< "${sun_hits}"

        # ── 3. Apply replacements ─────────────────────────────────────────────
        info "Applying provider substitutions..."
        if replace_providers "${full_path}"; then
            modified=true
            MODIFIED_FILES+=("${full_path}")
            info "Substitutions applied successfully."
        else
            warn "No substitutions made (unexpected grep/sed mismatch)."
            modified=false
        fi
    fi

    # ── 4. Run the test ───────────────────────────────────────────────────────
    test_results_dir="${RESULTS_DIR}/$(basename "${rel_path}" .java)"
    mkdir -p "${test_results_dir}"

    info "Running test with jtreg..."
    set +e
    "${JTREG_BIN}" \
        -jdk:"${JDK_HOME}" \
        -w:"${test_results_dir}/work" \
        -r:"${test_results_dir}/report" \
        -v:fail,error,time \
        -agentvm \
        "${full_path}"
    jtreg_exit=$?
    set -e

    # ── 5. Restore original ───────────────────────────────────────────────────
    if [[ "${modified}" == "true" ]]; then
        info "Restoring original file..."
        restore_file "${full_path}"
    fi

    # ── 6. Record result ──────────────────────────────────────────────────────
    if [[ ${jtreg_exit} -eq 0 ]]; then
        ok "PASSED: ${rel_path}"
        PASSED+=("${rel_path}")
    else
        err "FAILED: ${rel_path}  (jtreg exit ${jtreg_exit})"
        FAILED+=("${rel_path}")
        overall_exit=1
    fi
done

# ── final summary ─────────────────────────────────────────────────────────────
section "Test Summary"
echo -e "  ${GREEN}Passed : ${#PASSED[@]}${RESET}"
for t in "${PASSED[@]}"; do echo -e "    ${GREEN}✔${RESET} ${t}"; done

echo -e "  ${RED}Failed : ${#FAILED[@]}${RESET}"
for t in "${FAILED[@]}"; do echo -e "    ${RED}✘${RESET} ${t}"; done

echo -e "  Results written to: ${RESULTS_DIR}"

if [[ ${overall_exit} -ne 0 ]]; then
    err "One or more tests failed. All source files have been restored."
fi

exit ${overall_exit}
