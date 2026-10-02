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
- End a contract, create its final service and deposit settlement, and return the room to available status.
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
- Initialize the contract with the room's default rent, deposit, and service settings. The landlord can override these terms when creating the contract and modify the contract after creation without changing the room defaults.
- Contract changes apply only to future charges. Existing charges and billing history remain unchanged.
- Create the first month's bill with monthly rent and service charges plus the remaining contract deposit due, after crediting any reservation deposit received.
- Store contract terms in Dormio; signed lease document storage is not included in V1.

### Contract-end and move-out

- Allow the landlord to terminate an active contract for a room and create a contract-end bill for the renter.
- Include final service charges and refundable-deposit settlement as separate items. Apply the held deposit only against final charges for that same contract; refund any remaining deposit. If final charges exceed the deposit, the remainder stays due on the renter's combined balance. Do not apply the deposit to earlier or unrelated renter charges.
- The landlord manually enters the final-month rent amount on the contract-end bill; do not automatically prorate it.
- For usage-based services, use final contract meter readings to calculate the close-out charge.
- Preserve the ended contract and its billing history, and do not add future charges to it. When termination is confirmed, the room becomes **Available**, regardless of whether the final amount has been collected or the refund has been issued.
- Record each deposit refund with its amount, actual payment date, and method: **Cash** or **Transfer**.
- A deposit application or refund is not income or expense. Final service charges follow the renter-wide balance and income-recognition rules.

### Rent charges and payments

- Create one rent charge each month from the active contract's rent terms; do not allow the landlord to enter or edit ordinary monthly rent charges separately. The landlord can change the rent terms by modifying the contract. Final-month rent is entered manually on the contract-end bill and is not automatically prorated.
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

## Open Product Decisions

- When payments to the renter's combined balance are not allocated to individual charges, how should Dormio determine how much of the refundable contract deposit has actually been received for later application or refund?




