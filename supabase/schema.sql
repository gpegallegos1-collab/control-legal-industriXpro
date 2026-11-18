-- CONTROL LEGAL | Supabase schema
-- Ejecutar completo en Supabase > SQL Editor > New query.
create extension if not exists pgcrypto;

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  company_id uuid references public.companies(id),
  role text not null default 'client' check (role in ('platform_admin','client')),
  company_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.legal_records (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  category text not null check (category in ('municipal','state','federal','studies','training')),
  jurisdiction text,
  title text not null,
  authority text,
  owner text,
  issue_date date,
  due_date date,
  manual_status text check (manual_status in ('En proceso','No aplica') or manual_status is null),
  reference text,
  evidence_url text,
  notes text,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists legal_records_company_idx on public.legal_records(company_id);
create index if not exists legal_records_due_idx on public.legal_records(due_date);

create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  actor uuid,
  company_id uuid,
  record_id uuid,
  action text not null,
  details jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='platform_admin'); $$;

create or replace function public.my_company_id()
returns uuid language sql stable security definer set search_path=public
as $$ select company_id from public.profiles where id=auth.uid(); $$;

alter table public.companies enable row level security;
alter table public.profiles enable row level security;
alter table public.legal_records enable row level security;
alter table public.audit_log enable row level security;

drop policy if exists "companies admin all" on public.companies;
create policy "companies admin all" on public.companies for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());
drop policy if exists "companies client own read" on public.companies;
create policy "companies client own read" on public.companies for select to authenticated using (id=public.my_company_id());

drop policy if exists "profile self or admin read" on public.profiles;
create policy "profile self or admin read" on public.profiles for select to authenticated using (id=auth.uid() or public.is_platform_admin());
drop policy if exists "profile admin update" on public.profiles;
create policy "profile admin update" on public.profiles for update to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

drop policy if exists "records read own or admin" on public.legal_records;
create policy "records read own or admin" on public.legal_records for select to authenticated using (public.is_platform_admin() or company_id=public.my_company_id());
drop policy if exists "records insert own or admin" on public.legal_records;
create policy "records insert own or admin" on public.legal_records for insert to authenticated with check (public.is_platform_admin() or company_id=public.my_company_id());
drop policy if exists "records update own or admin" on public.legal_records;
create policy "records update own or admin" on public.legal_records for update to authenticated using (public.is_platform_admin() or company_id=public.my_company_id()) with check (public.is_platform_admin() or company_id=public.my_company_id());
drop policy if exists "records delete admin only" on public.legal_records;
create policy "records delete admin only" on public.legal_records for delete to authenticated using (public.is_platform_admin());

drop policy if exists "audit admin read" on public.audit_log;
create policy "audit admin read" on public.audit_log for select to authenticated using (public.is_platform_admin());
drop policy if exists "audit admin insert" on public.audit_log;
create policy "audit admin insert" on public.audit_log for insert to authenticated with check (public.is_platform_admin());

-- Alta inicial (después de crear el usuario en Authentication > Users):
-- Sustituye EMAIL_ADMIN por tu correo y NOMBRE_EMPRESA por IndustriXPro.
-- Inserta la empresa:
-- insert into public.companies(name) values ('IndustriXPro') returning id;
-- Asigna tu usuario como administrador usando el UUID que aparece en Authentication > Users:
-- insert into public.profiles(id, company_id, role, company_name)
-- values ('UUID_DEL_USUARIO','UUID_DE_LA_EMPRESA','platform_admin','IndustriXPro');

-- Alta de cada cliente:
-- 1) Crea la empresa: insert into public.companies(name) values ('Cliente Ejemplo') returning id;
-- 2) Crea su usuario en Authentication > Users (Add user).
-- 3) Asigna su perfil:
-- insert into public.profiles(id, company_id, role, company_name)
-- values ('UUID_USUARIO_CLIENTE','UUID_EMPRESA_CLIENTE','client','Cliente Ejemplo');

-- Recomendación de operación: deshabilitar el registro público de usuarios en Authentication > Settings.
