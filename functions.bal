import ballerina/log;
import ballerinax/stripe;

// Sync Salesforce Account to Stripe
public isolated function syncAccountToStripe(SalesforceAccount account) returns error? {
    // Validate account data
    error? validationResult = validateAccount(account);
    if validationResult is error {
        log:printError("Account validation failed", accountId = account.Id, 'error = validationResult);
        return validationResult;
    }

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
public isolated function syncContactToStripe(SalesforceContact contact) returns error? {
    // Validate contact data
    error? validationResult = validateContact(contact);
    if validationResult is error {
        log:printError("Contact validation failed", contactId = contact.Id, 'error = validationResult);
        return validationResult;
    }

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
isolated function writeBackStripeIdToSalesforce(string objectType, string recordId, string stripeCustomerId) returns error? {
    log:printInfo("Writing back Stripe ID to Salesforce", objectType = objectType, recordId = recordId, stripeCustomerId = stripeCustomerId);
    
    record {} updatePayload = {
        "Stripe_Customer_Id__c": stripeCustomerId
    };

    check salesforceClient->update(objectType, recordId, updatePayload);
    log:printInfo("Successfully wrote back Stripe ID to Salesforce");
}

// Delete Stripe Customer
public isolated function deleteStripeCustomer(string stripeCustomerId) returns error? {
    log:printInfo("Deleting Stripe customer", stripeCustomerId = stripeCustomerId);
    
    _ = check stripeClient->/customers/[stripeCustomerId].delete();
    
    log:printInfo("Successfully deleted Stripe customer", stripeCustomerId = stripeCustomerId);
}

// Handle Salesforce Account deletion
public isolated function handleAccountDeletion(SalesforceAccount account) returns error? {
    string? stripeCustomerId = account.Stripe_Customer_Id__c;
    
    if stripeCustomerId is () || stripeCustomerId == "" {
        log:printInfo("Account has no Stripe Customer ID, nothing to delete", accountId = account.Id);
        return;
    }

    if deleteStripeCustomerOnSalesforceDelete {
        check deleteStripeCustomer(stripeCustomerId);
    } else {
        log:printInfo("Delete handling disabled, skipping Stripe customer deletion", stripeCustomerId = stripeCustomerId);
    }
}

// Handle Salesforce Contact deletion
public isolated function handleContactDeletion(SalesforceContact contact) returns error? {
    string? stripeCustomerId = contact.Stripe_Customer_Id__c;
    
    if stripeCustomerId is () || stripeCustomerId == "" {
        log:printInfo("Contact has no Stripe Customer ID, nothing to delete", contactId = contact.Id);
        return;
    }

    if deleteStripeCustomerOnSalesforceDelete {
        check deleteStripeCustomer(stripeCustomerId);
    } else {
        log:printInfo("Delete handling disabled, skipping Stripe customer deletion", stripeCustomerId = stripeCustomerId);
    }
}
