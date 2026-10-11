-- KnightSaver hackathon backend
-- The database, not the iOS client, owns inventory and verified-impact state.

create extension if not exists pgcrypto;

create table if not exists public.campuses (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  timezone text not null default 'America/New_York',
  weekly_goal integer not null default 600 check (weekly_goal > 0),
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  account_role text not null default 'student' check (account_role in ('student', 'business')),
  campus_id uuid references public.campuses(id),
  phone_number text,
  league_opt_in boolean not null default false,
  league_nickname text,
  pass_token_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  campus_id uuid not null references public.campuses(id),
  name text not null,
  brand_key text not null default 'knightros',
  banner_asset_name text not null default 'BannerCafeBrunch',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (campus_id, name)
);

create table if not exists public.business_locations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  address text not null,
  latitude double precision not null,
  longitude double precision not null,
  timezone text not null default 'America/New_York',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (business_id, address)
);

create table if not exists public.staff_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  location_id uuid references public.business_locations(id) on delete cascade,
  role text not null default 'staff' check (role in ('staff', 'manager')),
  created_at timestamptz not null default now()
);

create unique index if not exists staff_membership_scope_unique
  on public.staff_memberships (user_id, business_id, coalesce(location_id, '00000000-0000-0000-0000-000000000000'::uuid));

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  location_id uuid not null references public.business_locations(id),
  created_by uuid references public.profiles(id),
  label text not null default 'Surprise Bag',
  is_surprise boolean not null default true,
  price_cents integer not null check (price_cents >= 0),
  total_quantity integer not null check (total_quantity >= 0),
  remaining_quantity integer not null check (remaining_quantity >= 0 and remaining_quantity <= total_quantity),
  pickup_start timestamptz not null,
  pickup_end timestamptz not null,
  public_description text not null,
  banner_asset_name text not null default 'BannerCafeBrunch',
  status text not null default 'available' check (status in ('draft', 'available', 'fully_reserved', 'paused', 'closed', 'cancelled')),
  estimated_kg_per_bag numeric(8,3) not null default 0.45 check (estimated_kg_per_bag >= 0),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (pickup_end > pickup_start)
);

create index if not exists listings_live_pickup_idx
  on public.listings (pickup_start)
  where status in ('available', 'fully_reserved');

