-- eMed schema setup

-- Create profiles table (extends auth.users)
create table profiles (
  id uuid references auth.users primary key,
  role text not null check (role in ('admin', 'staff', 'user')) default 'user',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Profile columns (migration-safe)
alter table profiles add column if not exists email text;
-- Migrate display name to full_name; keep migration-safe
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='profiles' and column_name='name'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='profiles' and column_name='full_name'
  ) then
    alter table profiles rename column name to full_name;
  end if;
end$$;

alter table profiles add column if not exists full_name text;
alter table profiles add column if not exists username text;
alter table profiles add column if not exists first_name text;
alter table profiles add column if not exists middle_name text;
alter table profiles add column if not exists last_name text;
alter table profiles add column if not exists address text;
alter table profiles add column if not exists birthday timestamptz;
alter table profiles add column if not exists phone text;

-- Soft-disable flag for accounts (admin-controlled)
alter table public.profiles add column if not exists disabled boolean not null default false;

-- Unique index on lower(username) for case-insensitive uniqueness (migration-safe)
do $$
begin
  if not exists (
    select 1 from pg_indexes where indexname = 'profiles_username_lower_unique'
  ) then
    create unique index profiles_username_lower_unique on profiles (lower(username));
  end if;
end$$;

-- gen_random_uuid() via pgcrypto
create table inventory (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  quantity integer not null check (quantity >= 0),
  category text,
  description text,
  min_quantity integer,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table announcements (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  body text not null,
  created_by uuid references profiles(id),
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table appointments (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references profiles(id) not null,
  staff_id uuid references profiles(id),
  status text not null check (status in ('requested', 'scheduled', 'completed', 'cancelled')) default 'requested',
  requested_at timestamp with time zone not null default timezone('utc'::text, now()),
  scheduled_at timestamp with time zone,
  notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Cancellation support (migration-safe)
alter table appointments add column if not exists cancelled_at timestamp with time zone;
alter table appointments add column if not exists cancelled_by uuid references profiles(id);
alter table appointments add column if not exists cancel_request_reason text;
alter table appointments add column if not exists cancel_request_at timestamp with time zone;

-- Basic RLS policies
alter table profiles enable row level security;
alter table inventory enable row level security;
alter table announcements enable row level security;
alter table appointments enable row level security;

-- Profiles policies
create policy "Public profiles are viewable by everyone"
  on profiles for select
  using (true);

-- Allow users to create and update ONLY their own profile rows
drop policy if exists "Users can insert own profile" on profiles;
create policy "Users can insert own profile"
  on profiles for insert
  with check (auth.uid() = id);

drop policy if exists "Users can update own profile" on profiles;
create policy "Users can update own profile"
  on profiles for update
  using (auth.uid() = id and exists (select 1 from public.profiles me where me.id = auth.uid() and coalesce(me.disabled,false) = false))
  with check (auth.uid() = id and exists (select 1 from public.profiles me where me.id = auth.uid() and coalesce(me.disabled,false) = false));

-- Admins can update non-admin profiles only (and cannot set role to admin)
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='profiles' and policyname='Admins can update any profile'
  ) then
    drop policy "Admins can update any profile" on public.profiles;
  end if;
  if exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='profiles' and policyname='Admins can update non-admin profiles'
  ) then
    drop policy "Admins can update non-admin profiles" on public.profiles;
  end if;
  create policy "Admins can update non-admin profiles"
    on public.profiles for update
    using (
      auth.role() = 'authenticated'
      and exists (
        select 1 from public.profiles ap
        where ap.id = auth.uid() and ap.role = 'admin'
      )
      and role <> 'admin' -- target row must not be an admin
    )
    with check (
      auth.role() = 'authenticated'
      and exists (
        select 1 from public.profiles ap
        where ap.id = auth.uid() and ap.role = 'admin'
      )
      and role <> 'admin' -- new row must not be admin either (prevents promotion)
    );
end$$;

-- Allow upsert when id == auth.uid()
drop policy if exists "Users can upsert own profile" on profiles;
create policy "Users can upsert own profile"
  on profiles for insert
  with check (auth.uid() = id);

-- Inventory policies
drop policy if exists "Inventory is viewable by authenticated users" on inventory;
create policy "Inventory is viewable by authenticated users"
  on inventory for select
  using (
    auth.role() = 'authenticated' and exists (
      select 1 from public.profiles me where me.id = auth.uid() and coalesce(me.disabled,false) = false
    )
  );

-- Inventory writes via RPC only
do $do$
begin
  for policy_name in select policyname from pg_policies where schemaname='public' and tablename='inventory' and cmd in ('insert','update','delete') loop
    execute format('drop policy if exists %I on public.inventory', policy_name);
  end loop;
end
$do$;

-- Auto-sync full_name
do $$
begin
  if exists (
    select 1 from pg_trigger where tgname = 'trg_profiles_full_name_sync'
  ) then
    drop trigger trg_profiles_full_name_sync on public.profiles;
  end if;
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.proname='profile_sync_full_name' and n.nspname='public'
  ) then
    drop function public.profile_sync_full_name();
  end if;
  create function public.profile_sync_full_name()
  returns trigger
  language plpgsql
  as $fn$
  begin
    -- Compose as: Last, First M.
    declare
      v_first text := coalesce(new.first_name, '');
      v_middle text := coalesce(new.middle_name, '');
      v_last text := coalesce(new.last_name, '');
      v_middle_initial text := null;
      v_parts text := '';
    begin
      if length(trim(v_middle)) > 0 then
        v_middle_initial := upper(left(trim(v_middle), 1)) || '.';
      end if;
      if length(trim(v_last)) > 0 then
        v_parts := trim(v_last);
      end if;
      if length(trim(v_first)) > 0 then
        if v_parts <> '' then
          v_parts := v_parts || ', ' || trim(v_first);
        else
          v_parts := trim(v_first);
        end if;
      end if;
      if v_middle_initial is not null then
        if v_parts <> '' then
          v_parts := v_parts || ' ' || v_middle_initial;
        else
          v_parts := v_middle_initial;
        end if;
      end if;
      new.full_name := trim(v_parts);
    end;
    return new;
  end;
  $fn$;
  create trigger trg_profiles_full_name_sync
  before insert or update of first_name, middle_name, last_name on public.profiles
  for each row execute procedure public.profile_sync_full_name();
