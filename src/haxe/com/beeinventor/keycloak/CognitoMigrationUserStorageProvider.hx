package com.beeinventor.keycloak;

import java.util.Collections;
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

class CognitoMigrationUserStorageProvider implements UserStorageProvider implements UserLookupProvider implements CredentialInputValidator {
	
	final session:KeycloakSession;
	final model:ComponentModel;
	final validator:Validator;
	
	public function new(session, model, validator) {
		this.session = session;
		this.model = model;
		this.validator = validator;
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
		
		return switch validator.validate(username, password) {
			case null:
				false;
			case attributes:
				session.userCredentialManager().updateCredential(realm, user, input);
				user.setEnabled(true);
				user.setEmailVerified(attributes['email_verified'] == 'true');
				for(key => value in attributes)
					user.setAttribute('cognito_$key', Collections.singletonList(value));
				user.setFederationLink(null);
				true;
		}
	}

	public function supportsCredentialType(type:String):Bool {
		return type == PasswordCredentialModel.TYPE;
	}

	public overload function getUserByEmail(realm:RealmModel, email:String):UserModel {
		return if(validator.exists(email)) {
			switch session.userLocalStorage().getUserByEmail(realm, email) {
				case null:
					final user = session.userLocalStorage().addUser(realm, email);
					user.setEmail(email);
					user.setFederationLink(model.getId());
					user;
				case user:
					user;
			}
		} else {
			null;
		}
	}

	public overload function getUserByEmail(email:String, realm:RealmModel):UserModel {
		return getUserByEmail(realm, email);
	}

	public overload function getUserById(realm:RealmModel, id:String):UserModel {
		return null;
	}

	public overload function getUserById(id:String, realm:RealmModel):UserModel {
		return getUserById(realm, id);
	}

	public overload function getUserByUsername(realm:RealmModel, username:String):UserModel {
		return null;
	}

	public overload function getUserByUsername(username:String, realm:RealmModel):UserModel {
		return getUserByUsername(realm, username);
	}
}