create table if not exists public.listing_inventory (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  item_name text not null,
  quantity integer not null check (quantity > 0),
  bag_allocation jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.reservations (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  listing_id uuid not null references public.listings(id),
  student_id uuid not null references public.profiles(id),
  quantity integer not null default 1 check (quantity > 0),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  status text not null default 'authorized' check (status in ('pending_payment', 'authorized', 'cancelled', 'pickup_verified', 'missed', 'refunded')),
  payment_status text not null default 'not_started' check (payment_status in ('not_started', 'authorized', 'capture_pending', 'captured', 'released', 'failed', 'refunded')),
  payment_provider_id text,
  verified_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists one_active_reservation_per_student_listing
  on public.reservations (student_id, listing_id)
  where status in ('pending_payment', 'authorized');

create table if not exists public.waitlist_entries (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  quantity integer not null default 1 check (quantity > 0),
  position bigint generated always as identity,
  status text not null default 'waiting' check (status in ('waiting', 'offered', 'accepted', 'expired', 'cancelled')),
  offer_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (listing_id, student_id)
);

create table if not exists public.pickup_verifications (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null unique references public.reservations(id),
  verified_by uuid not null references public.profiles(id),
  location_id uuid not null references public.business_locations(id),
  measured_weight_kg numeric(8,3) check (measured_weight_kg > 0),
  idempotency_key text not null unique,
  verified_at timestamptz not null default now()
);

create table if not exists public.impact_events (
  id uuid primary key default gen_random_uuid(),
  verification_id uuid not null unique references public.pickup_verifications(id) on delete cascade,
  student_id uuid not null references public.profiles(id),
  business_id uuid not null references public.businesses(id),
  campus_id uuid not null references public.campuses(id),
  bags integer not null check (bags > 0),
  measured_weight_kg numeric(8,3),
  estimated_weight_kg numeric(8,3) not null default 0,
  co2e_factor numeric(8,3) not null default 2.5,
  estimated_co2e_kg numeric(8,3) not null,
  revenue_cents integer not null default 0,
  occurred_at timestamptz not null default now()
);

create table if not exists public.leaderboard_events (
  id uuid primary key default gen_random_uuid(),
  verification_id uuid not null references public.pickup_verifications(id) on delete cascade,
  student_id uuid not null references public.profiles(id),
  campus_id uuid not null references public.campuses(id),
  score_date date not null,
  points integer not null default 1 check (points = 1),
  created_at timestamptz not null default now(),
  unique (student_id, campus_id, score_date)
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null unique references public.reservations(id),
  student_id uuid not null references public.profiles(id),
  business_id uuid not null references public.businesses(id),
  overall smallint not null check (overall between 1 and 5),
  portion smallint not null check (portion between 1 and 5),
  surprise_quality smallint not null check (surprise_quality between 1 and 5),
  pickup_experience smallint not null check (pickup_experience between 1 and 5),
  comment text not null default '',
  would_reserve_again boolean not null,
  photo_path text,
  moderation_status text not null default 'pending' check (moderation_status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

create table if not exists public.outbox_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  aggregate_id uuid,
  payload jsonb not null default '{}'::jsonb,
  processed_at timestamptz,
  attempts integer not null default 0,
  created_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at before update on public.profiles
for each row execute function public.touch_updated_at();
drop trigger if exists listings_touch_updated_at on public.listings;
create trigger listings_touch_updated_at before update on public.listings
for each row execute function public.touch_updated_at();
drop trigger if exists reservations_touch_updated_at on public.reservations;
create trigger reservations_touch_updated_at before update on public.reservations
for each row execute function public.touch_updated_at();
drop trigger if exists waitlist_touch_updated_at on public.waitlist_entries;
create trigger waitlist_touch_updated_at before update on public.waitlist_entries
for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, campus_id)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(new.email, '@', 1)),
    (select id from public.campuses order by created_at limit 1)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_staff_of_business(target_business uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.staff_memberships sm
    where sm.user_id = auth.uid() and sm.business_id = target_business
  );
$$;

create or replace function public.is_staff_of_location(target_location uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.staff_memberships sm
    join public.business_locations bl on bl.business_id = sm.business_id
    where sm.user_id = auth.uid()
      and bl.id = target_location
      and (sm.location_id is null or sm.location_id = target_location)
  );
$$;

create or replace function public.bootstrap_demo_identity()
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  caller_email text;
  demo_business uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  demo_location uuid := 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
begin
  select email into caller_email from auth.users where id = auth.uid();
  if caller_email = 'manager@knightros.example' then
    update public.profiles set account_role = 'business' where id = auth.uid();
    insert into public.staff_memberships (user_id, business_id, location_id, role)
    values (auth.uid(), demo_business, demo_location, 'manager')
    on conflict do nothing;
    return 'business';
  end if;
  update public.profiles set account_role = 'student' where id = auth.uid();
  return 'student';
end;
$$;

create or replace function public.get_knight_pass_token()
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  raw_token text := encode(gen_random_bytes(24), 'hex');
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  update public.profiles
  set pass_token_hash = encode(digest(raw_token, 'sha256'), 'hex')
  where id = auth.uid();
  return raw_token;
end;
$$;

create or replace function public.create_listing(
  p_id uuid,
  p_location_id uuid,
  p_price_cents integer,
  p_quantity integer,
  p_pickup_start timestamptz,
  p_pickup_end timestamptz,
  p_description text,
  p_banner_asset_name text default 'BannerCafeBrunch',
  p_is_surprise boolean default true,
  p_estimated_kg_per_bag numeric default 0.45
)
returns public.listings
language plpgsql security definer set search_path = ''
as $$
declare
  target_business uuid;
  result public.listings;
begin
  if p_quantity <= 0 or p_pickup_end <= p_pickup_start then
    raise exception 'invalid listing';
  end if;
  select business_id into target_business from public.business_locations where id = p_location_id and is_active;
  if target_business is null or not public.is_staff_of_location(p_location_id) then
    raise exception 'not authorized for this location';
  end if;
  insert into public.listings (
    id, business_id, location_id, created_by, label, is_surprise, price_cents,
    total_quantity, remaining_quantity, pickup_start, pickup_end,
    public_description, banner_asset_name, status, estimated_kg_per_bag
  ) values (
    coalesce(p_id, gen_random_uuid()), target_business, p_location_id, auth.uid(),
    case when p_is_surprise then 'Surprise Bag' else 'Rescue Bag' end,
    p_is_surprise, greatest(0, p_price_cents), p_quantity, p_quantity,
    p_pickup_start, p_pickup_end, left(trim(p_description), 500),
    p_banner_asset_name, 'available', greatest(0, p_estimated_kg_per_bag)
  ) returning * into result;
  insert into public.outbox_events(event_type, aggregate_id, payload)
  values ('listing.published', result.id, jsonb_build_object('location_id', p_location_id));
  return result;
end;
$$;

create or replace function public.reserve_listing(p_listing_id uuid, p_quantity integer default 1)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  target public.listings;
  created public.reservations;
  waitlisted public.waitlist_entries;
  reservation_code text;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if p_quantity <= 0 then raise exception 'quantity must be positive'; end if;
  select * into target from public.listings where id = p_listing_id for update;
  if target.id is null or target.status not in ('available', 'fully_reserved') then
    raise exception 'listing is not reservable';
  end if;
  if target.pickup_end <= now() then
    raise exception 'pickup window has ended';
  end if;
  if exists (
    select 1 from public.reservations
    where listing_id = p_listing_id and student_id = auth.uid()
      and status in ('pending_payment', 'authorized')
  ) then
    raise exception 'active reservation already exists';
  end if;
  if target.status = 'available' and target.remaining_quantity >= p_quantity then
    update public.listings
    set remaining_quantity = remaining_quantity - p_quantity,
        status = case when remaining_quantity - p_quantity = 0 then 'fully_reserved' else 'available' end,
        version = version + 1
    where id = target.id;
    reservation_code := 'KS-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    insert into public.reservations (
      code, listing_id, student_id, quantity, unit_price_cents, status, payment_status
    ) values (
      reservation_code, target.id, auth.uid(), p_quantity, target.price_cents,
      'authorized', case when target.price_cents = 0 then 'captured' else 'authorized' end
    ) returning * into created;
    insert into public.outbox_events(event_type, aggregate_id, payload)
    values ('reservation.created', created.id, jsonb_build_object('listing_id', target.id));
    return jsonb_build_object('kind', 'reserved', 'reservation_id', created.id, 'code', created.code);
  end if;
  insert into public.waitlist_entries(listing_id, student_id, quantity)
  values (target.id, auth.uid(), p_quantity)
  on conflict (listing_id, student_id) do update set status = 'waiting', updated_at = now()
  returning * into waitlisted;
  return jsonb_build_object('kind', 'waitlisted', 'waitlist_id', waitlisted.id, 'position', waitlisted.position);
end;
$$;

create or replace function public.cancel_reservation(p_reservation_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  target public.reservations;
  next_wait public.waitlist_entries;
begin
  select * into target from public.reservations where id = p_reservation_id for update;
  if target.id is null then raise exception 'reservation not found'; end if;
  if target.student_id <> auth.uid()
     and not public.is_staff_of_business((select business_id from public.listings where id = target.listing_id)) then
    raise exception 'not authorized';
  end if;
  if target.status not in ('pending_payment', 'authorized') then
    return jsonb_build_object('kind', 'unchanged', 'status', target.status);
  end if;
  update public.reservations
  set status = 'cancelled', payment_status = 'released', cancelled_at = now()
  where id = target.id;
  update public.listings
  set remaining_quantity = least(total_quantity, remaining_quantity + target.quantity),
      status = case when status = 'fully_reserved' then 'available' else status end,
      version = version + 1
  where id = target.listing_id and status in ('available', 'fully_reserved');
  select * into next_wait
  from public.waitlist_entries
  where listing_id = target.listing_id and status = 'waiting'
  order by position for update skip locked limit 1;
  if next_wait.id is not null then
    update public.waitlist_entries
    set status = 'offered', offer_expires_at = now() + interval '10 minutes'
    where id = next_wait.id;
    update public.listings
    set remaining_quantity = remaining_quantity - next_wait.quantity,
        status = case when remaining_quantity - next_wait.quantity = 0 then 'fully_reserved' else 'available' end,
        version = version + 1
    where id = target.listing_id and remaining_quantity >= next_wait.quantity;
    insert into public.outbox_events(event_type, aggregate_id, payload)
    values ('waitlist.offer_created', next_wait.id, jsonb_build_object('student_id', next_wait.student_id));
  end if;
  insert into public.outbox_events(event_type, aggregate_id, payload)
  values ('reservation.cancelled', target.id, '{}'::jsonb);
  return jsonb_build_object('kind', 'cancelled', 'offered_waitlist_id', next_wait.id);
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
  where p.pass_token_hash = encode(digest(p_token, 'sha256'), 'hex')
    and l.location_id = p_location_id
    and (
      (r.status = 'authorized' and p_now between l.pickup_start - interval '15 minutes' and l.pickup_end + interval '15 minutes')
      or (r.status = 'pickup_verified' and r.verified_at > p_now - interval '3 hours')
    )
  order by l.pickup_start;
end;
$$;

create or replace function public.verify_pickup(
  p_reservation_id uuid,
  p_location_id uuid,
  p_idempotency_key text,
  p_measured_weight_kg numeric default null,
  p_now timestamptz default now()
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  target public.reservations;
  target_listing public.listings;
  target_location public.business_locations;
  target_campus uuid;
  existing public.pickup_verifications;
  created_verification public.pickup_verifications;
  food_kg numeric;
begin
  if not public.is_staff_of_location(p_location_id) then raise exception 'not authorized'; end if;
  select * into existing from public.pickup_verifications where reservation_id = p_reservation_id;
  if existing.id is not null then
    return jsonb_build_object('kind', 'already_verified', 'verification_id', existing.id);
  end if;
  select * into target from public.reservations where id = p_reservation_id for update;
  select * into target_listing from public.listings where id = target.listing_id;
  select * into target_location from public.business_locations where id = p_location_id;
  select campus_id into target_campus from public.businesses where id = target_listing.business_id;
  if target.id is null or target.status <> 'authorized' then raise exception 'reservation cannot be verified'; end if;
  if target_listing.location_id <> p_location_id then raise exception 'wrong pickup location'; end if;
  if p_now < target_listing.pickup_start - interval '15 minutes'
     or p_now > target_listing.pickup_end + interval '15 minutes' then
    raise exception 'outside pickup window';
  end if;
  insert into public.pickup_verifications (
    reservation_id, verified_by, location_id, measured_weight_kg, idempotency_key, verified_at
  ) values (
    target.id, auth.uid(), p_location_id,
    case when p_measured_weight_kg > 0 then p_measured_weight_kg else null end,
    p_idempotency_key, p_now
  ) returning * into created_verification;
  update public.reservations
  set status = 'pickup_verified', payment_status = case when payment_status = 'authorized' then 'capture_pending' else payment_status end,
      verified_at = p_now
  where id = target.id;
  food_kg := coalesce(p_measured_weight_kg, target_listing.estimated_kg_per_bag * target.quantity);
  insert into public.impact_events (
    verification_id, student_id, business_id, campus_id, bags,
    measured_weight_kg, estimated_weight_kg, co2e_factor, estimated_co2e_kg,
    revenue_cents, occurred_at
  ) values (
    created_verification.id, target.student_id, target_listing.business_id,
    target_campus,
    target.quantity,
    case when p_measured_weight_kg > 0 then p_measured_weight_kg else null end,
    case when p_measured_weight_kg > 0 then 0 else food_kg end,
    2.5, food_kg * 2.5, target.quantity * target.unit_price_cents, p_now
  );
  insert into public.leaderboard_events (verification_id, student_id, campus_id, score_date)
  select created_verification.id, target.student_id, b.campus_id,
         (p_now at time zone target_location.timezone)::date
  from public.businesses b
  join public.profiles p on p.id = target.student_id
  where b.id = target_listing.business_id and p.league_opt_in
  on conflict (student_id, campus_id, score_date) do nothing;
  insert into public.outbox_events(event_type, aggregate_id, payload)
  values ('pickup.verified', target.id, jsonb_build_object('verification_id', created_verification.id));
  return jsonb_build_object('kind', 'verified', 'verification_id', created_verification.id);
end;
$$;

-- Public and account-safe read models.
create or replace view public.live_listings
with (security_invoker = true)
as
select
  l.id, l.business_id, l.location_id, b.name as business_name, b.brand_key,
  l.label, l.is_surprise, l.price_cents, l.total_quantity, l.remaining_quantity,
  l.pickup_start, l.pickup_end, l.public_description, l.banner_asset_name,
  l.status, bl.address, bl.latitude, bl.longitude,
  coalesce(round(avg(r.overall)::numeric, 1), 0) as rating,
  count(r.id)::integer as feedback_count,
  l.created_at, l.updated_at
from public.listings l
join public.businesses b on b.id = l.business_id
join public.business_locations bl on bl.id = l.location_id
left join public.reviews r on r.business_id = b.id and r.moderation_status = 'approved'
where l.status in ('available', 'fully_reserved') and b.is_active and bl.is_active
group by l.id, b.id, bl.id;

create or replace view public.personal_impact
with (security_invoker = true)
as
select student_id,
       sum(bags)::bigint as bags,
       coalesce(sum(measured_weight_kg), 0) as measured_weight_kg,
       coalesce(sum(estimated_weight_kg), 0) as estimated_weight_kg,
       coalesce(sum(estimated_co2e_kg), 0) as estimated_co2e_kg
from public.impact_events
group by student_id;

alter table public.campuses enable row level security;
alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_locations enable row level security;
alter table public.staff_memberships enable row level security;
alter table public.listings enable row level security;
alter table public.listing_inventory enable row level security;
alter table public.reservations enable row level security;
alter table public.waitlist_entries enable row level security;
alter table public.pickup_verifications enable row level security;
alter table public.impact_events enable row level security;
alter table public.leaderboard_events enable row level security;
alter table public.reviews enable row level security;
alter table public.outbox_events enable row level security;

drop policy if exists campuses_read on public.campuses;
create policy campuses_read on public.campuses for select using (true);
drop policy if exists profiles_own_read on public.profiles;
create policy profiles_own_read on public.profiles for select using (id = auth.uid());
drop policy if exists profiles_own_update on public.profiles;
create policy profiles_own_update on public.profiles for update using (id = auth.uid())
with check (id = auth.uid());
drop policy if exists businesses_read on public.businesses;
create policy businesses_read on public.businesses for select using (is_active or public.is_staff_of_business(id));
drop policy if exists locations_read on public.business_locations;
create policy locations_read on public.business_locations for select using (is_active or public.is_staff_of_business(business_id));
drop policy if exists memberships_own_read on public.staff_memberships;
create policy memberships_own_read on public.staff_memberships for select using (user_id = auth.uid());
drop policy if exists listings_read on public.listings;
create policy listings_read on public.listings for select using (
  status in ('available', 'fully_reserved') or public.is_staff_of_business(business_id)
);
drop policy if exists inventory_staff_read on public.listing_inventory;
create policy inventory_staff_read on public.listing_inventory for select using (
  public.is_staff_of_business((select l.business_id from public.listings l where l.id = listing_id))
);
drop policy if exists reservations_participant_read on public.reservations;
create policy reservations_participant_read on public.reservations for select using (
  student_id = auth.uid() or public.is_staff_of_business((select l.business_id from public.listings l where l.id = listing_id))
);
drop policy if exists waitlist_own_read on public.waitlist_entries;
create policy waitlist_own_read on public.waitlist_entries for select using (
  student_id = auth.uid() or public.is_staff_of_business((select l.business_id from public.listings l where l.id = listing_id))
);
drop policy if exists verifications_participant_read on public.pickup_verifications;
create policy verifications_participant_read on public.pickup_verifications for select using (
  exists(select 1 from public.reservations r where r.id = reservation_id and r.student_id = auth.uid())
  or public.is_staff_of_location(location_id)
);
drop policy if exists impact_owner_or_staff_read on public.impact_events;
create policy impact_owner_or_staff_read on public.impact_events for select using (
  student_id = auth.uid() or public.is_staff_of_business(business_id)
);
drop policy if exists leaderboard_public_read on public.leaderboard_events;
create policy leaderboard_public_read on public.leaderboard_events for select using (true);
drop policy if exists reviews_public_or_owner_read on public.reviews;
create policy reviews_public_or_owner_read on public.reviews for select using (
  moderation_status = 'approved' or student_id = auth.uid() or public.is_staff_of_business(business_id)
);
drop policy if exists reviews_verified_insert on public.reviews;
create policy reviews_verified_insert on public.reviews for insert with check (
  student_id = auth.uid()
  and exists (
    select 1 from public.reservations r
    where r.id = reservation_id and r.student_id = auth.uid() and r.status = 'pickup_verified'
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('reveal-photos', 'reveal-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/heic'])
on conflict (id) do nothing;

drop policy if exists reveal_photos_owner_insert on storage.objects;
create policy reveal_photos_owner_insert on storage.objects for insert to authenticated
with check (bucket_id = 'reveal-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists reveal_photos_owner_read on storage.objects;
create policy reveal_photos_owner_read on storage.objects for select to authenticated
using (bucket_id = 'reveal-photos' and (storage.foldername(name))[1] = auth.uid()::text);

grant usage on schema public to anon, authenticated;
grant select on public.campuses, public.businesses, public.business_locations, public.listings, public.reviews, public.live_listings to anon, authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, phone_number, campus_id, league_opt_in, league_nickname)
  on public.profiles to authenticated;
grant select on public.staff_memberships, public.listing_inventory, public.reservations,
  public.waitlist_entries, public.pickup_verifications, public.impact_events,
  public.leaderboard_events, public.reviews, public.personal_impact to authenticated;
grant insert on public.reviews to authenticated;
grant execute on function public.bootstrap_demo_identity() to authenticated;
grant execute on function public.get_knight_pass_token() to authenticated;
grant execute on function public.create_listing(uuid, uuid, integer, integer, timestamptz, timestamptz, text, text, boolean, numeric) to authenticated;
grant execute on function public.reserve_listing(uuid, integer) to authenticated;
grant execute on function public.cancel_reservation(uuid) to authenticated;
grant execute on function public.scan_knight_pass(text, uuid, timestamptz) to authenticated;
grant execute on function public.verify_pickup(uuid, uuid, text, numeric, timestamptz) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.listings;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.reservations;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.pickup_verifications;
exception when duplicate_object then null;
end $$;

