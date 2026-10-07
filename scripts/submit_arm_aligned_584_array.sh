#!/usr/bin/env bash
set -u

# Submit the 584-function ARM-aligned DCU run as independent DCU tasks.
ROOT="${ROOT:-/public/home/acmcs42wxa/yyb}"
INVENTORY="${INVENTORY:-$ROOT/itk_port_baseline_584/manifests/benchmark_inventory.tsv}"
MANIFEST="${MANIFEST:-$ROOT/manifests/itk_arm_aligned_584.tsv}"
RESULT_ROOT="${RESULT_ROOT:-$ROOT/results/arm_aligned_584_$(date +%Y%m%d_%H%M%S)}"
CHUNKS="${CHUNKS:-8}"
ACCOUNT="${ACCOUNT:-acmcs42wxa}"
PARTITION="${PARTITION:-hx1hdnormal}"
TIME_LIMIT="${TIME_LIMIT:-24:00:00}"
RUNNER="${RUNNER:-$ROOT/scripts/run_arm_aligned_584.sh}"

mkdir -p "$RESULT_ROOT/inventory"
cp "$MANIFEST" "$RESULT_ROOT/itk_arm_aligned_584.tsv"
printf 'result_root\t%s\nchunks\t%s\ninventory\t%s\n' \
  "$RESULT_ROOT" "$CHUNKS" "$INVENTORY" > "$RESULT_ROOT/submission.tsv"

job_ids=""
for chunk_index in $(seq 0 $((CHUNKS - 1))); do
  chunk="$RESULT_ROOT/inventory/chunk_$(printf '%02d' "$chunk_index").tsv"
  awk -v chunk_index="$chunk_index" -v chunks="$CHUNKS" \
    'NR == 1 || ((NR - 2) % chunks) == chunk_index { print }' \
    "$INVENTORY" > "$chunk"
  chunk_rows=$(($(wc -l < "$chunk") - 1))
  if [[ "$chunk_rows" -eq 0 ]]; then
    continue
  fi
  chunk_result="$RESULT_ROOT/chunk_$(printf '%02d' "$chunk_index")"
  job_id=$(sbatch --parsable \
    -A "$ACCOUNT" -p "$PARTITION" --gres=dcu:1 \
    -N 1 -n 1 -c 4 -t "$TIME_LIMIT" \
    -J "itk-arm584-$chunk_index" \
    -o "$RESULT_ROOT/slurm-%A.out" \
    --export=ALL,ROOT="$ROOT",INVENTORY="$chunk",RESULT_ROOT="$chunk_result" \
    "$RUNNER")
  printf '%s\t%s\t%s\t%s\n' "$chunk_index" "$job_id" "$chunk_rows" "$chunk_result" \
    >> "$RESULT_ROOT/submitted_jobs.tsv"
  job_ids="$job_ids $job_id"
done

echo "RESULT_ROOT=$RESULT_ROOT"
echo "JOB_IDS=$job_ids"
