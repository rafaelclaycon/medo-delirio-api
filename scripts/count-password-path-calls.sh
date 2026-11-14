#!/usr/bin/env bash
#
# Counts nginx requests that still send an admin password in the URL path
# (`…/unique-users/<password>` rather than `Authorization: Bearer`), per log
# file and per route. It prints route patterns only, never a password.
#
# Usage, on the server:   sudo bash scripts/count-password-path-calls.sh [log files…]
# Default: /var/log/nginx/access.log*  (.gz files are read too)
#
# Phase 5 of docs/vapor-modernization-plan.md: the path routes can be removed
# once this reports 0 for a few days in a row. The route list below comes from
# Tests/AppTests/RoutesTests.swift; delete this script together with those routes.

set -euo pipefail

if [ "$#" -eq 0 ]; then
    set -- /var/log/nginx/access.log*
fi

routes_file=$(mktemp)
trap 'rm -f "$routes_file"' EXIT
cat > "$routes_file" <<'ROUTES'
DELETE	^/api/v3/author/[^/]+/[^/]+$	-	/api/v3/author/:id/:password
DELETE	^/api/v3/music-genre/[^/]+/[^/]+$	-	/api/v3/music-genre/:id/:password
DELETE	^/api/v3/song/[^/]+/[^/]+$	-	/api/v3/song/:id/:password
DELETE	^/api/v3/sound/[^/]+/[^/]+$	-	/api/v3/sound/:id/:password
DELETE	^/api/v4/delete-all-reaction-sounds/[^/]+$	-	/api/v4/delete-all-reaction-sounds/:password
DELETE	^/api/v4/delete-all-reactions/[^/]+$	-	/api/v4/delete-all-reactions/:password
DELETE	^/api/v4/delete-reaction-sounds/[^/]+/[^/]+$	-	/api/v4/delete-reaction-sounds/:id/:password
DELETE	^/api/v4/delete-reaction/[^/]+/[^/]+$	-	/api/v4/delete-reaction/:id/:password
DELETE	^/api/v4/episode-highlight/[^/]+$	-	/api/v4/episode-highlight/:password
DELETE	^/api/v4/retro-banner/[^/]+$	-	/api/v4/retro-banner/:password
GET	^/api/v3/active-users-count-from/[^/]+/[^/]+$	-	/api/v3/active-users-count-from/:date/:password
GET	^/api/v3/active-users-daily-last-30-days/[^/]+$	-	/api/v3/active-users-daily-last-30-days/:password
GET	^/api/v3/all-device-model-names/[^/]+$	-	/api/v3/all-device-model-names/:password
GET	^/api/v3/all-ios-versions/[^/]+$	-	/api/v3/all-ios-versions/:password
GET	^/api/v3/device-analytics/[^/]+$	-	/api/v3/device-analytics/:password
GET	^/api/v3/device-model-history/[^/]+/[^/]+$	-	/api/v3/device-model-history/:modelName/:password
GET	^/api/v3/ios-version-device-breakdown/[^/]+/[^/]+$	-	/api/v3/ios-version-device-breakdown/:majorVersion/:password
GET	^/api/v3/ios-version-history/[^/]+/[^/]+$	-	/api/v3/ios-version-history/:majorVersion/:password
GET	^/api/v3/navigation-analytics/[^/]+$	-	/api/v3/navigation-analytics/:password
GET	^/api/v3/sessions-count-from/[^/]+/[^/]+$	-	/api/v3/sessions-count-from/:date/:password
GET	^/api/v4/chapters-usage-analytics/[^/]+$	-	/api/v4/chapters-usage-analytics/:password
GET	^/api/v4/election-live-analytics/[^/]+$	^(/api/v4/election-live-analytics/series)$	/api/v4/election-live-analytics/:password
GET	^/api/v4/election-live-analytics/series/[^/]+$	-	/api/v4/election-live-analytics/series/:password
GET	^/api/v4/election/channels/[^/]+$	-	/api/v4/election/channels/:password
GET	^/api/v4/election/status/[^/]+$	-	/api/v4/election/status/:password
GET	^/api/v4/episode-analytics/[^/]+$	-	/api/v4/episode-analytics/:password
GET	^/api/v4/folder-research-analytics/[^/]+$	-	/api/v4/folder-research-analytics/:password
GET	^/api/v4/games-analytics/[^/]+$	-	/api/v4/games-analytics/:password
GET	^/api/v4/push-audience/[^/]+$	-	/api/v4/push-audience/:password
GET	^/api/v4/push-broadcast/[^/]+/[^/]+$	-	/api/v4/push-broadcast/:id/:password
GET	^/api/v4/push-broadcasts/[^/]+$	-	/api/v4/push-broadcasts/:password
GET	^/api/v4/retro-banner/settings/[^/]+$	-	/api/v4/retro-banner/settings/:password
GET	^/api/v4/retro2026-analytics/[^/]+$	-	/api/v4/retro2026-analytics/:password
GET	^/api/v4/rss-status/[^/]+$	-	/api/v4/rss-status/:password
GET	^/api/v4/share-clip-analytics/[^/]+$	-	/api/v4/share-clip-analytics/:password
GET	^/api/v4/unique-users/[^/]+$	-	/api/v4/unique-users/:password
GET	^/api/v4/version-adoption-daily/[^/]+/[^/]+$	-	/api/v4/version-adoption-daily/:days/:password
GET	^/api/v4/version-distribution/[^/]+$	-	/api/v4/version-distribution/:password
GET	^/api/v4/version-signals-hourly/[^/]+/[^/]+$	-	/api/v4/version-signals-hourly/:date/:password
GET	^/api/v4/watch-pairing-rate/[^/]+$	-	/api/v4/watch-pairing-rate/:password
GET	^/api/v4/weekly-highlights-stats/[^/]+$	-	/api/v4/weekly-highlights-stats/:password
GET	^/api/v4/widget-summary/[^/]+$	-	/api/v4/widget-summary/:password
POST	^/api/v3/create-author/[^/]+$	-	/api/v3/create-author/:password
POST	^/api/v3/create-music-genre/[^/]+$	-	/api/v3/create-music-genre/:password
POST	^/api/v3/create-song/[^/]+$	-	/api/v3/create-song/:password
POST	^/api/v3/create-sound/[^/]+$	-	/api/v3/create-sound/:password
POST	^/api/v3/import-authors/[^/]+$	-	/api/v3/import-authors/:password
POST	^/api/v3/import-music-genres/[^/]+$	-	/api/v3/import-music-genres/:password
POST	^/api/v3/import-songs/[^/]+$	-	/api/v3/import-songs/:password
POST	^/api/v3/import-sounds/[^/]+$	-	/api/v3/import-sounds/:password
POST	^/api/v3/set-donor-names/[^/]+$	-	/api/v3/set-donor-names/:password
POST	^/api/v3/update-content-file/[^/]+/[^/]+/[^/]+$	-	/api/v3/update-content-file/:type/:id/:password
POST	^/api/v4/add-sounds-to-reaction/[^/]+$	-	/api/v4/add-sounds-to-reaction/:password
POST	^/api/v4/anniversary-banner/[^/]+$	-	/api/v4/anniversary-banner/:password
POST	^/api/v4/create-reaction/[^/]+$	-	/api/v4/create-reaction/:password
POST	^/api/v4/dynamic-banner/[^/]+$	-	/api/v4/dynamic-banner/:password
POST	^/api/v4/election/channels/[^/]+$	-	/api/v4/election/channels/:password
POST	^/api/v4/election/settings/[^/]+$	-	/api/v4/election/settings/:password
POST	^/api/v4/episode-highlight/[^/]+$	-	/api/v4/episode-highlight/:password
POST	^/api/v4/money-info/[^/]+$	-	/api/v4/money-info/:password
POST	^/api/v4/promo-banner/[^/]+$	-	/api/v4/promo-banner/:password
POST	^/api/v4/push-broadcast/[^/]+/cancel/[^/]+$	-	/api/v4/push-broadcast/:id/cancel/:password
POST	^/api/v4/push-broadcasts/[^/]+$	-	/api/v4/push-broadcasts/:password
POST	^/api/v4/repair-share-count-stat-content-types/[^/]+$	-	/api/v4/repair-share-count-stat-content-types/:password
POST	^/api/v4/replace-device-model-name/[^/]+/[^/]+/[^/]+$	-	/api/v4/replace-device-model-name/:password/:oldName/:newName
POST	^/api/v4/retro-banner/[^/]+$	-	/api/v4/retro-banner/:password
POST	^/api/v4/test-new-episode-push/[^/]+$	-	/api/v4/test-new-episode-push/:password
POST	^/api/v4/test-weekly-highlights-push/[^/]+$	-	/api/v4/test-weekly-highlights-push/:password
PUT	^/api/v3/change-update-visibility/[^/]+/[^/]+/[^/]+$	-	/api/v3/change-update-visibility/:updateId/:newValue/:password
PUT	^/api/v3/update-author/[^/]+$	-	/api/v3/update-author/:password
PUT	^/api/v3/update-content/[^/]+$	-	/api/v3/update-content/:password
PUT	^/api/v4/reaction/[^/]+$	-	/api/v4/reaction/:password
ROUTES

