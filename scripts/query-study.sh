#!/bin/bash
# Query DICOM Study Information

PACS_HOST=${PACS_HOST:-localhost}
PACS_PORT=${PACS_PORT:-4242}
LOCAL_AET=${LOCAL_AET:-FINDSCU}
REMOTE_AET=${REMOTE_AET:-ORTHANC}
PATIENT_ID=${1:-"*"}

echo "Querying studies for patient: $PATIENT_ID"

findscu \
    -v \
    -aet "$LOCAL_AET" \
    -aec "$REMOTE_AET" \
    -S \
    -k "QueryRetrieveLevel=STUDY" \
    -k "PatientID=$PATIENT_ID" \
    -k "StudyInstanceUID" \
    -k "StudyDescription" \
    -k "StudyDate" \
    -k "StudyTime" \
    -k "AccessionNumber" \
    "$PACS_HOST" "$PACS_PORT"
