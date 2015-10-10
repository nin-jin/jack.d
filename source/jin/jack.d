module jin.jack;

import std.stdio;
import std.file;
import std.conv;
import std.math;
import std.algorithm;
import std.array;
import jin.tree;

struct Tool {
	Tree function( Tool[ string ] , Tree ) handler;
	alias handler this;
}
alias Tools = Tool[ string ];

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
		return tools[ "" ]( tools , code );
	} catch( Throwable e ) {
		e.msg ~= "\n" ~ code.uri;
		throw e;
	}
}

Tools hack( Tools base , Tree function( Tools , Tree ) [ string ] addon ) {
	Tools tools;
	foreach( name , handler ; addon ) {
		tools[ name ] = Tool( addon[ name ] );
	}
	foreach( name , tool ; base ) {
		if( name in tools ) continue;
		tools[ name ] = tool;
	}
	return tools;
}

static Tools toolsEmpty = null;
static this() { toolsEmpty = [
	"" : Tool( ( Tools tools , Tree code ) {
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
	} ),
]; }

static Tools toolsAll = null;
static this() { toolsAll = toolsEmpty.hack([
	//"" : Tool( ( Tools tools , Tree code ) {
	//    try {
	//        return Tree.Name( "int" , Tree.Values([ code.name.to!int ]
	//                                              ) ); 
	//    } catch( Exception error ) {
	//        Tree[] childs = [];
	//        foreach( Tree child ; code.childs ) {
	//            auto res = tools.jack( child );
	//            if( res.name ) {
	//                childs ~= res;
	//            } else {
	//                childs ~= res.childs;
	//            }
	//        }
	//        return code.clone( childs );
	//    }
	//} ),
	"test" : ( Tools tools , Tree code ) {
		auto cases = code.select( "case" );
		auto one = tools[""]( tools , cases[0] ).rename( "result" );
		auto two = tools[""]( tools , cases[1] ).rename( "result" );
		auto name = code.select( "name" );
		if( one.to!string != two.to!string ) {
			throw new Exception( "Test fail: " ~ name.to!string ~ one.to!string ~ two.to!string ~ "----------------" );
		}
		return code.clone( name.childs ~ cases.childs ~ [ one ] );
	},
	"log" : ( Tools tools , Tree code ) {
		code = Tree.List( tools[""]( tools , code ).childs );
		code.pipe( stdout );
		return code;
	},
	"name" : ( Tools tools , Tree code ) {
		code = tools[""]( tools , code );
		return Tree.List( code.childs.map!( child => Tree.Value( child.name ) ).array );
	},
	"tree" : ( Tools tools , Tree code ) {
		return Tree.List( code.childs );
	},
	"make" : ( Tools tools , Tree code ) {
		auto name = tools[""]( tools , code.select( "name" )[0] );
		auto childs = tools[""]( tools , code.select( "child" )[0] );
		return Tree.Name( name.value , childs.childs );
	},
	"hide" : ( Tools tools , Tree code ) {
		return Tree.List([]);
	},
	"jack" : ( Tools tools , Tree code ) {
		code = tools[""]( tools , code );
		code = tools[""]( tools , code );
		return Tree.List( code.childs );
	},
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
		return Tree.List( code[ 0 .. $ - 1 ] );
	},
]); }

unittest {
	File( "./examples/test.jack.tree" ).jack( toolsAll ).pipe( stdout );
	//Tree.Value( 123 ).pipe( stdout );
}
