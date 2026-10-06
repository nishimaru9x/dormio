create function public.create_room(
  p_room_number text,
  p_default_monthly_rent numeric,
  p_default_security_deposit numeric
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_owner_id uuid := auth.uid();
  v_room_id uuid;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  if p_room_number is null or pg_catalog.length(pg_catalog.btrim(p_room_number)) = 0 then
    raise exception using errcode = '22023', message = 'Room number is required';
  end if;

  if p_default_monthly_rent is null
    or p_default_monthly_rent < 0
    or p_default_monthly_rent <> pg_catalog.round(p_default_monthly_rent, 2)
  then
    raise exception using errcode = '22023', message = 'Monthly rent must be a non-negative amount with at most two decimal places';
  end if;

  if p_default_security_deposit is null
    or p_default_security_deposit < 0
    or p_default_security_deposit <> pg_catalog.round(p_default_security_deposit, 2)
  then
    raise exception using errcode = '22023', message = 'Security deposit must be a non-negative amount with at most two decimal places';
  end if;

  insert into public.rooms (
    owner_id,
    room_number,
    default_monthly_rent,
    default_security_deposit
  )
  values (
    v_owner_id,
    pg_catalog.btrim(p_room_number),
    p_default_monthly_rent,
    p_default_security_deposit
  )
  returning id into v_room_id;

  return v_room_id;
end;
$function$;

create function public.create_renter(
  p_name text,
  p_phone_number text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_owner_id uuid := auth.uid();
  v_renter_id uuid;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  if p_name is null or pg_catalog.length(pg_catalog.btrim(p_name)) = 0 then
    raise exception using errcode = '22023', message = 'Renter name is required';
  end if;

  if p_phone_number is null or pg_catalog.length(pg_catalog.btrim(p_phone_number)) = 0 then
    raise exception using errcode = '22023', message = 'Renter phone number is required';
  end if;

  insert into public.renters (owner_id, name, phone_number)
  values (v_owner_id, pg_catalog.btrim(p_name), pg_catalog.btrim(p_phone_number))
  returning id into v_renter_id;

  return v_renter_id;
end;
$function$;

create function public.create_service(p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_owner_id uuid := auth.uid();
  v_service_id uuid;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  if p_name is null or pg_catalog.length(pg_catalog.btrim(p_name)) = 0 then
    raise exception using errcode = '22023', message = 'Service name is required';
  end if;

  insert into public.services (owner_id, name)
  values (v_owner_id, pg_catalog.btrim(p_name))
  returning id into v_service_id;

  return v_service_id;
end;
$function$;

create function public.set_room_service_setting(
  p_room_id uuid,
  p_service_id uuid,
  p_billing_basis text,
  p_rate numeric,
  p_enabled boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_owner_id uuid := auth.uid();
  v_setting_id uuid;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  if p_room_id is null or p_service_id is null then
    raise exception using errcode = '22023', message = 'Room and service are required';
  end if;

  if p_billing_basis is null or p_billing_basis not in ('per_room', 'per_person', 'by_usage') then
    raise exception using errcode = '22023', message = 'Invalid service billing basis';
  end if;

  if p_rate is null or p_rate < 0 or p_rate <> pg_catalog.round(p_rate, 4) then
    raise exception using errcode = '22023', message = 'Service rate must be non-negative with at most four decimal places';
  end if;

  if p_enabled is null then
    raise exception using errcode = '22023', message = 'Service enabled state is required';
  end if;

  perform 1
  from public.rooms as room
  where room.id = p_room_id
    and room.owner_id = v_owner_id
    and room.archived_at is null
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  perform 1
  from public.services as service
  where service.id = p_service_id
    and service.owner_id = v_owner_id
    and service.archived_at is null;

  if not found then
    raise exception using errcode = 'P0002', message = 'Service not found';
  end if;

  insert into public.room_service_settings (
    owner_id,
    room_id,
    service_id,
    billing_basis,
    rate,
    enabled
  )
  values (
    v_owner_id,
    p_room_id,
    p_service_id,
    p_billing_basis,
    p_rate,
    p_enabled
  )
  on conflict (room_id, service_id)
  do update set
    billing_basis = excluded.billing_basis,
    rate = excluded.rate,
    enabled = excluded.enabled
  returning id into v_setting_id;

  return v_setting_id;
end;
$function$;

create function public.create_reservation(
  p_room_id uuid,
  p_renter_id uuid,
  p_intended_move_in_date date,
  p_deposit_amount numeric default 0,
  p_deposit_received_on date default null,
  p_deposit_method text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_owner_id uuid := auth.uid();
  v_reservation_id uuid;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  if p_room_id is null or p_renter_id is null or p_intended_move_in_date is null then
    raise exception using errcode = '22023', message = 'Room, renter, and intended move-in date are required';
  end if;

  if p_deposit_amount is null
    or p_deposit_amount < 0
    or p_deposit_amount <> pg_catalog.round(p_deposit_amount, 2)
  then
    raise exception using errcode = '22023', message = 'Deposit amount must be non-negative with at most two decimal places';
  end if;

  if p_deposit_amount > 0 then
    if p_deposit_received_on is null
      or p_deposit_method is null
      or p_deposit_method not in ('cash', 'transfer')
    then
      raise exception using errcode = '22023', message = 'Deposit receipt date and method are required';
    end if;
  elsif p_deposit_received_on is not null or p_deposit_method is not null then
    raise exception using errcode = '22023', message = 'Receipt details require a positive deposit amount';
  end if;

  perform 1
  from public.rooms as room
  where room.id = p_room_id
    and room.owner_id = v_owner_id
    and room.archived_at is null
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  perform 1
  from public.renters as renter
  where renter.id = p_renter_id
    and renter.owner_id = v_owner_id
    and renter.archived_at is null;

  if not found then
    raise exception using errcode = 'P0002', message = 'Renter not found';
  end if;

  if exists (
    select 1
    from public.reservations as reservation
    where reservation.owner_id = v_owner_id
      and reservation.room_id = p_room_id
      and reservation.status = 'reserved'
  ) or exists (
    select 1
    from public.contracts as contract
    where contract.owner_id = v_owner_id
      and contract.room_id = p_room_id
      and contract.status = 'active'
  ) then
    raise exception using errcode = '55000', message = 'Room is not available';
  end if;

  insert into public.reservations (
    owner_id,
    room_id,
    renter_id,
    intended_move_in_date
  )
  values (
    v_owner_id,
    p_room_id,
    p_renter_id,
    p_intended_move_in_date
  )
  returning id into v_reservation_id;

  if p_deposit_amount > 0 then
    insert into public.deposit_transactions (
      owner_id,
      transaction_type,
      amount,
      occurred_on,
      method,
      reservation_id
    )
    values (
      v_owner_id,
      'receipt',
      p_deposit_amount,
      p_deposit_received_on,
      p_deposit_method,
      v_reservation_id
    );
  end if;

  return v_reservation_id;
end;
$function$;

create function public.cancel_reservation(p_reservation_id uuid)
returns numeric
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_owner_id uuid := auth.uid();
  v_room_id uuid;
  v_reservation public.reservations%rowtype;
  v_forfeited_amount numeric(12, 2);
  v_forfeiture_id uuid;
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  select reservation.room_id
  into v_room_id
  from public.reservations as reservation
  where reservation.id = p_reservation_id
    and reservation.owner_id = v_owner_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'Reservation not found';
  end if;

  perform 1
  from public.rooms as room
  where room.id = v_room_id
    and room.owner_id = v_owner_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  select reservation.*
  into v_reservation
  from public.reservations as reservation
  where reservation.id = p_reservation_id
    and reservation.owner_id = v_owner_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Reservation not found';
  end if;

  if v_reservation.status = 'cancelled' then
    select coalesce(pg_catalog.sum(deposit_txn.amount), 0)
    into v_forfeited_amount
    from public.deposit_transactions as deposit_txn
    where deposit_txn.reservation_id = p_reservation_id
      and deposit_txn.owner_id = v_owner_id
      and deposit_txn.transaction_type = 'forfeiture';

    return v_forfeited_amount;
  end if;

  if v_reservation.status <> 'reserved' then
    raise exception using errcode = '55000', message = 'Only an active reservation can be cancelled';
  end if;

  select coalesce(pg_catalog.sum(deposit_txn.amount), 0)
  into v_forfeited_amount
  from public.deposit_transactions as deposit_txn
  where deposit_txn.reservation_id = p_reservation_id
    and deposit_txn.owner_id = v_owner_id
    and deposit_txn.transaction_type = 'receipt';

  update public.reservations
  set status = 'cancelled'
  where id = p_reservation_id
    and owner_id = v_owner_id;

  if v_forfeited_amount > 0 then
    insert into public.deposit_transactions (
      owner_id,
      transaction_type,
      amount,
      occurred_on,
      reservation_id
    )
    values (
      v_owner_id,
      'forfeiture',
      v_forfeited_amount,
      current_date,
      p_reservation_id
    )
    returning id into v_forfeiture_id;

    insert into public.income_entries (
      owner_id,
      entry_type,
      amount,
      income_date,
      category,
      deposit_transaction_id
    )
    values (
      v_owner_id,
      'reservation_forfeiture',
      v_forfeited_amount,
      current_date,
      'Forfeited reservation deposit',
      v_forfeiture_id
    );
  end if;

  return v_forfeited_amount;
end;
$function$;

create function public.create_move_in(
  p_room_id uuid,
  p_renter_id uuid,
  p_move_in_date date,
  p_first_bill_due_date date,
  p_source_reservation_id uuid default null,
  p_monthly_rent numeric default null,
  p_security_deposit_amount numeric default null,
  p_resident_count integer default 1
)
returns table (contract_id uuid, first_bill_id uuid)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_owner_id uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_reservation public.reservations%rowtype;
  v_contract_id uuid;
  v_bill_id uuid;
  v_monthly_rent numeric(12, 2);
  v_security_deposit_amount numeric(12, 2);
  v_reservation_deposit numeric(12, 2) := 0;
  v_deposit_due numeric(12, 2);
  v_period_start date;
  v_service record;
  v_headcount integer;
  v_line_amount numeric(12, 2);
begin
  if v_owner_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  if p_room_id is null
    or p_renter_id is null
    or p_move_in_date is null
    or p_first_bill_due_date is null
    or p_resident_count is null
    or p_resident_count <= 0
  then
    raise exception using errcode = '22023', message = 'Room, renter, dates, and a positive resident count are required';
  end if;

  if p_monthly_rent is not null
    and (p_monthly_rent < 0 or p_monthly_rent <> pg_catalog.round(p_monthly_rent, 2))
  then
    raise exception using errcode = '22023', message = 'Monthly rent must be non-negative with at most two decimal places';
  end if;

  if p_security_deposit_amount is not null
    and (p_security_deposit_amount < 0 or p_security_deposit_amount <> pg_catalog.round(p_security_deposit_amount, 2))
  then
    raise exception using errcode = '22023', message = 'Security deposit must be non-negative with at most two decimal places';
  end if;

  select room.*
  into v_room
  from public.rooms as room
  where room.id = p_room_id
    and room.owner_id = v_owner_id
    and room.archived_at is null
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  perform 1
  from public.renters as renter
  where renter.id = p_renter_id
    and renter.owner_id = v_owner_id
    and renter.archived_at is null;

  if not found then
    raise exception using errcode = 'P0002', message = 'Renter not found';
  end if;

  if p_source_reservation_id is not null then
    select reservation.*
    into v_reservation
    from public.reservations as reservation
    where reservation.id = p_source_reservation_id
      and reservation.owner_id = v_owner_id
    for update;

    if not found then
      raise exception using errcode = 'P0002', message = 'Reservation not found';
    end if;

    if v_reservation.status <> 'reserved'
      or v_reservation.room_id <> p_room_id
      or v_reservation.renter_id <> p_renter_id
    then
      raise exception using errcode = '55000', message = 'Reservation is not active for this room and renter';
    end if;

    select coalesce(pg_catalog.sum(deposit_txn.amount), 0)
    into v_reservation_deposit
    from public.deposit_transactions as deposit_txn
    where deposit_txn.owner_id = v_owner_id
      and deposit_txn.reservation_id = p_source_reservation_id
      and deposit_txn.transaction_type = 'receipt';
  elsif exists (
    select 1
    from public.reservations as reservation
    where reservation.owner_id = v_owner_id
      and reservation.room_id = p_room_id
      and reservation.status = 'reserved'
  ) then
    raise exception using errcode = '55000', message = 'Room has an active reservation';
  end if;

  if exists (
    select 1
    from public.contracts as contract
    where contract.owner_id = v_owner_id
      and contract.room_id = p_room_id
      and contract.status = 'active'
  ) then
    raise exception using errcode = '55000', message = 'Room already has an active contract';
  end if;

  v_monthly_rent := coalesce(p_monthly_rent, v_room.default_monthly_rent);
  v_security_deposit_amount := coalesce(p_security_deposit_amount, v_room.default_security_deposit);
  v_period_start := pg_catalog.date_trunc('month', p_move_in_date::timestamp)::date;
  v_deposit_due := greatest(v_security_deposit_amount - v_reservation_deposit, 0);

  insert into public.contracts (
    owner_id,
    room_id,
    renter_id,
    source_reservation_id,
    move_in_date,
    monthly_rent,
    security_deposit_amount,
    resident_count
  )
  values (
    v_owner_id,
    p_room_id,
    p_renter_id,
    p_source_reservation_id,
    p_move_in_date,
    v_monthly_rent,
    v_security_deposit_amount,
    p_resident_count
  )
  returning id into v_contract_id;

  if p_source_reservation_id is not null then
    update public.reservations
    set status = 'converted'
    where id = p_source_reservation_id
      and owner_id = v_owner_id;
  end if;

  insert into public.contract_service_settings (
    owner_id,
    contract_id,
    service_id,
    billing_basis,
    rate,
    enabled
  )
  select
    v_owner_id,
    v_contract_id,
    setting.service_id,
    setting.billing_basis,
    setting.rate,
    setting.enabled
  from public.room_service_settings as setting
  join public.services as catalog_service
    on catalog_service.id = setting.service_id
    and catalog_service.owner_id = setting.owner_id
  where setting.owner_id = v_owner_id
    and setting.room_id = p_room_id
    and catalog_service.archived_at is null;

  insert into public.bills (
    owner_id,
    contract_id,
    bill_type,
    billing_period_start,
    due_date
  )
  values (
    v_owner_id,
    v_contract_id,
    'monthly',
    v_period_start,
    p_first_bill_due_date
  )
  returning id into v_bill_id;

  if v_monthly_rent > 0 then
    insert into public.bill_lines (
      owner_id,
      bill_id,
      line_type,
      amount,
      description,
      category_snapshot,
      calculation_snapshot
    )
    values (
      v_owner_id,
      v_bill_id,
      'rent',
      v_monthly_rent,
      'Monthly rent',
      'Rent',
      pg_catalog.jsonb_build_object(
        'monthly_rent', v_monthly_rent,
        'billing_period_start', v_period_start
      )
    );
  end if;

  if v_deposit_due > 0 then
    insert into public.bill_lines (
      owner_id,
      bill_id,
      line_type,
      amount,
      description,
      category_snapshot,
      calculation_snapshot
    )
    values (
      v_owner_id,
      v_bill_id,
      'deposit_due',
      v_deposit_due,
      'Remaining refundable security deposit',
      'Security deposit',
      pg_catalog.jsonb_build_object(
        'contract_deposit', v_security_deposit_amount,
        'reservation_deposit_credit', v_reservation_deposit
      )
    );
  end if;

  for v_service in
    select
      setting.service_id,
      setting.billing_basis,
      setting.rate,
      catalog_service.name as service_name
    from public.contract_service_settings as setting
    join public.services as catalog_service
      on catalog_service.id = setting.service_id
      and catalog_service.owner_id = setting.owner_id
    where setting.owner_id = v_owner_id
      and setting.contract_id = v_contract_id
      and setting.enabled
      and setting.billing_basis in ('per_room', 'per_person')
    order by catalog_service.name
  loop
    if v_service.billing_basis = 'per_person' then
      v_headcount := case when p_move_in_date = v_period_start then p_resident_count else 0 end;
      v_line_amount := pg_catalog.round(v_service.rate * v_headcount, 2);
    else
      v_headcount := null;
      v_line_amount := pg_catalog.round(v_service.rate, 2);
    end if;

    if v_line_amount > 0 then
      insert into public.bill_lines (
        owner_id,
        bill_id,
        line_type,
        amount,
        description,
        category_snapshot,
        service_id,
        service_name_snapshot,
        calculation_snapshot
      )
      values (
        v_owner_id,
        v_bill_id,
        'service',
        v_line_amount,
        v_service.service_name,
        v_service.service_name,
        v_service.service_id,
        v_service.service_name,
        pg_catalog.jsonb_build_object(
          'billing_basis', v_service.billing_basis,
          'rate', v_service.rate,
          'resident_count', v_headcount
        )
      );
    end if;
  end loop;

  return query select v_contract_id, v_bill_id;
end;
$function$;

revoke all on function public.create_room(text, numeric, numeric) from public, anon, authenticated;
revoke all on function public.create_renter(text, text) from public, anon, authenticated;
revoke all on function public.create_service(text) from public, anon, authenticated;
revoke all on function public.set_room_service_setting(uuid, uuid, text, numeric, boolean) from public, anon, authenticated;
revoke all on function public.create_reservation(uuid, uuid, date, numeric, date, text) from public, anon, authenticated;
revoke all on function public.cancel_reservation(uuid) from public, anon, authenticated;
revoke all on function public.create_move_in(uuid, uuid, date, date, uuid, numeric, numeric, integer) from public, anon, authenticated;

grant execute on function public.create_room(text, numeric, numeric) to authenticated;
grant execute on function public.create_renter(text, text) to authenticated;
grant execute on function public.create_service(text) to authenticated;
grant execute on function public.set_room_service_setting(uuid, uuid, text, numeric, boolean) to authenticated;
grant execute on function public.create_reservation(uuid, uuid, date, numeric, date, text) to authenticated;
grant execute on function public.cancel_reservation(uuid) to authenticated;
grant execute on function public.create_move_in(uuid, uuid, date, date, uuid, numeric, numeric, integer) to authenticated;