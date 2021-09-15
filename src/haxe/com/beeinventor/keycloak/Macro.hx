package com.beeinventor.keycloak;

import sys.io.File;

class Macro {
	public static macro function readPomInfo() {
		final content = File.getContent('pom.xml');
		final xml = new haxe.xml.Access(Xml.parse(content).firstElement());
		return macro $v{{
			version: xml.node.version.innerData,
			website: xml.node.scm.node.url.innerData,
		}};
	}
}