total=0
all_hits=""
printf '%8s  %-28s  %s\n' "calls" "latest one" "log file"
for log in "$@"; do
    [ -f "$log" ] || continue
    case "$log" in
        *.gz) reader=(gzip -dc -- "$log") ;;
        *)    reader=(cat -- "$log") ;;
    esac
    # Prints the route pattern of each old-style call, then "#latest<TAB>time" if there was one.
    hits=$("${reader[@]}" | awk -F'"' '
        # "GET /api/v4/unique-users": method plus the first three path segments, which
        # are constant in every admin route, so each line is checked against its own
        # route only instead of all 72.
        function key(method, path,    p) {
            split(path, p, "/")
            return method " /" p[2] "/" p[3] "/" p[4]
        }
        # First file: the route list, one tab-separated route per line.
        NR == FNR {
            split($0, f, "\t")
            n++
            re[n] = f[2]; excl[n] = f[3]; name[n] = f[1] " " f[4]
            k = key(f[1], f[4])
            bucket[k] = bucket[k] " " n
            next
        }
        {
            split($2, req, " ")
            path = req[2]
            sub(/\?.*/, "", path)
            k = key(req[1], path)
            if (!(k in bucket)) next
            m = split(bucket[k], ids, " ")
            for (j = 1; j <= m; j++) {
                i = ids[j]
                if (path ~ re[i] && (excl[i] == "-" || path !~ excl[i])) {
                    print name[i]
                    latest = $1
                    break
                }
            }
        }
        END {
            if (latest != "") {
                sub(/^[^[]*\[/, "", latest)
                sub(/\].*$/, "", latest)
                print "#latest\t" latest
            }
        }' "$routes_file" -)
    count=0
    latest="-"
    if [ -n "$hits" ]; then
        latest=$(printf '%s\n' "$hits" | grep '^#latest' | cut -f2)
        hits=$(printf '%s\n' "$hits" | grep -v '^#latest' || true)
        count=$(printf '%s\n' "$hits" | grep -c . || true)
        all_hits+="$hits"$'\n'
    fi
    printf '%8d  %-28s  %s\n' "$count" "$latest" "$log"
    total=$(( total + count ))
done

echo
echo "Total: $total"
if [ "$total" -gt 0 ]; then
    echo
    printf '%s' "$all_hits" | grep . | sort | uniq -c | sort -rn
fi
