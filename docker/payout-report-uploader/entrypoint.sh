#!/bin/bash -x

find /app/reports

echo "now rsyncing payout reports to $REPORT_BUCKET_URL"
# workload identity allows this to work
gsutil -m rsync -r /app/reports $REPORT_BUCKET_URL

echo "Done"
echo ""
