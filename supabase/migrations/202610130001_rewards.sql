-- Rewards tab: Saver Cash, partner rewards, badges and the Campus Rescue League.
-- Everything counts staff-verified pickups only: one row in impact_events per verified pickup.
-- Saver Cash is spent at campus partner kitchens: staff scan the student's Saver Cash QR (it
-- carries their Knight Pass token). Partner rewards (toys, a keychain, a seed kit…) come from
-- shops off campus that don't use KnightSaver: the student taps "Use at the shop" at the counter
-- and the cashier sees a one-time code.
-- Run after 202610100001_initial_schema.sql.

-- pgcrypto lives in the "extensions" schema on Supabase, and these functions run with an empty
-- search_path, so its functions must be named in full. The first migration called them bare,
-- which failed ("function gen_random_bytes(integer) does not exist").
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create or replace function public.get_knight_pass_token()
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  raw_token text := encode(extensions.gen_random_bytes(24), 'hex');
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  update public.profiles
  set pass_token_hash = encode(extensions.digest(raw_token, 'sha256'), 'hex')
  where id = auth.uid();
  return raw_token;
end;
$$;

create or replace function public.scan_knight_pass(
  p_token text,
  p_location_id uuid,
  p_now timestamptz default now()
)
returns table (
  reservation_id uuid,
  code text,
  student_display_name text,
  quantity integer,
  reservation_status text,
  already_verified boolean
)
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_staff_of_location(p_location_id) then raise exception 'not authorized'; end if;
  return query
  select r.id, r.code, p.display_name, r.quantity, r.status,
         exists(select 1 from public.pickup_verifications pv where pv.reservation_id = r.id)
  from public.profiles p
  join public.reservations r on r.student_id = p.id
  join public.listings l on l.id = r.listing_id
  where p.pass_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
    and l.location_id = p_location_id
    and (
      (r.status = 'authorized' and p_now between l.pickup_start - interval '15 minutes' and l.pickup_end + interval '15 minutes')
      or (r.status = 'pickup_verified' and r.verified_at > p_now - interval '3 hours')
    )
  order by l.pickup_start;
end;
$$;

-- Shops off campus that give KnightSaver students a reward. Hackathon demo partners: the names
-- are made up and must be replaced by real signed partners before launch.
create table if not exists public.reward_partners (
  id text primary key,
  name text not null,
  area text not null
);

insert into public.reward_partners (id, name, area) values
  ('lantern-toys', 'Lantern Toys', 'Waterford Lakes'),
  ('paper-owl-books', 'Paper Owl Books', 'University Blvd'),
  ('sprout-and-soil', 'Sprout & Soil', 'Oviedo'),
  ('spoke-line-bikes', 'Spoke Line Bikes', 'Alafaya Trail')
on conflict (id) do update set name = excluded.name, area = excluded.area;

-- What each number of verified pickups unlocks: Saver Cash or one partner reward.
-- Mirrors RewardRoad.milestones in the app.
create table if not exists public.reward_milestones (
  orders integer primary key check (orders > 0),
  cash_cents integer check (cash_cents > 0),
  reward_id text unique,
  reward_name text,
  partner_id text references public.reward_partners(id),
  check ((cash_cents is null) <> (reward_id is null)),
  check ((reward_id is null) = (partner_id is null))
);

insert into public.reward_milestones (orders, cash_cents, reward_id, reward_name, partner_id) values
  (1, 100, null, null, null),
  (3, 200, null, null, null),
  (5, null, 'mini-toy', 'Mystery mini toy', 'lantern-toys'),
  (8, 300, null, null, null),
  (10, null, 'bookworm-keychain', 'Bookworm keychain', 'paper-owl-books'),
  (12, 400, null, null, null),
  (15, null, 'herb-seed-kit', 'Herb seed kit', 'sprout-and-soil'),
  (18, 500, null, null, null),
  (20, null, 'bike-tune-up', 'Free bike tune-up', 'spoke-line-bikes'),
  (25, 800, null, null, null),
  (30, null, 'golden-knight', 'Golden Knight plush', 'lantern-toys')
