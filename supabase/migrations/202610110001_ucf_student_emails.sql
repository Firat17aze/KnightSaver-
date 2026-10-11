-- Students sign up with a one-time code emailed to their UCF address. The app already asks
-- for @ucf.edu; this makes the database refuse any other new account too, apart from the
-- seeded demo business manager. Business staff are not created in Supabase Auth yet.

create or replace function public.require_ucf_email()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  if right(lower(coalesce(new.email, '')), 8) <> '@ucf.edu'
     and lower(coalesce(new.email, '')) <> 'manager@knightros.example' then
    raise exception 'KnightSaver student accounts need an @ucf.edu email address.';
  end if;
  return new;
end;
$$;

drop trigger if exists require_ucf_email on auth.users;
create trigger require_ucf_email
before insert on auth.users
for each row execute procedure public.require_ucf_email();
