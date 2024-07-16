module event_manager::event_manager {

    use std::string::{String, utf8, append};
    use sui::event;
    use sui::coin::{Coin, Self};
    use sui::balance::{Balance, Self, zero};
    use sui::sui::SUI;
    use sui::clock::{Clock, timestamp_ms};

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
    public struct Event has key, store {
        id: UID,
        event_name: String,
        event_details: String,
        ticket_price: u64,
        total_tickets: u64,
        sold_tickets: u64,
        balance: Balance<SUI>,
        event_start_time: u64,
        event_end_time: u64,
    }

    public struct EventCap has key {
        id: UID,
        `for`: ID
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
        }, ctx.sender());
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
        let event_details = Event {
            id: object::new(ctx),
            event_name: event_name,
            event_details: event_details,
            ticket_price,
            total_tickets,
            sold_tickets: 0,
            balance: zero<SUI>(),
            event_start_time: clock.timestamp_ms() + start_time,
            event_end_time: clock.timestamp_ms() + end_time,
        };

        let cap = EventCap{
            id: object::new(ctx),
            `for`: object::id(&event_details)
        };

        // Emit an event when a new event is created
        event::emit(EventCreatedEvent {
            event_id: object::id(&event_details),
            event_name: event_name,
            event_details: event_details.event_details,
            ticket_price: event_details.ticket_price,
            total_tickets: event_details.total_tickets,
        });
        // transfer the cap
        transfer::transfer(cap, ctx.sender());
        // Share the newly created event
        transfer::share_object(event_details);
    }

    // Entry function to update event details by admin
    public entry fun update_event_details(
        cap: &EventCap,
        event: &mut Event,
        new_details: String
    ) {
        // Ensure that only the admin can update event details
        assert!(cap.`for` == object::id(event), EAdminOnly);
        event.event_details = new_details;
    }

    // Entry function to cancel an event
    public entry fun cancel_event(
        cap: &EventCap,
        self: &mut Event,
    ) {
        // Ensure that only the admin can cancel the event
        assert!(cap.`for` == object::id(self), EAdminOnly);
        event::emit(EventCreatedEvent {
            event_id: object::id(self),
            event_name: self.event_name,
            event_details: utf8(b"Event Cancelled"),
            ticket_price: self.ticket_price,
            total_tickets: self.total_tickets,
        });
    }

    // Entry function for users to buy tickets
    public entry fun buy_ticket(
        self: &mut Event,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // Check if the user has sufficient funds
        assert!(amount.value() >= self.ticket_price, EInsufficientFunds);
        // Ensure the event has not reached its total ticket limit
        assert!(self.sold_tickets < self.total_tickets, EFundingReached);
        self.sold_tickets = self.sold_tickets + 1;
        // Create a new ticket
        let ticket = Ticket {
            id: object::new(ctx),
            event_id: object::id(self),
            owner: ctx.sender(),
            refund: false,
        };

        // Update the sold tickets balance
        self.balance.join(amount.into_balance());

        // Emit an event when a ticket is minted
        event::emit(TicketMintedEvent {
            object_id: object::id(&ticket),
            owner: ctx.sender(),
            event_id: object::id(self),
            event_name: self.event_name,
            ticket_price: self.ticket_price,
        });

        // Transfer the ticket to the buyer
        transfer::transfer(ticket, ctx.sender());
    }

    // Entry function for admins to refund tickets
    public entry fun refund_ticket(
        self: &mut Event,
        ticket: Ticket,
        ctx: &mut TxContext
    ) {
        assert!(ticket.event_id == object::id(self), EInvalidCall); // Check if ticket is already refunded

        let owner = destroy_ticket(ticket);

        let coin = coin::take(&mut self.balance, self.ticket_price, ctx);

        transfer::public_transfer(coin, owner);
    }

    public fun withdraw(
        cap: &EventCap,
        self: &mut Event,
        ctx: &mut TxContext
    ) : Coin<SUI> {
        assert!(cap.`for` == object::id(self), EAdminOnly);
        coin::from_balance( self.balance.withdraw_all(), ctx)
    }

    // Entry function to validate a ticket
    public entry fun validate_ticket(
        ticket_id: &Ticket,
        event_id: &Event,
        clock: &Clock
    ) {
        // Ensure the event is currently active
        assert!(timestamp_ms(clock) >= event_id.event_start_time && timestamp_ms(clock) <= event_id.event_end_time, EEventNotActive);
        assert!(ticket_id.event_id == object::id(event_id), EInvalidCall); // Check ticket ownership
    }

    // Entry function for participants to register for an event
    public entry fun register_for_event(
        event_id: &mut Event,
        participant: &mut Participant
    ) {
        // Check if the participant is not already registered
        assert!(!vector::contains(&participant.registered_events, &object::id(event_id)), EInvalidCall);
        vector::push_back(&mut participant.registered_events, object::id(event_id)); // Register for the event
    }

    // Entry function for participants to check-in
    public entry fun check_in(
        event_id: &Event,
        participant: &Participant
    ) {
        assert!(vector::contains(&participant.registered_events, &object::id(event_id)), ENotRegistered); // Ensure participant is registered
    }

    // Entry function for participants to rate an event
    public entry fun rate_event(
        event_id: &Event,
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
        event_id: &Event,
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
        _event_id: &Event,
        participant: &mut Participant,
        message: String
    ) {
        vector::push_back(&mut participant.notifications, message); // Add notification message
    }

    // Function to get the attendance of an event
    public fun get_event_attendance(
        event_id: &Event
    ): u64 {
        balance::value(&event_id.balance) // Return the number of sold tickets
    }

    // Function to calculate total ticket sales for an event
    public fun get_ticket_sales(
        event_id: &Event
    ): u64 {
        event_id.ticket_price * balance::value(&event_id.balance) // Return total sales
    }

    // Function to generate an event report
    public fun generate_event_report(
        event_id: &Event
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

    // Function to list all events
    public fun list_events(
        events: vector<Event>
    ): vector<Event> {
        events // Return the list of events
    }

    fun destroy_ticket(self: Ticket) : address {
        let Ticket {
            id,
            event_id: _,
            owner,
            refund: _
        } = self;
        id.delete();
        owner
    }
}
