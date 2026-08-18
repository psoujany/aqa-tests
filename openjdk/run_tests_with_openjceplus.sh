#!/bin/sh
# =============================================================================
# run_tests_with_openjceplus.sh  (z/OS POSIX sh edition)
#
# For each Java test file (from a .txt list or supplied inline via -f):
#   1. Scan for Sun security provider string literals.
#   2. Replace them with "OpenJCEPlus".
#   3. Run the test sequentially with jtreg.
#   4. Restore the original file unconditionally (pass or fail).
#
# Usage:
#   ./openjdk/run_tests_with_openjceplus.sh [OPTIONS]
#
# Options:
#   -t <path>   Path to a .txt file whose first column contains test paths
#               (one per non-comment line).  Lines starting with '#' or blank
#               lines are skipped.
#               Format per line:
#                 <test/path/File.java> [<url> <platform>]
#   -f <paths>  Comma-separated list of test file paths
#               (relative to OPENJDK_DIR/test/jdk).
#               Used alone or combined with -t.
#   -j <path>   Path to the jtreg jar or binary  [auto-detect]
#   -d <path>   Path to the JDK under test        [auto-detect via JAVA_HOME]
#   -o <path>   Root of the openjdk-jdk source tree
#               [required: must contain test/jdk or jdk/test]
#   -r <path>   Directory to write JTR results
#               [default: /tmp/jtreg_results]
#   -h          Show this help and exit
#
# Sun -> OpenJCEPlus provider mapping (string literal replacements):
#   "SunJCE"     -> "OpenJCEPlus"
#   "SunJSSE"    -> "OpenJCEPlus"
#   "SunRsaSign" -> "OpenJCEPlus"
#   "SunEC"      -> "OpenJCEPlus"
#   "SUN"        -> "OpenJCEPlus"   (exact string literal)
#
# Exit codes:
#   0  All tests passed
#   1  One or more tests failed (originals already restored)
#   2  Script invocation error
#
# z/OS notes:
#   - Written for /bin/sh (ksh88-based) on z/OS; no bash extensions used.
#   - No ANSI colour codes (z/OS terminals may not support them).
#   - In-place sed uses a temp-file strategy (no sed -i).
#   - pipefail is not used; errors are checked explicitly.
#   - Arrays are simulated with index variables where needed.
# =============================================================================

set -eu

# ── logging helpers (plain, no ANSI — safe on z/OS) ──────────────────────────
info()    { echo "[INFO]  $*"; }
ok()      { echo "[PASS]  $*"; }
warn()    { echo "[WARN]  $*"; }
err()     { echo "[FAIL]  $*" >&2; }
section() { echo ""; echo "----------------------------------------"; echo " $*"; echo "----------------------------------------"; }

# ── defaults ──────────────────────────────────────────────────────────────────
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

FILES_INPUT=""
TXT_FILE=""
JTREG_JAR=""
JDK_HOME="${JAVA_HOME:-}"
OPENJDK_DIR=""
RESULTS_DIR="/tmp/jtreg_results"

# ── argument parsing (POSIX getopts) ──────────────────────────────────────────
usage() {
    sed -n 's/^# \{0,1\}//p' "$0" | sed -n '/^=====/,/^=====/p' | grep -v '^=====' 
    exit 0
}

while getopts "t:f:j:d:o:r:h" opt; do
    case "${opt}" in
        t) TXT_FILE="${OPTARG}" ;;
        f) FILES_INPUT="${OPTARG}" ;;
        j) JTREG_JAR="${OPTARG}" ;;
        d) JDK_HOME="${OPTARG}" ;;
        o) OPENJDK_DIR="${OPTARG}" ;;
        r) RESULTS_DIR="${OPTARG}" ;;
        h) usage ;;
        *) err "Unknown option: -${OPTARG}"; exit 2 ;;
    esac
done

if [ -z "${FILES_INPUT}" ] && [ -z "${TXT_FILE}" ]; then
    err "No test files specified. Use -t tests.txt and/or -f file1.java,file2.java"
    exit 2
fi

