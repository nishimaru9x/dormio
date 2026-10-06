create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  room_number text not null check (length(btrim(room_number)) > 0),
  default_monthly_rent numeric(12, 2) not null default 0 check (default_monthly_rent >= 0),
  default_security_deposit numeric(12, 2) not null default 0 check (default_security_deposit >= 0),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, owner_id)
);

create unique index rooms_owner_room_number_active_idx
  on public.rooms (owner_id, lower(room_number))
  where archived_at is null;

create table public.renters (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  name text not null check (length(btrim(name)) > 0),
  phone_number text not null check (length(btrim(phone_number)) > 0),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, owner_id)
);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  name text not null check (length(btrim(name)) > 0),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, owner_id)
);

create unique index services_owner_name_active_idx
  on public.services (owner_id, lower(name))
  where archived_at is null;

create table public.room_service_settings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  room_id uuid not null,
  service_id uuid not null,
  billing_basis text not null check (billing_basis in ('per_room', 'per_person', 'by_usage')),
  rate numeric(14, 4) not null check (rate >= 0),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  unique (room_id, service_id),
  foreign key (room_id, owner_id) references public.rooms (id, owner_id) on delete restrict,
  foreign key (service_id, owner_id) references public.services (id, owner_id) on delete restrict
);

create table public.reservations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  room_id uuid not null,
  renter_id uuid not null,
  intended_move_in_date date not null,
  status text not null default 'reserved' check (status in ('reserved', 'cancelled', 'converted')),
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  foreign key (room_id, owner_id) references public.rooms (id, owner_id) on delete restrict,
  foreign key (renter_id, owner_id) references public.renters (id, owner_id) on delete restrict
);

create unique index reservations_one_active_per_room_idx
  on public.reservations (room_id)
  where status = 'reserved';

create table public.contracts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  room_id uuid not null,
  renter_id uuid not null,
  source_reservation_id uuid,
  move_in_date date not null,
  monthly_rent numeric(12, 2) not null check (monthly_rent >= 0),
  security_deposit_amount numeric(12, 2) not null check (security_deposit_amount >= 0),
  resident_count integer not null default 1 check (resident_count > 0),
  status text not null default 'active' check (status in ('active', 'ended')),
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  foreign key (room_id, owner_id) references public.rooms (id, owner_id) on delete restrict,
  foreign key (renter_id, owner_id) references public.renters (id, owner_id) on delete restrict,
  foreign key (source_reservation_id, owner_id) references public.reservations (id, owner_id) on delete restrict
);

create unique index contracts_one_active_per_room_idx
  on public.contracts (room_id)
  where status = 'active';

create unique index contracts_one_per_source_reservation_idx
  on public.contracts (source_reservation_id)
  where source_reservation_id is not null;

create table public.contract_terminations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  contract_id uuid not null,
  move_out_date date not null,
  confirmed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (contract_id),
  unique (id, owner_id, contract_id),
  foreign key (contract_id, owner_id) references public.contracts (id, owner_id) on delete restrict
);

create table public.contract_service_settings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  contract_id uuid not null,
  service_id uuid not null,
  billing_basis text not null check (billing_basis in ('per_room', 'per_person', 'by_usage')),
  rate numeric(14, 4) not null check (rate >= 0),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  unique (contract_id, service_id),
  foreign key (contract_id, owner_id) references public.contracts (id, owner_id) on delete restrict,
  foreign key (service_id, owner_id) references public.services (id, owner_id) on delete restrict
);

create table public.meter_readings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  contract_service_setting_id uuid not null,
  period_start date not null,
  period_end date not null,
  start_reading numeric(14, 3) not null check (start_reading >= 0),
  end_reading numeric(14, 3) not null check (end_reading >= start_reading),
  status text not null default 'draft' check (status in ('draft', 'finalized', 'posted')),
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  unique (contract_service_setting_id, period_start),
  check (period_end > period_start),
  foreign key (contract_service_setting_id, owner_id) references public.contract_service_settings (id, owner_id) on delete restrict
);

create table public.bills (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  contract_id uuid not null,
  contract_termination_id uuid,
  bill_type text not null check (bill_type in ('monthly', 'contract_end')),
  billing_period_start date,
  due_date date,
  status text not null default 'draft' check (status in ('draft', 'posted')),
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  check (
    (bill_type = 'monthly'
      and billing_period_start is not null
      and billing_period_start = date_trunc('month', billing_period_start)::date
      and contract_termination_id is null
      and due_date is not null)
    or
    (bill_type = 'contract_end'
      and billing_period_start is null
      and contract_termination_id is not null)
  ),
  check ((status = 'draft' and posted_at is null) or (status = 'posted' and posted_at is not null)),
  foreign key (contract_id, owner_id) references public.contracts (id, owner_id) on delete restrict,
  foreign key (contract_termination_id, owner_id, contract_id)
    references public.contract_terminations (id, owner_id, contract_id) on delete restrict
);

create unique index bills_one_monthly_per_contract_idx
  on public.bills (contract_id, billing_period_start)
  where bill_type = 'monthly';

create unique index bills_one_contract_end_per_termination_idx
  on public.bills (contract_termination_id)
  where bill_type = 'contract_end';

