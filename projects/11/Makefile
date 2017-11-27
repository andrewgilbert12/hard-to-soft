compiler: jack.l jack.y
	lex jack.l
	yacc -d jack.y
	gcc lex.yy.c y.tab.c -o compiler
