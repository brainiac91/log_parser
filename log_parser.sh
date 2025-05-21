#!/bin/bash

LOG_FILE="logs.log"

awk -F',' '
{
  gsub(/^[ \t]+|[ \t]+$/, "", $1); # Trim timestamp
  gsub(/^[ \t]+|[ \t]+$/, "", $2); # Trim description
  gsub(/^[ \t]+|[ \t]+$/, "", $3); # Trim START/END
  gsub(/^[ \t]+|[ \t]+$/, "", $4); # Trim PID
  key = $4;

  if ($3 == "START") {
    start[key] = $1;
    desc[key] = $2;
  } else if ($3 == "END" && (key in start)) {
    start_time = "1900-01-01 " start[key];
    end_time = "1900-01-01 " $1;

    cmd = "date -d \"" end_time "\" +%s";
    cmd | getline end_epoch;
    close(cmd);

    cmd = "date -d \"" start_time "\" +%s";
    cmd | getline start_epoch;
    close(cmd);

    duration = end_epoch - start_epoch;
    minutes = int(duration / 60);
    seconds = duration % 60;

    status = "OK";
    if (duration > 600) status = "ERROR";
    else if (duration > 300) status = "WARNING";

    printf "%-7s %-25s %-8s %3dm %2ds\n", key, desc[key], status, minutes, seconds;
  }
}
' "$LOG_FILE" | sort -k5,5nr
