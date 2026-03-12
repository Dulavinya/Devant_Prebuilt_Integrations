import ballerina/log;

// Validate Salesforce Account before syncing
public isolated function validateAccount(SalesforceAccount account) returns error? {
    // Validate required fields
    if account?.Id is () || account?.Id == "" {
        return error("Account ID is required");
    }

    // Note: Accounts don't have standard Email field
    // Only EXTERNAL_ID match key works with Accounts (uses SF Id in Stripe metadata)
    // For EMAIL match key, use Contacts which have standard Email field
    if matchKey == EMAIL {
        log:printWarn("Account sync with EMAIL match key not supported (no Email field)", accountId = account?.Id);
        return error("Accounts don't support EMAIL match key - use EXTERNAL_ID or sync Contacts instead");
    }

    return;
}

// Validate Salesforce Contact before syncing
public isolated function validateContact(SalesforceContact contact) returns error? {
    // Validate required fields
    if contact?.Id is () || contact?.Id == "" {
        return error("Contact ID is required");
    }

    // Validate email if match key is EMAIL
    if matchKey == EMAIL {
        string? email = contact?.Email;
        if email is () || email == "" {
            log:printWarn("Contact has no email, cannot sync with EMAIL match key", contactId = contact?.Id);
            return error("Contact email is required for EMAIL match key");
        }
        if !isValidEmail(email) {
            log:printWarn("Contact has invalid email format", contactId = contact?.Id, email = email);
            return error("Invalid email format");
        }
    }
    // EXTERNAL_ID uses SF Id stored in Stripe metadata — always present if Id check above passed

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