# ── load test names from .txt file ────────────────────────────────────────────
# The .txt format (ProblemList style) has one test per line:
#   <test/path/File.java>  <issue-url>  <platform>
# Lines beginning with '#' or empty lines are ignored.
# Only the first whitespace-delimited token (the test path) is used.
if [ -n "${TXT_FILE}" ]; then
    if [ ! -f "${TXT_FILE}" ]; then
        err "txt file not found: ${TXT_FILE}"
        exit 2
    fi
    info "Reading test names from: ${TXT_FILE}"
    while IFS= read -r line || [ -n "${line}" ]; do
        # Skip blank lines and comments
        case "${line}" in
            ''|'#'*) continue ;;
        esac
        # Also skip lines that are only whitespace
        stripped=$(echo "${line}" | sed 's/^[[:space:]]*//')
        case "${stripped}" in
            ''|'#'*) continue ;;
        esac
        # Extract the first token (test path)
        token=$(echo "${line}" | awk '{print $1}')
        [ -z "${token}" ] && continue
        # Append to FILES_INPUT (comma-separated)
        if [ -z "${FILES_INPUT}" ]; then
            FILES_INPUT="${token}"
        else
            FILES_INPUT="${FILES_INPUT},${token}"
        fi
    done < "${TXT_FILE}"
    count=$(echo "${FILES_INPUT}" | tr ',' '\n' | wc -l | tr -d ' ')
    info "Loaded ${count} test(s) from txt file."
fi

# ── auto-detect JDK ───────────────────────────────────────────────────────────
if [ -z "${JDK_HOME}" ]; then
    _java=$(command -v java 2>/dev/null) || true
    if [ -n "${_java}" ]; then
        JDK_HOME=$(cd "$(dirname "${_java}")/.." && pwd)
    fi
fi

if [ -z "${JDK_HOME}" ] || [ ! -x "${JDK_HOME}/bin/java" ]; then
    err "JDK not found. Set JAVA_HOME or use -d /path/to/jdk."
    exit 2
fi

mkdir -p "${RESULTS_DIR}"

# ── portable in-place sed via temp file ───────────────────────────────────────
# z/OS sed does not support -i in all versions; use a temp file instead.
sed_inplace() {
    _expr="$1"
    _file="$2"
    _tmp="${_file}.sedtmp.$$"
    sed "${_expr}" "${_file}" > "${_tmp}" && mv "${_tmp}" "${_file}"
}

# ── helper: replace Sun providers in one file ─────────────────────────────────
# Provider mappings encoded as "PATTERN|REPLACEMENT" pairs.
# Returns 0 if at least one replacement was made, 1 otherwise.
replace_providers() {
    _rpfile="$1"
    _changed=0

    for _mapping in \
        '"SunJSSE"|"OpenJCEPlus"' \
        '"SunRsaSign"|"OpenJCEPlus"' \
        '"SunEC"|"OpenJCEPlus"' \
        '"SunJCE"|"OpenJCEPlus"' \
        '"SUN"|"OpenJCEPlus"'
    do
        _pat=$(echo "${_mapping}" | cut -d'|' -f1)
        _rep=$(echo "${_mapping}" | cut -d'|' -f2)
        if grep -qF "${_pat}" "${_rpfile}"; then
            # Backup before the very first modification
            if [ "${_changed}" -eq 0 ]; then
                cp "${_rpfile}" "${_rpfile}.bak"
            fi
            # Escape for sed: replace / with \/ in both pattern and replacement
            _pat_esc=$(echo "${_pat}" | sed 's/[\/&]/\\&/g')
            _rep_esc=$(echo "${_rep}" | sed 's/[\/&]/\\&/g')
            sed_inplace "s/${_pat_esc}/${_rep_esc}/g" "${_rpfile}"
            info "  Replaced ${_pat} -> ${_rep}"
            _changed=1
        fi
    done

    return $((1 - _changed))   # 0 = at least one change made
}

# ── helper: restore original file ─────────────────────────────────────────────
restore_file() {
    _rf="$1"
    if [ -f "${_rf}.bak" ]; then
        mv "${_rf}.bak" "${_rf}"
        info "  Restored: ${_rf}"
    fi
}

# ── split comma-separated file list into positional parameters ────────────────
# POSIX sh has no arrays; we iterate by splitting on commas via IFS.
overall_exit=0
passed_count=0
failed_count=0
passed_list=""
failed_list=""

