#!/bin/bash -x
# workload identity allows this to work
gcloud container clusters get-credentials blockchain --region $GCP_REGION

cd /app/reports

find

echo "now rsyncing payout reports to $REPORT_BUCKET_URL"
gsutil -m rsync /app/reports $REPORT_BUCKET_URL
