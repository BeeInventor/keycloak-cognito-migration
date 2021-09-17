package com.beeinventor.keycloak;

import sys.thread.Lock;
import sys.thread.Thread;
import org.keycloak.models.UserProvider;
import org.keycloak.storage.user.SynchronizationResult;
import haxe.DynamicAccess;
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
	
	public static inline final WEBHOOK_BATCH_SIZE = 100;
	
	final session:KeycloakSession;
	final model:ComponentModel;
	final cognito:Cognito;
	final webhooks:Webhooks;

	public function new(session, model, cognito, webhooks) {
		this.session = session;
		this.model = model;
		this.cognito = cognito;
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
		if (!supportsCredentialType(input.getType()))
			return false;

		final username = user.getUsername();
		final password = input.getChallengeResponse();

		return switch cognito.validate(username, password) {
			case null:
				false;
			case attributes:
				// TODO: old password may not comply with current password policies
				// need to find a way to bypass password policies, or force user to change password
				session.userCredentialManager().updateCredential(realm, user, input);
				user.setEnabled(true);
				user.setEmailVerified(attributes['email_verified'] == 'true');
				for (key => value in attributes)
					user.setAttribute('cognito_$key', Collections.singletonList(value));
				user.setFederationLink(null);
				
				// invoke webhook
				switch webhooks.onCredentialsMigrated {
					case null: // skip
					case webhook:
						final result = webhook.invoke('POST', {
							final headers = [];
							switch webhooks.auth {
								case null | '': // skip
								case v: headers.push({name: 'Authorization', value: v});
							}
							headers;
						}, {
							id: user.getId(),
							attributes: {
								final attr = new DynamicAccess();
								for (key => value in attributes)
									attr['cognito_$key'] = value;
								attr;
							}
						});
				}
				true;
		}
	}

	public function supportsCredentialType(type:String):Bool {
		return type == PasswordCredentialModel.TYPE;
	}

	public overload function getUserByEmail(realm:RealmModel, email:String):UserModel {
		return switch cognito.get(email) {
			case null:
				null;
			case remote:
				createUsersIfNotExists(
					session.userLocalStorage(),
					realm,
					model,
					webhooks,
					[{
						username: remote.getUsername(),
						attributes: [for(attr in remote.getUserAttributes()) attr.getName() => attr.getValue()],
					}]
				)[0];
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
	
	public static function createUsersIfNotExists(localStorage:UserProvider, realm:RealmModel, model:ComponentModel, webhooks:Webhooks, remoteUsers:Array<{username:String, attributes:Map<String, String>}>, ?result:SynchronizationResult):Array<UserModel> {
		final webhookPayloads:Array<Webhooks.UserPayload> = [];
		final ret:Array<UserModel> = [];

		for (remote in remoteUsers) {
			final attributes = remote.attributes;
			if (localStorage.searchForUserByUserAttributeStream(realm, 'cognito_sub', attributes['sub']).count() == 0) {
				if(result != null) result.increaseAdded();
				final username = remote.username;
				final local = localStorage.addUser(realm, username);
				ret.push(local);
				switch attributes['email'] {
					case null: // skip
					case email: local.setEmail(email);
				}

				for (key => value in attributes)
					local.setAttribute('cognito_$key', Collections.singletonList(value));

				local.setFederationLink(model.getId());

				// webhook
				webhookPayloads.push({
					id: local.getId(),
					attributes: {
						final attr = new DynamicAccess();
						for (key => value in attributes)
							attr['cognito_$key'] = value;
						attr;
					}
				});
			}
		}

		// run webhooks in parallel
		final lock = new Lock();
		final batches = Math.ceil(webhookPayloads.length / WEBHOOK_BATCH_SIZE);
		for (i in 0...batches) {
			final payloads = webhookPayloads.slice(i * WEBHOOK_BATCH_SIZE, (i+1) * WEBHOOK_BATCH_SIZE);
			Thread.create(() -> {
				// invoke webhook
				switch webhooks.onAccountCreated {
					case null: // skip
					case webhook:
						final result = webhook.invoke('POST', {
							final headers = [];
							switch webhooks.auth {
								case null | '': // skip
								case v: headers.push({name: 'Authorization', value: v});
							}
							headers;
						}, payloads);
				}

				lock.release();
			});
		}

		for (_ in 0...batches)
			lock.wait();
		
		return ret;
	}
}
