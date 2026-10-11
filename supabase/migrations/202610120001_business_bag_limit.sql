-- Per-business bag limit: the most Surprise Bags one listing may have.
-- The owner sets it in the app's Profile tab. Neither the AI proposal nor manual entry
-- can go above it, and the database refuses it too, whichever path writes the listing.

alter table public.businesses
  add column if not exists max_bags_per_listing integer not null default 10
  check (max_bags_per_listing between 1 and 100);

-- New listings must fit the limit. An existing listing may stay above a newly lowered
-- limit (its bags may already be reserved), but its total can't grow.
create or replace function public.enforce_listing_bag_limit()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  bag_limit integer;
begin
  select max_bags_per_listing into bag_limit from public.businesses where id = new.business_id;
  if bag_limit is not null
     and new.total_quantity > bag_limit
     and (tg_op = 'INSERT' or new.total_quantity > old.total_quantity) then
    raise exception 'bag limit exceeded: this business lists at most % bags per listing', bag_limit
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists listings_enforce_bag_limit on public.listings;
create trigger listings_enforce_bag_limit
before insert or update of total_quantity on public.listings
for each row execute function public.enforce_listing_bag_limit();

-- The signed-in staff member's business settings.
create or replace function public.get_business_settings()
returns table (business_id uuid, max_bags_per_listing integer)
language sql stable security definer set search_path = ''
as $$
  select b.id, b.max_bags_per_listing
  from public.staff_memberships sm
  join public.businesses b on b.id = sm.business_id
  where sm.user_id = auth.uid()
  order by sm.created_at
  limit 1;
$$;

-- Managers change the limit. Returns the saved value.
create or replace function public.set_max_bags_per_listing(p_max integer)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  target_business uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if p_max is null or p_max < 1 or p_max > 100 then
    raise exception 'the bag limit must be between 1 and 100';
  end if;
  select sm.business_id into target_business
  from public.staff_memberships sm
  where sm.user_id = auth.uid() and sm.role = 'manager'
  order by sm.created_at
  limit 1;
  if target_business is null then
    raise exception 'only a manager can change the bag limit';
  end if;
  update public.businesses set max_bags_per_listing = p_max where id = target_business;
  insert into public.outbox_events(event_type, aggregate_id, payload)
  values ('business.bag_limit_changed', target_business, jsonb_build_object('max_bags_per_listing', p_max));
  return p_max;
end;
$$;

grant execute on function public.get_business_settings() to authenticated;
grant execute on function public.set_max_bags_per_listing(integer) to authenticated;
