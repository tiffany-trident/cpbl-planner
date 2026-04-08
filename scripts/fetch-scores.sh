#!/bin/bash
# fetch-scores.sh — Fetch CPBL 2026 game data (with scores) and update RAW_DATA in index.html
# Usage: bash scripts/fetch-scores.sh
# Designed to run in GitHub Actions (ubuntu) or locally with bash + curl + node

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TMP_DIR=$(mktemp -d)

echo "[1/4] Fetching CPBL schedule page for token..."
curl -s -c "$TMP_DIR/cookies.txt" "https://www.cpbl.com.tw/schedule" -o "$TMP_DIR/page.html"

# Extract the second RequestVerificationToken (used for getgamedatas)
TOKEN=$(grep -o "RequestVerificationToken: '[^']*'" "$TMP_DIR/page.html" | tail -1 | sed "s/RequestVerificationToken: '//;s/'//")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to extract token"
  exit 1
fi
echo "   Token acquired."

echo "[2/4] Fetching game data from API..."
curl -s -b "$TMP_DIR/cookies.txt" -X POST "https://www.cpbl.com.tw/schedule/getgamedatas" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "RequestVerificationToken: $TOKEN" \
  -H "X-Requested-With: XMLHttpRequest" \
  -d "CalendarDate=2026%2F06%2F01&GameSno=01&KindCode=A&Location=" \
  -o "$TMP_DIR/raw_response.json"

# Verify response
if ! grep -q '"Success":true' "$TMP_DIR/raw_response.json"; then
  echo "ERROR: API returned failure"
  cat "$TMP_DIR/raw_response.json"
  exit 1
fi
echo "   API response OK."

echo "[3/4] Converting to RAW_DATA format..."
node -e "
const fs = require('fs');
const raw = JSON.parse(fs.readFileSync('$TMP_DIR/raw_response.json', 'utf8'));
const games = JSON.parse(raw.GameDatas);

const lines = games.map(g => {
  const date = g.GameDate.slice(0, 10);
  const time = g.GameDateTimeS.slice(11, 16);
  return JSON.stringify([
    date, time,
    g.VisitingTeamName, g.HomeTeamName, g.FieldAbbe,
    g.VisitingScore || 0, g.HomeScore || 0,
    g.WinningPitcherName || '', g.LoserPitcherName || '',
    g.CloserName || '', g.MvpName || '',
    g.GameResult == null ? '' : String(g.GameResult)
  ]);
});

const output = 'const RAW_DATA = [\\n' + lines.join(',\\n') + '\\n];';
fs.writeFileSync('$TMP_DIR/raw_data.js', output, 'utf8');
console.log('   Converted ' + games.length + ' games.');
"

echo "[4/4] Updating index.html..."
node -e "
const fs = require('fs');
const newData = fs.readFileSync('$TMP_DIR/raw_data.js', 'utf8');
let html = fs.readFileSync('$PROJECT_DIR/index.html', 'utf8');

// Replace RAW_DATA block
const start = html.indexOf('const RAW_DATA = [');
const end = html.indexOf('];', start) + 2;
if (start === -1 || end <= 1) {
  console.error('ERROR: Could not find RAW_DATA in index.html');
  process.exit(1);
}
html = html.slice(0, start) + newData + html.slice(end);
fs.writeFileSync('$PROJECT_DIR/index.html', html, 'utf8');
console.log('   index.html updated.');
"

# Also sync to cpbl-planner.html
cp "$PROJECT_DIR/index.html" "$PROJECT_DIR/cpbl-planner.html"
echo "   cpbl-planner.html synced."

# Cleanup
rm -rf "$TMP_DIR"
echo "Done!"
