#!/bin/bash

LOG_FILE="logs.log"

awk -F',' '
{
  gsub(/^[ \t]+|[ \t]+$/, "", $1); # Trim timestamp
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

    if (s == "" || e == "") {
      status = "INCOMPLETE"
      duration_str = "-"
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

      if (duration > 600) status = "ERROR"
      else if (duration > 300) status = "WARNING"
      else status = "OK"
    }

    printf "%-7s %-25s %-10s %s\n", pid, desc, status, duration_str
  }
}
' "$LOG_FILE" | sort -k5
