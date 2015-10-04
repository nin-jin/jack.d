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
					throw new Exception( "Supports only two arguments" );
				}
				auto one = this.hack( node[0] );
				auto two = this.hack( node[1] );
				if( one.to!string != two.to!string ) {
					throw new Exception( "Test fail" );
				}
				return one;
			},
			"log" : delegate( Tree node ) {
				if( node.length != 1 ) {
					throw new Exception( "Supports only one argument " );
				}
				auto res = this.hack( node[0] );
				res.pipe( stdout );
				return res;
			},
			"list" : delegate( Tree node ) {
				return node;
			},
			"jack" : delegate( Tree node ) {
				return this.hack( Tree.List( node[0].childs ) );
			},
			"head" : delegate( Tree node ) {
				if( node.length != 1 ) {
					throw new Exception( "Supports only one argument" );
				}
				return this.hack( node[0] )[0];
			},
			"tail" : delegate( Tree node ) {
				if( node.length != 1 ) {
					throw new Exception( "Supports only one argument" );
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

		try {
			if( code.name in jacks ) {
				return jacks[ code.name ]( code );
			}
			return jacks[ "" ]( code );
		} catch( Throwable e ) {
			e.msg ~= "\n" ~ code.uri;
			throw e;
		}
	}

}

unittest {
	auto jack = new Jack;
	auto test = Tree.parse( File( "./examples/test.jack.tree" ) );
	auto res = jack.hack( test );
}