end$$;

-- RPC: set item image
do $do$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.proname='inventory_set_item_image' and n.nspname='public'
  ) then
    drop function public.inventory_set_item_image(uuid, text);
  end if;
  create function public.inventory_set_item_image(p_item_id uuid, p_image_url text)
  returns void
  language plpgsql
  security definer
  set search_path = public, auth
  as $fn$
  declare v_actor_id uuid;
  begin
    perform set_config('app.rpc', 'inventory_set_item_image', true);
    v_actor_id := auth.uid();
    if exists (select 1 from public.profiles where id = v_actor_id and coalesce(disabled,false) = true) then
      raise exception 'forbidden';
    end if;
    if not exists (
      select 1 from public.profiles where id = v_actor_id and role in ('staff','admin')
    ) then raise exception 'forbidden'; end if;
    update public.inventory set image_url = p_image_url, updated_at = timezone('utc'::text, now())
    where id = p_item_id;
  end;
  $fn$;
  revoke all on function public.inventory_set_item_image(uuid, text) from public;
  grant execute on function public.inventory_set_item_image(uuid, text) to authenticated;
end
$do$;

notify pgrst, 'reload schema';

-- Mutations go through SECURITY DEFINER RPCs

-- Announcements policies
create policy "Announcements are viewable by authenticated users"
  on announcements for select
  using (auth.role() = 'authenticated');

create policy "Announcements can be created by admin and staff"
  on announcements for insert
  with check (
    auth.role() = 'authenticated' and 
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() 
      and profiles.role in ('admin', 'staff')
    )
  );

-- Appointments policies
create policy "Users can view their own appointments"
  on appointments for select
  using (
    auth.role() = 'authenticated' and (
      user_id = auth.uid() or
      exists (
        select 1 from profiles
        where profiles.id = auth.uid() 
        and profiles.role in ('admin', 'staff')
      )
    )
  );

