# Keycloak plugin for migrating users from AWS Cognito

## Description

This UserStorageProvider plugin will seamlessly migrate users from an existing Cognito user pool into Keycloak.

When an user attempts to login:
- Keycloak will first check if the user is already in its local database.
  - If yes, Keycloak will perform password validation against the local database.
  - If no, Keycloak will delegate the validation task to this provider which will check if the provided credentials can be used to log into the configured Cognito user pool.
    - If yes, the plugin will create a new user in the Keycloak local database with the provided credentials. Future logins for this user will then be validated against the local database and will not reach Cognito anymore.
    - If no, the login attempt will fail.

## Usage

1. Deploy the compiled jar to Keycloak per [this documentation](https://www.keycloak.org/docs/latest/server_development/#registering-provider-implementations). In a nutshell, copy the jar to the `standalone/deployments/` folder.
1. In Keycloak admin console, go to your realm > User Federation, and add "cognito-migration".
1. Insert the required configurations and save.
1. Done. From now on, any password login will perform the logic in the Description section above.

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
