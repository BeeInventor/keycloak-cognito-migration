package com.beeinventor.keycloak;

import org.keycloak.models.KeycloakSession;
import org.keycloak.services.resource.RealmResourceProvider;
import org.keycloak.Config.Config_Scope;
import org.keycloak.models.KeycloakSessionFactory;
import org.keycloak.services.resource.RealmResourceProviderFactory;

class CognitoMigrationResourceProviderFactory implements RealmResourceProviderFactory {
	
	public function new() {}

	public function close() {}

	public function create(session:KeycloakSession):RealmResourceProvider {
		return new CognitoMigrationResourceProvider(session);
	}

	public function getId():String {
		return 'cognito-migration';
	}

	public function init(config:Config_Scope) {}

	public function order():Int {
		return 10;
	}

	public function postInit(factory:KeycloakSessionFactory) {}
}