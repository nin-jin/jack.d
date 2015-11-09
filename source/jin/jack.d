module jin.jack;

import std.stdio;
import std.file;
import std.conv;
import std.math;
import std.algorithm;
import std.functional;
import std.array;
import jin.tree;

struct Tools {
	Tree delegate( Tools , Tree )[ string ] handlers;
	alias handlers this;

	Tools opBinary( string op = "~" )( Tools addon ) {
		Tools tools;
		foreach( name , handler ; this ) {
			tools[ name ] = this[ name ];
		}
		foreach( name , handler ; addon ) {
			tools[ name ] = addon[ name ];
		}
		return tools;
	}
}

Tree jack( Tools tools , File code ) {
	return tools.jack( Tree.parse( code ) );
}

Tree jack( File code , Tools tools ) {
	return tools.jack( Tree.parse( code ) );
}

Tree jack( Tools tools , string code , string uri = "" ) {
	return tools.jack( Tree.parse( code , uri ) );
}

Tree jack( Tree code , Tools tools ) {
	return tools.jack( code );
}

Tree jack( Tools tools , Tree code ) {
	try {
		if( code.name in tools ) {
			return tools[ code.name ]( tools , code );
		}
		throw new Exception( "Unknown type [" ~ code.name ~ "]" );
		//return tools[ "" ]( tools , code );
	} catch( Throwable e ) {
		e.msg ~= "\n" ~ code.uri;
		throw e;
	}
}

static Tools[string] tools;
static this() {

	tools[ "base" ] = Tools( [
		"" : ( Tools tools , Tree code ) {
			Tree[] childs = [];
			foreach( Tree child ; code.childs ) {
				auto res = tools.jack( child );
				if( cast( TreeList ) res ) {
					childs ~= res.childs;
				} else {
					childs ~= res;
				}
			}
			return code.clone( childs );
		},
	] );

	tools[ "meta" ] = Tools( [
		"name" : ( Tools tools , Tree code ) {
			code = tools[""]( tools , code );
			return Tree.List( code.childs.map!( child => Tree.Value( child.name ) ).array );
		},
		"tree" : ( Tools tools , Tree code ) {
			return Tree.List( code.childs );
		},
		"make" : ( Tools tools , Tree code ) {
			auto name = tools[""]( tools , code[ "name" ][0] );
			auto childs = tools[""]( tools , code[ "child" ][0] );
			return Tree.Name( name.value , childs.childs );
		},
		"hide" : ( Tools tools , Tree code ) {
			return Tree.List([]);
		},
		"jack" : ( Tools tools , Tree code ) {
			Tools subTools;
			foreach( let ; code["let "].childs ) {
				subTools[ let.name ] = ( Tools tools , Tree code ) {
					tools = tools ~ Tools([
						"from" : ( Tools tools2 , Tree code2 ) {
							return Tree.List( tools[""]( tools2 , code ).childs );
						},
					]);
					return Tree.List( tools[""]( tools , let ).childs );
				};
			}
			code = tools[""]( tools ~ subTools, code );
			code = tools[""]( tools ~ subTools , code );
			return Tree.List( code.childs );
		},
		"let" : ( Tools tools , Tree code ) {
			return Tree.List([]);
		}
	] );

	tools[ "list" ] = Tools( [
		"head" : ( Tools tools , Tree code ) {
			code = tools[""]( tools , code );
			return code[0];
		},
		"tail" : ( Tools tools , Tree code ) {
			code = tools[""]( tools , code );
			return code[ $ - 1 ];
		},
		"cut-head" : ( Tools tools , Tree code ) {
			code = tools[""]( tools , code );
			return Tree.List( code[ 1 .. $ ] );
		},
		"cut-tail" : ( Tools tools , Tree code ) {
			code = tools[""]( tools , code );
			return Tree.List( code[ 0 .. $ - 1 ] );
		},
	] );

	tools[ "test" ] = Tools( [
		"test" : ( Tools tools , Tree code ) {
			auto cases = code[ "case" ];
			auto one = tools[""]( tools , cases[0] ).rename( "result" );
			auto two = tools[""]( tools , cases[1] ).rename( "result" );
			auto name = code[ "name" ];
			if( one.to!string != two.to!string ) {
				throw new Exception( "Test fail: " ~ name.to!string ~ one.to!string ~ two.to!string ~ "----------------" );
			}
			return Tree.List([]); //code.clone( name.childs ~ cases.childs ~ [ one ] );
		},
		"log" : ( Tools tools , Tree code ) {
			code = Tree.List( tools[""]( tools , code ).childs );
			code.pipe( stdout );
			return code;
		},
	] );

	tools[ "logic" ] = Tools( [
		"true" : ( Tools tools , Tree code ) {
			return code;
		},
		"false" : ( Tools tools , Tree code ) {
			return code;
		},
		"false?" : ( Tools tools , Tree code ) {
			auto list = tools[""]( tools , code );
			return Tree.List( list.childs.map!( ( child ){
				return Tree.Name( child.name == "true" ? "false" : "true" );
			} ).array );
		},
		"every?" : ( Tools tools , Tree code ) {
			auto list = tools[""]( tools , code );
			foreach( item ; list.childs ) {
				if( item.name == "false" ) return Tree.Name( "false" );
			}
			return Tree.Name( "true" );
		},
		"some?" : ( Tools tools , Tree code ) {
			auto list = tools[""]( tools , code );
			foreach( item ; list.childs ) {
				if( item.name == "true" ) return Tree.Name( "true" );
			}
			return Tree.Name( "false" );
		},
		"order?" : ( Tools tools , Tree code ) {
			auto list = tools[""]( tools , code );
			for( auto i = 0 ; i < list.length - 1 ; ++i ) {
				if( list[ i ].value > list[ i + 1 ].value ) return Tree.Name( "false" );
			}
			return Tree.Name( "true" );
		},
	] );

	tools[ "math" ] = Tools( [
		"int" : ( Tools tools , Tree code ) {
			return code;
		},
		"float" : ( Tools tools , Tree code ) {
			return code;
		},
	] );

	tools[ "all" ] = tools[ "base" ] ~ tools[ "meta" ] ~ tools[ "list" ] ~ tools[ "logic" ] ~ tools[ "math" ] ~ tools[ "test" ];

}

unittest {
	File( "./examples/test.jack.tree" ).jack( tools[ "all" ] ).pipe( stdout );
}
