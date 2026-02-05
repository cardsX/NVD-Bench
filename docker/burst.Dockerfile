FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Install system dependencies
RUN apt-get update && apt-get install -y wget unzip && rm -rf /var/lib/apt/lists/*

# Build GPU-Burn using the WORKDIR
WORKDIR /opt/gpu-burn
RUN wget https://github.com/wilicc/gpu-burn/archive/refs/heads/master.zip && \
    unzip master.zip && mv gpu-burn-master/* . && \
    make && rm master.zip

# Environment Variables
ENV DURATION_MIN=1
ENV MAX_TEMP_LIMIT=85

# Entrypoint for Monitoring & Stress Test 
RUN printf '#!/bin/bash\nGPU_RAW_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits)\nGPU_SAFE_NAME=$(echo "$GPU_RAW_NAME" | sed "s/[^[:alnum:]]/_/g")\nTIMESTAMP=$(date +%%Y%%m%%d_%%H%%M%%S)\nFINAL_LOG="/var/log/burst_${GPU_SAFE_NAME}_${TIMESTAMP}.csv"\n\n# Initialize CSV with specific metrics for Burst (Power/Clock focus)\necho "timestamp,util_pct,temp_c,power_w,gpu_clk_mhz,status" > "$FINAL_LOG"\n\nTOTAL_SECONDS=$(( DURATION_MIN * 60 ))\n\necho "[INFO] Starting Burst Stress: ${DURATION_MIN} min (${TOTAL_SECONDS}s)"\necho "[SAFE] Critical Thermal Limit: ${MAX_TEMP_LIMIT}C"\n\n# Launch stress in background\n./gpu_burn ${TOTAL_SECONDS} > /dev/null & \nSTRESS_PID=$!\n\n# Telemetry and Emergency Break Loop\nwhile kill -0 $STRESS_PID 2>/dev/null; do\n    STATS=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw,clocks.current.graphics --format=csv,noheader,nounits | sed "s/[^0-9.,]//g")\n    UTIL=$(echo $STATS | cut -d, -f1)\n    T=$(echo $STATS | cut -d, -f2)\n    P=$(echo $STATS | cut -d, -f3)\n    GC=$(echo $STATS | cut -d, -f4)\n    TS=$(date +%%H:%%M:%%S)\n    STATUS="OK"\n\n    # Emergency Thermal Shutdown\n    if [ "$T" -ge "$MAX_TEMP_LIMIT" ]; then\n        STATUS="CRITICAL_OVERHEAT"\n        echo "$TS,$UTIL,$T,$P,$GC,$STATUS" >> "$FINAL_LOG"\n        echo -e "\n[!!!] EMERGENCY SHUTDOWN: ${T}C reached! Killing process..."\n        kill -9 $STRESS_PID 2>/dev/null\n        break\n    fi\n\n    echo "$TS,$UTIL,$T,$P,$GC,$STATUS" >> "$FINAL_LOG"\n    echo -ne "[RUNNING] T: $T C | P: $P W | U: $UTIL%% | C: $GC MHz\r"\n    sleep 1\ndone\n\nwait $STRESS_PID 2>/dev/null\necho -e "\n[INFO] Burst completed. CSV Report: $FINAL_LOG"' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
