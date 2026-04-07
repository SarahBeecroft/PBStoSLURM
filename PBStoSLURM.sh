#!/usr/bin/env bash
# ============================================================================
# pbs2slurm — Convert PBS/Torque job scripts to Slurm (SBATCH)
#
# Designed for USYD NCI users migrating to Pawsey.
# Handles common PBS directives, module loads, and job array syntax.
#
# Usage:
#   pbs2slurm my_job.pbs                  # prints converted script to stdout
#   pbs2slurm my_job.pbs -o my_job.slurm  # writes to file
#   pbs2slurm my_job.pbs --in-place       # overwrites original (makes .pbs.bak backup)
#   pbs2slurm --cheatsheet                # print PBS ↔ Slurm quick reference
#
# Author: auto-generated helper for Pawsey onboarding
# ============================================================================

set -euo pipefail

VERSION="1.1.0"

# --- Colours (disabled if not a terminal) ---
if [[ -t 1 ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    RED='\033[0;31m'
    RESET='\033[0m'
else
    BOLD='' DIM='' GREEN='' YELLOW='' CYAN='' RED='' RESET=''
fi

# ── Cheatsheet ──────────────────────────────────────────────────────────────
print_cheatsheet() {
cat <<'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    PBS / Torque  ↔  Slurm  Quick Reference                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                            ║
║  DIRECTIVES                                                                ║
║  ──────────────────────────────────────────────────────────────────────     ║
║  #PBS -N jobname              →  #SBATCH --job-name=jobname                ║
║  #PBS -q normal               →  #SBATCH --partition=work                  ║
║  #PBS -l walltime=HH:MM:SS   →  #SBATCH --time=HH:MM:SS                  ║
║  #PBS -l ncpus=N              →  #SBATCH --ntasks=1 --cpus-per-task=N      ║
║  #PBS -l mem=XGB              →  #SBATCH --mem=XG                          ║
║  #PBS -l ngpus=N              →  #SBATCH --gres=gpu:N                      ║
║  #PBS -l jobfs=XGB            →  (use $MYSCRATCH or $MYSOFTWARE)           ║
║  #PBS -l storage=gdata/xx     →  (not needed on Pawsey)                    ║
║  #PBS -l wd                   →  (Slurm defaults to submit dir)            ║
║  #PBS -P project              →  #SBATCH --account=project                 ║
║  #PBS -o stdout.log           →  #SBATCH --output=stdout.log               ║
║  #PBS -e stderr.log           →  #SBATCH --error=stderr.log                ║
║  #PBS -j oe                   →  #SBATCH --output=combined.log             ║
║  #PBS -M user@email           →  #SBATCH --mail-user=user@email            ║
║  #PBS -m abe                  →  #SBATCH --mail-type=BEGIN,END,FAIL        ║
║  #PBS -J 1-100                →  #SBATCH --array=1-100                     ║
║  #PBS -l select=N:...         →  #SBATCH --nodes=N --ntasks-per-node=...   ║
║  #PBS -W depend=afterok:ID    →  #SBATCH --dependency=afterok:ID           ║
║                                                                            ║
║  ENVIRONMENT VARIABLES                                                     ║
║  ──────────────────────────────────────────────────────────────────────     ║
║  $PBS_JOBID                   →  $SLURM_JOB_ID                             ║
║  $PBS_JOBNAME                 →  $SLURM_JOB_NAME                           ║
║  $PBS_O_WORKDIR               →  $SLURM_SUBMIT_DIR                         ║
║  $PBS_ARRAY_INDEX             →  $SLURM_ARRAY_TASK_ID                      ║
║  $PBS_NCPUS                   →  $SLURM_CPUS_PER_TASK                      ║
║  $PBS_NGPUS                   →  $SLURM_GPUS  /  $SLURM_GPUS_ON_NODE      ║
║  $PBS_NODEFILE                →  (srun handles distribution)               ║
║  $TMPDIR / $PBS_JOBFS         →  $MYSCRATCH  (Pawsey convention)           ║
║                                                                            ║
║  COMMANDS                                                                  ║
║  ──────────────────────────────────────────────────────────────────────     ║
║  qsub script.pbs              →  sbatch script.slurm                       ║
║  qstat                        →  squeue -u $USER                           ║
║  qstat -f JOBID               →  scontrol show job JOBID                   ║
║  qdel JOBID                   →  scancel JOBID                             ║
║  qsub -I                      →  salloc  (then srun --pty bash)            ║
║  pbsnodes -a                  →  sinfo                                     ║
║  nqstat / nqstat_anu          →  squeue --start                            ║
║                                                                            ║
║  PAWSEY-SPECIFIC NOTES                                                     ║
║  ──────────────────────────────────────────────────────────────────────     ║
║  • Default partition on Setonix: "work"                                    ║
║  • No storage directives needed (unlike NCI's gdata/scratch)               ║
║  • Slurm defaults to submitting from $PWD (no need for -l wd)              ║
║  • Use $MYSCRATCH, $MYSOFTWARE, $MYGROUP for Pawsey paths                  ║
║  • Load modules the same way: module load samtools/1.19                    ║
║  • For GPU jobs on Setonix GPU nodes: --partition=gpu --gres=gpu:N         ║
║                                                                            ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

# ── Usage ───────────────────────────────────────────────────────────────────
usage() {
    echo -e "${BOLD}pbs2slurm${RESET} v${VERSION} — Convert PBS job scripts to Slurm"
    echo ""
    echo -e "  ${CYAN}Usage:${RESET}"
    echo "    pbs2slurm <script.pbs> [options]"
    echo "    pbs2slurm --cheatsheet"
    echo ""
    echo -e "  ${CYAN}Options:${RESET}"
    echo "    -o, --output FILE    Write converted script to FILE"
    echo "    --in-place           Overwrite input file (backup saved as .pbs.bak)"
    echo "    --partition NAME     Override default partition (default: work)"
    echo "    --dry-run            Show what would change without writing"
    echo "    --cheatsheet         Print PBS ↔ Slurm quick-reference table"
    echo "    -h, --help           Show this help"
    echo ""
    echo -e "  ${CYAN}Examples:${RESET}"
    echo "    pbs2slurm my_job.pbs"
    echo "    pbs2slurm my_job.pbs -o my_job.slurm"
    echo "    pbs2slurm my_job.pbs --in-place --partition=gpu"
    echo "    pbs2slurm --cheatsheet"
}

# ── Main converter ──────────────────────────────────────────────────────────
convert_pbs_to_slurm() {
    local input_file="$1"
    local default_partition="${2:-work}"

    # Track what we've seen for summary
    local -a warnings=()
    local -a conversions=()

    # We'll accumulate SBATCH lines and body lines separately
    local -a sbatch_lines=()
    local -a body_lines=()
    local shebang="#!/bin/bash"
    local found_shebang=false
    local in_select_block=false

    # ── First pass: extract PBS select resources if present ──
    # NCI often uses:  #PBS -l select=2:ncpus=48:mem=190GB:...
    local select_nodes="" select_ncpus="" select_mem="" select_mpiprocs=""
    local select_ngpus="" select_ompthreads=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^#PBS[[:space:]]+-l[[:space:]]+select= ]]; then
            local select_str="${line#*select=}"
            # Extract node count (number before first colon)
            select_nodes=$(echo "$select_str" | grep -oP '^\d+' || true)
            select_ncpus=$(echo "$select_str" | grep -oP 'ncpus=\K\d+' || true)
            select_mem=$(echo "$select_str" | grep -oP 'mem=\K[0-9]+[A-Za-z]+' || true)
            select_mpiprocs=$(echo "$select_str" | grep -oP 'mpiprocs=\K\d+' || true)
            select_ngpus=$(echo "$select_str" | grep -oP 'ngpus=\K\d+' || true)
            select_ompthreads=$(echo "$select_str" | grep -oP 'ompthreads=\K\d+' || true)
        fi
    done < "$input_file"

    # If we found a select block, generate the SBATCH equivalents
    if [[ -n "$select_nodes" ]]; then
        sbatch_lines+=("#SBATCH --nodes=${select_nodes}")
        conversions+=("select=${select_nodes}:... → --nodes=${select_nodes}")
        if [[ -n "$select_mpiprocs" ]]; then
            sbatch_lines+=("#SBATCH --ntasks-per-node=${select_mpiprocs}")
            conversions+=("mpiprocs=${select_mpiprocs} → --ntasks-per-node=${select_mpiprocs}")
        fi
        if [[ -n "$select_ncpus" && -z "$select_mpiprocs" ]]; then
            sbatch_lines+=("#SBATCH --ntasks-per-node=${select_ncpus}")
            conversions+=("ncpus=${select_ncpus} → --ntasks-per-node=${select_ncpus}")
        elif [[ -n "$select_ncpus" && -n "$select_mpiprocs" ]]; then
            # ncpus per node with mpiprocs — cpus-per-task = ncpus / mpiprocs
            local cpt=$(( select_ncpus / select_mpiprocs ))
            if (( cpt > 1 )); then
                sbatch_lines+=("#SBATCH --cpus-per-task=${cpt}")
                conversions+=("ncpus/mpiprocs → --cpus-per-task=${cpt}")
            fi
        fi
        if [[ -n "$select_mem" ]]; then
            local mem_val="${select_mem^^}"
            mem_val="${mem_val/GB/G}"
            mem_val="${mem_val/MB/M}"
            sbatch_lines+=("#SBATCH --mem=${mem_val}")
            conversions+=("mem=${select_mem} → --mem=${mem_val}")
        fi
        if [[ -n "$select_ngpus" ]]; then
            sbatch_lines+=("#SBATCH --gres=gpu:${select_ngpus}")
            conversions+=("ngpus=${select_ngpus} → --gres=gpu:${select_ngpus}")
        fi
        if [[ -n "$select_ompthreads" ]]; then
            sbatch_lines+=("export OMP_NUM_THREADS=${select_ompthreads}")
            conversions+=("ompthreads=${select_ompthreads} → OMP_NUM_THREADS=${select_ompthreads}")
        fi
        in_select_block=true
    fi

    # ── Second pass: line-by-line conversion ──
    while IFS= read -r line; do
        # Shebang
        if [[ "$line" =~ ^#! ]]; then
            shebang="$line"
            found_shebang=true
            continue
        fi

        # Skip select lines (already handled)
        if [[ "$line" =~ ^#PBS[[:space:]]+-l[[:space:]]+select= ]]; then
            continue
        fi

        # ── PBS directive conversion ──
        if [[ "$line" =~ ^#PBS ]]; then
            local directive="$line"

            # -N jobname
            if [[ "$directive" =~ -N[[:space:]]+([^[:space:]]+) ]]; then
                sbatch_lines+=("#SBATCH --job-name=${BASH_REMATCH[1]}")
                conversions+=("-N → --job-name")

            # -P project
            elif [[ "$directive" =~ -P[[:space:]]+([^[:space:]]+) ]]; then
                sbatch_lines+=("#SBATCH --account=${BASH_REMATCH[1]}")
                conversions+=("-P → --account")

            # -q queue → partition
            elif [[ "$directive" =~ -q[[:space:]]+([^[:space:]]+) ]]; then
                local queue="${BASH_REMATCH[1]}"
                local partition="$default_partition"
                case "$queue" in
                    normal|workq)    partition="work" ;;
                    express|hugemem) partition="work" ; warnings+=("Queue '${queue}' mapped to 'work' — verify this is correct for your Pawsey allocation") ;;
                    gpu*|gpuvolta)   partition="gpu" ;;
                    copyq)           partition="copy" ;;
                    *)               partition="$default_partition" ; warnings+=("Unknown queue '${queue}' mapped to '${default_partition}' — please verify") ;;
                esac
                sbatch_lines+=("#SBATCH --partition=${partition}")
                conversions+=("-q ${queue} → --partition=${partition}")

            # -l walltime
            elif [[ "$directive" =~ -l[[:space:]]+walltime=([^[:space:],]+) ]]; then
                sbatch_lines+=("#SBATCH --time=${BASH_REMATCH[1]}")
                conversions+=("walltime → --time")

            # -l ncpus (standalone, not in select)
            elif [[ "$directive" =~ -l[[:space:]]+ncpus=([0-9]+) ]] && [[ "$in_select_block" == false ]]; then
                sbatch_lines+=("#SBATCH --ntasks=1")
                sbatch_lines+=("#SBATCH --cpus-per-task=${BASH_REMATCH[1]}")
                conversions+=("ncpus → --cpus-per-task")

            # -l mem
            elif [[ "$directive" =~ -l[[:space:]]+mem=([^[:space:],]+) ]] && [[ "$in_select_block" == false ]]; then
                local mem="${BASH_REMATCH[1]}"
                mem="${mem^^}"
                mem="${mem/GB/G}"
                mem="${mem/MB/M}"
                sbatch_lines+=("#SBATCH --mem=${mem}")
                conversions+=("mem → --mem")

            # -l ngpus (standalone)
            elif [[ "$directive" =~ -l[[:space:]]+ngpus=([0-9]+) ]] && [[ "$in_select_block" == false ]]; then
                sbatch_lines+=("#SBATCH --gres=gpu:${BASH_REMATCH[1]}")
                conversions+=("ngpus → --gres=gpu")

            # -l jobfs — Pawsey doesn't have jobfs
            elif [[ "$directive" =~ -l[[:space:]]+jobfs= ]]; then
                warnings+=("jobfs not available on Pawsey — use \$MYSCRATCH or local /tmp instead")
                body_lines+=("## PBS jobfs removed — use \$MYSCRATCH on Pawsey")

            # -l storage — not needed on Pawsey
            elif [[ "$directive" =~ -l[[:space:]]+storage= ]]; then
                warnings+=("storage directive removed — not needed on Pawsey (no gdata/scratch mounts)")

            # -l wd — Slurm already defaults to submit dir
            elif [[ "$directive" =~ -l[[:space:]]+wd ]]; then
                conversions+=("-l wd → (not needed, Slurm defaults to \$PWD)")

            # -o stdout
            elif [[ "$directive" =~ -o[[:space:]]+([^[:space:]]+) ]]; then
                sbatch_lines+=("#SBATCH --output=${BASH_REMATCH[1]}")
                conversions+=("-o → --output")

            # -e stderr
            elif [[ "$directive" =~ -e[[:space:]]+([^[:space:]]+) ]]; then
                sbatch_lines+=("#SBATCH --error=${BASH_REMATCH[1]}")
                conversions+=("-e → --error")

            # -j oe (join stdout+stderr)
            elif [[ "$directive" =~ -j[[:space:]]+oe ]]; then
                sbatch_lines+=("#SBATCH --output=%x.%j.log  # stdout+stderr combined")
                conversions+=("-j oe → --output (combined)")

            # -M mail user
            elif [[ "$directive" =~ -M[[:space:]]+([^[:space:]]+) ]]; then
                sbatch_lines+=("#SBATCH --mail-user=${BASH_REMATCH[1]}")
                conversions+=("-M → --mail-user")

            # -m mail events
            elif [[ "$directive" =~ -m[[:space:]]+([^[:space:]]+) ]]; then
                local pbs_mail="${BASH_REMATCH[1]}"
                local slurm_mail=""
                [[ "$pbs_mail" == *a* ]] && slurm_mail+="FAIL,"
                [[ "$pbs_mail" == *b* ]] && slurm_mail+="BEGIN,"
                [[ "$pbs_mail" == *e* ]] && slurm_mail+="END,"
                slurm_mail="${slurm_mail%,}"  # trim trailing comma
                [[ -z "$slurm_mail" ]] && slurm_mail="NONE"
                sbatch_lines+=("#SBATCH --mail-type=${slurm_mail}")
                conversions+=("-m ${pbs_mail} → --mail-type=${slurm_mail}")

            # -J array
            elif [[ "$directive" =~ -J[[:space:]]+([^[:space:]]+) ]]; then
                sbatch_lines+=("#SBATCH --array=${BASH_REMATCH[1]}")
                conversions+=("-J → --array")

            # -W depend
            elif [[ "$directive" =~ -W[[:space:]]+depend=([^[:space:]]+) ]]; then
                sbatch_lines+=("#SBATCH --dependency=${BASH_REMATCH[1]}")
                conversions+=("-W depend → --dependency")

            # Catch-all for unrecognised directives
            else
                body_lines+=("## UNHANDLED PBS DIRECTIVE (please convert manually):")
                body_lines+=("## ${directive}")
                warnings+=("Unrecognised directive: ${directive}")
            fi

            continue
        fi

        # ── Environment variable substitution in body ──
        # Use sed to avoid bash expanding empty $PBS_* variables
        local converted
        converted=$(printf '%s' "$line" | sed \
            -e 's/\${PBS_JOBID}/\${SLURM_JOB_ID}/g' \
            -e 's/\$PBS_JOBID/\$SLURM_JOB_ID/g' \
            -e 's/\${PBS_JOBNAME}/\${SLURM_JOB_NAME}/g' \
            -e 's/\$PBS_JOBNAME/\$SLURM_JOB_NAME/g' \
            -e 's/\${PBS_O_WORKDIR}/\${SLURM_SUBMIT_DIR}/g' \
            -e 's/\$PBS_O_WORKDIR/\$SLURM_SUBMIT_DIR/g' \
            -e 's/\${PBS_ARRAY_INDEX}/\${SLURM_ARRAY_TASK_ID}/g' \
            -e 's/\$PBS_ARRAY_INDEX/\$SLURM_ARRAY_TASK_ID/g' \
            -e 's/\${PBS_NCPUS}/\${SLURM_CPUS_PER_TASK}/g' \
            -e 's/\$PBS_NCPUS/\$SLURM_CPUS_PER_TASK/g' \
            -e 's/\${PBS_NGPUS}/\${SLURM_GPUS_ON_NODE}/g' \
            -e 's/\$PBS_NGPUS/\$SLURM_GPUS_ON_NODE/g' \
            -e 's/\${PBS_NODEFILE}/\${SLURM_JOB_NODELIST}/g' \
            -e 's/\$PBS_NODEFILE/\$SLURM_JOB_NODELIST/g' \
            -e 's/\${TMPDIR}/\${MYSCRATCH}/g' \
            -e 's/\$TMPDIR/\$MYSCRATCH/g' \
            -e 's/\${PBS_JOBFS}/\${MYSCRATCH}/g' \
            -e 's/\$PBS_JOBFS/\$MYSCRATCH/g' \
        )

        # Replace cd $PBS_O_WORKDIR (unnecessary in Slurm but harmless)
        if [[ "$converted" =~ ^[[:space:]]*cd[[:space:]]+\$SLURM_SUBMIT_DIR ]]; then
            body_lines+=("## cd \$SLURM_SUBMIT_DIR  # not needed — Slurm starts in submit directory")
            continue
        fi

        body_lines+=("$converted")

    done < "$input_file"

    # ── Assemble output ──
    echo "$shebang"
    echo "# ── Converted from PBS by pbs2slurm v${VERSION} ──"
    echo "# Original file: $(basename "$input_file")"
    echo "# Converted on:  $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Print SBATCH lines
    for sl in "${sbatch_lines[@]}"; do
        echo "$sl"
    done
    echo ""

    # Print body
    for bl in "${body_lines[@]}"; do
        echo "$bl"
    done

    # ── Print warnings to stderr ──
    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo "" >&2
        echo -e "${YELLOW}${BOLD}⚠  Conversion warnings:${RESET}" >&2
        for w in "${warnings[@]}"; do
            echo -e "  ${YELLOW}•${RESET} $w" >&2
        done
    fi

    # Print conversion summary to stderr
    if [[ ${#conversions[@]} -gt 0 ]]; then
        echo "" >&2
        echo -e "${GREEN}${BOLD}✓  Converted ${#conversions[@]} directives:${RESET}" >&2
        for c in "${conversions[@]}"; do
            echo -e "  ${DIM}${c}${RESET}" >&2
        done
    fi

    echo "" >&2
    echo -e "${CYAN}Tip:${RESET} Review the output and check partition/account settings for your Pawsey project." >&2
}

# ── Argument parsing ────────────────────────────────────────────────────────
INPUT_FILE=""
OUTPUT_FILE=""
IN_PLACE=false
DRY_RUN=false
PARTITION="work"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cheatsheet)
            print_cheatsheet
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --in-place)
            IN_PLACE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --partition|--partition=*)
            if [[ "$1" == *=* ]]; then
                PARTITION="${1#*=}"
                shift
            else
                PARTITION="$2"
                shift 2
            fi
            ;;
        -*)
            echo -e "${RED}Error:${RESET} Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            INPUT_FILE="$1"
            shift
            ;;
    esac
done

# ── Validate ────────────────────────────────────────────────────────────────
if [[ -z "$INPUT_FILE" ]]; then
    usage
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "${RED}Error:${RESET} File not found: ${INPUT_FILE}" >&2
    exit 1
fi

# Check it looks like a PBS script
if ! grep -q '#PBS' "$INPUT_FILE"; then
    echo -e "${YELLOW}Warning:${RESET} No #PBS directives found in ${INPUT_FILE}. Is this a PBS script?" >&2
fi

# ── Run conversion ──────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${CYAN}${BOLD}── Dry run: converted output ──${RESET}"
    convert_pbs_to_slurm "$INPUT_FILE" "$PARTITION"
elif [[ "$IN_PLACE" == true ]]; then
    cp "$INPUT_FILE" "${INPUT_FILE}.bak"
    convert_pbs_to_slurm "$INPUT_FILE" "$PARTITION" > "${INPUT_FILE}.tmp"
    mv "${INPUT_FILE}.tmp" "$INPUT_FILE"
    echo -e "${GREEN}✓${RESET} Converted in-place. Backup saved as ${INPUT_FILE}.bak" >&2
elif [[ -n "$OUTPUT_FILE" ]]; then
    convert_pbs_to_slurm "$INPUT_FILE" "$PARTITION" > "$OUTPUT_FILE"
    chmod +x "$OUTPUT_FILE"
    echo -e "${GREEN}✓${RESET} Written to ${OUTPUT_FILE}" >&2
else
    convert_pbs_to_slurm "$INPUT_FILE" "$PARTITION"
fi