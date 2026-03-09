import ballerina/log;

// Map Salesforce Account to Stripe Customer
public function mapAccountToStripeCustomer(SalesforceAccount account) returns record {} => {
    "name": account.Name,
    "email": account.Email__c,
    "phone": account.Phone,
    "description": account.Description,
    "address": {
        "line1": account.BillingStreet,
        "city": account.BillingCity,
        "state": account.BillingState,
        "postal_code": account.BillingPostalCode,
        "country": account.BillingCountry
    },
    "metadata": {
        "salesforce_id": account.Id ?: "",
        "source": "salesforce_account"
    }
};

// Map Salesforce Contact to Stripe Customer
public function mapContactToStripeCustomer(SalesforceContact contact) returns record {} {
    string fullName = "";
    if contact.FirstName is string {
        fullName = contact.FirstName ?: "";
    }
    if contact.LastName is string {
        string lastName = contact.LastName ?: "";
        fullName = fullName + (fullName != "" ? " " : "") + lastName;
    }

    return {
        "name": fullName,
        "email": contact.Email,
        "phone": contact.Phone,
        "description": contact.Description,
        "address": {
            "line1": contact.MailingStreet,
            "city": contact.MailingCity,
            "state": contact.MailingState,
            "postal_code": contact.MailingPostalCode,
            "country": contact.MailingCountry
        },
        "metadata": {
            "salesforce_id": contact.Id ?: "",
            "source": "salesforce_contact"
        }
    };
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
