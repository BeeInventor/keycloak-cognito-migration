package com.beeinventor.keycloak;

import org.keycloak.models.KeycloakSession;
import org.keycloak.services.resource.RealmResourceProvider;

class CognitoMigrationResourceProvider implements RealmResourceProvider {
	final session:KeycloakSession;
	
	public function new(session) {
		this.session = session;
	}

	public function close() {}

	public function getResource():Dynamic {
		return this;
	}
	
	@:keep
	@:meta(javax.ws.rs.GET())
	@:meta(javax.ws.rs.Path(value = 'search'))
	@:meta(javax.ws.rs.Produces(value = ['application/json']))
	// TODO: use QueryParam (see: https://github.com/HaxeFoundation/haxe/issues/10397)
	public function search(
		@:meta(javax.ws.rs.QueryParam(value = 'realm')) realm:String,
		@:meta(javax.ws.rs.QueryParam(value = 'id')) id:String
	):String {
		final realm = session.realmLocalStorage().getRealm(realm);
		final user = session.userLocalStorage().searchForUserByUserAttributeStream(realm, 'cognito_sub', id).findFirst();
		
		return haxe.Json.stringify({
			result: user.isPresent() ? user.get().getId() : null,
		});
	}
}