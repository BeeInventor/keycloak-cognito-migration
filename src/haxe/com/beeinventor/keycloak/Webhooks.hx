package com.beeinventor.keycloak;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.Json;
import java.net.HttpURLConnection;
import java.net.URL;

typedef Webhooks = {
	final ?auth:String;
	final ?onAccountCreated:Webhook<Array<UserPayload>>;
	final ?onCredentialsMigrated:Webhook<UserPayload>;
}

typedef WebhookHeader = {
	final name:String;
	final value:String;
}

typedef UserPayload = {
	final id:String;
	final attributes:Dynamic<String>;
}

abstract Webhook<Payload>(String) {
	public inline function new(v)
		this = v;
	
	public function invoke(method:String, headers:Array<WebhookHeader>, payload:Payload) {
		final url = new URL(this);
		final cnx:HttpURLConnection = cast url.openConnection();
		final data = Bytes.ofString(Json.stringify(payload));

		cnx.setRequestMethod(method);
		cnx.setRequestProperty('Content-Type', 'application/json');
		for(header in headers)
			cnx.setRequestProperty(header.name, header.value);
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
				while (true)
					switch body.read() {
						case -1: break;
						case v: buffer.addByte(v);
					}
				buffer.getBytes();
			}
		}
	}
}