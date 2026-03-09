import ballerina/http;
import ballerinax/'client.config as clientConfig;

// Salesforce Configuration
configurable string salesforceBaseUrl = ?;
configurable string salesforceClientId = ?;
configurable string salesforceClientSecret = ?;
configurable string salesforceRefreshToken = ?;
configurable string salesforceRefreshUrl = ?;

// Stripe Configuration
configurable string stripeApiKey = ?;

// Sync Configuration
configurable SyncDirection syncDirection = SF_TO_STRIPE;
configurable SourceObject sourceObject = ACCOUNT;
configurable MatchKey matchKey = EMAIL;
configurable boolean writeBackStripeId = true;
configurable string[] recordTypeFilter = [];
configurable string[] accountStatusFilter = [];

// Salesforce Listener Configuration
configurable string salesforceUsername = ?;
configurable string salesforcePassword = ?;
configurable boolean isSandbox = false;

// Salesforce Auth Configuration
public function getSalesforceAuthConfig() returns clientConfig:OAuth2RefreshTokenGrantConfig => {
    refreshUrl: salesforceRefreshUrl,
    refreshToken: salesforceRefreshToken,
    clientId: salesforceClientId,
    clientSecret: salesforceClientSecret
};

// Stripe Auth Configuration
public function getStripeAuthConfig() returns http:BearerTokenConfig => {
    token: stripeApiKey
};
