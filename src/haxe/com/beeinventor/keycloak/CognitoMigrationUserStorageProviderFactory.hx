package com.beeinventor.keycloak;

import java.util.ArrayList;
import java.util.HashMap;
import org.keycloak.component.ComponentModel;
import org.keycloak.component.ComponentValidationException;
import org.keycloak.Config;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;
import org.keycloak.models.KeycloakSessionTask;
import org.keycloak.models.RealmModel;
import org.keycloak.models.utils.KeycloakModelUtils;
import org.keycloak.provider.ProviderConfigProperty;
import org.keycloak.provider.ServerInfoAwareProviderFactory;
import org.keycloak.storage.user.ImportSynchronization;
import org.keycloak.storage.user.SynchronizationResult;
import org.keycloak.storage.UserStorageProvider;
import org.keycloak.storage.UserStorageProviderFactory;
import org.keycloak.storage.UserStorageProviderModel;
import org.keycloak.storage.UserStorageProviderSpi;
import tink.Adhoc;

class CognitoMigrationUserStorageProviderFactory implements UserStorageProviderFactory<CognitoMigrationUserStorageProvider>
		implements ServerInfoAwareProviderFactory implements ImportSynchronization {
	public static inline final AWS_ACCESS_KEY_ID = 'aws-access-key-id';
	public static inline final AWS_SECRET_ACCESS_KEY = 'aws-secret-access-key';
	public static inline final AWS_REGION = 'aws-region';
	public static inline final COGNITO_USER_POOL_ID = 'cognito-user-pool-id';
	public static inline final COGNITO_CLIENT_ID = 'cognito-client-id';
	public static inline final COGNITO_CLIENT_SECRET = 'cognito-client-secret';
	public static inline final WEBHOOK_AUTH_HEADER = 'webhook-auth-header';
	public static inline final WEBHOOK_ON_ACCOUNT_CREATED = 'webhook-on-account-created';
	public static inline final WEBHOOK_ON_CREDENTIALS_MIGRATED = 'webhook-on-credentials-migrated';

	public function new() {}

	public function getConfigProperties():java.util.List<ProviderConfigProperty> {
		final list = new ArrayList();

		inline function add(o, ?postprocess) {
			final property = new ProviderConfigProperty(o.name, o.label, o.helpText, o.type, o.defaultValue, o.secret);
			if (postprocess != null)
				postprocess(property);
			return list.add(property);
		}

		add({
			name: AWS_ACCESS_KEY_ID,
			label: 'AWS Access Key ID',
			helpText: null,
			type: ProviderConfigProperty.STRING_TYPE,
			defaultValue: '',
			secret: false,
		});

		add({
			name: AWS_SECRET_ACCESS_KEY,
			label: 'AWS Secret Access Key',
			helpText: null,
			type: ProviderConfigProperty.STRING_TYPE,
			defaultValue: '',
			secret: true,
		});

		add({
			name: AWS_REGION,
			label: 'AWS Region',
			helpText: null,
			type: ProviderConfigProperty.STRING_TYPE,
			defaultValue: '',
			secret: false,
		});

		add({
			name: COGNITO_USER_POOL_ID,
			label: 'Cognito User Pool ID',
			helpText: null,
			type: ProviderConfigProperty.STRING_TYPE,
			defaultValue: '',
			secret: false,
		});

		add({
			name: COGNITO_CLIENT_ID,
			label: 'Cognito Client ID',
			helpText: 'Reminder: "ALLOW_ADMIN_USER_PASSWORD_AUTH" has to be enabled for this client',
			type: ProviderConfigProperty.STRING_TYPE,
			defaultValue: '',
			secret: false,
		});

		add({
			name: COGNITO_CLIENT_SECRET,
			label: 'Cognito Client Secret',
			helpText: 'Optional. Leave blank if no secret is generated for this client',
			type: ProviderConfigProperty.STRING_TYPE,
			defaultValue: '',
			secret: true,
		});

		add({
			name: WEBHOOK_AUTH_HEADER,
			label: 'Webhook Authorization Header',
			helpText: 'Optional. Example: "Bearer MyToken"',
			type: ProviderConfigProperty.STRING_TYPE,
			defaultValue: '',
			secret: true,
		});

		add({
			name: WEBHOOK_ON_ACCOUNT_CREATED,
			label: 'Webhook (On Account Created)',
			helpText: 'Optional. ',
			type: ProviderConfigProperty.STRING_TYPE,
			defaultValue: '',
			secret: false,
		});

		add({
			name: WEBHOOK_ON_CREDENTIALS_MIGRATED,
			label: 'Webhook (On Credentials Migrated)',
			helpText: 'Optional. ',
			type: ProviderConfigProperty.STRING_TYPE,
			defaultValue: '',
			secret: false,
		});

		return list;
	}

	public function validateConfiguration(session:KeycloakSession, realm:RealmModel, model:ComponentModel) {
		final config = model.getConfig();

		inline function ensure(name:String) {
			switch config.getFirst(name) {
				case null | '':
					// WORKAROUND: the second param is for https://github.com/HaxeFoundation/haxe/issues/10380
					throw new ComponentValidationException('Missing Configuration: $name', name);
				case _:
					// ok
			}
		}

		ensure(AWS_ACCESS_KEY_ID);
		ensure(AWS_SECRET_ACCESS_KEY);
		ensure(AWS_REGION);
		ensure(COGNITO_CLIENT_ID);
		ensure(COGNITO_USER_POOL_ID);
	}

	public function getHelpText():String {
		return 'Migrate Cognito Users';
	}

	public function getId():String {
		return 'cognito-migration';
	}

	public function close() {}

	public overload function create(session:KeycloakSession):UserStorageProvider {
		// default method:
		// https://github.com/keycloak/keycloak/blob/cd342ad5714f15db1cc8b0cd55b788e6543c6dc8/server-spi/src/main/java/org/keycloak/component/ComponentFactory.java#L39
		// haxe bug tracker: https://github.com/HaxeFoundation/haxe/issues/10328
		return null;
	}

	public overload function create(session:KeycloakSession, model:ComponentModel):CognitoMigrationUserStorageProvider {
		return new CognitoMigrationUserStorageProvider(session, model, getCognito(model), getWebhooks(model));
	}

	public function order():Int {
		return 0;
	}

	public function init(config:Config_Scope) {}

	public function postInit(param1:KeycloakSessionFactory) {}

	public function getCommonProviderConfigProperties():java.util.List<ProviderConfigProperty> {
		// default method:
		// https://github.com/keycloak/keycloak/blob/cd342ad5714f15db1cc8b0cd55b788e6543c6dc8/server-spi/src/main/java/org/keycloak/storage/UserStorageProviderFactory.java#L110
		// haxe bug tracker: https://github.com/HaxeFoundation/haxe/issues/10328
		return UserStorageProviderSpi.commonConfig();
	}

	public function getTypeMetadata():java.util.Map<String, Dynamic> {
		// default method:
		// https://github.com/keycloak/keycloak/blob/cd342ad5714f15db1cc8b0cd55b788e6543c6dc8/server-spi/src/main/java/org/keycloak/storage/UserStorageProviderFactory.java#L115-L120
		// haxe bug tracker: https://github.com/HaxeFoundation/haxe/issues/10328
		final metadata = new HashMap();
		if (Std.isOfType(this, ImportSynchronization))
			metadata.put("synchronizable", true);
		return metadata;
	}

	public function onCreate(session:KeycloakSession, realm:RealmModel, model:ComponentModel) {}

	public function onUpdate(session:KeycloakSession, realm:RealmModel, oldModel:ComponentModel, newModel:ComponentModel) {}

	public function preRemove(session:KeycloakSession, realm:RealmModel, model:ComponentModel) {}

	public function getOperationalInfo():java.util.Map<String, String> {
		// These info will be shown in the Server Info page in admin console
		final info = new HashMap();
		final pom = Macro.readPomInfo();
		info.put('version', pom.version);
		info.put('website', pom.website);
		return info;
	}

	public function sync(sessionFactory:KeycloakSessionFactory, realmId:String, model:UserStorageProviderModel):SynchronizationResult {
		final cognito = getCognito(model);
		final webhooks = getWebhooks(model);
		final result = new SynchronizationResult();

		KeycloakModelUtils.runJobInTransaction(sessionFactory, new Adhoc<KeycloakSessionTask>(null, {
			run: (_, session:KeycloakSession) -> {
				CognitoMigrationUserStorageProvider.createUsersIfNotExist(
					session.userLocalStorage(),
					session.realms().getRealm(realmId),
					model,
					webhooks,
					cognito.list()
						.map(remote -> {
							username: remote.getUsername(),
							attributes: [for (attr in remote.getAttributes()) attr.getName() => attr.getValue()],
						}),
					result
				);
			}
		}));

		return result;
	}

	public function syncSince(lastSync:java.util.Date, sessionFactory:KeycloakSessionFactory, realmId:String,
			model:UserStorageProviderModel):SynchronizationResult {
		return sync(sessionFactory, realmId, model);
	}

	static function getCognito(model:ComponentModel) {
		return new Cognito({
			accessKeyId: model.getConfig().getFirst(AWS_ACCESS_KEY_ID),
			secretAccessKey: model.getConfig().getFirst(AWS_SECRET_ACCESS_KEY),
			region: model.getConfig().getFirst(AWS_REGION),
			userPoolId: model.getConfig().getFirst(COGNITO_USER_POOL_ID),
			clientId: model.getConfig().getFirst(COGNITO_CLIENT_ID),
			clientSecret: model.getConfig().getFirst(COGNITO_CLIENT_SECRET),
		});
	}

	static function getWebhooks(model:ComponentModel):Webhooks {
		return {
			auth: model.getConfig().getFirst(WEBHOOK_AUTH_HEADER),
			onAccountCreated: new Webhooks.Webhook(model.getConfig().getFirst(WEBHOOK_ON_ACCOUNT_CREATED)),
			onCredentialsMigrated: new Webhooks.Webhook(model.getConfig().getFirst(WEBHOOK_ON_CREDENTIALS_MIGRATED)),
		}
	}
}
