# Keycloak plugin for migrating users from AWS Cognito

## Description

This UserStorageProvider plugin will seamlessly migrate users from an existing Cognito user pool into Keycloak.

When an user attempts to login:
- Keycloak will first check if the user is already in its local database.
  - If yes, Keycloak will perform password validation against the local database.
  - If no, Keycloak will delegate the validation task to this provider which will check if the provided credentials can be used to log into the configured Cognito user pool.
    - If yes, the plugin will create a new user in the Keycloak local database with the provided credentials. Future logins for this user will then be validated against the local database and will not reach Cognito anymore.
    - If no, the login attempt will fail.

When an user is successfully migrated, its attributes in Cognito will also be copied to Keycloak, with a `cognito_` prefix (See webhook example below).

## Usage

1. Deploy the compiled jar to Keycloak per [this documentation](https://www.keycloak.org/docs/latest/server_development/#registering-provider-implementations). In a nutshell, copy the jar to the `standalone/deployments/` folder.
1. In Keycloak admin console, go to your realm > User Federation, and add "cognito-migration".
1. Insert the required configurations and save.
1. Done. From now on, any password login will perform the logic in the Description section above.

#### Webhook

There is a "On Account Created" and "On Credentials Migrated" webhook configuration.

When set, the plugin will invoke the webhook with a POST method and a JSON payload in the form shown below (typescript notation):

Note: Payload of "On Account Created" is an array, because accounts can be bulk-created via the Sync button

```ts
interface WebhookPayload {
  id: string;
  attributes: Record<string, string>;
}
```

Example:

```json
{
  "id": "8dc7fd6e-ffff-4820-88fa-2395129c3f5a",
  "attributes": {
    "cognito_preferred_mfa_setting": null,
    "cognito_user_status": "CONFIRMED",
    "cognito_email_verified": "true",
    "cognito_user_create_date": "2018-06-15T06:01:16Z",
    "cognito_user_last_modified_date": "2020-12-02T05:32:25Z",
    "cognito_username": "25d75cdd-ffff-4dc2-a913-156603436cc6",
    "cognito_sub": "25d75cdd-ffff-4dc2-a913-156603436cc6",
    "cognito_email": "user@abc.xyz",
  }
}
```

## Search API

This plugin also exposes an API that allow searching migrated users by their Cognito ID and will return the Keycloak User ID if found, or null otherwise.

|  |  |
| -- | -- |
| Method | GET |
| Path | `/realms/master/cognito-migration/search` |
| Query Param | id (cognito id), realm |
| Response | `{result:null\|string}` |

Example: `curl http://localhost:8080/admin/realms/master/cognito-migration/search?id=my-cognito-id&realm=my-realm`

## Canveat

When creating the user and setting its password in keycloak local database, the realm's password policies will apply.
That means if the user's password in Cognito does not comply with the policies, the migration will fail.
So make sure your realm's policies match those in your Cognito user pool.

## Development

1. Start the devcontainer
1. To compile the plugin as a deployable jar:  
  `mvn compile assembly:single`
1. To deploy to keycloak which is running in docker compose:  
  `cp target/*.jar .devcontainer/keycloak/deployments/`  
  (Keycloak will hot reload the provider when the jar is changed)

References:

- https://www.keycloak.org/docs/latest/server_development/#_user-storage-spi
- https://www.keycloak.org/docs/latest/server_development/#import-implementation-strategy
- https://www.keycloak.org/docs-api/15.0/javadocs/
- https://github.com/Smartling/keycloak-user-migration-provider
