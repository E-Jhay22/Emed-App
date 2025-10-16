-- ============================================
-- User Verification System Schema Extension
-- Add verification fields to profiles table
-- ============================================

-- Ensure required extension for gen_random_uuid()
create extension if not exists pgcrypto;

-- Add verification fields to profiles table
alter table public.profiles add column if not exists verified boolean not null default false;
alter table public.profiles add column if not exists verification_status text check (verification_status in ('pending', 'approved', 'rejected', null)) default null;
alter table public.profiles add column if not exists verification_documents jsonb default null;
alter table public.profiles add column if not exists verification_submitted_at timestamptz default null;
alter table public.profiles add column if not exists verification_reviewed_at timestamptz default null;
alter table public.profiles add column if not exists verification_reviewed_by uuid references public.profiles(id);

-- Update the protection function to include verification fields as privileged
create or replace function public.profiles_protect_privileged_fields()
returns trigger
language plpgsql
as $$
declare
  v_is_super boolean := false;
  v_owner_override text;
  v_rpc text;
begin
  -- Superuser/owner/maintenance bypass
  select rolsuper into v_is_super
  from pg_roles
  where rolname = current_user;

  v_owner_override := current_setting('app.owner_override', true);
  v_rpc := current_setting('app.rpc', true);

  if v_is_super
     or current_user in ('postgres','service_role')
     or coalesce(v_owner_override,'') = 'true' then
    return new;
  end if;

  -- Protect changing role
  if new.role is distinct from old.role then
    if v_rpc in ('admin_update_profile_role') then
      return new;
    end if;
    raise exception 'not authorized to change privileged fields';
  end if;

  -- Protect changing disabled
  if new.disabled is distinct from old.disabled then
    if v_rpc in ('admin_set_profile_disabled') then
      return new;
    end if;
    raise exception 'not authorized to change privileged fields';
  end if;

  -- Protect verification fields (only admins or specific RPCs can change these)
  if new.verified is distinct from old.verified 
     or new.verification_status is distinct from old.verification_status
     or new.verification_reviewed_at is distinct from old.verification_reviewed_at
     or new.verification_reviewed_by is distinct from old.verification_reviewed_by then
    if v_rpc in ('admin_approve_verification', 'admin_reject_verification') then
      return new;
    end if;
    raise exception 'not authorized to change privileged fields';
  end if;

  return new;
end;
$$;

-- Ensure trigger exists (safe re-run)
drop trigger if exists profiles_protect_privileged_fields_trg on public.profiles;
create trigger profiles_protect_privileged_fields_trg
before update on public.profiles
for each row execute function public.profiles_protect_privileged_fields();

-- ============================================
-- Verification Admin RPCs
-- ============================================