create policy "Users can create appointment requests"
  on appointments for insert
  with check (
    auth.role() = 'authenticated' and
    user_id = auth.uid()
  );

-- RPC: schedule appointment (SECURITY DEFINER)
do $do$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.proname='appointment_schedule' and n.nspname='public'
  ) then
    drop function public.appointment_schedule(uuid, timestamptz, uuid);
  end if;
  create function public.appointment_schedule(p_id uuid, p_scheduled_at timestamptz, p_staff_id uuid)
  returns void
  language plpgsql
  security definer
  set search_path = public, auth
  as $fn$
  declare v_actor_id uuid;
  begin
    perform set_config('app.rpc', 'appointment_schedule', true);
    v_actor_id := auth.uid();
    if exists (select 1 from public.profiles where id = v_actor_id and coalesce(disabled,false) = true) then
      raise exception 'forbidden';
    end if;
    if not exists (
      select 1 from public.profiles where id = v_actor_id and role in ('staff','admin')
    ) then raise exception 'forbidden'; end if;

    update public.appointments
      set scheduled_at = p_scheduled_at,
          staff_id = p_staff_id,
          status = 'scheduled'
      where id = p_id;

    -- Optional legacy column support: update "date" if such column exists
    if exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name='appointments' and column_name='date'
    ) then
      execute $$update public.appointments set "date" = ($$ || quote_literal(p_scheduled_at::date) || $$) where id = $$ || quote_literal(p_id);
    end if;
  end;
  $fn$;
  revoke all on function public.appointment_schedule(uuid, timestamptz, uuid) from public;
  grant execute on function public.appointment_schedule(uuid, timestamptz, uuid) to authenticated;
end
$do$;

notify pgrst, 'reload schema';

-- RPC: user cancels a requested appointment (SECURITY DEFINER)
do $do$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.proname='appointment_user_cancel_request' and n.nspname='public'
  ) then
    drop function public.appointment_user_cancel_request(uuid, text);
  end if;
  create function public.appointment_user_cancel_request(p_id uuid, p_reason text)
  returns void
  language plpgsql
  security definer
  set search_path = public, auth
  as $fn$
  declare v_actor uuid;
          v_owner uuid;
          v_status text;
  begin
    perform set_config('app.rpc','appointment_user_cancel_request',true);
    v_actor := auth.uid();
    select user_id, status into v_owner, v_status from public.appointments where id = p_id;
    if v_owner is null then raise exception 'not found'; end if;
    if v_actor <> v_owner then raise exception 'forbidden'; end if;
    if v_status <> 'requested' then raise exception 'only requested appointments can be cancelled by user'; end if;
    update public.appointments
      set status = 'cancelled',
          cancelled_at = timezone('utc'::text, now()),
          cancelled_by = v_actor,
          notes = coalesce(notes,'') || case when p_reason is not null and length(trim(p_reason))>0 then
                   case when notes is null or length(notes)=0 then '' else E'\n' end || 'Cancelled by user: ' || p_reason
                 else '' end
      where id = p_id;
  end;
  $fn$;
  revoke all on function public.appointment_user_cancel_request(uuid, text) from public;
  grant execute on function public.appointment_user_cancel_request(uuid, text) to authenticated;
end
$do$;

-- RPC: user requests cancellation for a scheduled appointment
do $do$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.proname='appointment_user_request_cancel_scheduled' and n.nspname='public'
  ) then
    drop function public.appointment_user_request_cancel_scheduled(uuid, text);
  end if;
  create function public.appointment_user_request_cancel_scheduled(p_id uuid, p_reason text)
  returns void
  language plpgsql
  security definer
  set search_path = public, auth
  as $fn$
  declare v_actor uuid;
          v_owner uuid;
          v_status text;
  begin
    perform set_config('app.rpc','appointment_user_request_cancel_scheduled',true);
    v_actor := auth.uid();
    select user_id, status into v_owner, v_status from public.appointments where id = p_id;
    if v_owner is null then raise exception 'not found'; end if;
    if v_actor <> v_owner then raise exception 'forbidden'; end if;
    if v_status <> 'scheduled' then raise exception 'can request cancel only for scheduled'; end if;
    update public.appointments
      set cancel_request_reason = nullif(trim(p_reason),''),
          cancel_request_at = timezone('utc'::text, now())
      where id = p_id;
  end;
  $fn$;
  revoke all on function public.appointment_user_request_cancel_scheduled(uuid, text) from public;
  grant execute on function public.appointment_user_request_cancel_scheduled(uuid, text) to authenticated;
