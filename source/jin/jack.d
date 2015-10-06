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

Tree jack( Tools tools , Tree code ) {
	return code.jack( tools );
}

Tree jack( Tree code , Tools tools ) {
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
		if( name in addon ) continue;
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
			if( res.name ) {
				childs ~= res;
			} else {
				childs ~= res.childs;
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
		auto one = tools.jack( cases[0][0] );
		auto two = tools.jack( cases[1][0] );
		auto name = code.select( "name" );
		if( one.to!string != two.to!string ) {
			throw new Exception( "Test fail: " ~ name.to!string ~ one.to!string ~ two.to!string ~ "----------------" );
		}
		return code.clone( name.childs ~ cases.childs ~ [ Tree.Name( "result" , [ one ] ) ] );
	},
	"log" : ( Tools tools , Tree code ) {
		if( code.length != 1 ) {
			throw new Exception( "Supports only one argument" );
		}
		auto res = tools.jack( code[0] );
		res.pipe( stdout );
		return res;
	},
	"list" : ( Tools tools , Tree code ) {
		return Tree.List( code.childs );
	},
	"jack" : ( Tools tools , Tree code ) {
		return tools.jack( Tree.List( code[0].childs ) );
	},
	"head" : ( Tools tools , Tree code ) {
		if( code.length != 1 ) {
			throw new Exception( "Supports only one argument" );
		}
		return tools.jack( code[0] )[0];
	},
	"tail" : ( Tools tools , Tree code ) {
		if( code.length != 1 ) {
			throw new Exception( "Supports only one argument" );
		}
		return tools.jack( code[0] )[ $ - 1 ];
	},
	"summ" : ( Tools tools , Tree code ) {
		int res = 0;
		foreach( Tree child ; code.childs ) {
			res += tools.jack( child ).name.to!int;
		}
		return Tree.Name( res.to!string );
	},
	"abs" : ( Tools tools , Tree code ) {
		return Tree.Name( abs( code[0].name.to!int ).to!string );
	},
]); }

unittest {
	File( "./examples/test.jack.tree" ).jack( toolsAll ).pipe( stdout );
	//Tree.Value( 123 ).pipe( stdout );
}
