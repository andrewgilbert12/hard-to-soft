 /* to compile this file: lex tokenizer.l && gcc yy.lex.c -o tokenizer */
 /* run by passing file to be tokenized as stdin: ./tokenizer <INFILE >OUTFILE */
letter [A-Za-z]
whitespace [ \t\n]
comment "//"[^\n]*"\n"
block-comment-start "/*""*"?
block-comment-end "*/"

%s initial
%x comment

%{
#include <stdio.h>
#include <stdlib.h>
%}

%%

{block-comment-start} BEGIN(comment); /* enter comment start condition */
<comment>{block-comment-end} BEGIN(initial); /* return to normal */
<comment>. ; /* ignore everything until we hit the end of our block comment */

{whitespace}|{comment} ; /* skip whitespace and comments */

"class"|"constructor"|"function"|"method"|"field"|"static"|"var"|"int"|"char"|"boolean"|"void"|"true"|"false"|"null"|"this"|"let"|"do"|"if"|"else"|"while"|"return" {
 printf("\t<keyword>%s</keyword>\n", yytext);
 }						    

"{"|"}"|"("|")"|"["|"]"|"."|","|";"|"+"|"-"|"*"|"/"|"|"|"="|"~" {
 printf("\t<symbol>%c</symbol>\n", *yytext);
 }

"<" {
 printf("\t<symbol>&lt;</symbol>\n");
 }

">" {
 printf("\t<symbol>&gt;</symbol>\n");
 }

"&" {
 printf("\t<symbol>&amp;</symbol>\n");
 }

"\"" {
 printf("\t<symbol>&quot;</symbol>\n");
 }

[0-9]+ {
 printf("\t<integerConstant>%s</integerConstant>\n", yytext);
 } /* max of 32767 */

{letter}({letter}|[0-9])*  {
 printf("\t<identifier>%s</identifier>\n", yytext);
 }

\"[^"\n]*\" {
 yytext[yyleng-2] = 0;
 printf("\t<stringConstant>%s</stringConstant>\n", yytext);
 }

%%

int yywrap() {
 return 1;
}

int main(void) {
  printf("<tokens>\n");
  yylex();
  printf("</tokens>\n");
}
