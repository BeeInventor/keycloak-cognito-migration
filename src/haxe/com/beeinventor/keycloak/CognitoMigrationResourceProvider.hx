package com.beeinventor.keycloak;

import org.keycloak.models.KeycloakSession;
import org.keycloak.services.resource.RealmResourceProvider;

// TODO: auth
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
	public function search(
		@:meta(javax.ws.rs.QueryParam(value = 'realm')) realm:String,
		@:meta(javax.ws.rs.QueryParam(value = 'id')) id:String
	):String {
		final realm = session.realmLocalStorage().getRealm(realm);
		
		// TODO: realm can be null
		final user = session.userLocalStorage().searchForUserByUserAttributeStream(realm, 'cognito_sub', id).findFirst();
		
		return haxe.Json.stringify({
			result: user.isPresent() ? user.get().getId() : null,
		});
	}
	
	@:keep
	@:meta(javax.ws.rs.POST())
	@:meta(javax.ws.rs.Path(value = 'unlink'))
	@:meta(javax.ws.rs.Produces(value = ['application/json']))
	public function unlink(
		@:meta(javax.ws.rs.QueryParam(value = 'realm')) realm:String,
		@:meta(javax.ws.rs.QueryParam(value = 'user')) user:String
	):String {
		final realm = session.realms().getRealm(realm);
		
		// TODO: realm can be null
		final user = session.users().getUserById(realm, user);
		
		// TODO: user can be null
		user.setFederationLink(null);
		
		if (session.getTransactionManager().isActive()) {
			session.getTransactionManager().commit();
		} else {
			throw 'Not in transaction, user cannot be updated';
		}
		
		return haxe.Json.stringify({
			result: 'ok'
		});
	}
}