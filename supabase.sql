create extension if not exists pgcrypto;
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,display_name text not null,created_at timestamptz default now());
create table if not exists public.contracts(id uuid primary key default gen_random_uuid(),car_name text not null,contract_no text unique not null,total_installments int not null,active boolean default true);
create table if not exists public.contract_members(id uuid primary key default gen_random_uuid(),contract_id uuid references public.contracts on delete cascade,user_id uuid references public.profiles on delete cascade,role text check(role in('payer','owner')),member_no int check(member_no in(1,2)),active boolean default true,unique(contract_id,user_id),unique(contract_id,member_no));
create table if not exists public.installments(id uuid primary key default gen_random_uuid(),contract_id uuid references public.contracts on delete cascade,installment_no int not null,amount numeric(12,2) not null,payer1_amount numeric(12,2) not null default 0,payer2_amount numeric(12,2) not null default 0,due_date date,status text default 'pending' check(status in('pending','partial','submitted','paid','rejected')),owner_note text,verified_by uuid references public.profiles,verified_at timestamptz,created_at timestamptz default now(),updated_at timestamptz default now(),unique(contract_id,installment_no));
create table if not exists public.installment_slips(id uuid primary key default gen_random_uuid(),installment_id uuid references public.installments on delete cascade,payer_no int not null check(payer_no in(1,2)),uploaded_by uuid references public.profiles,amount numeric(12,2) not null check(amount>0),storage_path text unique not null,file_name text not null,mime_type text,file_size bigint,note text,created_at timestamptz default now());
create table if not exists public.car_documents(id uuid primary key default gen_random_uuid(),contract_id uuid references public.contracts on delete cascade,uploaded_by uuid references public.profiles,name text not null,file_path text not null,created_at timestamptz default now());
create or replace function public.new_profile() returns trigger language plpgsql security definer set search_path=public as $$begin insert into profiles(id,display_name) values(new.id,coalesce(split_part(new.email,'@',1),'ผู้ใช้')) on conflict do nothing;return new;end$$;
drop trigger if exists auth_profile on auth.users;create trigger auth_profile after insert on auth.users for each row execute function public.new_profile();
insert into profiles(id,display_name) select id,split_part(email,'@',1) from auth.users on conflict do nothing;
create or replace function public.is_member(cid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from contract_members where contract_id=cid and user_id=auth.uid() and active)$$;
create or replace function public.is_owner(cid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from contract_members where contract_id=cid and user_id=auth.uid() and role='owner' and active)$$;
create or replace function public.my_member_no(cid uuid) returns int language sql stable security definer set search_path=public as $$select member_no from contract_members where contract_id=cid and user_id=auth.uid() and active limit 1$$;
create or replace function public.refresh_status(iid uuid) returns void language plpgsql security definer set search_path=public as $$declare r1 numeric;r2 numeric;p1 numeric;p2 numeric;st text;begin select payer1_amount,payer2_amount,status into r1,r2,st from installments where id=iid;if st='paid' then return;end if;select coalesce(sum(amount) filter(where payer_no=1),0),coalesce(sum(amount) filter(where payer_no=2),0) into p1,p2 from installment_slips where installment_id=iid;update installments set status=case when p1=0 and p2=0 then 'pending' when p1>=r1 and p2>=r2 then 'submitted' else 'partial' end,updated_at=now() where id=iid;end$$;
create or replace function public.slip_changed() returns trigger language plpgsql security definer set search_path=public as $$begin perform refresh_status(coalesce(new.installment_id,old.installment_id));return coalesce(new,old);end$$;
drop trigger if exists slip_changed on installment_slips;create trigger slip_changed after insert or update or delete on installment_slips for each row execute function slip_changed();
create or replace function public.owner_verify_installment(p_installment_id uuid,p_action text,p_note text default null) returns void language plpgsql security definer set search_path=public as $$declare cid uuid;r1 numeric;r2 numeric;p1 numeric;p2 numeric;begin select contract_id,payer1_amount,payer2_amount into cid,r1,r2 from installments where id=p_installment_id;if not is_owner(cid) then raise exception 'เฉพาะเจ้าของเท่านั้น';end if;select coalesce(sum(amount) filter(where payer_no=1),0),coalesce(sum(amount) filter(where payer_no=2),0) into p1,p2 from installment_slips where installment_id=p_installment_id;if p_action='approve' then if p1<r1 or p2<r2 then raise exception 'ยอดของผู้ผ่อนทั้งสองคนยังไม่ครบ';end if;update installments set status='paid',owner_note=p_note,verified_by=auth.uid(),verified_at=now() where id=p_installment_id;elsif p_action='reject' then update installments set status='rejected',owner_note=p_note,verified_by=auth.uid(),verified_at=now() where id=p_installment_id;else raise exception 'action ไม่ถูกต้อง';end if;end$$;
grant execute on function owner_verify_installment(uuid,text,text) to authenticated;
alter table profiles enable row level security;alter table contracts enable row level security;alter table contract_members enable row level security;alter table installments enable row level security;alter table installment_slips enable row level security;alter table car_documents enable row level security;
create policy profiles_read on profiles for select to authenticated using(id=auth.uid() or exists(select 1 from contract_members a join contract_members b on b.contract_id=a.contract_id where a.user_id=auth.uid() and b.user_id=profiles.id));
create policy contracts_read on contracts for select to authenticated using(is_member(id));
create policy members_read on contract_members for select to authenticated using(is_member(contract_id));
create policy installments_read on installments for select to authenticated using(is_member(contract_id));
create policy slips_read on installment_slips for select to authenticated using(exists(select 1 from installments i where i.id=installment_id and is_member(i.contract_id)));
create policy slips_insert on installment_slips for insert to authenticated with check(uploaded_by=auth.uid() and exists(select 1 from installments i where i.id=installment_id and i.status<>'paid' and my_member_no(i.contract_id)=payer_no));
create policy slips_delete on installment_slips for delete to authenticated using(exists(select 1 from installments i where i.id=installment_id and i.status<>'paid' and(uploaded_by=auth.uid() or is_owner(i.contract_id))));
create policy docs_read on car_documents for select to authenticated using(is_member(contract_id));create policy docs_insert on car_documents for insert to authenticated with check(uploaded_by=auth.uid() and is_member(contract_id));
grant select on profiles,contracts,contract_members,installments to authenticated;grant select,insert,delete on installment_slips to authenticated;grant select,insert on car_documents to authenticated;
insert into storage.buckets(id,name,public) values('payment-slips','payment-slips',false),('car-documents','car-documents',false) on conflict(id) do nothing;
create policy storage_slip_read on storage.objects for select to authenticated using(bucket_id='payment-slips' and is_member(((storage.foldername(name))[1])::uuid));
create policy storage_slip_insert on storage.objects for insert to authenticated with check(bucket_id='payment-slips' and is_member(((storage.foldername(name))[1])::uuid) and ((storage.foldername(name))[3])::uuid=auth.uid());
create policy storage_doc_read on storage.objects for select to authenticated using(bucket_id='car-documents' and is_member(((storage.foldername(name))[1])::uuid));
create policy storage_doc_insert on storage.objects for insert to authenticated with check(bucket_id='car-documents' and is_member(((storage.foldername(name))[1])::uuid));
do $$declare cid uuid;p1 uuid;p2 uuid;begin insert into contracts(car_name,contract_no,total_installments) values('MITSUBISHI Attrage','35-6404576',77) on conflict(contract_no) do update set car_name=excluded.car_name returning id into cid;insert into installments(contract_id,installment_no,amount,payer1_amount,payer2_amount,status) select cid,n,0,0,0,'paid' from generate_series(1,21)n on conflict(contract_id,installment_no) do nothing;insert into installments(contract_id,installment_no,amount,payer1_amount,payer2_amount,status) values (22,3465,3153.00,312.00),
(23,3465,3153.00,312.00),
(24,3465,3153.00,312.00),
(25,4455,4053.85,401.15),
(26,4455,4053.85,401.15),
(27,4455,4053.85,401.15),
(28,4455,4053.85,401.15),
(29,4455,4053.85,401.15),
(30,4455,4053.85,401.15),
(31,4455,4053.85,401.15),
(32,4455,4053.85,401.15),
(33,4455,4053.85,401.15),
(34,4455,4053.85,401.15),
(35,4455,4053.85,401.15),
(36,4455,4053.85,401.15),
(37,4950,4504.28,445.72),
(38,4950,4504.28,445.72),
(39,4950,4504.28,445.72),
(40,4950,4504.28,445.72),
(41,4950,4504.28,445.72),
(42,4950,4504.28,445.72),
(43,4950,4504.28,445.72),
(44,4950,4504.28,445.72),
(45,4950,4504.28,445.72),
(46,4950,4504.28,445.72),
(47,4950,4504.28,445.72),
(48,4950,4504.28,445.72),
(49,4950,4504.28,445.72),
(50,4950,4504.28,445.72),
(51,4950,4504.28,445.72),
(52,4950,4504.28,445.72),
(53,4950,4504.28,445.72),
(54,4950,4504.28,445.72),
(55,4950,4504.28,445.72),
(56,4950,4504.28,445.72),
(57,4950,4504.28,445.72),
(58,4950,4504.28,445.72),
(59,4950,4504.28,445.72),
(60,4950,4504.28,445.72),
(61,4950,4504.28,445.72),
(62,4950,4504.28,445.72),
(63,4950,4504.28,445.72),
(64,4950,4504.28,445.72),
(65,4950,4504.28,445.72),
(66,4950,4504.28,445.72),
(67,4950,4504.28,445.72),
(68,4950,4504.28,445.72),
(69,4950,4504.28,445.72),
(70,4950,4504.28,445.72),
(71,4950,4504.28,445.72),
(72,4950,4504.28,445.72),
(73,4950,4504.28,445.72),
(74,4950,4504.28,445.72),
(75,4950,4504.28,445.72),
(76,4950,4504.28,445.72),
(77,1894,1723.46,170.54) on conflict(contract_id,installment_no) do update set amount=excluded.amount,payer1_amount=excluded.payer1_amount,payer2_amount=excluded.payer2_amount;select id into p1 from auth.users where lower(email)='ciradech16@gmail.com';select id into p2 from auth.users where lower(email)='phikunthong.t@kkumail.com';if p1 is null then raise exception 'ไม่พบบัญชีคนที่ 1: ciradech16@gmail.com';end if;if p2 is null then raise exception 'ไม่พบบัญชีคนที่ 2: phikunthong.t@kkumail.com';end if;insert into profiles(id,display_name) values(p1,'คนที่ 1'),(p2,'คนที่ 2') on conflict(id) do update set display_name=excluded.display_name;delete from contract_members where contract_id=cid and member_no in(1,2);insert into contract_members(contract_id,user_id,role,member_no) values(cid,p1,'payer',1),(cid,p2,'owner',2);end$$;
