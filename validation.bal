import ballerina/log;

// Validate Salesforce Account before syncing
public isolated function validateAccount(SalesforceAccount account) returns error? {
    // Validate required fields
    if account.Id is () || account.Id == "" {
        return error("Account ID is required");
    }

    // Validate email if match key is EMAIL
    if matchKey == EMAIL {
        string? email = account.Email__c;
        if email is () || email == "" {
            log:printWarn("Account has no email, cannot sync with EMAIL match key", accountId = account.Id);
            return error("Account email is required for EMAIL match key");
        }
        
        // Basic email validation
        if !isValidEmail(email) {
            log:printWarn("Account has invalid email format", accountId = account.Id, email = email);
            return error("Invalid email format");
        }
    }

    // Validate external ID if match key is EXTERNAL_ID
    if matchKey == EXTERNAL_ID {
        // Use reflection to get the external ID field value
        // For now, we'll skip this validation as Ballerina doesn't support dynamic field access
        log:printDebug("External ID validation skipped - implement based on your field name");
    }

    return;
}

// Validate Salesforce Contact before syncing
public isolated function validateContact(SalesforceContact contact) returns error? {
    // Validate required fields
    if contact.Id is () || contact.Id == "" {
        return error("Contact ID is required");
    }

    // Validate email if match key is EMAIL
    if matchKey == EMAIL {
        string? email = contact.Email;
        if email is () || email == "" {
            log:printWarn("Contact has no email, cannot sync with EMAIL match key", contactId = contact.Id);
            return error("Contact email is required for EMAIL match key");
        }
        
        // Basic email validation
        if !isValidEmail(email) {
            log:printWarn("Contact has invalid email format", contactId = contact.Id, email = email);
            return error("Invalid email format");
        }
    }

    return;
}

// Basic email validation
isolated function isValidEmail(string email) returns boolean {
    // Simple email validation - contains @ and has characters before and after
    int? atIndex = email.indexOf("@");
    if atIndex is () || atIndex <= 0 || atIndex >= email.length() - 1 {
        return false;
    }
    
    // Check for dot after @
    string domain = email.substring(atIndex + 1);
    int? dotIndex = domain.indexOf(".");
    if dotIndex is () || dotIndex <= 0 || dotIndex >= domain.length() - 1 {
        return false;
    }
    
    return true;
}