on conflict (orders) do update set
  cash_cents = excluded.cash_cents,
  reward_id = excluded.reward_id,
  reward_name = excluded.reward_name,
  partner_id = excluded.partner_id;

-- Saver Cash staff took off a bill. Earned cash isn't stored: it follows from the verified
-- pickups and reward_milestones, so the balance is earned minus these.
create table if not exists public.saver_cash_spends (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id),
  business_id uuid not null references public.businesses(id),
  location_id uuid not null references public.business_locations(id),
  amount_cents integer not null check (amount_cents > 0),
  redeemed_by uuid not null references public.profiles(id),
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);
create index if not exists saver_cash_spends_student on public.saver_cash_spends (student_id);

-- Partner rewards students used at the shop. One of each per student; the code is what the
-- cashier sees on the student's screen.
create table if not exists public.partner_reward_redemptions (
  student_id uuid not null references public.profiles(id),
  reward_id text not null references public.reward_milestones(reward_id),
  code text not null unique,
  redeemed_at timestamptz not null default now(),
  primary key (student_id, reward_id)
);

-- Hackathon only: fixed rivals so the league isn't empty before real students join.
-- Delete these rows before launch.
create table if not exists public.league_demo_entries (
  nickname text primary key,
  week_points integer not null default 0 check (week_points >= 0),
  all_time_points integer not null default 0 check (all_time_points >= 0)
);
insert into public.league_demo_entries (nickname, week_points, all_time_points) values
  ('BagelBaron', 6, 57),
  ('SirScraps', 5, 61),
  ('MossKnight', 5, 44),
  ('LadyLeftover', 4, 49),
  ('Gr8Rescuer', 4, 38),
  ('CroissantQuest', 3, 31),
  ('NightOwlNom', 2, 22)
on conflict (nickname) do update set
  week_points = excluded.week_points,
  all_time_points = excluded.all_time_points;

-- League nicknames are unique among students who joined.
create unique index if not exists profiles_league_nickname_unique
  on public.profiles (lower(league_nickname))
  where league_opt_in and league_nickname is not null;

alter table public.reward_partners enable row level security;
alter table public.reward_milestones enable row level security;
alter table public.saver_cash_spends enable row level security;
alter table public.partner_reward_redemptions enable row level security;
alter table public.league_demo_entries enable row level security;

drop policy if exists reward_partners_read on public.reward_partners;
create policy reward_partners_read on public.reward_partners for select using (true);
drop policy if exists reward_milestones_read on public.reward_milestones;
create policy reward_milestones_read on public.reward_milestones for select using (true);
drop policy if exists cash_spends_owner_or_staff_read on public.saver_cash_spends;
create policy cash_spends_owner_or_staff_read on public.saver_cash_spends for select using (
  student_id = auth.uid() or public.is_staff_of_business(business_id)
);
drop policy if exists redemptions_owner_read on public.partner_reward_redemptions;
create policy redemptions_owner_read on public.partner_reward_redemptions for select using (student_id = auth.uid());
-- league_demo_entries has no policy: it's read only through get_league.

-- The league used to be readable row by row, with student ids. It now comes from get_league,
-- which returns nicknames only, so students can read just their own rows.
drop policy if exists leaderboard_public_read on public.leaderboard_events;
drop policy if exists leaderboard_own_read on public.leaderboard_events;
create policy leaderboard_own_read on public.leaderboard_events for select using (student_id = auth.uid());

-- Helpers. Not granted to the app; the RPCs below call them.

create or replace function public.rewards_timezone(p_student uuid)
returns text
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select c.timezone from public.profiles p join public.campuses c on c.id = p.campus_id where p.id = p_student),
    'America/New_York'
  );
$$;

create or replace function public.rewards_verified_pickups(p_student uuid)
returns integer
language sql stable security definer set search_path = ''
as $$
  select count(*)::integer from public.impact_events where student_id = p_student;
$$;

create or replace function public.rewards_cash_earned(p_student uuid)
returns integer
language sql stable security definer set search_path = ''
as $$
  select coalesce(sum(m.cash_cents), 0)::integer
  from public.reward_milestones m
  where m.cash_cents is not null and m.orders <= public.rewards_verified_pickups(p_student);
