module jin.jack;

import std.stdio;
import std.file;
import std.conv;
import std.math;
import std.algorithm;
import std.array;
import jin.tree;

class Jack {

	Tree jack( File code ) {
		return this.jack( Tree.parse( code ) );
	}

	Tree jack( string code , string uri = "" ) {
		return this.jack( Tree.parse( code , uri ) );
	}

	Tree jack( Tree code ) {
		auto jacks = [
			"test" : delegate( Tree node ) {
				if( node.length != 2 ) {
					throw new Exception( "Supports only two arguments" );
				}
				auto one = this.jack( node[0] );
				auto two = this.jack( node[1] );
				if( one.to!string != two.to!string ) {
					throw new Exception( "Test fail:\n" ~ one.to!string ~ two.to!string ~ "----------------" );
				}
				return one;
			},
			"log" : delegate( Tree node ) {
				if( node.length != 1 ) {
					throw new Exception( "Supports only one argument" );
				}
				auto res = this.jack( node[0] );
				res.pipe( stdout );
				return res;
			},
			"list" : delegate( Tree node ) {
				return node;
			},
			"jack" : delegate( Tree node ) {
				return this.jack( Tree.List( node[0].childs ) );
			},
			"head" : delegate( Tree node ) {
				if( node.length != 1 ) {
					throw new Exception( "Supports only one argument" );
				}
				return this.jack( node[0] )[0];
			},
			"tail" : delegate( Tree node ) {
				if( node.length != 1 ) {
					throw new Exception( "Supports only one argument" );
				}
				return this.jack( node[0] )[ $ - 1 ];
			},
			"summ" : delegate( Tree node ) {
				int res = 0;
				foreach( Tree child ; node.childs ) {
					res += this.jack( child ).value!int;
				}
				return Tree.Name( "int" , [ Tree.Value( res.to!string ) ] );
			},
			"abs" : delegate( Tree node ) {
				auto childs = node.childs.map!( ( child ) {
					return Tree.Name( "int" , [ Tree.Value( abs( child.value!int ).to!string ) ] );
				} ).array;
				return Tree.List( childs );
			},
			"" : delegate( Tree node ) {
				Tree[] childs = [];
				foreach( Tree child ; node.childs ) {
					auto res = this.jack( child );
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
	auto base = new Jack;
	auto res = base.jack( File( "./examples/test.jack.tree" ) );
	res.pipe( stdout );
}
