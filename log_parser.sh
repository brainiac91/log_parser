#!/bin/bash

LOG_FILE="logs.log"
RESULT_FILE="results.log"

# ANSI colors
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
GREY='\033[0;90m'
NC='\033[0m' # No Color

# Header
echo -e "${GREY}== Log Analysis Run @ $(date) ==${NC}"
echo "== Log Analysis Run @ $(date)" > "$RESULT_FILE"

awk -F',' -v RED="$RED" -v YELLOW="$YELLOW" -v GREEN="$GREEN" -v GREY="$GREY" -v NC="$NC" '
{
  gsub(/^[ \t]+|[ \t]+$/, "", $1);
  gsub(/^[ \t]+|[ \t]+$/, "", $2);
  gsub(/^[ \t]+|[ \t]+$/, "", $3);
  gsub(/^[ \t]+|[ \t]+$/, "", $4);

  time = $1
  desc = $2
  event = $3
  pid = $4

  if (event == "START") {
    start[pid] = time
    description[pid] = desc
    seen[pid] = 1
  } else if (event == "END") {
    end[pid] = time
    seen[pid] = 1
  }
}

END {
  for (pid in seen) {
    desc = description[pid]
    s = start[pid]
    e = end[pid]
    raw_status = ""
    duration_str = "-"

    if (s == "" || e == "") {
      raw_status = "INCOMPLETE"
      color_status = GREY raw_status NC
    } else {
      start_time = "1900-01-01 " s
      end_time = "1900-01-01 " e

      cmd = "date -d \"" end_time "\" +%s"
      cmd | getline end_epoch
      close(cmd)

      cmd = "date -d \"" start_time "\" +%s"
      cmd | getline start_epoch
      close(cmd)

      duration = end_epoch - start_epoch
      minutes = int(duration / 60)
      seconds = duration % 60
      duration_str = sprintf("%dm %02ds", minutes, seconds)

      if (duration > 600) {
        raw_status = "ERROR"
        color_status = RED raw_status NC
      }
      else if (duration > 300) {
        raw_status = "WARNING"
        color_status = YELLOW raw_status NC
      }
      else {
        raw_status = "OK"
        color_status = GREEN raw_status NC
      }
    }

    printf "%-7s %-25s %-10s %s\n", pid, desc, color_status, duration_str
    printf "%-7s %-25s %-10s %s\n", pid, desc, raw_status, duration_str >> "'"$RESULT_FILE"'"
  }
}
' "$LOG_FILE" | sort -k5