$$;

create or replace function public.rewards_cash_spent(p_student uuid)
returns integer
language sql stable security definer set search_path = ''
as $$
  select coalesce(sum(amount_cents), 0)::integer from public.saver_cash_spends where student_id = p_student;
$$;

-- League points: one per campus-local day with a verified pickup, since p_since (null: all time).
create or replace function public.rewards_points(p_student uuid, p_since date)
returns integer
language sql stable security definer set search_path = ''
as $$
  select count(distinct (ie.occurred_at at time zone c.timezone)::date)::integer
  from public.impact_events ie
  join public.campuses c on c.id = ie.campus_id
  where ie.student_id = p_student
    and (p_since is null or (ie.occurred_at at time zone c.timezone)::date >= p_since);
$$;

-- Weeks in a row (Monday to Sunday) with a verified pickup. A week with no pickup yet doesn't
-- break the streak, matching the app.
create or replace function public.rewards_weekly_streak(p_student uuid)
returns integer
language plpgsql stable security definer set search_path = ''
as $$
declare
  tz text := public.rewards_timezone(p_student);
  week date := date_trunc('week', now() at time zone tz)::date;
  streak integer := 0;
begin
  if not exists (
    select 1 from public.impact_events
    where student_id = p_student and date_trunc('week', occurred_at at time zone tz)::date = week
  ) then
    week := week - 7;
  end if;
  while exists (
    select 1 from public.impact_events
    where student_id = p_student and date_trunc('week', occurred_at at time zone tz)::date = week
  ) loop
    streak := streak + 1;
    week := week - 7;
  end loop;
  return streak;
end;
$$;

create or replace function public.rewards_week_ends_at(p_tz text)
returns timestamptz
language sql stable set search_path = ''
as $$
  select ((date_trunc('week', now() at time zone p_tz) + interval '7 days') at time zone p_tz);
$$;

-- Student RPCs

-- Everything the Rewards tab shows about the signed-in student.
create or replace function public.get_my_rewards()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  me uuid := auth.uid();
  me_profile public.profiles;
  tz text;
begin
  if me is null then raise exception 'authentication required'; end if;
  select * into me_profile from public.profiles where id = me;
  tz := public.rewards_timezone(me);
  return jsonb_build_object(
    'orders', public.rewards_verified_pickups(me),
    'bags', (select coalesce(sum(bags), 0) from public.impact_events where student_id = me),
    'kitchens', (select count(distinct business_id) from public.impact_events where student_id = me),
    'measured_kg', (select coalesce(sum(measured_weight_kg), 0) from public.impact_events where student_id = me),
    'co2e_kg', (select coalesce(sum(estimated_co2e_kg), 0) from public.impact_events where student_id = me),
    'night_pickup', exists (
      select 1 from public.impact_events ie join public.campuses c on c.id = ie.campus_id
      where ie.student_id = me and extract(hour from ie.occurred_at at time zone c.timezone) >= 20
    ),
    'weekly_streak', public.rewards_weekly_streak(me),
    'cash_earned_cents', public.rewards_cash_earned(me),
    'cash_spent_cents', public.rewards_cash_spent(me),
    'redeemed', coalesce(
      (select jsonb_agg(jsonb_build_object('reward_id', reward_id, 'code', code, 'redeemed_at', redeemed_at) order by redeemed_at)
       from public.partner_reward_redemptions where student_id = me),
      '[]'::jsonb
    ),
    'points_this_week', public.rewards_points(me, date_trunc('week', now() at time zone tz)::date),
    'points_all_time', public.rewards_points(me, null),
    'league_opt_in', coalesce(me_profile.league_opt_in, false),
    'league_nickname', me_profile.league_nickname,
    'week_ends_at', public.rewards_week_ends_at(tz)
  );
end;
$$;

-- The Campus Rescue League for 'week' or 'all_time': the top 10 by nickname, plus the caller's
-- own row. Students who haven't joined are never listed.
create or replace function public.get_league(p_period text default 'week')
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  me uuid := auth.uid();
  tz text := public.rewards_timezone(auth.uid());
  since date;
  result jsonb;
