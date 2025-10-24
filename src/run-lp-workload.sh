#!/bin/bash



run_lp_workload() {
  : "${MIN_FRAMES:?MIN_FRAMES env not set}"
  local pipeline_count="$1"
  if ! [[ "$pipeline_count" =~ ^[0-9]+$ ]] || [ "$pipeline_count" -lt 1 ]; then
    echo "ERROR: pipeline count must be positive integer" >&2
    return 1
  fi

  # Purpose:
  # 1. Provision docker compose workload for pipeline_count parallel pipelines.
  # 2. Monitor logs until either enough frames collected or timeout/error.
  # 3. Tear down containers, then parse FPS lines and compute KPIs via awk_utils.
  # 4. Write KPI summary to benchmark-<N>/kpi.txt.
  #
  # Termination conditions in while loop:
  #   a) Any log shows "The server closed the connection." for all pipelines.
  #   b) Collected frame samples >= MIN_FRAMES * PIPELINE_COUNT.
  #   c) MAX_DURATION elapsed (default 300s).
  #
  # awk section:
  #   - Extract per-stream FPS snapshots.
  #   - Build arrays throughput[log_index][stream_index][sample_index].
  #   - Derive per-stream medians, min of medians, cumulative sum, and max stdev.

  export PIPELINE_COUNT="$pipeline_count"
  export RESULTS_DIR="$(pwd)"/benchmark-"$PIPELINE_COUNT"
  local results_dir="benchmark-$PIPELINE_COUNT"
  rm -rf "$results_dir"
  mkdir -p "$results_dir"

  (
    cd src || { echo "ERROR: cannot cd src" >&2; exit 1; }
    # Ensure cleanup even on early exit
    trap 'docker compose down -v --remove-orphans >/dev/null 2>&1' EXIT

    if docker compose up -d --wait; then
      local stime=$SECONDS
      local nsamples_target=$(( MIN_FRAMES * PIPELINE_COUNT ))
      while [ $(( SECONDS - stime )) -lt ${MAX_DURATION:-300} ]; do
        # If each pipeline log has a server closed message, break early
        if [ "$(grep -F 'The server closed the connection.' ../"$results_dir"/${PIPELINE_PREFIX:-gst-launch}_*.log 2>/dev/null | wc -l)" -ge "$PIPELINE_COUNT" ]; then
          echo "Detected server closed message for all pipelines; stopping." >&2
          break
        fi
        local nsamples
        nsamples=$(grep -F ', frame_num=(uint)' ../"$results_dir"/${PIPELINE_PREFIX:-gst-launch}_*.log 2>/dev/null | wc -l)
        echo "$nsamples out of $nsamples_target..." 1>&2
        [ "$nsamples" -lt "$nsamples_target" ] || break
        sleep 1
      done
    else
      echo "ERROR: docker compose up failed" >&2
    fi
    docker compose logs > ../"$results_dir"/docker-compose.logs
    # down handled by trap
  )

  # KPI extraction
  gawk -v ns="$PIPELINE_COUNT" "$awk_utils"'
    BEGIN {
      split("",files)
    }
    FNR==1 {
      if (!(FILENAME in files))
        files[FILENAME]=length(files)+1
    }
    /^FpsCounter\(last [0-9.]*sec\):/ && /, number-streams=/ && /, per-stream=/{
      ++fps_data_ct[FILENAME]
      ns=gensub(/^.*, number-streams=([0-9]*),.*$/,"\\1",1,$0)*1
      if (ns==1) {
        fps_data[files[FILENAME]][fps_data_ct[FILENAME]][1]=gensub(/^.*, per-stream=([0-9.]*).*$/,"\\1",1,$0)*1
      } else if (ns>1) {
        nf=split(gensub(/^.*, per-stream=[0-9.]* fps \(([0-9., ]*)\)/,"\\1",1,$0),fields,",")
        for (i=1;i<=ns;i++) {
          fps_data[files[FILENAME]][fps_data_ct[FILENAME]][i]=fields[i]*1
        }
      }
      if (ns>fps_streams[files[FILENAME]])
        fps_streams[files[FILENAME]]=ns
    }
    END {
      for (i=1;i<=length(files);i++) {
        j1=0
        for (j=1;j<=length(fps_data[i]);j++)
          if (length(fps_data[i][j])>=fps_streams[i]) {
            ++j1
            for (k=1;k<=fps_streams[i];k++)
              throughput[i][k][j1]=fps_data[i][j][k]
          }
      }

      ns1=0
      for (i=1;i<=length(files);i++) {
        for (k=1;k<=length(throughput[i]);k++) {
          throughput_med[i][k]=calc_median(throughput[i][k])
          if (throughput_med[i][k]>0) {
            throughput_std[i][k]=calc_stdev(throughput[i][k])
            print "throughput #"i"/"k": "throughput_med[i][k]
          }
        }
        throughput_med_min[i]=calc_min(throughput_med[i])
        throughput_med_sum[i]=calc_sum(throughput_med[i])
        throughput_std_max[i]=calc_max(throughput_std[i])
        ns1++
      }
      med=calc_median(throughput_med_min)
      print "throughput median: "med
      print "throughput average: "calc_avg(throughput_med_min)
      print "throughput cumulative: "calc_sum(throughput_med_sum)
      print "throughput stdev: "calc_max(throughput_std_max)
      mm=(ns1<0)?0:calc_min(throughput_med_min)
      print "throughput median-min: "mm
    }
  ' "$results_dir"/${PIPELINE_PREFIX:-gst-launch}_*.log > "$results_dir"/kpi.txt
}
