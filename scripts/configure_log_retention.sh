#!/usr/bin/env bash
set -euo pipefail

# Cloud Functions logs are stored in Google Cloud Logging. Configure retention
# on the configurable _Default bucket so old diagnostic logs are automatically
# deleted by Google Cloud Logging instead of requiring a scheduled cleanup job.
#
# Usage:
#   ./scripts/configure_log_retention.sh
#   LOG_RETENTION_DAYS=14 ./scripts/configure_log_retention.sh
#
# _Default retention can be changed. The _Required bucket is controlled by
# Google Cloud and cannot be deleted/retention-reduced by this script.

PROJECT_ID="${FIREBASE_PROJECT_ID:-poultryinventory}"
RETENTION_DAYS="${LOG_RETENTION_DAYS:-7}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud CLI is required. Install Google Cloud CLI and authenticate first."
  exit 1
fi

if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || [ "$RETENTION_DAYS" -lt 1 ] || [ "$RETENTION_DAYS" -gt 3650 ]; then
  echo "ERROR: LOG_RETENTION_DAYS must be an integer from 1 to 3650."
  exit 1
fi

echo "Configuring Cloud Logging _Default bucket retention..."
echo "Project: $PROJECT_ID"
echo "Retention: $RETENTION_DAYS days"

gcloud logging buckets update _Default \
  --project="$PROJECT_ID" \
  --location=global \
  --retention-days="$RETENTION_DAYS"

echo ""
echo "Done. Logs in the _Default bucket will be automatically removed after $RETENTION_DAYS days."