begin
  if me is null then raise exception 'authentication required'; end if;
  if p_period not in ('week', 'all_time') then raise exception 'period must be week or all_time'; end if;
  if p_period = 'week' then since := date_trunc('week', now() at time zone tz)::date; end if;

  with players as (
    select p.league_nickname as nickname, p.id = me as is_you, public.rewards_points(p.id, since) as points
    from public.profiles p
    where p.league_opt_in and p.league_nickname is not null and p.account_role = 'student'
    union all
    select d.nickname, false, case when since is null then d.all_time_points else d.week_points end
    from public.league_demo_entries d
    where not exists (
      select 1 from public.profiles p
      where p.league_opt_in and lower(p.league_nickname) = lower(d.nickname)
    )
  ),
  ranked as (
    select nickname, is_you, points,
           rank() over (order by points desc)::integer as rank,
           row_number() over (order by points desc, is_you desc, nickname) as position
    from players
  )
  select jsonb_build_object(
    'entries', coalesce(
      (select jsonb_agg(jsonb_build_object('rank', rank, 'nickname', nickname, 'points', points, 'is_you', is_you) order by position)
       from ranked where position <= 10),
      '[]'::jsonb
    ),
    'you', (select jsonb_build_object('rank', rank, 'nickname', nickname, 'points', points, 'is_you', true)
            from ranked where is_you limit 1),
    'week_ends_at', public.rewards_week_ends_at(tz)
  ) into result;
  return result;
end;
$$;

