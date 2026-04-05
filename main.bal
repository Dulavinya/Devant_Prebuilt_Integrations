import ballerina/log;
import ballerinax/salesforce;

// Salesforce Listener Configuration
// NOTE: Before running, ensure Change Data Capture is enabled in Salesforce:
// Setup → Change Data Capture → Select Account and Contact → Save
// Using OAuth2 refresh token auth (avoids SOAP username/password/security token requirement)
listener salesforce:Listener changeEventListener = new ({
    auth: {
        refreshUrl: salesforceConfig.refreshUrl,
        refreshToken: salesforceConfig.refreshToken,
        clientId: salesforceConfig.clientId,
        clientSecret: salesforceConfig.clientSecret
    },
    baseUrl: salesforceConfig.baseUrl
});

// Salesforce Change Event Service
// Channel name is required by the salesforce:Listener.
// /data/ChangeEvents subscribes to all CDC-enabled objects (Account, Contact, etc.)
service "/data/ChangeEvents" on changeEventListener {

    // Handle Create Events
    remote function onCreate(salesforce:EventData eventData) returns error? {
        log:printInfo("Received create event from Salesforce");

        // Determine object type from event metadata
        string entityType = eventData.metadata?.entityName ?: "";
        log:printInfo("[onCreate] entityType=" + entityType + " sourceObject=" + sourceObject);

        // CDC changedData does not include Id — inject it from metadata.recordId
        string recordId = eventData.metadata?.recordId ?: "";
        map<json> data = eventData.changedData;
        data["Id"] = recordId;

        // Route to appropriate handler based on entity type
        if entityType == "Account" && (sourceObject == ACCOUNT || sourceObject == BOTH) {
            // Try to fetch full Account record to ensure we have all fields
            SalesforceAccount account;
            // Query with flexible map type to handle optional custom fields
            // Include RecordTypeId and AccountStatus__c if filters are configured
            string soqlQuery = string `SELECT Id, Name, Phone, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry, Description, Stripe_Customer_Id__c, Email__c`;
            if recordTypeFilter.length() > 0 {
                soqlQuery += ", RecordTypeId";
            }
            if accountStatusFilter.length() > 0 {
                soqlQuery += ", AccountStatus__c";
            }
            soqlQuery += string ` FROM Account WHERE Id = '${recordId}'`;
            
            stream<map<anydata>, error?>|error queryResultOrError = salesforceClient->query(soqlQuery);
            if queryResultOrError is error {
                log:printError("[onCreate] SOQL query failed for Account", 'error = queryResultOrError, recordId = recordId);
                return;
            }
            stream<map<anydata>, error?> queryResult = queryResultOrError;
            
            record {|map<anydata> value;|}?|error nextRecord = queryResult.next();
            if nextRecord is error {
                log:printError("[onCreate] Failed to read Account query result", 'error = nextRecord, recordId = recordId);
                return;
            }
            
            record {|map<anydata> value;|}? queryRecord = nextRecord;
            if queryRecord is record {|map<anydata> value;|} {
                map<anydata> accountMap = queryRecord.value;
                account = {
                    Id: <string?>(accountMap["Id"]),
                    Name: <string?>(accountMap["Name"]),
                    Phone: <string?>(accountMap["Phone"]),
                    ShippingStreet: <string?>(accountMap["ShippingStreet"]),
                    ShippingCity: <string?>(accountMap["ShippingCity"]),
                    ShippingState: <string?>(accountMap["ShippingState"]),
                    ShippingPostalCode: <string?>(accountMap["ShippingPostalCode"]),
                    ShippingCountry: <string?>(accountMap["ShippingCountry"]),
                    Description: <string?>(accountMap["Description"]),
                    Stripe_Customer_Id__c: <string?>(accountMap["Stripe_Customer_Id__c"]),
                    "Email__c": accountMap["Email__c"],
                    "RecordTypeId": accountMap["RecordTypeId"],
                    "AccountStatus__c": accountMap["AccountStatus__c"]
                };
                log:printInfo("[onCreate] Fetched full Account record", accountId = account?.Id);
            } else {
                // Fallback to CDC data if query returns nothing
                log:printWarn("[onCreate] SOQL query returned no results, using CDC data", recordId = recordId);
                SalesforceAccount|error cdcAccount = data.cloneWithType();
                if cdcAccount is error {
                    log:printError("[onCreate] Failed to parse Account data", 'error = cdcAccount, recordId = recordId);
                    return;
                }
                account = cdcAccount;
            }
            
            error? result = syncAccountToStripe(account);
            if result is error {
                log:printError("[onCreate] Failed to sync Account to Stripe", 'error = result, accountId = account?.Id);
            }
        } else if entityType == "Contact" && (sourceObject == CONTACT || sourceObject == BOTH) {
            // CDC changedData may not include FirstName/LastName on create (only Name)
            // Fetch full record to ensure we have all fields
            SalesforceContact contact;
            string soqlQuery = string `SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, Description, Stripe_Customer_Id__c FROM Contact WHERE Id = '${recordId}'`;
            
            stream<map<anydata>, error?>|error queryResultOrError = salesforceClient->query(soqlQuery);
            if queryResultOrError is error {
                log:printError("[onCreate] SOQL query failed for Contact", 'error = queryResultOrError, recordId = recordId);
                return;
            }
            stream<map<anydata>, error?> queryResult = queryResultOrError;
            
            record {|map<anydata> value;|}?|error nextRecord = queryResult.next();
            if nextRecord is error {
                log:printError("[onCreate] Failed to read Contact query result", 'error = nextRecord, recordId = recordId);
                return;
            }
            
            record {|map<anydata> value;|}? queryRecord = nextRecord;
            if queryRecord is record {|map<anydata> value;|} {
                map<anydata> contactMap = queryRecord.value;
                contact = {
                    Id: <string?>(contactMap["Id"]),
                    FirstName: <string?>(contactMap["FirstName"]),
                    LastName: <string?>(contactMap["LastName"]),
                    Email: <string?>(contactMap["Email"]),
                    Phone: <string?>(contactMap["Phone"]),
                    MailingStreet: <string?>(contactMap["MailingStreet"]),
                    MailingCity: <string?>(contactMap["MailingCity"]),
                    MailingState: <string?>(contactMap["MailingState"]),
                    MailingPostalCode: <string?>(contactMap["MailingPostalCode"]),
                    MailingCountry: <string?>(contactMap["MailingCountry"]),
                    Description: <string?>(contactMap["Description"]),
                    Stripe_Customer_Id__c: <string?>(contactMap["Stripe_Customer_Id__c"])
                };
                log:printInfo("[onCreate] Fetched full Contact record", contactId = contact?.Id);
            } else {
                // Fallback to CDC data if query returns nothing
                log:printWarn("[onCreate] SOQL query returned no results, using CDC data", recordId = recordId);
                SalesforceContact|error cdcContact = data.cloneWithType();
                if cdcContact is error {
                    log:printError("[onCreate] Failed to parse Contact data", 'error = cdcContact, recordId = recordId);
                    return;
                }
                contact = cdcContact;
            }
            log:printInfo("[onCreate] Contact parsed", contactId = contact?.Id);
            error? result = syncContactToStripe(contact);
            if result is error {
                log:printError("[onCreate] Failed to sync Contact to Stripe", 'error = result, contactId = contact?.Id);
            }
        } else {
            log:printInfo("[onCreate] No handler for entityType='" + entityType + "' sourceObject='" + sourceObject + "'");
        }
    }

    // Handle Update Events
    remote function onUpdate(salesforce:EventData eventData) returns error? {
        log:printInfo("Received update event from Salesforce");

        // Determine object type from event metadata
        string entityType = eventData.metadata?.entityName ?: "";
        string recordId = eventData.metadata?.recordId ?: "";
        log:printInfo("[onUpdate] entityType=" + entityType + " recordId=" + recordId + " sourceObject=" + sourceObject);

        // Skip writeback-triggered update events (only Stripe_Customer_Id__c changed)
        map<json> changedFields = eventData.changedData;
        
        log:printInfo("[onUpdate] changedData keys BEFORE any filtering: " + changedFields.keys().toString());

        // Detect if this is actually a delete event mislabelled as update
        json changeTypeVal = changedFields["ChangeEventHeader"] is map<json>
            ? ((<map<json>>changedFields["ChangeEventHeader"])["changeType"] ?: "")
            : "";
        log:printInfo("[onUpdate] changeType from ChangeEventHeader: " + changeTypeVal.toString());
        
        // Filter out system fields that are always present in CDC events
        map<json> filteredFields = {};
        foreach var [key, value] in changedFields.entries() {
            if key != "ChangeEventHeader" && key != "LastModifiedDate" {
                filteredFields[key] = value;
            }
        }
        
        // If only Stripe_Customer_Id__c was changed (after filtering system fields), skip processing
        if filteredFields.length() == 1 && filteredFields.hasKey("Stripe_Customer_Id__c") {
            log:printInfo("[onUpdate] Skipping writeback-triggered update (Stripe_Customer_Id__c changed)");
            return;
        }
        
        // If no meaningful fields changed (empty after filtering), skip processing
        if filteredFields.length() == 0 {
            log:printInfo("[onUpdate] No meaningful fields changed, skipping update");
            return;
        }

        // CDC changedData does not include Id — inject it from metadata.recordId
        map<json> data = changedFields;
        data["Id"] = recordId;

        log:printInfo("[onUpdate] changedData keys: " + data.keys().toString());

        // Route to appropriate handler based on entity type
        if entityType == "Account" && (sourceObject == ACCOUNT || sourceObject == BOTH) {
            // CDC changedData only contains changed fields - fetch full record to get all fields including Stripe_Customer_Id__c
            SalesforceAccount account;
            // Query with flexible map type to handle optional custom fields
            // Include RecordTypeId and AccountStatus__c if filters are configured
            string soqlQuery = string `SELECT Id, Name, Phone, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry, Description, Stripe_Customer_Id__c, Email__c`;
            if recordTypeFilter.length() > 0 {
                soqlQuery += ", RecordTypeId";
            }
            if accountStatusFilter.length() > 0 {
                soqlQuery += ", AccountStatus__c";
            }
            soqlQuery += string ` FROM Account WHERE Id = '${recordId}'`;
            
            stream<map<anydata>, error?>|error queryResultOrError = salesforceClient->query(soqlQuery);
            if queryResultOrError is error {
                log:printError("[onUpdate] SOQL query failed for Account", 'error = queryResultOrError, recordId = recordId);
                return;
            }
            stream<map<anydata>, error?> queryResult = queryResultOrError;
            
            record {|map<anydata> value;|}|error? queryRecord = queryResult.next();
            if queryRecord is error {
                log:printError("[onUpdate] Failed to read query result, cannot sync without full record", 'error = queryRecord, recordId = recordId);
                return;
            } else if queryRecord is record {|map<anydata> value;|} {
                map<anydata> accountMap = queryRecord.value;
                account = {
                    Id: <string?>(accountMap["Id"]),
                    Name: <string?>(accountMap["Name"]),
                    Phone: <string?>(accountMap["Phone"]),
                    ShippingStreet: <string?>(accountMap["ShippingStreet"]),
                    ShippingCity: <string?>(accountMap["ShippingCity"]),
                    ShippingState: <string?>(accountMap["ShippingState"]),
                    ShippingPostalCode: <string?>(accountMap["ShippingPostalCode"]),
                    ShippingCountry: <string?>(accountMap["ShippingCountry"]),
                    Description: <string?>(accountMap["Description"]),
                    Stripe_Customer_Id__c: <string?>(accountMap["Stripe_Customer_Id__c"]),
                    "Email__c": accountMap["Email__c"],
                    "RecordTypeId": accountMap["RecordTypeId"],
                    "AccountStatus__c": accountMap["AccountStatus__c"]
                };
                log:printInfo("[onUpdate] Fetched full Account record", accountId = account?.Id);
            } else {
                // Query returned nothing - record may have been deleted
                log:printWarn("[onUpdate] SOQL query returned no results, cannot sync without full record", recordId = recordId);
                return;
            }
            log:printInfo("[onUpdate] Account parsed", accountId = account?.Id, stripeCustomerId = account?.Stripe_Customer_Id__c);
            error? result = syncAccountToStripe(account, true);
            if result is error {
                log:printError("[onUpdate] Failed to sync Account to Stripe", 'error = result, accountId = account?.Id);
            }
        } else if entityType == "Contact" && (sourceObject == CONTACT || sourceObject == BOTH) {
            // CDC changedData only contains changed fields - fetch full record to get FirstName/LastName
            SalesforceContact contact;
            string soqlQuery = string `SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, Description, Stripe_Customer_Id__c FROM Contact WHERE Id = '${recordId}'`;
            
            stream<map<anydata>, error?>|error queryResultOrError = salesforceClient->query(soqlQuery);
            if queryResultOrError is error {
                log:printError("[onUpdate] SOQL query failed for Contact", 'error = queryResultOrError, recordId = recordId);
                return;
            }
            stream<map<anydata>, error?> queryResult = queryResultOrError;
            
            record {|map<anydata> value;|}|error? queryRecord = queryResult.next();
            if queryRecord is error {
                log:printError("[onUpdate] Failed to read query result, cannot sync without full record", 'error = queryRecord, recordId = recordId);
                return;
            } else if queryRecord is record {|map<anydata> value;|} {
                map<anydata> contactMap = queryRecord.value;
                contact = {
                    Id: <string?>(contactMap["Id"]),
                    FirstName: <string?>(contactMap["FirstName"]),
                    LastName: <string?>(contactMap["LastName"]),
                    Email: <string?>(contactMap["Email"]),
                    Phone: <string?>(contactMap["Phone"]),
                    MailingStreet: <string?>(contactMap["MailingStreet"]),
                    MailingCity: <string?>(contactMap["MailingCity"]),
                    MailingState: <string?>(contactMap["MailingState"]),
                    MailingPostalCode: <string?>(contactMap["MailingPostalCode"]),
                    MailingCountry: <string?>(contactMap["MailingCountry"]),
                    Description: <string?>(contactMap["Description"]),
                    Stripe_Customer_Id__c: <string?>(contactMap["Stripe_Customer_Id__c"])
                };
                log:printInfo("[onUpdate] Fetched full Contact record", contactId = contact?.Id);
            } else {
                // Query returned nothing - record may have been deleted
                log:printWarn("[onUpdate] SOQL query returned no results, cannot sync without full record", recordId = recordId);
                return;
            }
            log:printInfo("[onUpdate] Contact parsed", contactId = contact?.Id);
            error? result = syncContactToStripe(contact, true);
            if result is error {
                log:printError("[onUpdate] Failed to sync Contact to Stripe", 'error = result, contactId = contact?.Id);
            }
        } else {
            log:printInfo("[onUpdate] No handler for entityType='" + entityType + "' sourceObject='" + sourceObject + "'");
        }
    }

    // Handle Delete Events
    remote function onDelete(salesforce:EventData eventData) returns error? {
        log:printInfo("Received delete event from Salesforce");

        // Determine object type from event metadata
        string entityType = eventData.metadata?.entityName ?: "";
        string recordId = eventData.metadata?.recordId ?: "";

        if recordId == "" {
            log:printWarn("[onDelete] No recordId in event metadata, skipping");
            return;
        }

        log:printInfo("[onDelete] Processing delete", entityType = entityType, recordId = recordId);

        // Check if delete handling is enabled
        if !deleteStripeCustomerOnSalesforceDelete {
            log:printInfo("[onDelete] Delete handling disabled, skipping Stripe customer deletion", recordId = recordId);
            return;
        }

        // Record is already deleted in SF — find Stripe customer by salesforce_id metadata
        if entityType == "Account" && (sourceObject == ACCOUNT || sourceObject == BOTH) {
            error? result = deleteStripeCustomerBySalesforceId(recordId);
            if result is error {
                log:printError("Failed to handle Account deletion", accountId = recordId, 'error = result);
            }
        } else if entityType == "Contact" && (sourceObject == CONTACT || sourceObject == BOTH) {
            error? result = deleteStripeCustomerBySalesforceId(recordId);
            if result is error {
                log:printError("Failed to handle Contact deletion", contactId = recordId, 'error = result);
            }
        }
    }

    // Handle Restore Events
    remote function onRestore(salesforce:EventData eventData) returns error? {
        log:printInfo("Received restore event from Salesforce");

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