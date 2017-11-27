letter [A-Za-z]
whitespace [ \t\n\r]
comment "//"[^\n]*"\n"
block-comment-start "/*""*"?
block-comment-end "*/"

 /* exclusive start pattern (x) is a flex-only feature */
%s initial
%x comment

%{
#include <stdio.h>
#include <stdlib.h>
#include "y.tab.h"
%}

%%

{block-comment-start} BEGIN(comment); /* enter comment start condition */
<comment>{block-comment-end} BEGIN(initial); /* return to normal */
<comment>. ; /* ignore everything until we hit the end of our block comment */

{whitespace}|{comment} ; /* skip whitespace and comments */

"class" {
    return K_CLASS;
 }

"constructor" {
    return K_CONSTRUCTOR;
 }

"function" {
    return K_FUNCTION;
 }

"method" {
    return K_METHOD;
 }

"field" {
    return K_FIELD;
 }

"static" {
    return K_STATIC;
 }

"var" {
    return K_VAR;
 }

"int" {
    return K_INT;
 }

"char" {
    return K_CHAR;
 }

"boolean" {
    return K_BOOLEAN;
 }

"void" {
    return K_VOID;
 }

"true" {
    return K_TRUE;
 }

"false" {
    return K_FALSE;
 }

"null" {
    return K_NULL;
 }

"this" {
    return K_THIS;
 }

"let" {
    return K_LET;
 }

"do" {
    return K_DO;
 }

"if" {
    return K_IF;
 }

"else" {
    return K_ELSE;
 }

"while" {
    return K_WHILE;
 }

"return" {
    return K_RETURN;
 }

"{" {
    return S_LBRACE;
 }

"}" {
    return S_RBRACE;
 }

"(" {
    return S_LPAREN;
 }

")" {
    return S_RPAREN;
 }

"[" {
    return S_LBRACKET;
 }

"]" {
    return S_RBRACKET;
 }

"." {
    return S_DOT;
 }

"," {
    return S_COMMA;
 }

";" {
    return S_SEMICOLON;
 }

"+" {
    return S_PLUS;
 }

"-" {
    return S_MINUS;
 }

"*" {
    return S_MULT;
 }

"/" {
    return S_DIV;
 }

"|" {
    return S_OR;
 }


"=" {
    return S_EQ;
 }


"~" {
    return S_NOT;
 }


"<" {
    return S_LT;
 }

">" {
    return S_GT;
 }

"&" {
    return S_AND;
 }

"\"" {
    return S_QUOT;
 }

"-"?[0-9]+ {
    yylval.number = atoi(yytext);
    return INTEGER;
 } /* max of 32767 */

\"[^"\n]*\" {
    yytext[yyleng-1] = 0;
    yylval.string = strdup(yytext+1);
    return STRING;
 }

{letter}({letter}|[0-9])*  {
    yylval.string = strdup(yytext);
    return IDENTIFIER;
 }

%%

int yywrap() {
 return 1;
 }