-- Joins or leaves the league. Nicknames are 2 to 20 characters and unique.
create or replace function public.set_league_profile(p_opt_in boolean, p_nickname text default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  clean text := nullif(btrim(coalesce(p_nickname, '')), '');
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if p_opt_in then
    if clean is null or char_length(clean) < 2 or char_length(clean) > 20 then
      raise exception 'Use a nickname of 2 to 20 characters.';
    end if;
    if exists (
      select 1 from public.profiles
      where league_opt_in and lower(league_nickname) = lower(clean) and id <> auth.uid()
    ) or exists (select 1 from public.league_demo_entries where lower(nickname) = lower(clean)) then
      raise exception 'That nickname is taken. Try another one.';
    end if;
  end if;
  update public.profiles
  set league_opt_in = p_opt_in,
      league_nickname = coalesce(clean, league_nickname),
      updated_at = now()
  where id = auth.uid();
  return jsonb_build_object('league_opt_in', p_opt_in, 'league_nickname', coalesce(clean, (select league_nickname from public.profiles where id = auth.uid())));
end;
$$;

-- Uses a partner reward at the shop: it must be unlocked by verified pickups. Returns the
-- one-time code the cashier sees. Using it again returns the first code and time, unchanged.
create or replace function public.redeem_partner_reward(p_reward_id text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := auth.uid();
  milestone public.reward_milestones;
  used public.partner_reward_redemptions;
begin
  if me is null then raise exception 'authentication required'; end if;
  select * into milestone from public.reward_milestones where reward_id = p_reward_id;
  if milestone.orders is null then raise exception 'Unknown partner reward.'; end if;
  if public.rewards_verified_pickups(me) < milestone.orders then
    raise exception '% unlocks at % verified pickups.', milestone.reward_name, milestone.orders;
  end if;
  insert into public.partner_reward_redemptions (student_id, reward_id, code)
  values (me, p_reward_id, 'KS-' || upper(encode(extensions.gen_random_bytes(3), 'hex')))
  on conflict (student_id, reward_id) do nothing;
  select * into used from public.partner_reward_redemptions where student_id = me and reward_id = p_reward_id;
  return jsonb_build_object('reward_id', used.reward_id, 'code', used.code, 'redeemed_at', used.redeemed_at);
end;
$$;

-- Staff RPCs at campus partner kitchens. p_token is the Knight Pass token inside the student's
-- Saver Cash QR. p_location_id
-- may be left out: it then defaults to the caller's own pickup location.

create or replace function public.rewards_staff_location(p_location_id uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    p_location_id,
    (select coalesce(sm.location_id, (
              select bl.id from public.business_locations bl
              where bl.business_id = sm.business_id and bl.is_active
              order by bl.created_at limit 1))
     from public.staff_memberships sm
     where sm.user_id = auth.uid()
     order by sm.created_at
     limit 1)
  );
$$;

-- The student's Saver Cash at this counter.
create or replace function public.scan_rewards(p_token text, p_location_id uuid default null)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  location uuid := public.rewards_staff_location(p_location_id);
  student public.profiles;
begin
  if location is null or not public.is_staff_of_location(location) then raise exception 'not authorized'; end if;
  select * into student from public.profiles
  where pass_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  if student.id is null then raise exception 'No KnightSaver account matches this pass.'; end if;
  return jsonb_build_object(
    'student_display_name', student.display_name,
    'verified_pickups', public.rewards_verified_pickups(student.id),
    'cash_balance_cents', public.rewards_cash_earned(student.id) - public.rewards_cash_spent(student.id)
  );
end;
$$;

-- Takes Saver Cash off a bill. Safe to retry with the same p_idempotency_key.
create or replace function public.redeem_saver_cash(
  p_token text,
  p_amount_cents integer,
  p_idempotency_key text,
  p_location_id uuid default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  location uuid := public.rewards_staff_location(p_location_id);
  student public.profiles;
  existing public.saver_cash_spends;
  kitchen uuid;
  balance integer;
begin
  if location is null or not public.is_staff_of_location(location) then raise exception 'not authorized'; end if;
  select * into existing from public.saver_cash_spends where idempotency_key = p_idempotency_key;
  if existing.id is not null then
    return jsonb_build_object(
      'kind', 'already_redeemed',
      'amount_cents', existing.amount_cents,
      'balance_cents', public.rewards_cash_earned(existing.student_id) - public.rewards_cash_spent(existing.student_id)
    );
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then raise exception 'Enter an amount above $0.'; end if;
  select * into student from public.profiles
  where pass_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  if student.id is null then raise exception 'No KnightSaver account matches this pass.'; end if;
  -- One redemption at a time per student, so two counters can't spend the same balance.
  perform pg_advisory_xact_lock(hashtext('saver_cash:' || student.id::text));
  balance := public.rewards_cash_earned(student.id) - public.rewards_cash_spent(student.id);
  if p_amount_cents > balance then
    raise exception 'Only $%.% Saver Cash left.', balance / 100, lpad((balance % 100)::text, 2, '0');
  end if;
  select business_id into kitchen from public.business_locations where id = location;
  insert into public.saver_cash_spends (student_id, business_id, location_id, amount_cents, redeemed_by, idempotency_key)
  values (student.id, kitchen, location, p_amount_cents, auth.uid(), p_idempotency_key);
  return jsonb_build_object(
    'kind', 'redeemed',
    'student_display_name', student.display_name,
    'amount_cents', p_amount_cents,
    'balance_cents', balance - p_amount_cents
  );
end;
$$;

revoke all on function public.rewards_timezone(uuid) from public, anon, authenticated;
revoke all on function public.rewards_verified_pickups(uuid) from public, anon, authenticated;
revoke all on function public.rewards_cash_earned(uuid) from public, anon, authenticated;
revoke all on function public.rewards_cash_spent(uuid) from public, anon, authenticated;
revoke all on function public.rewards_points(uuid, date) from public, anon, authenticated;
revoke all on function public.rewards_weekly_streak(uuid) from public, anon, authenticated;
revoke all on function public.rewards_staff_location(uuid) from public, anon, authenticated;

grant select on public.reward_partners, public.reward_milestones to anon, authenticated;
grant select on public.saver_cash_spends, public.partner_reward_redemptions to authenticated;
grant execute on function public.get_my_rewards() to authenticated;
grant execute on function public.get_league(text) to authenticated;
grant execute on function public.set_league_profile(boolean, text) to authenticated;
grant execute on function public.redeem_partner_reward(text) to authenticated;
grant execute on function public.scan_rewards(text, uuid) to authenticated;
grant execute on function public.redeem_saver_cash(text, integer, text, uuid) to authenticated;