-- Approve user verification
create or replace function public.admin_approve_verification(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare 
  v_actor uuid;
  v_actor_role text;
begin
  -- Mark this call so trigger permits verification field changes
  perform set_config('app.rpc', 'admin_approve_verification', true);

  -- Caller must be admin
  v_actor := auth.uid();
  select role into v_actor_role from public.profiles where id = v_actor;
  
  if v_actor_role != 'admin' then
    raise exception 'forbidden: only admins can approve verification';
  end if;

  update public.profiles
  set 
    verified = true,
    verification_status = 'approved',
    verification_reviewed_at = timezone('utc'::text, now()),
    verification_reviewed_by = v_actor
  where id = p_user_id;

  if not found then
    raise exception 'user not found';
  end if;
end;
$$;

revoke all on function public.admin_approve_verification(uuid) from public;
grant execute on function public.admin_approve_verification(uuid) to authenticated;

-- Reject user verification
create or replace function public.admin_reject_verification(p_user_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare 
  v_actor uuid;
  v_actor_role text;
  v_current_docs jsonb;
begin
  -- Mark this call so trigger permits verification field changes
  perform set_config('app.rpc', 'admin_reject_verification', true);

  -- Caller must be admin
  v_actor := auth.uid();
  select role into v_actor_role from public.profiles where id = v_actor;
  
  if v_actor_role != 'admin' then
    raise exception 'forbidden: only admins can reject verification';
  end if;

  -- Get current documents to add rejection reason
  select verification_documents into v_current_docs from public.profiles where id = p_user_id;
  
  -- Add rejection reason to documents metadata
  v_current_docs := coalesce(v_current_docs, '{}'::jsonb) || 
    jsonb_build_object('rejection_reason', coalesce(p_reason, 'Verification documents rejected'));

  update public.profiles
  set 
    verified = false,
    verification_status = 'rejected',
    verification_reviewed_at = timezone('utc'::text, now()),
    verification_reviewed_by = v_actor,
    verification_documents = v_current_docs
  where id = p_user_id;

  if not found then
    raise exception 'user not found';
  end if;
end;
$$;

revoke all on function public.admin_reject_verification(uuid, text) from public;
grant execute on function public.admin_reject_verification(uuid, text) to authenticated;

-- User submit verification documents
create or replace function public.submit_verification_documents(
  p_selfie_url text,
  p_id_document_url text,
  p_proof_of_residence_url text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare 
  v_user_id uuid;
  v_docs jsonb;
begin
  v_user_id := auth.uid();
  
  if v_user_id is null then
    raise exception 'user not authenticated';
  end if;

  -- Build documents object
  v_docs := jsonb_build_object(
    'selfie_url', p_selfie_url,
    'id_document_url', p_id_document_url,
    'proof_of_residence_url', p_proof_of_residence_url,
    'submitted_at', timezone('utc'::text, now())
  );

  update public.profiles
  set 
    verification_documents = v_docs,
    verification_status = 'pending',
    verification_submitted_at = timezone('utc'::text, now()),
    -- Reset previous review data
    verification_reviewed_at = null,
    verification_reviewed_by = null,
    verified = false
  where id = v_user_id;

  if not found then
    raise exception 'user profile not found';
  end if;
end;
$$;

revoke all on function public.submit_verification_documents(text, text, text) from public;
grant execute on function public.submit_verification_documents(text, text, text) to authenticated;

-- ============================================
-- Storage bucket for verification documents
-- ============================================

-- Create storage bucket for verification documents (run this in Supabase dashboard or via SQL)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'verification-documents', 
  'verification-documents', 
  false, 
  10485760, -- 10MB limit
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
) on conflict (id) do nothing;

-- Storage policy: users can upload their own verification documents
drop policy if exists "Users can upload their own verification documents" on storage.objects;
create policy "Users can upload their own verification documents"
on storage.objects for insert
with check (
  bucket_id = 'verification-documents' 
  and auth.role() = 'authenticated'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Storage policy: users can view their own verification documents
drop policy if exists "Users can view their own verification documents" on storage.objects;
create policy "Users can view their own verification documents"
on storage.objects for select
using (
  bucket_id = 'verification-documents' 
  and auth.role() = 'authenticated'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Storage policy: admins can view all verification documents
drop policy if exists "Admins can view all verification documents" on storage.objects;
create policy "Admins can view all verification documents"
on storage.objects for select
using (
  bucket_id = 'verification-documents' 
  and auth.role() = 'authenticated'
  and exists (
    select 1 from public.profiles 
    where id = auth.uid() and role = 'admin'
  )
);

-- ============================================
-- Appointment Chat System
-- ============================================

-- Create appointment_messages table for chat functionality
create table if not exists public.appointment_messages (
  id uuid default gen_random_uuid() primary key,
  appointment_id uuid not null references public.appointments(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  sender_role text not null check (sender_role in ('user', 'staff', 'admin')),
  message text not null,
  created_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists idx_appointment_messages_appointment_id on public.appointment_messages(appointment_id);
create index if not exists idx_appointment_messages_created_at on public.appointment_messages(created_at);

-- Enable RLS for appointment messages
alter table public.appointment_messages enable row level security;

-- Policy: Users and staff can view messages for appointments they're involved in
drop policy if exists "Users can view messages for their appointments" on public.appointment_messages;
create policy "Users can view messages for their appointments"
on public.appointment_messages for select
using (
  auth.role() = 'authenticated' and (
    -- User can see messages for their own appointments
    exists (
      select 1 from public.appointments a
      where a.id = appointment_id 
      and a.user_id = auth.uid()
    )
    or
    -- Staff/admin can see messages for all appointments
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() 
      and p.role in ('staff', 'admin')
    )
  )
);

-- Policy: Users and staff can send messages for appointments they're involved in
drop policy if exists "Users can send messages for their appointments" on public.appointment_messages;
create policy "Users can send messages for their appointments"
on public.appointment_messages for insert
with check (
  auth.role() = 'authenticated' and
  sender_id = auth.uid() and (
    -- User can send messages for their own appointments
    exists (
      select 1 from public.appointments a
      where a.id = appointment_id 
      and a.user_id = auth.uid()
    )
    or
    -- Staff/admin can send messages for any appointment
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() 
      and p.role in ('staff', 'admin')
    )
  )
);

-- ============================================
-- Updated Appointment Policies with Verification Check
-- ============================================

-- Drop existing appointment creation policy
drop policy if exists "Users can create appointment requests" on public.appointments;

-- New policy: Only verified users can create appointments
drop policy if exists "Verified users can create appointment requests" on public.appointments;
create policy "Verified users can create appointment requests"
on public.appointments for insert
with check (
  auth.role() = 'authenticated' and
  user_id = auth.uid() and
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() 
    and p.verified = true
    and coalesce(p.disabled, false) = false
  )
);

-- RPC: Send appointment message
create or replace function public.send_appointment_message(
  p_appointment_id uuid,
  p_message text
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_sender_id uuid;
  v_sender_role text;
  v_message_id uuid;
  v_can_send boolean := false;
begin
  v_sender_id := auth.uid();
  
  if v_sender_id is null then
    raise exception 'user not authenticated';
  end if;

  -- Get sender role
  select role into v_sender_role from public.profiles where id = v_sender_id;
  
  -- Check if user can send message to this appointment
  if exists (
    select 1 from public.appointments a
    where a.id = p_appointment_id 
    and a.user_id = v_sender_id
  ) then
    v_can_send := true;
  end if;

  -- Staff/admin can send messages to any appointment
  if v_sender_role in ('staff', 'admin') then
    v_can_send := true;
  end if;

  if not v_can_send then
    raise exception 'not authorized to send message to this appointment';
  end if;

  -- Insert message
  insert into public.appointment_messages (
    appointment_id, 
    sender_id, 
    sender_role, 
    message
  ) values (
    p_appointment_id, 
    v_sender_id, 
    v_sender_role, 
    trim(p_message)
  ) returning id into v_message_id;

  return v_message_id;
end;
$$;

revoke all on function public.send_appointment_message(uuid, text) from public;
grant execute on function public.send_appointment_message(uuid, text) to authenticated;

-- RPC: Get appointment messages
create or replace function public.get_appointment_messages(p_appointment_id uuid)
returns table(
  id uuid,
  appointment_id uuid,
  sender_id uuid,
  sender_name text,
  sender_role text,
  message text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
  v_user_role text;
  v_can_view boolean := false;
begin
  v_user_id := auth.uid();
  
  if v_user_id is null then
    raise exception 'user not authenticated';
  end if;

  -- Get user role
  select role into v_user_role from public.profiles where id = v_user_id;
  
  -- Check if user can view messages for this appointment
  if exists (
    select 1 from public.appointments a
    where a.id = p_appointment_id 
    and a.user_id = v_user_id
  ) then
    v_can_view := true;
  end if;

  -- Staff/admin can view messages for any appointment
  if v_user_role in ('staff', 'admin') then
    v_can_view := true;
  end if;

  if not v_can_view then
    raise exception 'not authorized to view messages for this appointment';
  end if;

  -- Return messages with sender names
  return query
  select 
    m.id,
    m.appointment_id,
    m.sender_id,
    coalesce(p.full_name, p.email, 'Unknown User') as sender_name,
    m.sender_role,
    m.message,
    m.created_at
  from public.appointment_messages m
  join public.profiles p on p.id = m.sender_id
  where m.appointment_id = p_appointment_id
  order by m.created_at asc;
end;
$$;

revoke all on function public.get_appointment_messages(uuid) from public;
grant execute on function public.get_appointment_messages(uuid) to authenticated;

-- Refresh PostgREST schema cache
notify pgrst, 'reload schema';