create table public.bill_lines (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  bill_id uuid not null,
  line_type text not null check (line_type in ('rent', 'final_rent', 'service', 'deposit_due', 'deposit_applied', 'deposit_refund_due')),
  amount numeric(12, 2) not null check (amount > 0),
  description text not null check (length(btrim(description)) > 0),
  category_snapshot text,
  service_id uuid,
  service_name_snapshot text,
  calculation_snapshot jsonb not null default '{}'::jsonb,
  meter_reading_id uuid,
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  check (
    (line_type = 'service' and service_id is not null and service_name_snapshot is not null)
    or (line_type <> 'service' and service_id is null and service_name_snapshot is null)
  ),
  foreign key (bill_id, owner_id) references public.bills (id, owner_id) on delete restrict,
  foreign key (service_id, owner_id) references public.services (id, owner_id) on delete restrict,
  foreign key (meter_reading_id, owner_id) references public.meter_readings (id, owner_id) on delete restrict
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  renter_id uuid not null,
  amount numeric(12, 2) not null check (amount > 0),
  paid_on date not null,
  method text not null check (method in ('cash', 'transfer')),
  idempotency_key uuid,
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  unique (owner_id, idempotency_key),
  foreign key (renter_id, owner_id) references public.renters (id, owner_id) on delete restrict
);

create table public.deposit_transactions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  transaction_type text not null check (transaction_type in ('receipt', 'application', 'forfeiture', 'refund')),
  amount numeric(12, 2) not null check (amount > 0),
  occurred_on date not null,
  method text check (method in ('cash', 'transfer')),
  payment_id uuid,
  reservation_id uuid,
  contract_id uuid,
  bill_line_id uuid,
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  check (
    (transaction_type = 'receipt'
      and method is not null
      and bill_line_id is null
      and (
        (reservation_id is not null and contract_id is null and payment_id is null)
        or (reservation_id is null and contract_id is not null and payment_id is not null)
      ))
    or
    (transaction_type = 'application'
      and method is null
      and payment_id is null
      and reservation_id is null
      and contract_id is not null
      and bill_line_id is not null)
    or
    (transaction_type = 'forfeiture'
      and method is null
      and payment_id is null
      and reservation_id is not null
      and contract_id is null
      and bill_line_id is null)
    or
    (transaction_type = 'refund'
      and method is not null
      and payment_id is null
      and reservation_id is null
      and contract_id is not null
      and bill_line_id is null)
  ),
  foreign key (payment_id, owner_id) references public.payments (id, owner_id) on delete restrict,
  foreign key (reservation_id, owner_id) references public.reservations (id, owner_id) on delete restrict,
  foreign key (contract_id, owner_id) references public.contracts (id, owner_id) on delete restrict,
  foreign key (bill_line_id, owner_id) references public.bill_lines (id, owner_id) on delete restrict
);

create table public.income_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  entry_type text not null check (entry_type in ('rent', 'service', 'other', 'reservation_forfeiture')),
  amount numeric(12, 2) not null check (amount > 0),
  income_date date not null,
  category text not null check (length(btrim(category)) > 0),
  bill_line_id uuid,
  deposit_transaction_id uuid,
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  check (
    (entry_type in ('rent', 'service') and bill_line_id is not null and deposit_transaction_id is null)
    or (entry_type = 'reservation_forfeiture' and bill_line_id is null and deposit_transaction_id is not null)
    or (entry_type = 'other' and bill_line_id is null and deposit_transaction_id is null)
  ),
  foreign key (bill_line_id, owner_id) references public.bill_lines (id, owner_id) on delete restrict,
  foreign key (deposit_transaction_id, owner_id) references public.deposit_transactions (id, owner_id) on delete restrict
);

create unique index income_entries_one_per_bill_line_idx
  on public.income_entries (bill_line_id)
  where bill_line_id is not null;

create unique index income_entries_one_per_deposit_transaction_idx
  on public.income_entries (deposit_transaction_id)
  where deposit_transaction_id is not null;

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  room_id uuid,
  amount numeric(12, 2) not null check (amount > 0),
  spent_on date not null,
  category text not null check (length(btrim(category)) > 0),
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  foreign key (room_id, owner_id) references public.rooms (id, owner_id) on delete restrict
);

create table public.maintenance_issues (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  room_id uuid not null,
  description text not null check (length(btrim(description)) > 0),
  issue_date date not null,
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved')),
  notes text,
  created_at timestamptz not null default now(),
  unique (id, owner_id),
  foreign key (room_id, owner_id) references public.rooms (id, owner_id) on delete restrict
);

do $$
declare
  target_table text;
begin
  for target_table in
    select unnest(array[
      'rooms',
      'renters',
      'services',
      'room_service_settings',
      'reservations',
      'contracts',
      'contract_terminations',
      'contract_service_settings',
      'meter_readings',
      'bills',
      'bill_lines',
      'payments',
      'deposit_transactions',
      'income_entries',
      'expenses',
      'maintenance_issues'
    ]::text[])
  loop
    execute format('alter table public.%I enable row level security', target_table);
    execute format(
      'create policy %I on public.%I for select to authenticated using (owner_id = (select auth.uid()))',
      target_table || '_owner_select',
      target_table
    );
    execute format('revoke all privileges on table public.%I from anon, authenticated', target_table);
    execute format('grant select on table public.%I to authenticated', target_table);
  end loop;
end;
$$;