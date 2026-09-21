#!/usr/bin/env bash

SONARR_URL="http://192.168.178.57:8990"
SONARR_API_KEY="4a43fe1ca4fa45f89045d34b0efda9f5"

# Step 1: Get all queue items that are blocked or pending import
queue_items=$(curl -s "$SONARR_URL/api/v3/queue/details" \
  -H "X-Api-Key: $SONARR_API_KEY" | \
  jq '[.[] | select(.trackedDownloadState == "importBlocked" or .trackedDownloadState == "importPending")]')

echo "Found $(echo "$queue_items" | jq 'length') items to import"

# Step 2: For each item, get its files and build the import payload
all_files="[]"

while IFS= read -r item; do
  download_id=$(echo "$item" | jq -r '.downloadId')
  series_id=$(echo "$item" | jq -r '.seriesId')

  echo "Fetching files for downloadId=$download_id seriesId=$series_id"

  files=$(curl -s "$SONARR_URL/api/v3/manualimport?downloadId=$download_id&seriesId=$series_id" \
    -H "X-Api-Key: $SONARR_API_KEY" | \
    jq '[.[] | {
      path: .path,
      folderName: .folderName,
      seriesId: .series.id,
      episodeIds: [.episodes[].id],
      downloadId: .downloadId,
      quality: .quality,
      languages: .languages,
      releaseGroup: .releaseGroup,
      indexerFlags: .indexerFlags
    }]')

  all_files=$(echo "$all_files $files" | jq -s 'add')
done < <(echo "$queue_items" | jq -c '.[]')

echo "Total files to import: $(echo "$all_files" | jq 'length')"

# Step 3: Trigger the import
curl -s -X POST "$SONARR_URL/api/v3/command" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"ManualImport\", \"importMode\": \"Auto\", \"files\": $all_files}" | \
  jq '{id: .id, name: .name, status: .status}'
