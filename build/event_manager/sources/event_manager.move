module event_manager::event_manager {
    
    use std::string::{String, utf8, append};
    use sui::event;
    use sui::coin::{Coin, Self};
    use sui::balance::{Balance, Self, zero};
    use sui::sui::SUI;
    use sui::clock::{Clock, timestamp_ms};
    use sui::tx_context::sender;

    // Error codes for different scenarios
    const EInsufficientFunds: u64 = 1;
    const EEventNotActive: u64 = 2;
    const EInvalidCall: u64 = 4;
    const EFundingReached: u64 = 5;
    const ENotRegistered: u64 = 6;
    const EAdminOnly: u64 = 10;

    // Structure for Admin capabilities
    public struct AdminCap has key { id: UID }

    // Structure for Event details
    public struct EventDetails has key, store {
        id: UID,
        event_name: String,
        event_details: String,
        ticket_price: u64,
        total_tickets: u64,
        sold_tickets: Balance<SUI>,
        event_start_time: u64,
        event_end_time: u64,
    }

    // Structure for Ticket information
    public struct Ticket has key, store {
        id: UID,
        event_id: ID,
        owner: address,
        refund: bool,
    }

    // Structure for Participant information
    public struct Participant has key, store {
        id: UID,
        registered_events: vector<ID>,
        notifications: vector<String>,
    }

    // Structure for User Profile
    public struct Profile has key, store {
        id: UID,
        user_address: address,
        verified: bool,
        reputation_score: u64,
    }

    // Event structure for when a ticket is minted
    public struct TicketMintedEvent has copy, drop {
        object_id: ID,
        owner: address,
        event_id: ID,
        event_name: String,
        ticket_price: u64,
    }

    // Event structure for when an event is created
    public struct EventCreatedEvent has copy, drop {
        event_id: ID,
        event_name: String,
        event_details: String,
        ticket_price: u64,
        total_tickets: u64,
    }

    // Initialization function for the module
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, sender(ctx));
    }

    // Entry function to create a new event
    public entry fun create_event(
        event_name: String,
        event_details: String,
        ticket_price: u64,
        total_tickets: u64,
        start_time: u64,
        end_time: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let event_details = EventDetails {
            id: object::new(ctx),
            event_name: event_name,
            event_details: event_details,
            ticket_price,
            total_tickets,
            sold_tickets: zero<SUI>(),
            event_start_time: timestamp_ms(clock) + start_time,
            event_end_time: timestamp_ms(clock) + end_time,
        };

        // Emit an event when a new event is created
        event::emit(EventCreatedEvent {
            event_id: object::id(&event_details),
            event_name: event_name,
            event_details: event_details.event_details,
            ticket_price: event_details.ticket_price,
            total_tickets: event_details.total_tickets,
        });

        // Share the newly created event
        transfer::share_object(event_details);
    }

    // Entry function to update event details by admin
    public entry fun update_event_details(
        admin: &AdminCap,
        event_id: &mut EventDetails,
        new_details: String
    ) {
        // Ensure that only the admin can update event details
        assert!(object::id(admin) == object::id(event_id), EAdminOnly);
        event_id.event_details = new_details;
    }

    // Entry function to cancel an event
    public entry fun cancel_event(
        admin: &AdminCap,
        event_id: &mut EventDetails,
        _ctx: &mut TxContext
    ) {
        // Ensure that only the admin can cancel the event
        assert!(object::id(admin) == object::id(event_id), EAdminOnly);
        event::emit(EventCreatedEvent {
            event_id: object::id(event_id),
            event_name: event_id.event_name,
            event_details: utf8(b"Event Cancelled"),
            ticket_price: event_id.ticket_price,
            total_tickets: event_id.total_tickets,
        });
    }

    // Entry function for users to buy tickets
    public entry fun buy_ticket(
        event_id: &mut EventDetails,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // Check if the user has sufficient funds
        assert!(coin::value(&amount) >= event_id.ticket_price, EInsufficientFunds);
        // Ensure the event has not reached its total ticket limit
        assert!(balance::value(&event_id.sold_tickets) < event_id.total_tickets, EFundingReached);

        // Create a new ticket
        let ticket = Ticket {
            id: object::new(ctx),
            event_id: object::id(event_id),
            owner: sender(ctx),
            refund: false,
        };

        // Update the sold tickets balance
        balance::join(&mut event_id.sold_tickets, coin::into_balance(amount));

        // Emit an event when a ticket is minted
        event::emit(TicketMintedEvent {
            object_id: object::id(&ticket),
            owner: sender(ctx),
            event_id: object::id(event_id),
            event_name: event_id.event_name,
            ticket_price: event_id.ticket_price,
        });

        // Transfer the ticket to the buyer
        transfer::transfer(ticket, sender(ctx));
    }

    // Entry function for admins to refund tickets
    public entry fun refund_ticket(
        admin: &AdminCap,
        ticket_id: &mut Ticket,
        event_id: &mut EventDetails,
        ctx: &mut TxContext
    ) {
        // Ensure only the admin can initiate a refund
        assert!(object::id(admin) == object::id(event_id), EAdminOnly);
        assert!(!ticket_id.refund, EInvalidCall); // Check if ticket is already refunded

        ticket_id.refund = true; // Mark ticket as refunded
        let amount = coin::from_balance(balance::split(&mut event_id.sold_tickets, event_id.ticket_price), ctx);
        transfer_funds(amount, event_id, ctx); // Transfer funds back to the user
    }

    // Entry function to validate a ticket
    public entry fun validate_ticket(
        ticket_id: &Ticket,
        event_id: &EventDetails,
        clock: &Clock
    ) {
        // Ensure the event is currently active
        assert!(timestamp_ms(clock) >= event_id.event_start_time && timestamp_ms(clock) <= event_id.event_end_time, EEventNotActive);
        assert!(ticket_id.event_id == object::id(event_id), EInvalidCall); // Check ticket ownership
    }

    // Entry function for reselling tickets
    public entry fun resell_ticket(
        ticket_id: &mut Ticket,
        new_owner: address,
        amount: Coin<SUI>,
        event_id: &mut EventDetails,
        ctx: &mut TxContext
    ) {
        // Check if the ticket price is met
        assert!(coin::value(&amount) >= event_id.ticket_price, EInsufficientFunds);
        assert!(ticket_id.owner == sender(ctx), EInvalidCall); // Ensure the ticket owner is the seller

        ticket_id.owner = new_owner; // Change ownership of the ticket
        balance::join(&mut event_id.sold_tickets, coin::into_balance(amount)); // Update ticket sales
    }

    // Entry function for participants to register for an event
    public entry fun register_for_event(
        event_id: &mut EventDetails,
        participant: &mut Participant
    ) {
        // Check if the participant is not already registered
        assert!(!vector::contains(&participant.registered_events, &object::id(event_id)), EInvalidCall);
        vector::push_back(&mut participant.registered_events, object::id(event_id)); // Register for the event
    }

    // Entry function for participants to check-in
    public entry fun check_in(
        event_id: &EventDetails,
        participant: &Participant
    ) {
        assert!(vector::contains(&participant.registered_events, &object::id(event_id)), ENotRegistered); // Ensure participant is registered
    }

    // Entry function for participants to rate an event
    public entry fun rate_event(
        event_id: &EventDetails,
        _rating: u64,
        participant: &Participant
    ) {
        assert!(vector::contains(&participant.registered_events, &object::id(event_id)), ENotRegistered); // Check registration
    }

    // Function to view registered tickets for a participant
    public fun view_tickets(
        participant: &Participant
    ): vector<ID> {
        participant.registered_events // Return the list of registered events
    }

    // Entry function for participants to subscribe to event notifications
    public entry fun subscribe_to_event_notifications(
        event_id: &EventDetails,
        participant: &mut Participant
    ) {
        let notification = utf8(b"Subscribed to notifications for event: ");
        let mut message = notification;
        append(&mut message, event_id.event_name); // Create notification message
        vector::push_back(&mut participant.notifications, message); // Store notification
        vector::push_back(&mut participant.registered_events, object::id(event_id)); // Register for the event
    }

    // Entry function to send notifications to participants
    public entry fun send_notification(
        _event_id: &EventDetails,
        participant: &mut Participant,
        message: String
    ) {
        vector::push_back(&mut participant.notifications, message); // Add notification message
    }

    // Function to get the attendance of an event
    public fun get_event_attendance(
        event_id: &EventDetails
    ): u64 {
        balance::value(&event_id.sold_tickets) // Return the number of sold tickets
    }

    // Function to calculate total ticket sales for an event
    public fun get_ticket_sales(
        event_id: &EventDetails
    ): u64 {
        event_id.ticket_price * balance::value(&event_id.sold_tickets) // Return total sales
    }

    // Function to generate an event report
    public fun generate_event_report(
        event_id: &EventDetails
    ): String {
        let _attendance = get_event_attendance(event_id); // Get attendance
        let _sales = get_ticket_sales(event_id); // Get sales
        let mut report = utf8(b"Event Report:\n");
        append(&mut report, utf8(b"Event Name: "));
        append(&mut report, event_id.event_name);
        append(&mut report, utf8(b"\nTotal Tickets: "));
        append(&mut report, utf8(b"\nSold Tickets: "));
        append(&mut report, utf8(b"\nTicket Sales: "));
        report // Return the report string
    }

    // Entry function to register a user profile
    public entry fun register_profile(
        user_address: address,
        _public_key: vector<u8>,
        ctx: &mut TxContext
    ) {
        let profile = Profile {
            id: object::new(ctx),
            user_address,
            verified: false,
            reputation_score: 0,
        };
        transfer::transfer(profile, user_address); // Transfer profile to the user
    }

    // Function to verify a user profile by admin
    public fun verify_profile(admin: &AdminCap, profile: &mut Profile) {
        assert!(object::id(admin) == object::id(profile), EAdminOnly); // Ensure only admin can verify
        profile.verified = true; // Mark profile as verified
    }

    // Function to update reputation score by admin
    public fun update_reputation(admin: &AdminCap, profile: &mut Profile, score: u64) {
        assert!(object::id(admin) == object::id(profile), EAdminOnly); // Ensure only admin can update
        profile.reputation_score = score; // Update the reputation score
    }

    // Function for user authentication (placeholder)
    public fun authenticate_user(
        _account: &Profile,
        _signature: vector<u8>,
        _message: vector<u8>
    ): bool {
        true // Placeholder for actual authentication logic
    }

    // Entry function to transfer funds
    public entry fun transfer_funds(
        amount: Coin<SUI>,
        _event_id: &mut EventDetails,
        ctx: &mut TxContext
    ) {
        transfer::public_transfer(amount, sender(ctx)); // Transfer funds to the sender
    }

    // Function to list all events
    public fun list_events(
        events: vector<EventDetails>
    ): vector<EventDetails> {
        events // Return the list of events
    }
}
