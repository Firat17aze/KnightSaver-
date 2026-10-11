-- Hackathon demo only: six earlier verified pickups for alex@ucf.edu at Knightro's, so the
-- server-backed Rewards tab has Saver Cash, a toy, badges and league points to show, and
-- Alex joins the league as "Sir Alex". Run after seed.sql and the rewards migration, once
-- both demo accounts exist. Safe to run again. Delete these rows before launch.
do $$
declare
  alex uuid := (select id from auth.users where email = 'alex@ucf.edu');
  manager uuid := (select id from auth.users where email = 'manager@knightros.example');
  campus uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  kitchen uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  location uuid := 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  listing uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  tz text := 'America/New_York';
  pickup record;
  picked_up_at timestamptz;
  food_kg numeric;
  reservation uuid;
  verification uuid;
begin
  if alex is null or manager is null then
    raise exception 'Sign in once with both demo accounts first, so they exist.';
  end if;

  update public.profiles
  set display_name = 'Alex Knight', league_opt_in = true, league_nickname = coalesce(league_nickname, 'Sir Alex')
  where id = alex;

  for pickup in
    select * from (values
      (1, 'KS-D101', 12, 30, 1, null::numeric),
      (2, 'KS-D102', 20, 40, 1, 0.60),
      (6, 'KS-D103', 17, 15, 2, null),
      (9, 'KS-D104', 13, 5, 1, 0.48),
      (16, 'KS-D105', 18, 0, 1, null),
      (23, 'KS-D106', 12, 45, 1, null)
    ) as t(days_ago, code, hour, minute, bags, weighed_kg)
  loop
    continue when exists (select 1 from public.reservations where code = pickup.code);
    picked_up_at := (((now() at time zone tz)::date - pickup.days_ago) + make_time(pickup.hour, pickup.minute, 0)) at time zone tz;
    food_kg := coalesce(pickup.weighed_kg, 0.45 * pickup.bags);

    insert into public.reservations (code, listing_id, student_id, quantity, unit_price_cents, status, payment_status, verified_at, created_at)
    values (pickup.code, listing, alex, pickup.bags, 599, 'pickup_verified', 'captured', picked_up_at, picked_up_at - interval '3 hours')
    returning id into reservation;

    insert into public.pickup_verifications (reservation_id, verified_by, location_id, measured_weight_kg, idempotency_key, verified_at)
    values (reservation, manager, location, pickup.weighed_kg, 'demo-' || pickup.code, picked_up_at)
    returning id into verification;

    insert into public.impact_events (
      verification_id, student_id, business_id, campus_id, bags, measured_weight_kg, estimated_weight_kg,
      co2e_factor, estimated_co2e_kg, revenue_cents, occurred_at
    ) values (
      verification, alex, kitchen, campus, pickup.bags, pickup.weighed_kg,
      case when pickup.weighed_kg is null then food_kg else 0 end,
      2.5, food_kg * 2.5, pickup.bags * 599, picked_up_at
    );

    insert into public.leaderboard_events (verification_id, student_id, campus_id, score_date)
    values (verification, alex, campus, (picked_up_at at time zone tz)::date)
    on conflict (student_id, campus_id, score_date) do nothing;
  end loop;
end;
$$;
