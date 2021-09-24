package com.beeinventor.keycloak;

import java.util.HashMap;
import org.keycloak.Config.Config_Scope;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;
import org.keycloak.provider.ServerInfoAwareProviderFactory;
import org.keycloak.services.resource.RealmResourceProvider;
import org.keycloak.services.resource.RealmResourceProviderFactory;

class CognitoMigrationResourceProviderFactory implements RealmResourceProviderFactory implements ServerInfoAwareProviderFactory {
	
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
	
	
	public function getOperationalInfo():java.util.Map<String, String> {
		// These info will be shown in the Server Info page in admin console
		final info = new HashMap();
		final pom = Macro.readPomInfo();
		info.put('version', pom.version);
		info.put('website', pom.website);
		return info;
	}
}