# Count total for banner
total=$(echo "${FILES_INPUT}" | tr ',' '\n' | wc -l | tr -d ' ')
section "Starting sequential test run  (${total} file(s))"
info "jtreg   : ${JTREG_JAR}"
info "JDK     : ${JDK_HOME}"
info "TestBase: ${OPENJDK_DIR}"
info "Results : ${RESULTS_DIR}"

# Iterate over comma-separated list
_IFS_SAVE="${IFS}"
IFS=','
for rel_path in ${FILES_INPUT}; do
    IFS="${_IFS_SAVE}"

    # Trim whitespace
    rel_path=$(echo "${rel_path}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    full_path="${OPENJDK_DIR}/${rel_path}"

    section "Processing: ${rel_path}"

    # ── 1. Validate file exists ───────────────────────────────────────────────
    if [ ! -f "${full_path}" ]; then
        err "File not found: ${full_path}"
        failed_list="${failed_list}${rel_path} [file not found]
"
        failed_count=$((failed_count + 1))
        overall_exit=1
        IFS=','
        continue
    fi

    # ── 2. Check for Sun providers ────────────────────────────────────────────
    info "Scanning for Sun provider references..."
    # Use fixed-string grep for each known pattern; collect hits
    sun_hits=""
    for _p in '"SunJCE"' '"SunJSSE"' '"SunRsaSign"' '"SunEC"' '"SUN"'; do
        _h=$(grep -nF "${_p}" "${full_path}" 2>/dev/null) || true
        if [ -n "${_h}" ]; then
            sun_hits="${sun_hits}${_h}
"
        fi
    done

    modified=false
    if [ -z "${sun_hits}" ]; then
        warn "No Sun provider references found -- running test unmodified."
    else
        info "Found Sun provider references:"
        echo "${sun_hits}" | while IFS= read -r _line; do
            [ -n "${_line}" ] && info "  ${_line}"
        done

        # ── 3. Apply replacements ─────────────────────────────────────────────
        info "Applying provider substitutions..."
        if replace_providers "${full_path}"; then
            modified=true
            info "Substitutions applied successfully."
        else
            warn "No substitutions made (unexpected grep/sed mismatch)."
        fi
    fi

    # ── 4. Run the test ───────────────────────────────────────────────────────
    _testname=$(basename "${rel_path}" .java)
    test_results_dir="${RESULTS_DIR}/${_testname}"
    mkdir -p "${test_results_dir}"

    info "Running test with jtreg..."
    set +e
    "${JDK_HOME}/bin/java" \
        -jar ${JTREG_JAR} \
        -agentvm \
        -jdk:"${JDK_HOME}" \
        -w:"${test_results_dir}/work" \
        -r:"${test_results_dir}/report" \
        -v:fail,error,time \
        "${full_path}"
    jtreg_exit=$?
    set -e

    # ── 5. Restore original ───────────────────────────────────────────────────
    if [ "${modified}" = "true" ]; then
        info "Restoring original file..."
        restore_file "${full_path}"
    fi

    # ── 6. Record result ──────────────────────────────────────────────────────
    if [ "${jtreg_exit}" -eq 0 ]; then
        ok "PASSED: ${rel_path}"
        passed_list="${passed_list}  ${rel_path}
"
        passed_count=$((passed_count + 1))
    else
        err "FAILED: ${rel_path}  (jtreg exit ${jtreg_exit})"
        failed_list="${failed_list}  ${rel_path}
"
        failed_count=$((failed_count + 1))
        overall_exit=1
    fi

    IFS=','
done
IFS="${_IFS_SAVE}"

# ── final summary ──────────────────────────────────────────────────────────────
section "Test Summary"
echo "  Passed : ${passed_count}"
if [ -n "${passed_list}" ]; then
    echo "${passed_list}" | while IFS= read -r _t; do
        [ -n "${_t}" ] && echo "    [PASS] ${_t}"
    done
fi

echo "  Failed : ${failed_count}"
if [ -n "${failed_list}" ]; then
    echo "${failed_list}" | while IFS= read -r _t; do
        [ -n "${_t}" ] && echo "    [FAIL] ${_t}"
    done
fi

echo "  Results written to: ${RESULTS_DIR}"

if [ "${overall_exit}" -ne 0 ]; then
    err "One or more tests failed. All source files have been restored."
fi

exit ${overall_exit}
