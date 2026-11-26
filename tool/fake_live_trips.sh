#!/usr/bin/env bash
# Fake live trips and ETAs in the LOCAL Supabase database (development only).
#
#   tool/fake_live_trips.sh          # arrival times only (seed default)
#   tool/fake_live_trips.sh --map    # route A visible on the map as well
#   tool/fake_live_trips.sh --clean  # remove the fake trips
#
# DB_URL defaults to the local stack of buspilot-org/server.
set -euo pipefail

DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:55322/postgres}"
case "$DB_URL" in
  *@127.0.0.1:*|*@localhost:*) ;;
  *) echo "Refusing to write fake data to a non-local database: $DB_URL" >&2; exit 1 ;;
esac

here="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
  --clean)
    psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
delete from public.trip_instance where trip_id in (select id from public.trip where gtfs_id like 'dev-live-%');
delete from public.trip_instance where id = 'd0000000-0000-4000-8000-0000000009d1';
delete from public.trip where gtfs_id like 'dev-live-%';
delete from public.service_calendar where gtfs_id = 'dev-live';
update public.route set visibility = null where id = 'd0000000-0000-4000-8000-000000000101';
update public.audience_route set can_see_map = false where route_id = 'd0000000-0000-4000-8000-000000000101';
SQL
    ;;
  --map) psql "$DB_URL" -v map=on -f "$here/fake_live_trips.sql" ;;
  "") psql "$DB_URL" -v map=off -f "$here/fake_live_trips.sql" ;;
  *) echo "usage: $0 [--map|--clean]" >&2; exit 2 ;;
esac
