# Dormio V1 Product Requirements

**Status:** Working scope. Confirmed requirements are separated from decisions that still need product-owner input.

## Product Goal

Help an individual landlord manage room availability, reservations, renter contracts, monthly charges, income and expenses, room services, and maintenance in one staff-only app.

## V1 Outcomes

The landlord can:

- See which rooms are available, reserved, or occupied.
- Reserve a room for a renter or move the renter in directly.
- Create a move-in contract using room defaults or contract-specific terms.
- Create the first month's bill, including rent, services, and any remaining deposit due.
- Record payments, track expenses, and review monthly income and expenses.
- Track maintenance issues separately from room availability.

## Primary User

- **User:** An individual landlord.
- **Access:** Staff-only; renters do not sign in or use Dormio in V1.

## V1 Requirements

### Rooms and renters

- Manage rooms as standalone records, without property, building, or address details. Each room has a name or number, default monthly rent, and default refundable security-deposit amount.
- Set each room's status to **Available**, **Reserved**, or **Occupied**. Maintenance is tracked separately and is not a room status in V1.
- Maintain renter records with **Name** and **Phone number** as required fields. Visitor tracking is not included.
- A room may have at most one active contract, linked to one main renter. The main renter may live with other residents, but Dormio does not store individual records for them. The contract records an anonymous resident headcount, including the main renter.

### Reservations and move-in contracts

- To reserve an available room, record the renter, intended move-in date, and any payment received toward the refundable security deposit. Record the payment amount, date, and method (**Cash** or **Transfer**). The room status changes to **Reserved**.
- If a reservation is canceled, the amount of security deposit received becomes income, categorized as **Forfeited reservation deposit**, and the room status returns to **Available**.
- Allow a renter to move into an available room without a prior reservation.
- When a renter moves in, create a contract linked to the renter and room, and record the move-in date. The room status changes to **Occupied**.
- Start the contract with the room's default rent, deposit, and service settings. Allow the landlord to override these terms for that contract without changing the room defaults.
- Create the first month's bill with monthly rent and service charges plus the remaining contract deposit due, after crediting any reservation deposit received.
- Store contract terms in Dormio; signed lease document storage is not included in V1.

### Rent charges and payments

- Manually enter one rent charge per month, with an amount and due date.
- Allow multiple manual payments toward the renter's combined outstanding balance, including payments made using different methods. Do not require the landlord to allocate a payment to an individual rent or service line item.
- For each payment, record the amount, date, and method: **Cash** or **Transfer**.
- Reject any payment greater than the renter's current combined outstanding balance; do not carry overpayments forward as credit.
- Show the combined renter balance as **Unpaid**, **Partially paid**, or **Paid**, based on total charges and payments received.
- Count rent and service charges as income only when the renter's combined balance across posted charges and payments reaches zero. Partial payments reduce the balance but are not income; recognize eligible charges in the month the balance reaches zero. Categorize rent as **Rent** and each service charge by its service name. Do not count refundable security deposits as income unless a reservation is canceled.

### Renter room services

- Allow the landlord to create and name services for renters, including electricity, water, and other services, and assign default services to rooms. Contract-specific service settings may override the room defaults.
- Calculate service charges monthly using one of these bases:
  - **Per room:** a fixed monthly amount.
  - **Per person:** a monthly rate multiplied by the anonymous resident headcount on the room's active contract on the first day of the month.
  - **By usage:** the difference between the start and end meter readings multiplied by a landlord-set price per unit. A unit label is not required in V1.
- Record start and end meter readings for each usage-based billing period.
- Allow the landlord to correct meter readings before the service charge is added to the renter's monthly bill.
- Show room-service charges as separate line items on the renter's bill alongside rent.

### Income, expenses, and monthly summary

- Record other income separately and give each entry a category or label.
- Record expenses when money is actually spent and give each expense a category or label. A shared expense may be left unassigned to a room.
- Show a monthly summary of total recorded income, total expenses, and the difference (income minus expenses).

### Maintenance

- Track maintenance for a room with an issue description, date, status, and notes. Maintenance records do not change the room's status.
- Do not track repair costs in V1.

## V1 Non-Goals

- Property management, including property, building, or address records.
- Renter accounts, renter-facing workflows, or in-app payment processing.
- Visitor tracking.
- Tracking unpaid landlord bills.
- Contract-end and move-out workflows, including security-deposit refunds or deductions; deferred to V2.



