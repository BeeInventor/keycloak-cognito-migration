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
	@:meta(javax.ws.rs.POST())
	@:meta(javax.ws.rs.Path(value = 'search'))
	@:meta(javax.ws.rs.Consumes(value = ['application/json']))
	@:meta(javax.ws.rs.Produces(value = ['application/json']))
	// TODO: use QueryParam (see: https://github.com/HaxeFoundation/haxe/issues/10397)
	public function search(query:SearchQuery):String {
		final realm = session.realmLocalStorage().getRealm(query.realm);
		final user = session.userLocalStorage().searchForUserByUserAttributeStream(realm, 'cognito_sub', query.id).findFirst();
		
		return haxe.Json.stringify({
			result: user.isPresent() ? user.get().getId() : null,
		});
	}
}

class SearchQuery {
	public var id:String;
	public var realm:String;
	public function new() {}
}