end
$do$;

-- RPC: staff/admin cancel appointment (approve cancellation)
do $do$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.proname='appointment_cancel' and n.nspname='public'
  ) then
    drop function public.appointment_cancel(uuid, text, uuid);
  end if;
  create function public.appointment_cancel(p_id uuid, p_reason text, p_staff_id uuid)
  returns void
  language plpgsql
  security definer
  set search_path = public, auth
  as $fn$
  declare v_actor uuid;
          v_role text;
  begin
    perform set_config('app.rpc','appointment_cancel',true);
    v_actor := auth.uid();
    if exists (select 1 from public.profiles where id=v_actor and role in ('staff','admin')) is not true then
      raise exception 'forbidden';
    end if;
    update public.appointments
      set status='cancelled',
          cancelled_at = timezone('utc'::text, now()),
          cancelled_by = p_staff_id,
          cancel_request_reason = null,
          cancel_request_at = null,
          notes = coalesce(notes,'') || case when p_reason is not null and length(trim(p_reason))>0 then
                   case when notes is null or length(notes)=0 then '' else E'\n' end || 'Cancelled by staff: ' || p_reason
                 else '' end
      where id = p_id;
  end;
  $fn$;
  revoke all on function public.appointment_cancel(uuid, text, uuid) from public;
  grant execute on function public.appointment_cancel(uuid, text, uuid) to authenticated;
end
$do$;

notify pgrst, 'reload schema';

-- Seed/sample data removed

-- Auto-create profiles row on auth.user insert
do $$
begin
  if not exists (
    select 1 from pg_proc where proname = 'handle_new_user_profile'
  ) then
    create function handle_new_user_profile()
    returns trigger as $trg$
    begin
      insert into public.profiles (id, role, created_at)
      values (new.id, 'user', timezone('utc'::text, now()))
      on conflict (id) do nothing;
      return new;
    end;
    $trg$ language plpgsql security definer;

    create trigger on_auth_user_created
      after insert on auth.users
      for each row execute procedure handle_new_user_profile();
  end if;
end$$;

-- Resolve email by username (SECURITY DEFINER)
do $$
begin
  -- Drop existing to allow re-create on changes
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.proname = 'email_for_username' and n.nspname = 'public'
  ) then
    drop function public.email_for_username(text);
  end if;

  create function public.email_for_username(u text)
  returns text
  language plpgsql
  security definer
  set search_path = public, auth
  as $rpc$
  declare out_email text;
  begin
    select au.email into out_email
    from public.profiles p
    join auth.users au on au.id = p.id
    where lower(p.username) = lower(u)
    limit 1;
    return out_email;
  end;
  $rpc$;

  -- Restrict and grant execution to client roles
  revoke all on function public.email_for_username(text) from public;
  grant execute on function public.email_for_username(text) to anon, authenticated;
end$$;

-- Backfill profiles.email from auth.users
update public.profiles p
set email = au.email
from auth.users au
where p.id = au.id and (p.email is null or trim(p.email) = '');

notify pgrst, 'reload schema';

-- Inventory extensions (append-only)

-- Create inventory_transactions table
do $do$
begin
  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'inventory_transactions'
  ) then
    create table public.inventory_transactions (
      id uuid default gen_random_uuid() primary key,
      item_id uuid not null references public.inventory(id) on delete cascade,
      item_name text not null,
      type text not null check (type in ('receive','dispense','adjust')),
      delta integer not null,
      new_quantity integer not null,
      patient_name text,
      notes text,
      actor_id uuid not null references public.profiles(id),
      actor_name text,
      created_at timestamptz not null default timezone('utc'::text, now())
    );
    create index on public.inventory_transactions (item_id);
    create index on public.inventory_transactions (created_at);
    create index on public.inventory_transactions (type);
  end if;
