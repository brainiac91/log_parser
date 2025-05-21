# log_parser

Bash script analyzes log files to extract job execution details, calculate durations, determine job statuses, and generate a formatted report. It provides both a colorized terminal output and a plain text output file (`results.log`), along with a summary of job statuses.

## Features

* Parses log files with comma-separated values.
* Identifies job start and end events based on Process ID (PID).
* Calculates the duration of each job.
* Assigns a status to each job:
    * **OK**: Job completed successfully within a defined timeframe.
    * **WARNING**: Job took longer than expected but completed.
    * **ERROR**: Job took excessively long.
    * **INCOMPLETE**: Job has a START event but no corresponding END event, or vice-versa.
    * **ERROR_TIME**: Problem calculating job duration (e.g., end time before start time, unparseable time).
    * **UNKNOWN**: Fallback status if no other status can be determined.
* Color-codes output in the terminal for readability (e.g., different colors for task types and statuses).
* Generates a plain text `results.log` file with the analysis.
* Provides a summary of total jobs and counts for each status at the end of the report.
* Allows specifying a custom log file path as a command-line argument.

## Prerequisites

* A Unix-like environment (Linux, macOS) with Bash.
* Standard Unix utilities: `awk`, `date`, `grep`, `sed`, `sort`.

## Log File Format

The script expects the input log file to be a comma-separated value (CSV) file where each line represents a job event. Each line should have the following four fields in order:

1.  **Time**: The time of the event (e.g., `HH:MM:SS`).
2.  **Description**: A textual description of the job (e.g., `scheduled task 032`, `background job wmy`).
3.  **Event Type**: Either `START` or `END`.
4.  **PID**: The Process ID of the job.

**Example Log Line:**


11:35:23,scheduled task 032,START,37980
11:35:56,scheduled task 032,END,37980


Whitespace around fields will be automatically trimmed by the script.

## Usage

1.  Save the script to a file (e.g., `log_parser.sh`).
2.  Make the script executable:
    ```bash
    chmod +x log_parser.sh
    ```
3.  Run the script:
    * To analyze the default `logs.log` file (expected in the same directory):
        ```bash
        ./log_parser.sh
        ```
    * To analyze a specific log file:
        ```bash
        ./log_parser.sh /path/to/your/logfile.log
        ```

## Output

The script produces two main outputs:

1.  **Terminal Output:**
    * A header indicating the run time.
    * Formatted column headers: `PID`, `TASK`, `START`, `END`, `STATUS`, `DURATION`.
    * A list of processed jobs, sorted by status (based on the 7th field of the colored output, which usually corresponds to status). Task descriptions and statuses are color-coded.
    * A summary section at the end, showing the total number of jobs and a breakdown by status.

2.  **`results.log` File:**
    * A plain text file created in the same directory as the script.
    * Contains the same header, column headers, and job details as the terminal output but without ANSI color codes. Job lines in this file are in the order they were processed by `awk` (typically PID order, not sorted by status).
    * Includes the same summary section at the end.

**Status Thresholds (Default):**

* **OK**: Duration <= 300 seconds (5 minutes)
* **WARNING**: Duration > 300 seconds AND <= 600 seconds (10 minutes)
* **ERROR**: Duration > 600 seconds

## Script Breakdown

The script is composed of a Bash shell wrapper and  `awk` script:

* **Bash Wrapper:**
    * Handles command-line arguments (log file path).
    * Sets up ANSI color variables.
    * Prints initial headers.
    * Calls the main `awk` script, capturing its entire output.
    * Post-processes the `awk` output:
        * Separates lines intended for terminal display and file logging.
        * Sorts the terminal output.
        * Extracts and formats the summary data.
* **Awk Script:**
    * Parses each line of the log file.
    * Uses associative arrays to store start times, end times, and descriptions for each job PID.
    * Calculates job durations by invoking the `date` command (this can be a performance consideration for very large files).
    * Determines job status based on completeness and duration thresholds.
    * Formats output lines with prefixes (`TERM_JOB:`, `FILE_JOB:`) for the shell to process.
    * Aggregates status counts and generates a compact summary string (`SUMMARY_DATA:`).
