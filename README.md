# Event Management Decentralized Platform

## Overview

This decentralized platform, built on the Sui Move blockchain, facilitates the creation, management, and participation in events. It offers a robust set of features for event organizers and participants, including event creation, ticket sales, participant registration, notifications, and event reporting. The platform ensures security and transparency through the use of smart contracts and decentralized principles.

## Key Structures and Components

### AdminCap
- **AdminCap**: Structure representing the administrative capabilities, containing a unique identifier (UID).

### EventDetails
- **EventDetails**: Structure containing detailed information about an event, such as the event name, details, ticket price, total tickets, sold tickets, start and end times.

### Ticket
- **Ticket**: Structure representing a ticket for an event, including event ID, owner address, and refund status.

### Participant
- **Participant**: Structure containing information about a participant, including registered events and notifications.

### Profile
- **Profile**: Structure representing a user profile, including user address, verification status, and reputation score.

### Event Types
- **TicketMintedEvent**: Event emitted when a ticket is minted.
- **EventCreatedEvent**: Event emitted when an event is created.

## Error Codes

- **EInsufficientFunds (1)**: Indicates insufficient funds for ticket purchase.
- **EEventNotActive (2)**: Indicates the event is not currently active.
- **EInvalidCall (4)**: Indicates an invalid function call.
- **EFundingReached (5)**: Indicates that the funding or ticket limit for an event has been reached.
- **ENotRegistered (6)**: Indicates the participant is not registered for the event.
- **EAdminOnly (10)**: Indicates that the action is restricted to the admin.

## Functions

### Initialization
- **init**: Initializes the module by transferring AdminCap to the sender.

### Event Management
- **create_event**: Allows the creation of a new event, emitting an `EventCreatedEvent` and sharing the event details.
- **update_event_details**: Allows the admin to update event details.
- **cancel_event**: Allows the admin to cancel an event, emitting an `EventCreatedEvent` indicating cancellation.

### Ticket Management
- **buy_ticket**: Allows users to buy tickets for an event, emitting a `TicketMintedEvent` and transferring the ticket to the buyer.
- **refund_ticket**: Allows the admin to refund tickets, transferring the funds back to the user.
- **validate_ticket**: Validates if a ticket is legitimate and if the event is currently active.
- **resell_ticket**: Allows users to resell tickets to a new owner.

### Participant Management
- **register_for_event**: Registers a participant for an event.
- **check_in**: Allows participants to check in for an event.
- **rate_event**: Allows participants to rate an event.

### Notification Management
- **subscribe_to_event_notifications**: Allows participants to subscribe to event notifications.
- **send_notification**: Sends notifications to participants.

### User Profile Management
- **register_profile**: Registers a user profile on the platform.
- **verify_profile**: Allows the admin to verify a user profile.
- **update_reputation**: Allows the admin to update a user’s reputation score.
- **authenticate_user**: Placeholder function for user authentication.

### Financial Management
- **transfer_funds**: Transfers funds within the platform.
- **get_event_attendance**: Returns the number of sold tickets for an event.
- **get_ticket_sales**: Calculates total ticket sales for an event.
- **generate_event_report**: Generates a report for an event, including attendance and sales.

### Event Listing
- **list_events**: Lists all events on the platform.

## Usage

1. **Initialization**: Deploy the smart contract and call the `init` function to set up the AdminCap.
2. **Event Creation**: Use `create_event` to create new events with detailed information.
3. **Ticket Purchase**: Participants can buy tickets using the `buy_ticket` function, ensuring they have sufficient funds.
4. **Event Management**: Admins can update or cancel events using `update_event_details` and `cancel_event`.
5. **Participant Engagement**: Participants can register, check-in, rate events, and subscribe to notifications using the respective functions.
6. **Financial Transactions**: Manage funds and refunds using `transfer_funds` and `refund_ticket`.
7. **Event Reports**: Generate reports and view event details using `generate_event_report`.

## Conclusion

This platform leverages the power of blockchain to provide a decentralized solution for event management. It ensures transparency, security, and ease of use for both event organizers and participants. By utilizing smart contracts, the platform automates many aspects of event management, making it efficient and reliable.