end
$do$;

-- Transactions RLS
alter table public.inventory_transactions enable row level security;
do $do$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='inventory_transactions' and policyname='Transactions readable by staff/admin'
  ) then
    create policy "Transactions readable by staff/admin" on public.inventory_transactions for select
    using (
      auth.role() = 'authenticated' and exists (
        select 1 from public.profiles where id = auth.uid() and role in ('staff','admin')
      )
    );
  end if;
end
$do$;

-- RPC: receive stock
do $do$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.proname='inventory_receive_stock' and n.nspname='public') then
    drop function public.inventory_receive_stock(uuid, integer, text);
  end if;
  create function public.inventory_receive_stock(p_item_id uuid, p_quantity integer, p_notes text default null)
  returns void
  language plpgsql
  security definer
  set search_path = public, auth
  as $fn$
  declare
    v_old int;
    v_new int;
    v_name text;
    v_actor text;
    v_actor_id uuid;
    v_name_col text;
  begin
    perform set_config('app.rpc', 'inventory_receive_stock', true);
    if p_quantity <= 0 then raise exception 'quantity must be > 0'; end if;
    v_actor_id := auth.uid();
    if exists (select 1 from public.profiles where id = v_actor_id and coalesce(disabled,false) = true) then
      raise exception 'forbidden';
    end if;
    -- Resolve the correct name column in a migration-safe way
    select column_name into v_name_col
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'inventory'
       and column_name in ('name','item_name','title')
     order by case column_name when 'name' then 1 when 'item_name' then 2 else 3 end
     limit 1;
    if v_name_col is null then
      raise exception 'name-like column not found on inventory';
    end if;
    execute format('select coalesce(%I, ''''), quantity from public.inventory where id = $1 for update', v_name_col)
      into v_name, v_old using p_item_id;
    if v_name is null then raise exception 'item not found'; end if;
    v_new := v_old + p_quantity;
    update public.inventory set quantity = v_new, updated_at = timezone('utc'::text, now()) where id = p_item_id;
  select full_name into v_actor from public.profiles where id = v_actor_id;
    insert into public.inventory_transactions(item_id, item_name, type, delta, new_quantity, notes, actor_id, actor_name)
    values (p_item_id, v_name, 'receive', p_quantity, v_new, p_notes, v_actor_id, v_actor);
  end;
  $fn$;
  revoke all on function public.inventory_receive_stock(uuid, integer, text) from public;
  grant execute on function public.inventory_receive_stock(uuid, integer, text) to authenticated;
end
$do$;

-- RPC: dispense stock
do $do$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.proname='inventory_dispense_medicines' and n.nspname='public') then
    drop function public.inventory_dispense_medicines(uuid, integer, text, text);
  end if;
  create function public.inventory_dispense_medicines(p_item_id uuid, p_quantity integer, p_patient_name text default null, p_notes text default null)
  returns void
  language plpgsql
  security definer
  set search_path = public, auth
  as $fn$
  declare
    v_old int;
    v_new int;
    v_name text;
    v_actor text;
    v_actor_id uuid;
    v_name_col text;
  begin
    perform set_config('app.rpc', 'inventory_dispense_medicines', true);
    if p_quantity <= 0 then raise exception 'quantity must be > 0'; end if;
    if p_patient_name is null or length(trim(p_patient_name)) = 0 then
      raise exception 'patient name is required';
    end if;
    v_actor_id := auth.uid();
    if exists (select 1 from public.profiles where id = v_actor_id and coalesce(disabled,false) = true) then
      raise exception 'forbidden';
    end if;
    -- Resolve the correct name column in a migration-safe way
    select column_name into v_name_col
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'inventory'
       and column_name in ('name','item_name','title')
     order by case column_name when 'name' then 1 when 'item_name' then 2 else 3 end
     limit 1;
    if v_name_col is null then
      raise exception 'name-like column not found on inventory';
    end if;
    execute format('select coalesce(%I, ''''), quantity from public.inventory where id = $1 for update', v_name_col)
      into v_name, v_old using p_item_id;
    if v_name is null then raise exception 'item not found'; end if;
    v_new := greatest(0, v_old - p_quantity);
    update public.inventory set quantity = v_new, updated_at = timezone('utc'::text, now()) where id = p_item_id;
  select full_name into v_actor from public.profiles where id = v_actor_id;
    insert into public.inventory_transactions(item_id, item_name, type, delta, new_quantity, patient_name, notes, actor_id, actor_name)
    values (p_item_id, v_name, 'dispense', -p_quantity, v_new, p_patient_name, p_notes, v_actor_id, v_actor);
  end;
  $fn$;
  revoke all on function public.inventory_dispense_medicines(uuid, integer, text, text) from public;
  grant execute on function public.inventory_dispense_medicines(uuid, integer, text, text) to authenticated;
