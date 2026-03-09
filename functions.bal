import ballerina/log;
import ballerinax/stripe;

// Sync Salesforce Account to Stripe
public function syncAccountToStripe(SalesforceAccount account) returns error? {
    // Check if record passes filters
    if !passesFilters(account.RecordTypeId, account.AccountStatus__c) {
        log:printInfo("Account filtered out, skipping sync", accountId = account.Id);
        return;
    }

    // Map to Stripe customer payload
    record {} customerPayload = mapAccountToStripeCustomer(account);

    // Check if customer already exists in Stripe
    string? existingStripeId = account.Stripe_Customer_Id__c;
    string? email = account.Email__c;

    if existingStripeId is string && existingStripeId != "" {
        // Update existing customer
        log:printInfo("Updating existing Stripe customer", stripeCustomerId = existingStripeId);
        stripe:customers_customer_body payload = check customerPayload.cloneWithType();
        stripe:Customer updatedCustomer = check stripeClient->/customers/[existingStripeId].post(payload);
        log:printInfo("Successfully updated Stripe customer", stripeCustomerId = updatedCustomer.id);
    } else {
        // Search for existing customer by email if match key is EMAIL
        if matchKey == EMAIL && email is string && email != "" {
            stripe:CustomerResourceCustomerList searchResult = check stripeClient->/customers.get(email = email);
            if searchResult.data.length() > 0 {
                // Customer exists, update it
                stripe:Customer existingCustomer = searchResult.data[0];
                log:printInfo("Found existing Stripe customer by email", stripeCustomerId = existingCustomer.id);
                stripe:customers_customer_body payload = check customerPayload.cloneWithType();
                stripe:Customer updatedCustomer = check stripeClient->/customers/[existingCustomer.id].post(payload);
                
                // Write back Stripe ID to Salesforce if configured
                if writeBackStripeId {
                    check writeBackStripeIdToSalesforce("Account", account.Id ?: "", updatedCustomer.id);
                }
                return;
            }
        }

        // Create new customer
        log:printInfo("Creating new Stripe customer", accountId = account.Id);
        stripe:customers_body payload = check customerPayload.cloneWithType();
        stripe:Customer newCustomer = check stripeClient->/customers.post(payload);
        log:printInfo("Successfully created Stripe customer", stripeCustomerId = newCustomer.id);

        // Write back Stripe ID to Salesforce if configured
        if writeBackStripeId {
            check writeBackStripeIdToSalesforce("Account", account.Id ?: "", newCustomer.id);
        }
    }
}

// Sync Salesforce Contact to Stripe
public function syncContactToStripe(SalesforceContact contact) returns error? {
    // Check if record passes filters (only RecordType for contacts)
    if !passesFilters(contact.RecordTypeId, ()) {
        log:printInfo("Contact filtered out, skipping sync", contactId = contact.Id);
        return;
    }

    // Map to Stripe customer payload
    record {} customerPayload = mapContactToStripeCustomer(contact);

    // Check if customer already exists in Stripe
    string? existingStripeId = contact.Stripe_Customer_Id__c;
    string? email = contact.Email;

    if existingStripeId is string && existingStripeId != "" {
        // Update existing customer
        log:printInfo("Updating existing Stripe customer", stripeCustomerId = existingStripeId);
        stripe:customers_customer_body payload = check customerPayload.cloneWithType();
        stripe:Customer updatedCustomer = check stripeClient->/customers/[existingStripeId].post(payload);
        log:printInfo("Successfully updated Stripe customer", stripeCustomerId = updatedCustomer.id);
    } else {
        // Search for existing customer by email if match key is EMAIL
        if matchKey == EMAIL && email is string && email != "" {
            stripe:CustomerResourceCustomerList searchResult = check stripeClient->/customers.get(email = email);
            if searchResult.data.length() > 0 {
                // Customer exists, update it
                stripe:Customer existingCustomer = searchResult.data[0];
                log:printInfo("Found existing Stripe customer by email", stripeCustomerId = existingCustomer.id);
                stripe:customers_customer_body payload = check customerPayload.cloneWithType();
                stripe:Customer updatedCustomer = check stripeClient->/customers/[existingCustomer.id].post(payload);
                
                // Write back Stripe ID to Salesforce if configured
                if writeBackStripeId {
                    check writeBackStripeIdToSalesforce("Contact", contact.Id ?: "", updatedCustomer.id);
                }
                return;
            }
        }

        // Create new customer
        log:printInfo("Creating new Stripe customer", contactId = contact.Id);
        stripe:customers_body payload = check customerPayload.cloneWithType();
        stripe:Customer newCustomer = check stripeClient->/customers.post(payload);
        log:printInfo("Successfully created Stripe customer", stripeCustomerId = newCustomer.id);

        // Write back Stripe ID to Salesforce if configured
        if writeBackStripeId {
            check writeBackStripeIdToSalesforce("Contact", contact.Id ?: "", newCustomer.id);
        }
    }
}

// Write back Stripe Customer ID to Salesforce
function writeBackStripeIdToSalesforce(string objectType, string recordId, string stripeCustomerId) returns error? {
    log:printInfo("Writing back Stripe ID to Salesforce", objectType = objectType, recordId = recordId, stripeCustomerId = stripeCustomerId);
    
    record {} updatePayload = {
        "Stripe_Customer_Id__c": stripeCustomerId
    };

    check salesforceClient->update(objectType, recordId, updatePayload);
    log:printInfo("Successfully wrote back Stripe ID to Salesforce");
}
