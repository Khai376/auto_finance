-- FINAL migration. Back up the project before running.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.contracts (
  id uuid primary key default gen_random_uuid(),
  car_name text not null,
  contract_no text not null unique,
  total_installments integer not null check(total_installments>0),
  default_installment_amount numeric(12,2) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.contract_members (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.contracts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check(role in('payer','owner')),
  member_no integer not null check(member_no in(1,2)),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(contract_id,user_id), unique(contract_id,member_no)
);
create table if not exists public.installments (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.contracts(id) on delete cascade,
  installment_no integer not null,
  amount numeric(12,2) not null default 0,
  due_date date,
  status text not null default 'pending' check(status in('pending','partial','submitted','paid','rejected')),
  owner_note text,
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(contract_id,installment_no)
);
alter table public.installments add column if not exists payer1_amount numeric(12,2) not null default 0;
alter table public.installments add column if not exists payer2_amount numeric(12,2) not null default 0;

create table if not exists public.installment_slips (
  id uuid primary key default gen_random_uuid(),
  installment_id uuid not null references public.installments(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id),
  amount numeric(12,2) not null check(amount>0),
  storage_path text not null unique,
  file_name text not null,
  mime_type text,
  file_size bigint,
  note text,
  created_at timestamptz not null default now()
);
alter table public.installment_slips add column if not exists payer_no integer;
alter table public.installment_slips drop constraint if exists installment_slips_payer_no_check;
alter table public.installment_slips add constraint installment_slips_payer_no_check check(payer_no in(1,2));

create table if not exists public.car_documents (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.contracts(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id),
  name text not null,
  file_path text not null,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,display_name) values(new.id,coalesce(nullif(new.raw_user_meta_data->>'display_name',''),split_part(new.email,'@',1),'ผู้ใช้งาน')) on conflict(id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
insert into public.profiles(id,display_name) select id,coalesce(split_part(email,'@',1),'ผู้ใช้งาน') from auth.users on conflict(id) do nothing;

create or replace function public.is_contract_member(p_contract_id uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.contract_members where contract_id=p_contract_id and user_id=auth.uid() and active); $$;
create or replace function public.is_contract_owner(p_contract_id uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.contract_members where contract_id=p_contract_id and user_id=auth.uid() and role='owner' and active); $$;
create or replace function public.my_member_no(p_contract_id uuid) returns integer language sql stable security definer set search_path=public as $$ select member_no from public.contract_members where contract_id=p_contract_id and user_id=auth.uid() and active limit 1; $$;

create or replace function public.refresh_installment_status(p_id uuid) returns void language plpgsql security definer set search_path=public as $$
declare r1 numeric;r2 numeric;s1 numeric;s2 numeric;current_status text;
begin
  select payer1_amount,payer2_amount,status into r1,r2,current_status from public.installments where id=p_id;
  if current_status='paid' then return; end if;
  select coalesce(sum(amount) filter(where payer_no=1),0),coalesce(sum(amount) filter(where payer_no=2),0) into s1,s2 from public.installment_slips where installment_id=p_id;
  update public.installments set status=case when s1=0 and s2=0 then 'pending' when s1>=r1 and s2>=r2 then 'submitted' else 'partial' end,updated_at=now() where id=p_id;
end; $$;
create or replace function public.after_slip_change() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public.refresh_installment_status(coalesce(new.installment_id,old.installment_id)); return coalesce(new,old); end; $$;
drop trigger if exists installment_slip_changed on public.installment_slips;
create trigger installment_slip_changed after insert or update or delete on public.installment_slips for each row execute function public.after_slip_change();

drop function if exists public.owner_verify_installment(uuid,text,text);
create function public.owner_verify_installment(p_installment_id uuid,p_action text,p_note text default null) returns void language plpgsql security definer set search_path=public as $$
declare cid uuid;r1 numeric;r2 numeric;s1 numeric;s2 numeric;
begin
  select contract_id,payer1_amount,payer2_amount into cid,r1,r2 from public.installments where id=p_installment_id;
  if not found then raise exception 'ไม่พบข้อมูลงวด'; end if;
  if not public.is_contract_owner(cid) then raise exception 'เฉพาะเจ้าของสัญญาเท่านั้น'; end if;
  select coalesce(sum(amount) filter(where payer_no=1),0),coalesce(sum(amount) filter(where payer_no=2),0) into s1,s2 from public.installment_slips where installment_id=p_installment_id;
  if p_action='approve' then
    if s1<r1 or s2<r2 then raise exception 'ยอดของผู้ผ่อนทั้งสองคนยังไม่ครบ'; end if;
    update public.installments set status='paid',owner_note=nullif(trim(p_note),''),verified_by=auth.uid(),verified_at=now(),updated_at=now() where id=p_installment_id;
  elsif p_action='reject' then
    update public.installments set status='rejected',owner_note=nullif(trim(p_note),''),verified_by=auth.uid(),verified_at=now(),updated_at=now() where id=p_installment_id;
  else raise exception 'action ต้องเป็น approve หรือ reject'; end if;
end; $$;
grant execute on function public.owner_verify_installment(uuid,text,text) to authenticated;

alter table public.profiles enable row level security; alter table public.contracts enable row level security; alter table public.contract_members enable row level security; alter table public.installments enable row level security; alter table public.installment_slips enable row level security; alter table public.car_documents enable row level security;
drop policy if exists profiles_read on public.profiles; create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid() or exists(select 1 from public.contract_members a join public.contract_members b on b.contract_id=a.contract_id where a.user_id=auth.uid() and b.user_id=profiles.id and a.active and b.active));
drop policy if exists contracts_read on public.contracts; create policy contracts_read on public.contracts for select to authenticated using(public.is_contract_member(id));
drop policy if exists members_read on public.contract_members; create policy members_read on public.contract_members for select to authenticated using(public.is_contract_member(contract_id));
drop policy if exists installments_read on public.installments; create policy installments_read on public.installments for select to authenticated using(public.is_contract_member(contract_id));
drop policy if exists slips_read on public.installment_slips; create policy slips_read on public.installment_slips for select to authenticated using(exists(select 1 from public.installments i where i.id=installment_id and public.is_contract_member(i.contract_id)));
drop policy if exists slips_insert on public.installment_slips; create policy slips_insert on public.installment_slips for insert to authenticated with check(uploaded_by=auth.uid() and exists(select 1 from public.installments i where i.id=installment_id and i.status<>'paid' and public.my_member_no(i.contract_id)=payer_no));
drop policy if exists slips_delete on public.installment_slips; create policy slips_delete on public.installment_slips for delete to authenticated using(exists(select 1 from public.installments i where i.id=installment_id and i.status<>'paid' and(uploaded_by=auth.uid() or public.is_contract_owner(i.contract_id))));
drop policy if exists docs_read on public.car_documents; create policy docs_read on public.car_documents for select to authenticated using(public.is_contract_member(contract_id));
drop policy if exists docs_insert on public.car_documents; create policy docs_insert on public.car_documents for insert to authenticated with check(uploaded_by=auth.uid() and public.is_contract_member(contract_id));
grant select on public.profiles,public.contracts,public.contract_members,public.installments to authenticated; grant select,insert,delete on public.installment_slips to authenticated; grant select,insert on public.car_documents to authenticated;

insert into storage.buckets(id,name,public,file_size_limit) values('payment-slips','payment-slips',false,10485760),('car-documents','car-documents',false,20971520) on conflict(id) do update set public=false;
drop policy if exists storage_slips_read on storage.objects; create policy storage_slips_read on storage.objects for select to authenticated using(bucket_id='payment-slips' and public.is_contract_member(((storage.foldername(name))[1])::uuid));
drop policy if exists storage_slips_insert on storage.objects; create policy storage_slips_insert on storage.objects for insert to authenticated with check(bucket_id='payment-slips' and public.is_contract_member(((storage.foldername(name))[1])::uuid) and ((storage.foldername(name))[3])::uuid=auth.uid());
drop policy if exists storage_docs_read on storage.objects; create policy storage_docs_read on storage.objects for select to authenticated using(bucket_id='car-documents' and public.is_contract_member(((storage.foldername(name))[1])::uuid));
drop policy if exists storage_docs_insert on storage.objects; create policy storage_docs_insert on storage.objects for insert to authenticated with check(bucket_id='car-documents' and public.is_contract_member(((storage.foldername(name))[1])::uuid));

do $$
declare cid uuid;p1 uuid;p2 uuid;
begin
  insert into public.contracts(car_name,contract_no,total_installments,default_installment_amount,active) values('MITSUBISHI Attrage','35-6404576',77,3465,true)
  on conflict(contract_no) do update set car_name=excluded.car_name,total_installments=excluded.total_installments,default_installment_amount=excluded.default_installment_amount,active=true,updated_at=now() returning id into cid;
  insert into public.installments(contract_id,installment_no,amount,payer1_amount,payer2_amount,status)
  select cid,n,0,0,0,'paid' from generate_series(1,21)n on conflict(contract_id,installment_no) do update set status='paid';
  with source(installment_no,amount,payer1_amount,payer2_amount) as (values
      (22, 3465, 3153.00, 312.00),
      (23, 3465, 3153.00, 312.00),
      (24, 3465, 3153.00, 312.00),
      (25, 4455, 4053.85, 401.15),
      (26, 4455, 4053.85, 401.15),
      (27, 4455, 4053.85, 401.15),
      (28, 4455, 4053.85, 401.15),
      (29, 4455, 4053.85, 401.15),
      (30, 4455, 4053.85, 401.15),
      (31, 4455, 4053.85, 401.15),
      (32, 4455, 4053.85, 401.15),
      (33, 4455, 4053.85, 401.15),
      (34, 4455, 4053.85, 401.15),
      (35, 4455, 4053.85, 401.15),
      (36, 4455, 4053.85, 401.15),
      (37, 4950, 4504.28, 445.72),
      (38, 4950, 4504.28, 445.72),
      (39, 4950, 4504.28, 445.72),
      (40, 4950, 4504.28, 445.72),
      (41, 4950, 4504.28, 445.72),
      (42, 4950, 4504.28, 445.72),
      (43, 4950, 4504.28, 445.72),
      (44, 4950, 4504.28, 445.72),
      (45, 4950, 4504.28, 445.72),
      (46, 4950, 4504.28, 445.72),
      (47, 4950, 4504.28, 445.72),
      (48, 4950, 4504.28, 445.72),
      (49, 4950, 4504.28, 445.72),
      (50, 4950, 4504.28, 445.72),
      (51, 4950, 4504.28, 445.72),
      (52, 4950, 4504.28, 445.72),
      (53, 4950, 4504.28, 445.72),
      (54, 4950, 4504.28, 445.72),
      (55, 4950, 4504.28, 445.72),
      (56, 4950, 4504.28, 445.72),
      (57, 4950, 4504.28, 445.72),
      (58, 4950, 4504.28, 445.72),
      (59, 4950, 4504.28, 445.72),
      (60, 4950, 4504.28, 445.72),
      (61, 4950, 4504.28, 445.72),
      (62, 4950, 4504.28, 445.72),
      (63, 4950, 4504.28, 445.72),
      (64, 4950, 4504.28, 445.72),
      (65, 4950, 4504.28, 445.72),
      (66, 4950, 4504.28, 445.72),
      (67, 4950, 4504.28, 445.72),
      (68, 4950, 4504.28, 445.72),
      (69, 4950, 4504.28, 445.72),
      (70, 4950, 4504.28, 445.72),
      (71, 4950, 4504.28, 445.72),
      (72, 4950, 4504.28, 445.72),
      (73, 4950, 4504.28, 445.72),
      (74, 4950, 4504.28, 445.72),
      (75, 4950, 4504.28, 445.72),
      (76, 4950, 4504.28, 445.72),
      (77, 1894, 1723.46, 170.54)
  )
  insert into public.installments(contract_id,installment_no,amount,payer1_amount,payer2_amount,status)
  select cid,installment_no,amount,payer1_amount,payer2_amount,'pending' from source
  on conflict(contract_id,installment_no) do update set amount=excluded.amount,payer1_amount=excluded.payer1_amount,payer2_amount=excluded.payer2_amount,updated_at=now();
  select id into p1 from auth.users where lower(email)='ciradech16@gmail.com' limit 1;
  select id into p2 from auth.users where lower(email)='phikunthong.t@kkumail.com' limit 1;
  if p1 is null then raise exception 'ไม่พบบัญชีคนที่ 1: ciradech16@gmail.com'; end if;
  if p2 is null then raise exception 'ไม่พบบัญชีคนที่ 2: phikunthong.t@kkumail.com'; end if;
  insert into public.profiles(id,display_name) values(p1,'ผู้ผ่อนคนที่ 1'),(p2,'ผู้ผ่อนคนที่ 2') on conflict(id) do update set display_name=excluded.display_name,updated_at=now();
  delete from public.contract_members where contract_id=cid and(member_no in(1,2) or user_id in(p1,p2));
  insert into public.contract_members(contract_id,user_id,role,member_no,active) values(cid,p1,'payer',1,true),(cid,p2,'owner',2,true);
end; $$;

-- Expected: 56 rows, total 263749.00, split totals 239999.86 and 23749.14.
select count(*) remaining_rows,sum(amount) remaining_total,sum(payer1_amount) payer1_total,sum(payer2_amount) payer2_total
from public.installments i join public.contracts c on c.id=i.contract_id where c.contract_no='35-6404576' and i.installment_no between 22 and 77;