end
$do$;

-- RPC: adjust stock
do $do$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.proname='inventory_adjust_stock' and n.nspname='public') then
    drop function public.inventory_adjust_stock(uuid, integer, text);
  end if;
  create function public.inventory_adjust_stock(p_item_id uuid, p_delta integer, p_notes text default null)
  returns void
  language plpgsql
  security definer
  set search_path = public, auth
  as $fn$
  declare
    v_old int;
    v_new int;
    v_name text;
    v_actor text;
    v_actor_id uuid;
    v_name_col text;
  begin
    perform set_config('app.rpc', 'inventory_adjust_stock', true);
    v_actor_id := auth.uid();
    if exists (select 1 from public.profiles where id = v_actor_id and coalesce(disabled,false) = true) then
      raise exception 'forbidden';
    end if;
    -- Resolve the correct name column in a migration-safe way
    select column_name into v_name_col
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'inventory'
       and column_name in ('name','item_name','title')
     order by case column_name when 'name' then 1 when 'item_name' then 2 else 3 end
     limit 1;
    if v_name_col is null then
      raise exception 'name-like column not found on inventory';
    end if;
    execute format('select coalesce(%I, ''''), quantity from public.inventory where id = $1 for update', v_name_col)
      into v_name, v_old using p_item_id;
    if v_name is null then raise exception 'item not found'; end if;
    v_new := greatest(0, v_old + p_delta);
    update public.inventory set quantity = v_new, updated_at = timezone('utc'::text, now()) where id = p_item_id;
  select full_name into v_actor from public.profiles where id = v_actor_id;
    insert into public.inventory_transactions(item_id, item_name, type, delta, new_quantity, notes, actor_id, actor_name)
    values (p_item_id, v_name, 'adjust', p_delta, v_new, p_notes, v_actor_id, v_actor);
  end;
  $fn$;
  revoke all on function public.inventory_adjust_stock(uuid, integer, text) from public;
  grant execute on function public.inventory_adjust_stock(uuid, integer, text) to authenticated;
end
$do$;

notify pgrst, 'reload schema';

-- Inventory CRUD RPCs: create item
do $do$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.proname='inventory_create_item' and n.nspname='public'
  ) then
    drop function public.inventory_create_item(text, text, text, integer, integer, text);
  end if;
  create function public.inventory_create_item(
    p_name text,
    p_description text default null,
    p_category text default null,
    p_min_quantity integer default null,
    p_initial_quantity integer default 0,
    p_notes text default null
  )
  returns uuid
  language plpgsql
  security definer
  set search_path = public, auth
  as $fn$
  declare
    v_id uuid;
    v_actor_id uuid;
    v_actor text;
    v_qty int;
    v_name_col text;
  begin
    perform set_config('app.rpc', 'inventory_create_item', true);
    v_actor_id := auth.uid();
    if exists (select 1 from public.profiles where id = v_actor_id and coalesce(disabled,false) = true) then
      raise exception 'forbidden';
    end if;
    if not exists (
      select 1 from public.profiles where id = v_actor_id and role in ('staff','admin')
    ) then raise exception 'forbidden'; end if;

    -- Resolve name-like column
    select column_name into v_name_col
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'inventory'
       and column_name in ('name','item_name','title')
     order by case column_name when 'name' then 1 when 'item_name' then 2 else 3 end
     limit 1;
    if v_name_col is null then
      raise exception 'name-like column not found on inventory';
    end if;

    execute format(
      'insert into public.inventory(%I, description, category, quantity, min_quantity) values ($1, $2, $3, 0, $4) returning id',
      v_name_col
    ) using p_name, p_description, p_category, p_min_quantity into v_id;

    if p_initial_quantity is not null and p_initial_quantity > 0 then
      -- apply initial stock and audit
  select full_name into v_actor from public.profiles where id = v_actor_id;
      update public.inventory
        set quantity = quantity + p_initial_quantity,
            updated_at = timezone('utc'::text, now())
        where id = v_id
        returning quantity into v_qty;
      insert into public.inventory_transactions(
        item_id, item_name, type, delta, new_quantity, notes, actor_id, actor_name
      ) values (
        v_id, p_name, 'receive', p_initial_quantity, v_qty, p_notes, v_actor_id, v_actor
      );
    end if;

    return v_id;
  end;
  $fn$;
  revoke all on function public.inventory_create_item(text, text, text, integer, integer, text) from public;
  grant execute on function public.inventory_create_item(text, text, text, integer, integer, text) to authenticated;
end
$do$;

-- Inventory CRUD RPCs: update item
do $do$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.proname='inventory_update_item' and n.nspname='public'
  ) then
    drop function public.inventory_update_item(uuid, text, text, text, integer);
  end if;
  create function public.inventory_update_item(
    p_item_id uuid,
    p_name text default null,
    p_description text default null,
    p_category text default null,
    p_min_quantity integer default null
  )
  returns void
  language plpgsql
  security definer
  set search_path = public, auth
  as $fn$
  declare
    v_actor_id uuid;
    v_name_col text;
  begin
    perform set_config('app.rpc', 'inventory_update_item', true);
    v_actor_id := auth.uid();
    if exists (select 1 from public.profiles where id = v_actor_id and coalesce(disabled,false) = true) then
      raise exception 'forbidden';
    end if;
    if not exists (
      select 1 from public.profiles where id = v_actor_id and role in ('staff','admin')
    ) then raise exception 'forbidden'; end if;

    -- Resolve name-like column
    select column_name into v_name_col
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'inventory'
       and column_name in ('name','item_name','title')
     order by case column_name when 'name' then 1 when 'item_name' then 2 else 3 end
     limit 1;
    if v_name_col is null then
      raise exception 'name-like column not found on inventory';
    end if;

    execute format(
      'update public.inventory set %1$I = coalesce($1, %1$I), description = case when $2 is null then description else $2 end, category = case when $3 is null then category else $3 end, min_quantity = coalesce($4, min_quantity), updated_at = timezone('utc'::text, now()) where id = $5',
      v_name_col
    ) using p_name, p_description, p_category, p_min_quantity, p_item_id;
  end;
  $fn$;
  revoke all on function public.inventory_update_item(uuid, text, text, text, integer) from public;
  grant execute on function public.inventory_update_item(uuid, text, text, text, integer) to authenticated;
end
$do$;

-- Inventory CRUD RPCs: delete item
do $do$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.proname='inventory_delete_item' and n.nspname='public'
  ) then
    drop function public.inventory_delete_item(uuid);
  end if;
  create function public.inventory_delete_item(p_item_id uuid)
  returns void
  language plpgsql
  security definer
  set search_path = public, auth
  as $fn$
  declare v_actor_id uuid;
  begin
    perform set_config('app.rpc', 'inventory_delete_item', true);
    v_actor_id := auth.uid();
    if exists (select 1 from public.profiles where id = v_actor_id and coalesce(disabled,false) = true) then
      raise exception 'forbidden';
    end if;
    if not exists (
      select 1 from public.profiles where id = v_actor_id and role in ('staff','admin')
    ) then raise exception 'forbidden'; end if;
    delete from public.inventory where id = p_item_id;
  end;
  $fn$;
  revoke all on function public.inventory_delete_item(uuid) from public;
  grant execute on function public.inventory_delete_item(uuid) to authenticated;
end
$do$;

notify pgrst, 'reload schema';