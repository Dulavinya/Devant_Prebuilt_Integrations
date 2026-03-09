import ballerina/log;
import ballerinax/salesforce;

// Salesforce Listener Configuration
listener salesforce:Listener salesforceListener = new ({
    auth: {
        username: salesforceUsername,
        password: salesforcePassword
    },
    isSandBox: isSandbox
});

// Salesforce Change Event Service for Accounts
service salesforce:Service on salesforceListener {

    // Handle Account Create Events
    remote function onCreate(salesforce:EventData eventData) returns error? {
        log:printInfo("Received Account create event from Salesforce");

        // Only process if sync direction allows SF to Stripe
        if syncDirection == STRIPE_TO_SF {
            log:printInfo("Sync direction is Stripe to SF, skipping Account create event");
            return;
        }

        // Only process if source object includes Accounts
        if sourceObject == CONTACT {
            log:printInfo("Source object is Contact only, skipping Account event");
            return;
        }

        // Extract account data from event
        anydata payloadData = eventData["payload"] ?: {};
        record {} payload = check payloadData.ensureType();
        SalesforceAccount account = check payload.cloneWithType();

        // Sync to Stripe
        check syncAccountToStripe(account);
    }

    // Handle Account Update Events
    remote function onUpdate(salesforce:EventData eventData) returns error? {
        log:printInfo("Received Account update event from Salesforce");

        // Only process if sync direction allows SF to Stripe
        if syncDirection == STRIPE_TO_SF {
            log:printInfo("Sync direction is Stripe to SF, skipping Account update event");
            return;
        }

        // Only process if source object includes Accounts
        if sourceObject == CONTACT {
            log:printInfo("Source object is Contact only, skipping Account event");
            return;
        }

        // Extract account data from event
        anydata payloadData = eventData["payload"] ?: {};
        record {} payload = check payloadData.ensureType();
        SalesforceAccount account = check payload.cloneWithType();

        // Sync to Stripe
        check syncAccountToStripe(account);
    }

    // Handle Account Delete Events
    remote function onDelete(salesforce:EventData eventData) returns error? {
        log:printInfo("Received Account delete event from Salesforce - no action taken");
        return;
    }

    // Handle Account Restore Events
    remote function onRestore(salesforce:EventData eventData) returns error? {
        log:printInfo("Received Account restore event from Salesforce");

        // Only process if sync direction allows SF to Stripe
        if syncDirection == STRIPE_TO_SF {
            log:printInfo("Sync direction is Stripe to SF, skipping Account restore event");
            return;
        }

        // Only process if source object includes Accounts
        if sourceObject == CONTACT {
            log:printInfo("Source object is Contact only, skipping Account event");
            return;
        }

        // Extract account data from event
        anydata payloadData = eventData["payload"] ?: {};
        record {} payload = check payloadData.ensureType();
        SalesforceAccount account = check payload.cloneWithType();

        // Sync to Stripe
        check syncAccountToStripe(account);
    }
}
