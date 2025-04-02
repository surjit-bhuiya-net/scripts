#!/bin/bash

# Check if script is executed in /DNIF directory
if [[ $(pwd) != "/DNIF" ]]; then
    echo "Error: This script must be executed in the /DNIF directory. Exiting."
    exit 1
fi

# Progress bar function
progress_bar() {
    local progress=$1
    local total=$2
    local percent=$((progress * 100 / total))
    if [ $percent -gt 100 ]; then percent=100; fi
    local bar_width=50
    local filled=$((bar_width * percent / 100))
    local empty=$((bar_width - filled))

    printf "\r["
    printf "%0.s#" $(seq 1 $filled)
    printf "%0.s-" $(seq 1 $empty)
    printf "] %d%%" $percent
}

# Prompt for output file
read -p "Enter the name of the output file (without extension): " OUTPUT_FILE
OUTPUT_FILE="${OUTPUT_FILE}.txt"

# Initialize output file with headers
cat > "$OUTPUT_FILE" << EOF
===========================================
          Sysbench Test Report
===========================================
Generated on: $(date)
===========================================

EOF

# Total steps for progress bar
TOTAL_STEPS=10
STEP=0

# Log functions
log_section() {
    echo -e "\n$1\n$(printf '%.0s=' {1..50})" >> "$OUTPUT_FILE"
}

log_result() {
    echo "$1" >> "$OUTPUT_FILE"
}

# Step 1: Check if sysbench is installed
STEP=$((STEP + 1))
progress_bar $STEP $TOTAL_STEPS

log_section "Sysbench Installation Check"
if ! command -v sysbench &>/dev/null; then
    log_result "Sysbench not found. Installing..."
    sudo apt-get update -y >/dev/null 2>&1
    sudo apt-get install -y sysbench >/dev/null 2>&1
    if command -v sysbench &>/dev/null; then
        log_result "Sysbench installed successfully."
    else
        log_result "Sysbench installation failed. Exiting."
        echo -e "\nInstallation failed. Exiting."
        exit 1
    fi
else
    log_result "Sysbench is already installed."
fi

# Step 2: CPU Test (1 thread)
STEP=$((STEP + 1))
progress_bar $STEP $TOTAL_STEPS
log_section "CPU Test (1 Thread)"

CPU_TEST_1=$(sysbench --test=cpu --num-threads=1 --cpu-max-prime=20000 run 2>&1)
CPU_SPEED_1=$(echo "$CPU_TEST_1" | grep "events per second:" | awk '{print $NF}')
CPU_EVENTS_1=$(echo "$CPU_TEST_1" | grep "total number of events:" | awk '{print $NF}')
CPU_TIME_1=$(echo "$CPU_TEST_1" | grep "total time:" | awk '{print $NF}')

log_result "CPU Speed (events/sec): $CPU_SPEED_1"
log_result "Total Events: $CPU_EVENTS_1"
log_result "Total Time (sec): $CPU_TIME_1"

# Step 3: CPU Test (8 threads)
STEP=$((STEP + 1))
progress_bar $STEP $TOTAL_STEPS
log_section "CPU Test (8 Threads)"

CPU_TEST_8=$(sysbench --test=cpu --num-threads=8 --cpu-max-prime=20000 run 2>&1)
CPU_SPEED_8=$(echo "$CPU_TEST_8" | grep "events per second:" | awk '{print $NF}')
CPU_EVENTS_8=$(echo "$CPU_TEST_8" | grep "total number of events:" | awk '{print $NF}')
CPU_TIME_8=$(echo "$CPU_TEST_8" | grep "total time:" | awk '{print $NF}')

log_result "CPU Speed (events/sec): $CPU_SPEED_8"
log_result "Total Events: $CPU_EVENTS_8"
log_result "Total Time (sec): $CPU_TIME_8"

# Step 4: Memory Test (1 thread)
STEP=$((STEP + 1))
progress_bar $STEP $TOTAL_STEPS
log_section "Memory Test (1 Thread)"

MEMORY_TEST_1=$(sysbench --test=memory --num-threads=1 run 2>&1)
MEMORY_OPS_1=$(echo "$MEMORY_TEST_1" | grep "Total operations:" | grep -oP '\(\K[^)]+' | awk '{print $1}')
MEMORY_MB_1=$(echo "$MEMORY_TEST_1" | grep "MiB transferred" | grep -oP '\(\K[^)]+' | awk '{print $1}')

