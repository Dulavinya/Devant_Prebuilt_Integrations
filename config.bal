import ballerina/http;
import ballerinax/'client.config as clientConfig;

// Salesforce Configuration Record Type
public type SalesforceConfig record {|
    string baseUrl;
    string clientId;
    string clientSecret;
    string refreshToken;
    string refreshUrl;
|};

configurable SalesforceConfig salesforceConfig = ?;

// Stripe Configuration
configurable string stripeApiKey = ?;

// Sync Configuration
configurable SourceObject sourceObject = BOTH;
configurable MatchKey matchKey = EMAIL;
configurable boolean writeBackStripeId = true;
configurable string[] recordTypeFilter = [];
configurable string[] accountStatusFilter = [];

// Delete Handling Configuration
configurable boolean deleteStripeCustomerOnSalesforceDelete = true;

// Salesforce Auth Configuration
public function getSalesforceAuthConfig() returns clientConfig:OAuth2RefreshTokenGrantConfig => {
    refreshUrl: salesforceConfig.refreshUrl,
    refreshToken: salesforceConfig.refreshToken,
    clientId: salesforceConfig.clientId,
    clientSecret: salesforceConfig.clientSecret
};

// Stripe Auth Configuration
public function getStripeAuthConfig() returns http:BearerTokenConfig => {
    token: stripeApiKey
};
