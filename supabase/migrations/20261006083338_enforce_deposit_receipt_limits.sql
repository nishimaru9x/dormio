create or replace function public.enforce_deposit_receipt_limit()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $function$
declare
	v_deposit_limit numeric(12, 2);
	v_prior_receipts numeric;
	v_reservation_status text;
	v_source_reservation_id uuid;
begin
	if new.transaction_type <> 'receipt' then
		return new;
	end if;

	if new.reservation_id is not null then
		select room.default_security_deposit
		into v_deposit_limit
		from public.reservations as reservation
		join public.rooms as room
			on room.id = reservation.room_id
			and room.owner_id = reservation.owner_id
		where reservation.id = new.reservation_id
			and reservation.owner_id = new.owner_id
		for update of room;

		if not found then
			raise exception using errcode = '23503', message = 'Room or reservation not found for deposit receipt';
		end if;

		select reservation.status
		into v_reservation_status
		from public.reservations as reservation
		where reservation.id = new.reservation_id
			and reservation.owner_id = new.owner_id
		for update;

		if not found then
			raise exception using errcode = '23503', message = 'Reservation not found for deposit receipt';
		end if;

		if v_reservation_status <> 'reserved' then
			raise exception using errcode = '55000', message = 'Cannot receive a deposit for an inactive reservation';
		end if;

		select coalesce(pg_catalog.sum(deposit_txn.amount), 0)
		into v_prior_receipts
		from public.deposit_transactions as deposit_txn
		where deposit_txn.owner_id = new.owner_id
			and deposit_txn.reservation_id = new.reservation_id
			and deposit_txn.transaction_type = 'receipt';
	elsif new.contract_id is not null then
		select contract.security_deposit_amount, contract.source_reservation_id
		into v_deposit_limit, v_source_reservation_id
		from public.contracts as contract
		where contract.id = new.contract_id
			and contract.owner_id = new.owner_id
		for update;

		if not found then
			raise exception using errcode = '23503', message = 'Contract not found for deposit receipt';
		end if;

		select coalesce(pg_catalog.sum(deposit_txn.amount), 0)
		into v_prior_receipts
		from public.deposit_transactions as deposit_txn
		where deposit_txn.owner_id = new.owner_id
			and deposit_txn.transaction_type = 'receipt'
			and (
				deposit_txn.contract_id = new.contract_id
				or (
					v_source_reservation_id is not null
					and deposit_txn.reservation_id = v_source_reservation_id
				)
			);
	else
		raise exception using errcode = '23514', message = 'Deposit receipt must belong to a reservation or contract';
	end if;

	if v_prior_receipts + new.amount > v_deposit_limit then
		raise exception using errcode = '23514', message = 'Deposit receipt exceeds the refundable security deposit due';
	end if;

	return new;
end;
$function$;

create or replace function public.enforce_contract_deposit_limit()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $function$
declare
	v_prior_receipts numeric;
begin
	if new.source_reservation_id is not null then
		perform 1
		from public.reservations as reservation
		where reservation.id = new.source_reservation_id
			and reservation.owner_id = new.owner_id
		for update;

		if not found then
			raise exception using errcode = '23503', message = 'Source reservation not found';
		end if;
	end if;

	select coalesce(pg_catalog.sum(deposit_txn.amount), 0)
	into v_prior_receipts
	from public.deposit_transactions as deposit_txn
	where deposit_txn.owner_id = new.owner_id
		and deposit_txn.transaction_type = 'receipt'
		and (
			deposit_txn.contract_id = new.id
			or (
				new.source_reservation_id is not null
				and deposit_txn.reservation_id = new.source_reservation_id
			)
		);

	if v_prior_receipts > new.security_deposit_amount then
		raise exception using errcode = '23514', message = 'Contract deposit cannot be less than deposits already received';
	end if;

	return new;
end;
$function$;

drop trigger if exists deposit_transactions_receipt_limit on public.deposit_transactions;
create trigger deposit_transactions_receipt_limit
before insert on public.deposit_transactions
for each row
execute function public.enforce_deposit_receipt_limit();

drop trigger if exists contracts_deposit_limit_before_insert on public.contracts;
create trigger contracts_deposit_limit_before_insert
before insert on public.contracts
for each row
execute function public.enforce_contract_deposit_limit();

drop trigger if exists contracts_deposit_limit_before_amount_update on public.contracts;
create trigger contracts_deposit_limit_before_amount_update
before update of security_deposit_amount on public.contracts
for each row
execute function public.enforce_contract_deposit_limit();

revoke all on function public.enforce_deposit_receipt_limit() from public, anon, authenticated;
revoke all on function public.enforce_contract_deposit_limit() from public, anon, authenticated;
