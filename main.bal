import ballerina/log;
import ballerinax/salesforce;

// Salesforce Listener Configuration
// NOTE: Before running, ensure Change Data Capture is enabled in Salesforce:
// Setup → Change Data Capture → Select Account and Contact → Save
// Using OAuth2 refresh token auth (avoids SOAP username/password/security token requirement)
listener salesforce:Listener changeEventListener = new ({
    auth: {
        refreshUrl: salesforceRefreshUrl,
        refreshToken: salesforceRefreshToken,
        clientId: salesforceClientId,
        clientSecret: salesforceClientSecret
    },
    baseUrl: salesforceBaseUrl
});

// Salesforce Change Event Service
// Channel name is required by the salesforce:Listener.
// /data/ChangeEvents subscribes to all CDC-enabled objects (Account, Contact, etc.)
service "/data/ChangeEvents" on changeEventListener {

    // Handle Create Events
    remote function onCreate(salesforce:EventData eventData) returns error? {
        log:printInfo("Received create event from Salesforce");

        // Only process if sync direction allows SF to Stripe
        if syncDirection == STRIPE_TO_SF {
            log:printInfo("Sync direction is Stripe to SF, skipping create event");
            return;
        }

        // Determine object type from event metadata
        string entityType = eventData.metadata?.entityName ?: "";
        log:printInfo("[onCreate] entityType=" + entityType + " sourceObject=" + sourceObject);

        // CDC changedData does not include Id — inject it from metadata.recordId
        string recordId = eventData.metadata?.recordId ?: "";
        map<json> data = eventData.changedData;
        data["Id"] = recordId;

        // Route to appropriate handler based on entity type
        if entityType == "Account" && (sourceObject == ACCOUNT || sourceObject == BOTH) {
            SalesforceAccount|error account = data.cloneWithType();
            if account is error {
                log:printError("[onCreate] Failed to parse Account data", 'error = account, data = data.toString());
                return;
            }
            error? result = syncAccountToStripe(account);
            if result is error {
                log:printError("[onCreate] Failed to sync Account to Stripe", 'error = result, accountId = account.Id);
            }
        } else if entityType == "Contact" && (sourceObject == CONTACT || sourceObject == BOTH) {
            SalesforceContact|error contact = data.cloneWithType();
            if contact is error {
                log:printError("[onCreate] Failed to parse Contact data", 'error = contact, data = data.toString());
                return;
            }
            log:printInfo("[onCreate] Contact parsed", contactId = contact.Id, email = contact.Email, name = (contact.FirstName ?: "") + " " + (contact.LastName ?: ""));
            error? result = syncContactToStripe(contact);
            if result is error {
                log:printError("[onCreate] Failed to sync Contact to Stripe", 'error = result, contactId = contact.Id);
            }
        } else {
            log:printInfo("[onCreate] No handler for entityType='" + entityType + "' sourceObject='" + sourceObject + "'");
        }
    }

    // Handle Update Events
    remote function onUpdate(salesforce:EventData eventData) returns error? {
        log:printInfo("Received update event from Salesforce");

        // Only process if sync direction allows SF to Stripe
        if syncDirection == STRIPE_TO_SF {
            log:printInfo("Sync direction is Stripe to SF, skipping update event");
            return;
        }

        // Determine object type from event metadata
        string entityType = eventData.metadata?.entityName ?: "";

        // CDC changedData does not include Id — inject it from metadata.recordId
        string recordId = eventData.metadata?.recordId ?: "";
        map<json> data = eventData.changedData;
        data["Id"] = recordId;

        // Route to appropriate handler based on entity type
        if entityType == "Account" && (sourceObject == ACCOUNT || sourceObject == BOTH) {
            SalesforceAccount account = check data.cloneWithType();
            check syncAccountToStripe(account);
        } else if entityType == "Contact" && (sourceObject == CONTACT || sourceObject == BOTH) {
            SalesforceContact contact = check data.cloneWithType();
            check syncContactToStripe(contact);
        }
    }

    // Handle Delete Events
    remote function onDelete(salesforce:EventData eventData) returns error? {
        log:printInfo("Received delete event from Salesforce");

        // Only process if sync direction allows SF to Stripe
        if syncDirection == STRIPE_TO_SF {
            log:printInfo("Sync direction is Stripe to SF, skipping delete event");
            return;
        }

        // Determine object type from event metadata
        string entityType = eventData.metadata?.entityName ?: "";

        // CDC changedData does not include Id — inject it from metadata.recordId
        string recordId = eventData.metadata?.recordId ?: "";
        map<json> data = eventData.changedData;
        data["Id"] = recordId;

        // Route to appropriate handler based on entity type
        if entityType == "Account" && (sourceObject == ACCOUNT || sourceObject == BOTH) {
            SalesforceAccount account = check data.cloneWithType();
            error? result = handleAccountDeletion(account);
            if result is error {
                log:printError("Failed to handle Account deletion", accountId = account.Id, 'error = result);
            }
            return result;
        } else if entityType == "Contact" && (sourceObject == CONTACT || sourceObject == BOTH) {
            SalesforceContact contact = check data.cloneWithType();
            error? result = handleContactDeletion(contact);
            if result is error {
                log:printError("Failed to handle Contact deletion", contactId = contact.Id, 'error = result);
            }
            return result;
        }
    }

    // Handle Restore Events
    remote function onRestore(salesforce:EventData eventData) returns error? {
        log:printInfo("Received restore event from Salesforce");

        // Only process if sync direction allows SF to Stripe
        if syncDirection == STRIPE_TO_SF {
            log:printInfo("Sync direction is Stripe to SF, skipping restore event");
            return;
        }

        // Determine object type from event metadata
        string entityType = eventData.metadata?.entityName ?: "";

        // CDC changedData does not include Id — inject it from metadata.recordId
        string recordId = eventData.metadata?.recordId ?: "";
        map<json> data = eventData.changedData;
        data["Id"] = recordId;

        // Route to appropriate handler based on entity type
        if entityType == "Account" && (sourceObject == ACCOUNT || sourceObject == BOTH) {
            SalesforceAccount account = check data.cloneWithType();
            check syncAccountToStripe(account);
        } else if entityType == "Contact" && (sourceObject == CONTACT || sourceObject == BOTH) {
            SalesforceContact contact = check data.cloneWithType();
            check syncContactToStripe(contact);
        }
    }
}
