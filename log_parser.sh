#!/bin/bash

LOG_FILE="${1:-logs.log}" #option to specify logfile. defaults to logs.log
RESULT_FILE="results.log"

#colors
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
GREY='\033[0;90m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
NC='\033[0m' #no color

#header for terminal and file
echo -e "${GREY}== Log Analysis Run @ $(date) ==${NC}"
echo "== Log Analysis Run @ $(date)" > "$RESULT_FILE" # Overwrite result file

#column headers for terminal
printf "%-7s %-24s %-10s %-10s %-9s %-10s\n" "PID" "TASK" "START" "END" "STATUS" "DURATION"
#headers for file
printf "%-7s %-24s %-10s %-10s %-9s %-10s\n" "PID" "TASK" "START" "END" "STATUS" "DURATION" >> "$RESULT_FILE"

#processes the log file
full_awk_output=$(awk -F',' \
    -v RED="$RED" -v YELLOW="$YELLOW" -v GREEN="$GREEN" -v GREY="$GREY" \
    -v NC="$NC" -v BLUE="$BLUE" -v MAGENTA="$MAGENTA" '
    BEGIN {
        #init counters
        status_summary["OK"] = 0
        status_summary["WARNING"] = 0
        status_summary["ERROR"] = 0
        status_summary["INCOMPLETE"] = 0
        status_summary["ERROR_TIME"] = 0 #jobs with time calculation issues
        status_summary["UNKNOWN"] = 0    #fallback status
        total_jobs = 0

        #array for ordered status keys for summary
        ordered_status_keys[0]="OK";
        ordered_status_keys[1]="WARNING";
        ordered_status_keys[2]="ERROR";
        ordered_status_keys[3]="ERROR_TIME";
        ordered_status_keys[4]="INCOMPLETE";
        ordered_status_keys[5]="UNKNOWN";
        num_ordered_keys = 6;
    }

    {
        #trim spaces
        gsub(/^[ \t]+|[ \t]+$/, "", $1); # time
        gsub(/^[ \t]+|[ \t]+$/, "", $2); # desc
        gsub(/^[ \t]+|[ \t]+$/, "", $3); # event
        gsub(/^[ \t]+|[ \t]+$/, "", $4); # pid

        time = $1
        desc = $2
        event = $3
        pid = $4

        #skip if PID is empty after trim
        if (pid == "") next;

        if (event == "START") {
            start[pid] = time
            description[pid] = desc
            if (!(pid in seen_pids)) {
                seen_pids[pid] = 1
            }
        } else if (event == "END") {
            end[pid] = time
            if (!(pid in seen_pids)) {
                seen_pids[pid] = 1
                if (desc != "") { #store description if available with END event
                     description[pid] = desc
                }
            }
        }
    }

    END {
        #process PIDs
        for (pid_key in seen_pids) { 
            total_jobs++ # increment for each uniq Pid

            current_desc = description[pid_key]
            if (current_desc == "") {
                current_desc = "N/A"
            }
            
            s = start[pid_key]
            e = end[pid_key]
            
            s_display = (s == "") ? "-" : s
            e_display = (e == "") ? "-" : e

            raw_status = ""
            duration_str = "-"
            color_status = ""
            color_task = ""

            #color based on desc
            if (current_desc ~ /background job/) {
                color_task = MAGENTA current_desc NC
            } else if (current_desc ~ /scheduled task/) {
                color_task = BLUE current_desc NC
            } else {
                color_task = current_desc
            }

            if (s == "" || e == "") {
                raw_status = "INCOMPLETE"
                color_status = GREY raw_status NC
            } else {
                start_datetime_str = "1900-01-01 " s
                end_datetime_str = "1900-01-01 " e

                cmd_start_epoch = "date -d \"" start_datetime_str "\" +%s"
                cmd_end_epoch = "date -d \"" end_datetime_str "\" +%s"
                
                start_epoch = 0; end_epoch = 0; time_parse_ok = 1;

                if ( (cmd_start_epoch | getline temp_start_epoch) > 0 ) { start_epoch = temp_start_epoch; } else { time_parse_ok = 0; }
                close(cmd_start_epoch);

                if (time_parse_ok && (cmd_end_epoch | getline temp_end_epoch) > 0 ) { end_epoch = temp_end_epoch; } else { time_parse_ok = 0; }
                close(cmd_end_epoch);

                if (!time_parse_ok || start_epoch == 0 || end_epoch == 0 || end_epoch < start_epoch) {
                    raw_status = "ERROR_TIME"
                    color_status = RED raw_status NC
                    duration_str = "err"
                } else {
                    duration = end_epoch - start_epoch
                    minutes = int(duration / 60)
                    seconds = duration % 60
                    duration_str = sprintf("%dm %02ds", minutes, seconds)

                    if (duration > 600) { raw_status = "ERROR"; color_status = RED raw_status NC; }
                    else if (duration > 300) { raw_status = "WARNING"; color_status = YELLOW raw_status NC; }
                    else { raw_status = "OK"; color_status = GREEN raw_status NC; }
                }
            }
            
            if (raw_status == "") { raw_status = "UNKNOWN"; color_status = GREY raw_status NC; }
            status_summary[raw_status]++;

            #format terminal output
            printf "TERM_JOB:%-7s %-35s %-10s %-10s %-20s %-10s\n", pid_key, color_task, s_display, e_display, color_status, duration_str;
            #format file output
            printf "FILE_JOB:%-7s %-35s %-10s %-10s %-20s %-10s\n", pid_key, current_desc, s_display, e_display, raw_status, duration_str;
        }

        #compose summary.
        summary_str = "SUMMARY_DATA:TotalJobs=" total_jobs;
        for (i = 0; i < num_ordered_keys; i++) {
             key = ordered_status_keys[i];
             #include status in summary if status count > 0
             if (key in status_summary && status_summary[key] > 0) {
                summary_str = summary_str ";" key "=" status_summary[key];
             }
        }
        print summary_str;
    }
' "$LOG_FILE")

#extract jobs remove prefix sort and print
echo "$full_awk_output" | grep '^TERM_JOB:' | sed 's/^TERM_JOB://' | sort -k7 #sort based on the 7th column

#extract jobs remove prefix and append to file
echo "$full_awk_output" | grep '^FILE_JOB:' | sed 's/^FILE_JOB://' >> "$RESULT_FILE"


#extract summary string
summary_data_string=$(echo "$full_awk_output" | grep '^SUMMARY_DATA:' | sed 's/^SUMMARY_DATA://')

#summary output 
echo 
echo -e "${BLUE}== Job Summary ==${NC}"
#parse summary_data_string and print
echo "$summary_data_string" | awk -F';' \
    -v BLUE="$BLUE" -v GREEN="$GREEN" -v YELLOW="$YELLOW" -v RED="$RED" -v GREY="$GREY" -v NC="$NC" '
{
    for (i = 1; i <= NF; i++) {
        split($i, pair, "=");
        key = pair[1];
        value = pair[2];
        if (key == "TotalJobs") {
            printf "%sTotal Jobs: %d%s\n", BLUE, value, NC;
        } else if (key == "OK") {
            printf "%sOK: %d%s\n", GREEN, value, NC;
        } else if (key == "WARNING") {
            printf "%sWARNING: %d%s\n", YELLOW, value, NC;
        } else if (key == "ERROR") {
            printf "%sERROR: %d%s\n", RED, value, NC;
        } else if (key == "ERROR_TIME") {
            printf "%sERROR_TIME: %d%s\n", RED, value, NC;
        } else if (key == "INCOMPLETE") {
            printf "%sINCOMPLETE: %d%s\n", GREY, value, NC;
        } else if (key == "UNKNOWN") {
            printf "%sUNKNOWN: %d%s\n", GREY, value, NC;
        }
    }
}'

#file summary
echo >> "$RESULT_FILE"
echo "== Job Summary ==" >> "$RESULT_FILE"
#parse summary_data_string and append to results.log
echo "$summary_data_string" | awk -F';' '
{
    for (i = 1; i <= NF; i++) {
        split($i, pair, "=");
        key = pair[1];
        value = pair[2];
        if (key == "TotalJobs") {
            printf "Total Jobs: %d\n", value;
        } else { #for other statuses like Ok, warning, etc.
            printf "%s: %d\n", key, value;
        }
    }
}' >> "$RESULT_FILE"
