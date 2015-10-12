/* Parse simple html with embedded elm */

%lex
%x tag com hb arg argval

letter      [a-zA-Z]
digit       [0-9]
namechar    {digit}|{letter}|"."|"-"|"_"|":"
name        ({letter}|"_"|":"){namechar}*
elmname     ({letter}|"_")({letter}|{digit}|"_")*

%%

<INITIAL,tag>\s+    /* skip whitespace */
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
<argval>[^\"']+       return 'VALUE';

<INITIAL,tag>"{{"   { this.begin('hb'); return 'OPEN'; }
<hb>"}}"            { this.popState(); return 'CLOSE' }
<hb>{elmname}       { return 'ELMNAME'; }
<hb>"."             { return "."; }

[^<>{]+              return 'TEXT';

/lex

%start root
%ebnf
%%

root
    : content* EOF
        { return $1; }
    ;

content
    : tag -> $1
    | handlebars -> { hb: $1}
    | comment -> $1
    | TEXT -> { text: $1.replace(/^\s+|\s+$/g, "") }
    ;

comment
    : OPENCOM BODYCOM? CLOSECOM -> { comment: $2 || "" }
    ;

tag
    : emptyTag -> $1
    | openTag (content*) closeTag
        { $$ = $1; $1.children = $2; $1.closeTag = $3;
        }
    ;

emptyTag
    : OPENBTAG NAME CLOSEBTAG -> { tag: $2, attrs: [] }
    | OPENBTAG NAME attrs CLOSEBTAG -> { tag: $2, attrs: $3 }
    ;

openTag
    : OPENBTAG NAME CLOSETAG -> { tag: $2, attrs: [] }
    | OPENBTAG NAME attrs CLOSETAG -> { tag: $2, attrs: $3 }
    ;

closeTag
    : OPENETAG NAME CLOSETAG -> $2
    ;

attrs
    : attr -> [$1]
    | attrs attr
        { $$ = $1; $1.push($2); }
    ;

attr
    : NAME
    | NAME EQ VALUE -> { key: $1, value: $3 }
    | NAME EQ QUOT VALUE QUOT -> { key: $1, value: $4 }
    ;

// handlebars
handlebars
    : OPEN ELMNAME ('.' ELMNAME)* CLOSE -> { name: $2, tail: $1 + "." + $3 }
    ;