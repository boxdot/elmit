/* Parse simple html with embedded elm */

%lex
%x tag com hb arg argval

letter      [a-zA-Z]
digit       [0-9]
namechar    {digit}|{letter}|"."|"-"|"_"|":"
name        ({letter}|"_"|":"){namechar}*
elmname     ({letter}|"_")({letter}|{digit}|"_")*

LEFT_STRIP    "~"
RIGHT_STRIP   "~"

LOOKAHEAD           [=~}\s\/.)|]
LITERAL_LOOKAHEAD   [~}\s)]

ID    [^\s!"#%-,\.\/;->@\[-\^`\{-~]+/{LOOKAHEAD}

%%

<INITIAL,tag,hb>\s+    /* skip whitespace */
<<EOF>>             return 'EOF';

/* Strip Comments */
/* TODO: maybe we should leave them? */
"<!--"              { this.begin('com');  return 'OPENCOM';  }
<com>"-->"          { this.popState();    return 'CLOSECOM'; }
<com>[\s\S]*?(?=\-\-\>)  return "BODYCOM";

"</"                { this.begin('tag'); return 'OPENETAG';  }
"<"                 { this.begin('tag'); return 'OPENBTAG';  }
<tag>"/>"           { this.popState();   return 'CLOSEBTAG'; }
<tag>">"            { this.popState();   return 'CLOSETAG';  }
<tag>{name}         return 'NAME';
<tag>"="            { this.begin('arg'); return 'EQ'; }
<arg>{name}         { this.popState(); return 'VALUE' };
<arg>"\""|"'"       { this.begin('argval'); return 'QUOT'; }
<argval>"\""|"'"    { this.popState(); this.popState(); return 'QUOT'; }
<argval>[^\"']+     { return 'VALUE';}

// handlebars lexer

[^\x00]*?/("{{")                 this.begin('hb');

<hb>"{{"{LEFT_STRIP}?">"         return 'OPEN_PARTIAL';
<hb>"{{"{LEFT_STRIP}?"#>"        return 'OPEN_PARTIAL_BLOCK';
<hb>"{{"{LEFT_STRIP}?"#""*"?     return 'OPEN_BLOCK';
<hb>"{{"{LEFT_STRIP}?"/"         return 'OPEN_ENDBLOCK';
<hb>"{{"{LEFT_STRIP}?"^"\s*{RIGHT_STRIP}?"}}"        this.popState(); return 'INVERSE';
<hb>"{{"{LEFT_STRIP}?\s*"else"\s*{RIGHT_STRIP}?"}}"  this.popState(); return 'INVERSE';
<hb>"{{"{LEFT_STRIP}?"^"         return 'OPEN_INVERSE';
<hb>"{{"{LEFT_STRIP}?\s*"else"   return 'OPEN_INVERSE_CHAIN';
<hb>"{{"{LEFT_STRIP}?"{"         return 'OPEN_UNESCAPED';
<hb>"{{"{LEFT_STRIP}?"&"         return 'OPEN';
<hb>"{{"{LEFT_STRIP}?"*"?        return 'OPEN';

<hb>"="                          return 'EQUALS';
<hb>".."                         return 'ID';
<hb>"."/{LOOKAHEAD}              return 'ID';
<hb>[\/.]                        return 'SEP';
<hb>\s+                          // ignore whitespace
<hb>"}"{RIGHT_STRIP}?"}}"        this.popState(); return 'CLOSE_UNESCAPED';
<hb>{RIGHT_STRIP}?"}}"           this.popState(); return 'CLOSE';
<hb>'"'("\\"["]|[^"])*'"'        return 'STRING';
<hb>"'"("\\"[']|[^'])*"'"        return 'STRING';
<hb>"@"                          return 'DATA';
<hb>"true"/{LITERAL_LOOKAHEAD}   return 'BOOLEAN';
<hb>"false"/{LITERAL_LOOKAHEAD}  return 'BOOLEAN';
<hb>"undefined"/{LITERAL_LOOKAHEAD} return 'UNDEFINED';
<hb>"null"/{LITERAL_LOOKAHEAD}   return 'NULL';
<hb>\-?[0-9]+(?:\.[0-9]+)?/{LITERAL_LOOKAHEAD} return 'NUMBER';
<hb>"as"\s+"|"                   return 'OPEN_BLOCK_PARAMS';
<hb>"|"                          return 'CLOSE_BLOCK_PARAMS';

<hb>{ID}                         return 'ID';

<hb>'['('\\]'|[^\]])*']'         return 'ID';
<hb>.                            return 'INVALID';

<INITIAL,hb><<EOF>>              return 'EOF';

[^<>{]+              return 'TEXT';

/lex

%start root
%ebnf
%%

root
    : content* EOF
        { return yy.List($1); }
    ;

content
    : tag -> $1
    | comment -> $1
    | TEXT -> yy.Text($1.replace(/^\s+|\s+$/g, ""))
    | statement -> { hb: $1 }
    ;

comment
    : OPENCOM BODYCOM? CLOSECOM -> yy.Comment($2 ? $2 : "")
    ;

tag
    : emptyTag -> $1
    | openTag (content*) closeTag
      {
        if ($1.tag != $3) {
          throw Error(
            "Non matching open and close tag: " + $1.tag + ", " + $3);
        }
        $$ = yy.Tag($1.tag, $1.attrs, yy.List($2))
      }
    ;

emptyTag
    : OPENBTAG NAME CLOSEBTAG -> yy.Tag($2, yy.Nil, yy.Nil)
    | OPENBTAG NAME attrs CLOSEBTAG -> yy.Tag($2, $3, yy.Nil)
    ;

openTag
    : OPENBTAG NAME CLOSETAG -> { tag: $2, attrs: yy.Nil }
    | OPENBTAG NAME attrs CLOSETAG -> { tag: $2, attrs: $3 }
    ;

closeTag
    : OPENETAG NAME CLOSETAG -> $2
    ;

attrs
    : attr -> yy.Cons($1, yy.Nil)
    | attr attrs -> yy.Cons($1, $2)
    ;

attr
    : NAME -> yy.Attr($1, yy.Nothing)
    | NAME EQ VALUE -> yy.Attr($1, yy.Just($3))
    | NAME EQ QUOT VALUE QUOT -> yy.Attr($1, yy.Just($4))
    ;

// handlebars

program
  : content* -> $1
  ;

statement
  : mustache -> $1
  | block -> $1
  | rawBlock -> $1
  | partial -> $1
  | partialBlock -> $1
  | COMMENT {
    $$ = {
      type: 'CommentStatement',
      value: $1,
      loc: @$
    };
  };

//rawBlock
//  : openRawBlock content+ END_RAW_BLOCK
//  ;

openRawBlock
  : OPEN_RAW_BLOCK helperName param* hash? CLOSE_RAW_BLOCK -> { path: $2, params: $3, hash: $4 }
  ;

block
  : openBlock program inverseChain? closeBlock
    { type: 'block', $$.children = $2; }
  | openInverse program inverseAndProgram? closeBlock -> $1
  ;

openBlock
  : OPEN_BLOCK helperName param* hash? blockParams? CLOSE
    -> { open: $1, path: $2, params: $3, hash: $4, blockParams: $5 }
  ;

openInverse
  : OPEN_INVERSE helperName param* hash? blockParams? CLOSE
    -> { path: $2, params: $3, hash: $4, blockParams: $5 }
  ;

openInverseChain
  : OPEN_INVERSE_CHAIN helperName param* hash? blockParams? CLOSE
    -> { path: $2, params: $3, hash: $4, blockParams: $5 }
  ;

inverseAndProgram
  : INVERSE program -> { program: $2 }
  ;

inverseChain
  : openInverseChain program inverseChain?
  | inverseAndProgram -> $1
  ;

closeBlock
  : OPEN_ENDBLOCK helperName CLOSE -> {path: $2}
  ;

mustache
  // Parsing out the '&' escape token at AST level saves ~500 bytes after min due to the removal of one parser node.
  // This also allows for handler unification as all mustache node instances can utilize the same handler
  : OPEN helperName param* hash? CLOSE
    -> { type: 'mustache', path: $2, params: $3, hash: $4 }
  | OPEN_UNESCAPED helperName param* hash? CLOSE_UNESCAPED -> yy.prepareMustache($2, $3, $4, $1, @$)
  ;

partial
  : OPEN_PARTIAL partialName param* hash? CLOSE {
    $$ = {
      type: 'PartialStatement',
      name: $2,
      params: $3,
      hash: $4,
      indent: '',
      loc: @$
    };
  }
  ;
partialBlock
  : openPartialBlock program closeBlock -> yy.preparePartialBlock($1, $2, $3, @$)
  ;
openPartialBlock
  : OPEN_PARTIAL_BLOCK partialName param* hash? CLOSE -> { path: $2, params: $3, hash: $4 }
  ;

param
  : helperName -> $1
  | sexpr -> $1
  ;

sexpr
  : OPEN_SEXPR helperName param* hash? CLOSE_SEXPR {
    $$ = {
      type: 'SubExpression',
      path: $2,
      params: $3,
      hash: $4,
      loc: yy.locInfo(@$)
    };
  };

hash
  : hashSegment+ -> {type: 'Hash', pairs: $1, loc: @$}
  ;

hashSegment
  : ID EQUALS param -> {type: 'HashPair', value: $3, loc: @$}
  ;

blockParams
  : OPEN_BLOCK_PARAMS ID+ CLOSE_BLOCK_PARAMS -> $2
  ;

helperName
  : path -> $1
  | dataName -> $1
  | STRING -> {type: 'StringLiteral', value: $1, original: $1, loc: yy.locInfo(@$)}
  | NUMBER -> {type: 'NumberLiteral', value: Number($1), original: Number($1), loc: yy.locInfo(@$)}
  | BOOLEAN -> {type: 'BooleanLiteral', value: $1 === 'true', original: $1 === 'true', loc: yy.locInfo(@$)}
  | UNDEFINED -> {type: 'UndefinedLiteral', original: undefined, value: undefined, loc: yy.locInfo(@$)}
  | NULL -> {type: 'NullLiteral', original: null, value: null, loc: yy.locInfo(@$)}
  ;

partialName
  : helperName -> $1
  | sexpr -> $1
  ;

dataName
  : DATA pathSegments
  ;

path
  : pathSegments
  ;

pathSegments
  : pathSegments SEP ID
    { $1.push({part: $3, original: $3, separator: $2 }); $$ = $1; }
  | ID -> [{part: $1, original: $1}]
  ;