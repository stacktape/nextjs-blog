#!/bin/bash

# Get command line arguments
URL=$1
REQ_PER_SEC=$2
OUTPUT_FILE=$3

# Validate arguments
if [ -z "$URL" ] || [ -z "$REQ_PER_SEC" ] || [ -z "$OUTPUT_FILE" ]; then
  echo "Usage: $0 <URL> <REQ_PER_SEC> <OUTPUT_FILE>"
  exit 1
fi

DURATION=10  # 10 seconds
RESPONSE_TIMES_FILE=$(mktemp)  # Temporary file to store response times
RESPONSE_TIMES=()

# Function to send a single request and measure response time
send_request() {
  local start_time=$(date +%s%N)

  # Send an HTTP request to the specified URL and measure response time
  if curl -s -o /dev/null -w "%{http_code}" "$URL" | grep -q "200"; then
    local request_end_time=$(date +%s%N)
    local response_time=$((request_end_time - start_time))
    echo "$response_time" >> "$RESPONSE_TIMES_FILE"
  else
    echo "Request failed"
    exit 1
  fi
}

# Function to send requests in parallel and capture response times
send_requests() {
  local start_time=$(date +%s)
  local end_time

  while (( $(date +%s) - start_time < DURATION )); do
    # Send requests in parallel and capture response times
    for (( i = 0; i < REQ_PER_SEC; i++ )); do
      send_request &
      PIDS[${i}]=$!
    done

    # Wait for all background processes to finish before proceeding
    for (( i = 0; i < REQ_PER_SEC; i++ )); do
      wait ${PIDS[${i}]}
    done
  done
}

# Call the function to send requests
send_requests

# Read response times from the temporary file
RESPONSE_TIMES=($(cat "$RESPONSE_TIMES_FILE"))

# Convert the array of response times to a JSON array
JSON_RESPONSE_TIMES=$(printf "%s\n" "${RESPONSE_TIMES[@]}" | jq -s .)

# Save response times to the specified output file as a JSON array
echo $JSON_RESPONSE_TIMES > "$OUTPUT_FILE"

# Clean up temporary files
rm "$RESPONSE_TIMES_FILE"

echo "Response times data saved in $OUTPUT_FILE"
