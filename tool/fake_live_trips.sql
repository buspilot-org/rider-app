-- Development only: fake live state for the demo operator of the server seed
-- (buspilot-org/server, supabase/seed.sql), until the engine fills
-- trip_instance and stop_event. Run with tool/fake_live_trips.sh against the
-- LOCAL Supabase database; never against a shared one.
--
-- Adds three trips of the demo pattern for today (Asia/Tokyo), relative to now:
--   - started 14 minutes ago, active, about 4 minutes late
--   - starts in 40 minutes, planned
--   - starts in 80 minutes, cancelled
-- and a vehicle position for the active one. Running it again replaces them.
--
-- psql variable `map` (on/off): make route A an invited_map route the demo
-- audience may see on a map, or restore arrival times only.

\set ON_ERROR_STOP on

begin;

-- Only a database with the demo seed: refuse anything else, even when it is
-- reachable on 127.0.0.1 (a tunnel to a shared database, say).
do $$
begin
  if not exists (select 1 from public.operator
                  where id = 'd0000000-0000-4000-8000-000000000001' and slug = 'demo-kobe' and plan = 'demo')
     or (select count(*) from public.operator) > 5 then
    raise exception 'not the local demo database: refusing to write fake data';
  end if;
end;
$$;

create temporary table dev_now on commit drop as
select
  (now() at time zone 'Asia/Tokyo')::date as today,
  extract(epoch from (now() at time zone 'Asia/Tokyo')::time)::integer as secs;

-- Remove the previous run.
delete from public.trip_instance
 where trip_id in (select id from public.trip where gtfs_id like 'dev-live-%');
delete from public.trip where gtfs_id like 'dev-live-%';

-- A calendar that runs today only.
insert into public.service_calendar (id, operator_id, gtfs_id, name, weekdays, start_date, end_date, skip_national_holidays)
select 'd0000000-0000-4000-8000-0000000009c1', 'd0000000-0000-4000-8000-000000000001',
       'dev-live', 'Development: today only', 127, today, today, false
  from dev_now
on conflict (id) do update set start_date = excluded.start_date, end_date = excluded.end_date;

insert into public.trip (id, operator_id, gtfs_id, pattern_id, service_calendar_id, start_time, headsign)
select v.id::uuid, 'd0000000-0000-4000-8000-000000000001', v.gtfs_id,
       'd0000000-0000-4000-8000-000000000301', 'd0000000-0000-4000-8000-0000000009c1',
       greatest(0, d.secs + v.offset_s), '{"en": "School", "ja": "学校"}'
  from dev_now d,
       (values ('d0000000-0000-4000-8000-0000000009a1', 'dev-live-active', -14 * 60),
               ('d0000000-0000-4000-8000-0000000009a2', 'dev-live-planned', 40 * 60),
               ('d0000000-0000-4000-8000-0000000009a3', 'dev-live-cancelled', 80 * 60))
       as v (id, gtfs_id, offset_s);

insert into public.trip_instance (id, operator_id, service_date, kind, trip_id, vehicle_id, status, started_at, progress_at, last_confirmed_stop_sequence)
select v.id::uuid, 'd0000000-0000-4000-8000-000000000001', d.today, 'scheduled', v.trip_id::uuid,
       case when v.status = 'active' then 'd0000000-0000-4000-8000-000000000701'::uuid end,
       v.status::public.trip_instance_status,
       case when v.status = 'active' then now() - interval '14 minutes' end,
       case when v.status = 'active' then now() end,
       case when v.status = 'active' then 3 end
  from dev_now d,
       (values ('d0000000-0000-4000-8000-0000000009b1', 'd0000000-0000-4000-8000-0000000009a1', 'active'),
               ('d0000000-0000-4000-8000-0000000009b2', 'd0000000-0000-4000-8000-0000000009a2', 'planned'),
               ('d0000000-0000-4000-8000-0000000009b3', 'd0000000-0000-4000-8000-0000000009a3', 'cancelled'))
       as v (id, trip_id, status);

-- Stop events of the active trip: stops 1–3 departed, 4 approaching, 5–6
-- upcoming; everything about 4 minutes behind the timetable.
insert into public.stop_event (operator_id, trip_instance_id, stop_sequence, state, eta, approaching_at, arrived_at, departed_at)
select 'd0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-0000000009b1', ps.stop_sequence,
       case when ps.stop_sequence <= 3 then 'departed'
            when ps.stop_sequence = 4 then 'approaching'
            else 'upcoming' end::public.stop_event_state,
       t0 + make_interval(secs => ps.arrival_offset + 240),
       case when ps.stop_sequence = 4 then now() end,
       case when ps.stop_sequence <= 3 then t0 + make_interval(secs => ps.arrival_offset + 200) end,
       case when ps.stop_sequence <= 3 then t0 + make_interval(secs => ps.departure_offset + 240) end
  from public.pattern_stop ps,
       (select now() - interval '14 minutes' as t0) s
 where ps.pattern_id = 'd0000000-0000-4000-8000-000000000301';

insert into public.stop_event (operator_id, trip_instance_id, stop_sequence, eta)
select 'd0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-0000000009b2', ps.stop_sequence,
       now() + interval '40 minutes' + make_interval(secs => ps.arrival_offset)
  from public.pattern_stop ps
 where ps.pattern_id = 'd0000000-0000-4000-8000-000000000301';

-- Between Sannomiya and Motomachi.
insert into public.vehicle_state (vehicle_id, operator_id, trip_instance_id, location, speed_kmh, heading, recorded_at)
values ('d0000000-0000-4000-8000-000000000701', 'd0000000-0000-4000-8000-000000000001',
        'd0000000-0000-4000-8000-0000000009b1', 'SRID=4326;POINT(135.1912 34.6922)', 22, 240, now())
on conflict (vehicle_id) do update
  set trip_instance_id = excluded.trip_instance_id, location = excluded.location,
      recorded_at = excluded.recorded_at, speed_kmh = excluded.speed_kmh, heading = excluded.heading;

update public.route
   set visibility = case when :'map' = 'on' then 'invited_map'::public.route_visibility end
 where id = 'd0000000-0000-4000-8000-000000000101';
update public.audience_route
   set can_see_map = (:'map' = 'on')
 where route_id = 'd0000000-0000-4000-8000-000000000101';

commit;

select ti.status, t.gtfs_id, to_char((timestamp '2000-01-01' + make_interval(secs => t.start_time)), 'HH24:MI') as starts
  from public.trip_instance ti join public.trip t on t.id = ti.trip_id
 where t.gtfs_id like 'dev-live-%'
 order by t.start_time;
