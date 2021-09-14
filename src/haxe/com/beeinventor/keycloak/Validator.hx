package com.beeinventor.keycloak;

import java.lang.Throwable;
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
			switch Std.downcast(cast ex, Throwable) {
				case null: // skip
				case e: e.printStackTrace();
			}
			false;
		}
	}
	
	public function validate(username:String, password:String) {
		return try {
			// checks if the password is correct
			auth(username, password);
			
			// get the user and return its id
			final result = get(username);
			final attributes = [
				'username' => result.getUsername(),
				'user_create_date' => formatDate(result.getUserCreateDate()),
				'user_last_modified_date' => formatDate(result.getUserLastModifiedDate()),
				'user_status' => result.getUserStatus(),
				'preferred_mfa_setting' => result.getPreferredMfaSetting(),
			];
			
			for(attr in result.getUserAttributes()) 
				attributes[attr.getName()] = attr.getValue();
				
			attributes;
			
		} catch (ex) {
			switch Std.downcast(cast ex, Throwable) {
				case null: // skip
				case e: e.printStackTrace();
			}
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
	
	function formatDate(date:java.util.Date) {
		final format = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
		format.setTimeZone(java.util.TimeZone.getTimeZone('UTC'));
		return format.format(date);
	}
}
