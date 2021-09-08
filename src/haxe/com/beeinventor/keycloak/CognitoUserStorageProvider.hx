package com.beeinventor.keycloak;

import org.keycloak.component.ComponentModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.credential.CredentialInput;
import org.keycloak.credential.CredentialInputValidator;
import org.keycloak.models.credential.PasswordCredentialModel;
import org.keycloak.models.GroupModel;
import org.keycloak.models.RealmModel;
import org.keycloak.models.RoleModel;
import org.keycloak.models.UserModel;
import org.keycloak.storage.user.UserLookupProvider;
import org.keycloak.storage.UserStorageProvider;

class CognitoUserStorageProvider implements UserStorageProvider implements UserLookupProvider implements CredentialInputValidator {
	
	final session:KeycloakSession;
	final model:ComponentModel;
	
	public function new(session, model) {
		this.session = session;
		this.model = model;
		
		// model.getConfig(); // TODO: get aws keys from config
	}

	public function close() {
		// do nothing
	}

	public overload function preRemove(realm:RealmModel) {
		// do nothing
	}

	public overload function preRemove(realm:RealmModel, group:GroupModel) {
		// do nothing
	}

	public overload function preRemove(realm:RealmModel, role:RoleModel) {
		// do nothing
	}

	public function isConfiguredFor(realm:RealmModel, user:UserModel, type:String):Bool {
		return supportsCredentialType(type);
	}

	public function isValid(realm:RealmModel, user:UserModel, input:CredentialInput):Bool {
		if(!supportsCredentialType(input.getType())) return false;
		
		final username = user.getUsername();
		final password = input.getChallengeResponse();
		
		trace(username, password);
		
		// https://www.keycloak.org/docs/latest/server_development/#import-implementation-strategy
		
			
		final checker = new com.beeinventor.keycloak.Checker({
			accessKeyId: model.getConfig().getFirst(CognitoUserStorageProviderFactory.AWS_ACCESS_KEY_ID),
			secretAccessKey: model.getConfig().getFirst(CognitoUserStorageProviderFactory.AWS_SECRET_ACCESS_KEY),
			region: model.getConfig().getFirst(CognitoUserStorageProviderFactory.AWS_REGION),
			userPoolId: model.getConfig().getFirst(CognitoUserStorageProviderFactory.COGNITO_USER_POOL_ID),
			clientId: model.getConfig().getFirst(CognitoUserStorageProviderFactory.COGNITO_CLIENT_ID),
			clientSecret: model.getConfig().getFirst(CognitoUserStorageProviderFactory.COGNITO_CLIENT_SECRET),
		});
		
		return switch checker.check(username, password) {
			case null:
				false;
			case remote:
				session.userCredentialManager().updateCredential(realm, user, input);
				user.setEmailVerified(true);
				user.setFederationLink(null);
				user.setEnabled(true);
				true;
		}
	}

	public function supportsCredentialType(type:String):Bool {
		return type == PasswordCredentialModel.TYPE;
	}

	public overload function getUserByEmail(realm:RealmModel, email:String):UserModel {
		// TODO: check with cognito that the specified email actually exists
		return switch session.userLocalStorage().getUserByEmail(realm, email) {
			case null:
				final user = session.userLocalStorage().addUser(realm, email);
				user.setEmail(email);
				user.setFederationLink(model.getId());
				user;
			case user:
				user;
		}
	}

	public overload function getUserByEmail(email:String, realm:RealmModel):UserModel {
		return getUserByEmail(realm, email);
	}

	public overload function getUserById(realm:RealmModel, id:String):UserModel {
		throw new haxe.exceptions.NotImplementedException();
	}

	public overload function getUserById(id:String, realm:RealmModel):UserModel {
		return getUserById(realm, id);
	}

	public overload function getUserByUsername(realm:RealmModel, username:String):UserModel {
		throw new haxe.exceptions.NotImplementedException();
	}

	public overload function getUserByUsername(username:String, realm:RealmModel):UserModel {
		return getUserByUsername(realm, username);
	}
}