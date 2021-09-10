package com.beeinventor.keycloak;

import com.amazonaws.auth.AWSStaticCredentialsProvider;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.services.cognitoidp.AWSCognitoIdentityProvider;
import com.amazonaws.services.cognitoidp.AWSCognitoIdentityProviderClientBuilder;
import com.amazonaws.services.cognitoidp.model.AdminGetUserRequest;
import com.amazonaws.services.cognitoidp.model.AdminInitiateAuthRequest;
import com.amazonaws.services.cognitoidp.model.AuthFlowType;
import java.util.HashMap;

class Validator {
	
	final region:String;
	final userPoolId:String;
	final clientId:String;
	final clientSecret:String;
	
	final client:AWSCognitoIdentityProvider;
		
	public function new(config) {
		region = config.region;
		userPoolId = config.userPoolId;
		clientId = config.clientId;
		clientSecret = config.clientSecret;
		
		client = AWSCognitoIdentityProviderClientBuilder
			.standard()
			.withRegion(region)
			.withCredentials(new AWSStaticCredentialsProvider(new BasicAWSCredentials(config.accessKeyId, config.secretAccessKey)))
			.build();
	}
	
	public function exists(username:String):Bool {
		return try {
			final result = get(username);
			result.getEnabled();
		} catch (ex) {
			false;
		}
	}
	
	public function validate(username:String, password:String) {
		return try {
			// checks if the password is correct
			auth(username, password);
			
			// get the user and return its id
			final result = get(username);
			
			var id = result.getUsername(); 
			var emailVerified = false;
			final attributes = new Map();
			
			for(attr in result.getUserAttributes()) {
				final value = attr.getValue();
				switch attr.getName() {
					case 'sub':
						id = value;
					case 'email_verified':
						emailVerified = value == 'true';
					case key:
						attributes[key] = value;
				}
			}
				
			{id: id, emailVerified: emailVerified, attributes: attributes}
			
		} catch (ex) {
			null;
		}
	}
	
	function get(username:String) {
		return client.adminGetUser({
			new AdminGetUserRequest()
				.withUserPoolId(userPoolId)
				.withUsername(username);
		});
	}
	
	function auth(username:String, password:String) {
		return client.adminInitiateAuth({
			new AdminInitiateAuthRequest()
				.withUserPoolId(userPoolId)
				.withClientId(clientId)
				.withAuthFlow(AuthFlowType.ADMIN_USER_PASSWORD_AUTH) // NOTE: enable this flow in cognito console
				.withAuthParameters({
					final params = new HashMap();
					params.put('USERNAME', username);
					params.put('PASSWORD', password);
					switch clientSecret {
						case null | '': // skip
						case _: params.put('SECRET_HASH', clientSecret);
					}
					params;
				});
		});
	}
}
