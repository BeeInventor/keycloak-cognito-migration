package com.beeinventor.keycloak;

import haxe.DynamicAccess;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.Json;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Collections;
import org.keycloak.component.ComponentModel;
import org.keycloak.credential.CredentialInput;
import org.keycloak.credential.CredentialInputValidator;
import org.keycloak.models.credential.PasswordCredentialModel;
import org.keycloak.models.GroupModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.RoleModel;
import org.keycloak.models.UserModel;
import org.keycloak.storage.user.UserLookupProvider;
import org.keycloak.storage.UserStorageProvider;

class CognitoMigrationUserStorageProvider implements UserStorageProvider implements UserLookupProvider implements CredentialInputValidator {
	
	final session:KeycloakSession;
	final model:ComponentModel;
	final validator:Validator;
	final webhooks:Webhooks;
	
	public function new(session, model, validator, webhooks) {
		this.session = session;
		this.model = model;
		this.validator = validator;
		this.webhooks = webhooks;
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
				// TODO: old password may not comply with current password policies
				// need to find a way to bypass password policies, or force user to change password
				session.userCredentialManager().updateCredential(realm, user, input);
				user.setEnabled(true);
				user.setEmailVerified(attributes['email_verified'] == 'true');
				for(key => value in attributes)
					user.setAttribute('cognito_$key', Collections.singletonList(value));
				user.setFederationLink(null);
				switch webhooks.onSuccess {
					case null | '': // skip
					case url: 
						final result = invokeWebhook(url, 'POST', {
							id: user.getId(),
							attributes: {
								final attr = new DynamicAccess();
								for(key => value in attributes)
									attr['cognito_$key'] = value;
								attr;
							}
						});
						trace('webhook result: ${result.status} ${result.body.toString()}');
				}
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
	
	function invokeWebhook(url:String, method:String, payload:WebhookPayload) {
		final url = new URL(url);
		final cnx:HttpURLConnection = cast url.openConnection();
		final data = Bytes.ofString(Json.stringify(payload));
		
		cnx.setRequestMethod('POST');
		cnx.setRequestProperty('Content-Type', 'application/json');
		cnx.setDoOutput(true);
		
		final out = cnx.getOutputStream();
		out.write(data.getData());
		out.flush();
		out.close();
		
		return {
			status: cnx.getResponseCode(),
			body: {
				final body = cnx.getInputStream();
				final buffer = new BytesBuffer();
				while(true) switch body.read() {
					case -1: break; 
					case v: buffer.addByte(v);
				}
				buffer.getBytes();
			}
		}
	}
}

typedef WebhookPayload = {
	final id:String;
	final attributes:Dynamic<String>;
}