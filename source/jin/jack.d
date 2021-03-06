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
	return tools.jack( new Tree( code ) );
}

Tree jack( File code , Tools tools ) {
	return tools.jack( new Tree( code ) );
}

Tree jack( Tools tools , string code , string uri = "" ) {
	return tools.jack( new Tree( code , uri ) );
}

Tree jack( Tree code , Tools tools ) {
	return tools.jack( code );
}

Tree jack( Tools tools , Tree code ) {
	try {
		if( code.name in tools ) {
			return tools[ code.name ]( tools , code );
		}
		//throw new Exception( "Unknown type [" ~ code.name ~ "]" );
		return tools[ "" ]( tools , code );
	} catch( Throwable e ) {
		e.msg ~= "\n" ~ code.uri ~ " " ~ code.name;
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
				if( res.name.length ) {
					childs ~= res;
				} else {
					childs ~= res.childs;
				}
			}
			return code.make( null , null , childs );
		},
	] );

	tools[ "meta" ] = Tools( [
		"name" : ( Tools tools , Tree code ) {
			code = tools[""]( tools , code );
			return new Tree( "" , "" , code.childs.map!( child => new Tree( "str" , child.name , [] ) ).array );
		},
		"tree" : ( Tools tools , Tree code ) {
			return new Tree( "" , "" , code.childs );
		},
		"make" : ( Tools tools , Tree code ) {
			auto name = tools[""]( tools , code[ "name" ][0] );
			auto value = tools[""]( tools , code[ "value" ][0] );
			auto childs = tools[""]( tools , code[ "child" ][0] );
			return new Tree( name.value , value.value , childs.childs );
		},
		"hide" : ( Tools tools , Tree code ) {
			return new Tree( "" , "" , [] );
		},
		"case" : ( Tools tools , Tree code ) {
			code = tools[""]( tools , code );
			return new Tree( "" , "" , code.childs.map!( child => new Tree( child.name ~ "!" , "" , [] ).jack( tools ) ).array );
		},
		"jack" : ( Tools tools , Tree code ) {
			Tools subTools;
			auto defTools = Tools([
				"inherit" : ( Tools tools2 , Tree code2 ) {
					subTools = tools ~ subTools;
					return new Tree( "" , "" , [] );
				},
				"let" : ( Tools tools2 , Tree code2 ) {
					foreach( let ; code2.childs ) {
						if( let.name in subTools )  throw new Exception( "Redeclaration [" ~ let.name ~ "]" );
						subTools[ let.name ] = ( Tools tools3 , Tree code3 ) {
							tools3 = tools3 ~ Tools([
								"from" : ( Tools tools4 , Tree code4 ) {
									return new Tree( "" , "" , tools[""]( tools4 , code3 ).childs );
								},
							]);
							return new Tree( "" , "" , tools[""]( tools3 , let ).childs );
						};
					}
					return new Tree( "" , "" , [] );
				},
			]);
			code = tools[""]( tools ~ defTools, code );
			code = tools[""]( subTools , code );
			return new Tree( "" , "" , code.childs );
		},
		"let" : ( Tools tools , Tree code ) {
			return new Tree( "" , "" , [] );
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
			return new Tree( "" , "" , code[ 1 .. $ ] );
		},
		"cut-tail" : ( Tools tools , Tree code ) {
			code = tools[""]( tools , code );
			return new Tree( "" , "" , code[ 0 .. $ - 1 ] );
		},
	] );

	tools[ "test" ] = Tools( [
		"test" : ( Tools tools , Tree code ) {
			auto cases = code[ "case" ];
			auto one = tools[""]( tools , cases[0] ).make( "result" );
			auto two = tools[""]( tools , cases[1] ).make( "result" );
			auto name = code[ "name" ];
			if( one.to!string != two.to!string ) {
				throw new Exception( "Test fail: " ~ name.to!string ~ one.to!string ~ two.to!string ~ "----------------" );
			}
			return new Tree( "" , "" , [] ); //code.clone( name.childs ~ cases.childs ~ [ one ] );
		},
		"log" : ( Tools tools , Tree code ) {
			code = new Tree( "" , "" , tools[""]( tools , code ).childs );
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
			return new Tree( "" , "" , list.childs.map!( ( child ){
				return new Tree( child.name == "true" ? "false" : "true" , "" , [] );
			} ).array );
		},
		"every?" : ( Tools tools , Tree code ) {
			auto list = tools[""]( tools , code );
			foreach( item ; list.childs ) {
				if( item.name == "false" ) return new Tree( "false" , "" , [] );
			}
			return new Tree( "true" , "" , [] );
		},
		"some?" : ( Tools tools , Tree code ) {
			auto list = tools[""]( tools , code );
			foreach( item ; list.childs ) {
				if( item.name == "true" ) return new Tree( "true" , "" , [] );
			}
			return new Tree( "false" , "" , [] );
		},
		"order?" : ( Tools tools , Tree code ) {
			auto list = tools[""]( tools , code );
			for( auto i = 0 ; i < list.length - 1 ; ++i ) {
				if( list[ i ].value > list[ i + 1 ].value ) return new Tree( "false" , "" , [] );
			}
			return new Tree( "true" , "" , [] );
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
