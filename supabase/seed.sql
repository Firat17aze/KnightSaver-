insert into public.campuses (id, name, timezone, weekly_goal)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'UCF Main Campus', 'America/New_York', 600)
on conflict (id) do update set name = excluded.name, timezone = excluded.timezone, weekly_goal = excluded.weekly_goal;

insert into public.businesses (id, campus_id, name, brand_key, banner_asset_name)
values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Knightro''s Kitchen',
  'knightros',
  'BannerCafeBrunch'
)
on conflict (id) do update set name = excluded.name, brand_key = excluded.brand_key;

insert into public.business_locations (id, business_id, name, address, latitude, longitude, timezone)
values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'Student Union',
  'Student Union · Level 1',
  28.6016,
  -81.2005,
  'America/New_York'
)
on conflict (id) do update set address = excluded.address, latitude = excluded.latitude, longitude = excluded.longitude;

insert into public.listings (
  id, business_id, location_id, label, is_surprise, price_cents,
  total_quantity, remaining_quantity, pickup_start, pickup_end,
  public_description, banner_asset_name, status, estimated_kg_per_bag
)
values (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'Surprise Bag', true, 599, 7, 7,
  now() + interval '45 minutes',
  now() + interval '1 hour 15 minutes',
  'A changing mix of today''s surplus items, packed for one easy campus pickup.',
  'BannerCafeBrunch', 'available', 0.45
)
on conflict (id) do update set
  remaining_quantity = excluded.remaining_quantity,
  pickup_start = excluded.pickup_start,
  pickup_end = excluded.pickup_end,
  status = excluded.status,
  updated_at = now();

