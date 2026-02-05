FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

RUN apt-get update && apt-get install -y build-essential git coreutils sed && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/NVIDIA/cuda-samples.git /opt/cuda-samples
RUN SAMPLE_PATH=$(find /opt/cuda-samples -name p2pBandwidthLatencyTest -type d | head -n 1) && \
    COMMON_PATH=$(find /opt/cuda-samples -name Common -type d | head -n 1) && \
    nvcc -I"$SAMPLE_PATH" -I"$COMMON_PATH" "$SAMPLE_PATH"/*.cu -o /usr/local/bin/p2p_bench -arch=sm_86 -O3

ENV DURATION_MIN=1

RUN printf '#!/bin/bash\n# 1. GPU Identification\nGPU_RAW_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits)\nGPU_NAME=$(echo "$GPU_RAW_NAME" | sed "s/[^[:alnum:]]/_/g" | sed "s/__*/_/g")\n\n# 2. Setup paths and logic\nTOTAL_SECONDS=$(( DURATION_MIN * 60 ))\nTEMP_OUT="/tmp/stress_test_running.csv"\nTIMESTAMP=$(date +%%Y%%m%%d_%%H%%M%%S)\nFINAL_FILENAME="p2p_${GPU_NAME}_${TIMESTAMP}.csv"\n\n# CSV Header with Clocks\necho "timestamp,vram_bw_gb_s,temp_c,power_w,gpu_clk_mhz,mem_clk_mhz" > "$TEMP_OUT"\n\nEND_TIME=$(( $(date +%%s) + TOTAL_SECONDS ))\necho "[INFO] Starting Diagnostic Stress Test (${DURATION_MIN} min)..."\n\nwhile [ $(date +%%s) -lt $END_TIME ]; do\n    # Bandwidth extraction\n    RAW_DATA=$(/usr/local/bin/p2p_bench | grep -A 2 "Bidirectional P2P=Enabled" | grep "^[[:space:]]*0")\n    BW=$(echo "$RAW_DATA" | awk "{print \$2}" | sed "s/[^0-9.]//g")\n    \n    # Extended Telemetry: Temp, Power, Graphics Clock, Memory Clock\n    STATS=$(nvidia-smi --query-gpu=temperature.gpu,power.draw,clocks.current.graphics,clocks.current.memory --format=csv,noheader,nounits | sed "s/[^0-9.,]//g")\n    T=$(echo $STATS | cut -d, -f1)\n    P=$(echo $STATS | cut -d, -f2)\n    GC=$(echo $STATS | cut -d, -f3)\n    MC=$(echo $STATS | cut -d, -f4)\n    TS=$(date +%%H:%%M:%%S)\n    \n    if [[ ! -z "$BW" && "$BW" != "." ]]; then\n        CSV_LINE="$TS,$BW,$T,$P,$GC,$MC"\n        echo "$CSV_LINE" >> "$TEMP_OUT"\n        sync "$TEMP_OUT"\n        echo "[$TS] BW: $BW GB/s | Temp: $T C | Pwr: $P W | Clk: $GC/$MC MHz"\n    fi\n    sleep 1\ndone\n\n# 3. Finalize\nmv "$TEMP_OUT" "/var/log/$FINAL_FILENAME"\necho "[SUCCESS] Saved: /home/cards/test_gpu_new/gpu_workbench/logs/$FINAL_FILENAME"' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
