#!/bin/bash
# Query DICOM Patient Information

PACS_HOST=${PACS_HOST:-localhost}
PACS_PORT=${PACS_PORT:-4242}
LOCAL_AET=${LOCAL_AET:-FINDSCU}
REMOTE_AET=${REMOTE_AET:-ORTHANC}
PATIENT_NAME=${1:-"*"}

echo "Querying patient information for: $PATIENT_NAME"

findscu \
    -v \
    -aet "$LOCAL_AET" \
    -aec "$REMOTE_AET" \
    -P \
    -k "QueryRetrieveLevel=PATIENT" \
    -k "PatientName=$PATIENT_NAME" \
    -k "PatientID" \
    -k "PatientBirthDate" \
    -k "PatientSex" \
    "$PACS_HOST" "$PACS_PORT"
