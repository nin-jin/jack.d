module jin.jack;

import std.stdio;
import jin.tree;
import std.file;
import std.conv;

class Jack {

	Tree hack( File code ) {
		return this.hack( Tree.parse( code ) );
	}

	Tree hack( string code , string uri = "" ) {
		return this.hack( Tree.parse( code , uri ) );
	}

	Tree hack( Tree code ) {
		auto jacks = [
			"test" : delegate( Tree node ) {
				if( node.length != 2 ) {
					throw new Exception( "supports only two arguments: " ~ node.uri );
				}
				auto one = this.hack( node[0] );
				auto two = this.hack( node[1] );
				if( one.to!string != two.to!string ) {
					throw new Exception( "test fail: " ~ node.uri );
				}
				return one;
			},
			"log" : delegate( Tree node ) {
				if( node.length != 1 ) {
					throw new Exception( "supports only one argument: " ~ node.uri );
				}
				auto res = this.hack( node[0] );
				res.pipe( stdout );
				return res;
			},
			"tree" : delegate( Tree node ) {
				return Tree.List( node.childs );
			},
			"head" : delegate( Tree node ) {
				if( node.length != 1 ) {
					throw new Exception( "supports only one argument: " ~ node.uri );
				}
				return this.hack( node[0] )[0];
			},
			"tail" : delegate( Tree node ) {
				if( node.length != 1 ) {
					throw new Exception( "supports only one argument: " ~ node.uri );
				}
				return this.hack( node[0] )[ $ - 1 ];
			},
			"" : delegate( Tree node ) {
				Tree[] childs = [];
				foreach( Tree child ; node.childs ) {
					auto res = this.hack( child );
					if( res.name ) {
						childs ~= res;
					} else {
						childs ~= res.childs;
					}
				}
				return node.clone( childs );
			},
		];

		if( code.name in jacks ) {
			return jacks[ code.name ]( code );
		}
		
		return jacks[ "" ]( code );
	}

}

unittest {
	auto jack = new Jack;
	auto res = jack.hack( File( "./examples/log.jack.tree" ) );
	res.pipe( stdout );
}
