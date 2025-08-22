#!/bin/bash

# DCMTK Connection Test Script
# Tests basic connectivity to PACS server

# Load environment variables if available
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Default values
PACS_HOST=${PACS_HOST:-"orthanc"}
PACS_PORT=${PACS_PORT:-"4242"}
REMOTE_AET=${REMOTE_AET:-"ORTHANC"}
LOCAL_AET=${LOCAL_AET:-"FINDSCU"}

echo "Testing connection to ${PACS_HOST}:${PACS_PORT}"
echo "Local AET: ${LOCAL_AET}, Remote AET: ${REMOTE_AET}"

# Test basic connectivity
echo "1. Testing network connectivity..."
ping -c 3 "${PACS_HOST}"

echo "2. Testing port connectivity..."
telnet "${PACS_HOST}" "${PACS_PORT}" < /dev/null

echo "3. Testing DICOM association..."
# Simple echo SCU test
echoscu -v -aet "${LOCAL_AET}" -aec "${REMOTE_AET}" "${PACS_HOST}" "${PACS_PORT}"

echo "Connection test completed."
