import ballerina/log;

// Map Salesforce Account to Stripe Customer
public isolated function mapAccountToStripeCustomer(SalesforceAccount account) returns record {} {
    map<json> payload = {
        "metadata": {
            "salesforce_id": account?.Id ?: "",
            "source": "salesforce_account"
        }
    };
    
    // Only include name if it's not empty
    if account?.Name is string && account?.Name != "" {
        payload["name"] = account?.Name;
    }
    
    if account?.Email__c is string && account?.Email__c != "" { payload["email"] = account?.Email__c; }
    if account?.Phone is string { payload["phone"] = account?.Phone; }
    if account?.Description is string { payload["description"] = account?.Description; }

    map<json> address = {};
    if account?.BillingStreet is string { address["line1"] = account?.BillingStreet; }
    if account?.BillingCity is string { address["city"] = account?.BillingCity; }
    if account?.BillingState is string { address["state"] = account?.BillingState; }
    if account?.BillingPostalCode is string { address["postal_code"] = account?.BillingPostalCode; }
    if account?.BillingCountry is string { address["country"] = account?.BillingCountry; }
    if address.length() > 0 { payload["address"] = address; }

    return payload;
}

// Map Salesforce Contact to Stripe Customer
public isolated function mapContactToStripeCustomer(SalesforceContact contact) returns record {} {
    map<json> payload = {
        "metadata": {
            "salesforce_id": contact?.Id ?: "",
            "source": "salesforce_contact"
        }
    };
    
    // Only include name if first or last name is present
    string firstName = contact?.FirstName ?: "";
    string lastName = contact?.LastName ?: "";
    string fullName = (firstName + " " + lastName).trim();

    if fullName != "" {
        payload["name"] = fullName;
    }
    
    if contact?.Email is string && contact?.Email != "" { payload["email"] = contact?.Email; }
    if contact?.Phone is string && contact?.Phone != "" { payload["phone"] = contact?.Phone; }
    if contact?.Description is string { payload["description"] = contact?.Description; }

    // Mailing Address -> Billing Address (address)
    map<json> billingAddress = {};
    if contact?.MailingStreet is string && contact?.MailingStreet != "" { billingAddress["line1"] = contact?.MailingStreet; }
    if contact?.MailingCity is string && contact?.MailingCity != "" { billingAddress["city"] = contact?.MailingCity; }
    if contact?.MailingState is string && contact?.MailingState != "" { billingAddress["state"] = contact?.MailingState; }
    if contact?.MailingPostalCode is string && contact?.MailingPostalCode != "" { billingAddress["postal_code"] = contact?.MailingPostalCode; }
    if contact?.MailingCountry is string && contact?.MailingCountry != "" { billingAddress["country"] = contact?.MailingCountry; }
    if billingAddress.length() > 0 { payload["address"] = billingAddress; }

    // Other Address -> Shipping Address (shipping.address)
    map<json> shippingAddress = {};
    if contact?.OtherStreet is string && contact?.OtherStreet != "" { shippingAddress["line1"] = contact?.OtherStreet; }
    if contact?.OtherCity is string && contact?.OtherCity != "" { shippingAddress["city"] = contact?.OtherCity; }
    if contact?.OtherState is string && contact?.OtherState != "" { shippingAddress["state"] = contact?.OtherState; }
    if contact?.OtherPostalCode is string && contact?.OtherPostalCode != "" { shippingAddress["postal_code"] = contact?.OtherPostalCode; }
    if contact?.OtherCountry is string && contact?.OtherCountry != "" { shippingAddress["country"] = contact?.OtherCountry; }
    if shippingAddress.length() > 0 {
        map<json> shipping = {"address": shippingAddress};
        // Add name to shipping if available
        if fullName != "" {
            shipping["name"] = fullName;
        }
        payload["shipping"] = shipping;
    }

    return payload;
}

// Check if record passes filters
public function passesFilters(string? recordTypeId, string? accountStatus) returns boolean {
    // Check RecordType filter
    if recordTypeFilter.length() > 0 {
        if recordTypeId is () {
            log:printDebug("Record filtered out: No RecordTypeId");
            return false;
        }
        boolean recordTypeMatch = false;
        foreach string allowedType in recordTypeFilter {
            if recordTypeId == allowedType {
                recordTypeMatch = true;
                break;
            }
        }
        if !recordTypeMatch {
            log:printDebug("Record filtered out: RecordTypeId does not match filter");
            return false;
        }
    }

    // Check AccountStatus filter
    if accountStatusFilter.length() > 0 {
        if accountStatus is () {
            log:printDebug("Record filtered out: No AccountStatus");
            return false;
        }
        boolean statusMatch = false;
        foreach string allowedStatus in accountStatusFilter {
            if accountStatus == allowedStatus {
                statusMatch = true;
                break;
            }
        }
        if !statusMatch {
            log:printDebug("Record filtered out: AccountStatus does not match filter");
            return false;
        }
    }

    return true;
}