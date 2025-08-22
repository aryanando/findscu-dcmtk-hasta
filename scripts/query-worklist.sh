#!/bin/bash
# Query DICOM Modality Worklist

PACS_HOST=${PACS_HOST:-localhost}
PACS_PORT=${PACS_PORT:-4242}
LOCAL_AET=${LOCAL_AET:-FINDSCU}
REMOTE_AET=${REMOTE_AET:-ORTHANC}

echo "Querying Modality Worklist from $PACS_HOST:$PACS_PORT"

findscu \
    -v \
    -aet "$LOCAL_AET" \
    -aec "$REMOTE_AET" \
    -W \
    -k "ScheduledProcedureStepSequence[0].Modality" \
    -k "ScheduledProcedureStepSequence[0].ScheduledStationAETitle" \
    -k "ScheduledProcedureStepSequence[0].ScheduledProcedureStepStartDate" \
    -k "ScheduledProcedureStepSequence[0].ScheduledProcedureStepStartTime" \
    -k "PatientName" \
    -k "PatientID" \
    -k "AccessionNumber" \
    "$PACS_HOST" "$PACS_PORT"
