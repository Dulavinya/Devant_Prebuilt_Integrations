import ballerina/log;

// Bulk sync all Accounts from Salesforce to Stripe
public function bulkSyncAccountsToStripe() returns error? {
    log:printInfo("Starting bulk sync of Accounts from Salesforce to Stripe");

    // Query all Account fields (optional filter fields queried only if filters are configured)
    string soqlQuery = "SELECT Id, Name, Phone, ShippingStreet, ShippingCity, ShippingState, " +
                       "ShippingPostalCode, ShippingCountry, Description, Stripe_Customer_Id__c";
    if recordTypeFilter.length() > 0 {
        soqlQuery += ", RecordTypeId";
    }
    if accountStatusFilter.length() > 0 {
        soqlQuery += ", AccountStatus__c";
    }
    soqlQuery += " FROM Account";

    // Execute query with flexible map type to handle optional custom fields
    stream<map<anydata>, error?> accountStream = check salesforceClient->query(soqlQuery);

    int successCount = 0;
    int errorCount = 0;

    // Process each account
    check from map<anydata> accountData in accountStream
        do {
            SalesforceAccount account = {
                Id: <string?>(accountData["Id"]),
                Name: <string?>(accountData["Name"]),
                Phone: <string?>(accountData["Phone"]),
                ShippingStreet: <string?>(accountData["ShippingStreet"]),
                ShippingCity: <string?>(accountData["ShippingCity"]),
                ShippingState: <string?>(accountData["ShippingState"]),
                ShippingPostalCode: <string?>(accountData["ShippingPostalCode"]),
                ShippingCountry: <string?>(accountData["ShippingCountry"]),
                Description: <string?>(accountData["Description"]),
                Stripe_Customer_Id__c: <string?>(accountData["Stripe_Customer_Id__c"]),
                "RecordTypeId": accountData["RecordTypeId"],
                "AccountStatus__c": accountData["AccountStatus__c"]
            };
            error? result = syncAccountToStripe(account);
            if result is error {
                log:printError("Failed to sync Account", accountId = account?.Id, 'error = result);
                errorCount += 1;
            } else {
                successCount += 1;
            }
        };

    log:printInfo("Bulk sync of Accounts completed", successCount = successCount, errorCount = errorCount);
}

// Bulk sync all Contacts from Salesforce to Stripe
public function bulkSyncContactsToStripe() returns error? {
    log:printInfo("Starting bulk sync of Contacts from Salesforce to Stripe");

    // Build SOQL query - Contact doesn't have RecordTypeId or AccountStatus__c fields
    string soqlQuery = "SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, " +
                       "MailingState, MailingPostalCode, MailingCountry, Description, " +
                       "Stripe_Customer_Id__c FROM Contact";

    // Execute query with flexible map type
    stream<map<anydata>, error?> contactStream = check salesforceClient->query(soqlQuery);

    int successCount = 0;
    int errorCount = 0;

    // Process each contact
    check from map<anydata> contactData in contactStream
        do {
            SalesforceContact contact = {
                Id: <string?>(contactData["Id"]),
                FirstName: <string?>(contactData["FirstName"]),
                LastName: <string?>(contactData["LastName"]),
                Email: <string?>(contactData["Email"]),
                Phone: <string?>(contactData["Phone"]),
                MailingStreet: <string?>(contactData["MailingStreet"]),
                MailingCity: <string?>(contactData["MailingCity"]),
                MailingState: <string?>(contactData["MailingState"]),
                MailingPostalCode: <string?>(contactData["MailingPostalCode"]),
                MailingCountry: <string?>(contactData["MailingCountry"]),
                Description: <string?>(contactData["Description"]),
                Stripe_Customer_Id__c: <string?>(contactData["Stripe_Customer_Id__c"])
            };
            error? result = syncContactToStripe(contact);
            if result is error {
                log:printError("Failed to sync Contact", contactId = contact?.Id, 'error = result);
                errorCount += 1;
            } else {
                successCount += 1;
            }
        };

    log:printInfo("Bulk sync of Contacts completed", successCount = successCount, errorCount = errorCount);
}

// Main bulk sync function based on configuration
public function bulkSync() returns error? {
    log:printInfo("Starting bulk sync based on configuration", sourceObject = sourceObject);

    if sourceObject == ACCOUNT || sourceObject == BOTH {
        check bulkSyncAccountsToStripe();
    }

    if sourceObject == CONTACT || sourceObject == BOTH {
        check bulkSyncContactsToStripe();
    }
}