log_result "Memory Operations/sec: $MEMORY_OPS_1"
log_result "Memory Throughput (MiB/sec): $MEMORY_MB_1"

# Step 5: Memory Test (8 threads)
STEP=$((STEP + 1))
progress_bar $STEP $TOTAL_STEPS
log_section "Memory Test (8 Threads)"

MEMORY_TEST_8=$(sysbench --test=memory --num-threads=8 run 2>&1)
MEMORY_OPS_8=$(echo "$MEMORY_TEST_8" | grep "Total operations:" | grep -oP '\(\K[^)]+' | awk '{print $1}')
MEMORY_MB_8=$(echo "$MEMORY_TEST_8" | grep "MiB transferred" | grep -oP '\(\K[^)]+' | awk '{print $1}')

log_result "Memory Operations/sec: $MEMORY_OPS_8"
log_result "Memory Throughput (MiB/sec): $MEMORY_MB_8"

# Step 6: File I/O Test
STEP=$((STEP + 1))
progress_bar $STEP $TOTAL_STEPS
log_section "File I/O Test"

# Check if there is enough space (150GB) before running the test
AVAILABLE_SPACE=$(df --output=avail / | tail -n 1)
AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

if [ $AVAILABLE_SPACE_GB -lt 150 ]; then
    echo "Error: Not enough disk space available. At least 150GB is required. Exiting."
    exit 1
fi

# Execute prepare command
FILEIO_PREPARE=$(sysbench --test=fileio --file-total-size=150G prepare 2>&1)
FILEIO_WRITTEN=$(echo "$FILEIO_PREPARE" | grep -oP 'written in \K[0-9.]+ seconds')

if [ -z "$FILEIO_WRITTEN" ]; then
    log_result "File preparation completed, but could not capture write time."
else
    log_result "File preparation completed. Write time: $FILEIO_WRITTEN."
fi

# Execute random read/write test
FILEIO_TEST=$(sysbench --test=fileio --file-total-size=150G --file-test-mode=rndrw --max-requests=0 run 2>&1)
READ_SEC=$(echo "$FILEIO_TEST" | grep "reads/s:" | awk '{print $NF}')
WRITE_SEC=$(echo "$FILEIO_TEST" | grep "writes/s:" | awk '{print $NF}')
FSYNCS_SEC=$(echo "$FILEIO_TEST" | grep "fsyncs/s:" | awk '{print $NF}')
READ_MB_SEC=$(echo "$FILEIO_TEST" | grep "read, MiB/s:" | awk '{print $NF}')
WRITE_MB_SEC=$(echo "$FILEIO_TEST" | grep "written, MiB/s:" | awk '{print $NF}')
AVG_EVENTS_STDDEV=$(echo "$FILEIO_TEST" | grep "events (avg/stddev):" | awk '{print $3}')
AVG_EXECUTION_STDDEV=$(echo "$FILEIO_TEST" | grep "execution time (avg/stddev):" | awk '{print $4}')

log_result "Reads/sec: $READ_SEC"
log_result "Writes/sec: $WRITE_SEC"
log_result "Fsyncs/sec: $FSYNCS_SEC"
log_result "Throughput - Read (MiB/sec): $READ_MB_SEC"
log_result "Throughput - Write (MiB/sec): $WRITE_MB_SEC"
log_result "Threads fairness - events (avg/stddev): $AVG_EVENTS_STDDEV"
log_result "Threads fairness - execution time (avg/stddev): $AVG_EXECUTION_STDDEV"

# Cleanup files
sysbench --test=fileio --file-total-size=150G cleanup >/dev/null 2>&1
log_result "File cleanup completed."

# Finalize progress bar and log file
progress_bar $TOTAL_STEPS $TOTAL_STEPS
echo -e "\n===========================================\n" >> "$OUTPUT_FILE"
echo -e "            Sysbench Tests Completed            " >> "$OUTPUT_FILE"
echo -e "===========================================\n" >> "$OUTPUT_FILE"

# Completion message
echo -e "\n\nSysbench tests completed. Results saved to $OUTPUT_FILE"
