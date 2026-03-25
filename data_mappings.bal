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
    if account?.Name !is "" {
        payload["name"] = account?.Name;
    }
    
    if account?.Email__c !is "" { payload["email"] = account?.Email__c; }
    if account?.Phone !is () { payload["phone"] = account?.Phone; }
    if account?.Description !is () { payload["description"] = account?.Description; }

    // Billing Address -> Stripe address field
    map<json> billingAddress = {};
    if account?.BillingStreet !is "" { billingAddress["line1"] = account?.BillingStreet; }
    if account?.BillingCity !is "" { billingAddress["city"] = account?.BillingCity; }
    if account?.BillingState !is "" { billingAddress["state"] = account?.BillingState; }
    if account?.BillingPostalCode !is "" { billingAddress["postal_code"] = account?.BillingPostalCode; }
    if account?.BillingCountry !is "" { billingAddress["country"] = account?.BillingCountry; }
    if billingAddress.length() > 0 { payload["address"] = billingAddress; }

    // Shipping Address -> Stripe shipping.address field
    map<json> shippingAddress = {};
    if account?.ShippingStreet !is "" { shippingAddress["line1"] = account?.ShippingStreet; }
    if account?.ShippingCity !is "" { shippingAddress["city"] = account?.ShippingCity; }
    if account?.ShippingState !is "" { shippingAddress["state"] = account?.ShippingState; }
    if account?.ShippingPostalCode !is "" { shippingAddress["postal_code"] = account?.ShippingPostalCode; }
    if account?.ShippingCountry !is "" { shippingAddress["country"] = account?.ShippingCountry; }
    if shippingAddress.length() > 0 {
        map<json> shipping = {"address": shippingAddress};
        // Add name to shipping if available
        if account?.Name !is "" {
            shipping["name"] = account?.Name;
        }
        payload["shipping"] = shipping;
    }

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
    
    if contact?.Email !is "" { payload["email"] = contact?.Email; }
    if contact?.Phone !is "" { payload["phone"] = contact?.Phone; }
    if contact?.Description !is () { payload["description"] = contact?.Description; }

    // Mailing Address -> Billing Address (address)
    map<json> billingAddress = {};
    if contact?.MailingStreet !is "" { billingAddress["line1"] = contact?.MailingStreet; }
    if contact?.MailingCity !is "" { billingAddress["city"] = contact?.MailingCity; }
    if contact?.MailingState !is "" { billingAddress["state"] = contact?.MailingState; }
    if contact?.MailingPostalCode !is "" { billingAddress["postal_code"] = contact?.MailingPostalCode; }
    if contact?.MailingCountry !is "" { billingAddress["country"] = contact?.MailingCountry; }
    if billingAddress.length() > 0 { payload["address"] = billingAddress; }

    // Other Address -> Shipping Address (shipping.address)
    map<json> shippingAddress = {};
    if contact?.OtherStreet !is "" { shippingAddress["line1"] = contact?.OtherStreet; }
    if contact?.OtherCity !is "" { shippingAddress["city"] = contact?.OtherCity; }
    if contact?.OtherState !is "" { shippingAddress["state"] = contact?.OtherState; }
    if contact?.OtherPostalCode !is "" { shippingAddress["postal_code"] = contact?.OtherPostalCode; }
    if contact?.OtherCountry !is "" { shippingAddress["country"] = contact?.OtherCountry; }
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