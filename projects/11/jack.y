%{
 #include <stdio.h>
 #include <stdlib.h> /* malloc */
 #include <string.h> /* strlen */

 enum var_extent {
   STATIC,
   FIELD,
   ARG,
   LOCAL
 };

 enum subroutine_type {
   CONSTRUCTOR,
   FUNCTION,
   METHOD
 };

 enum var_type {
   VOID,
   PRIMITIVE,
   OBJECT
 };

 char *current_class_name;
 enum var_extent current_var_extent;
 char *current_var_type;

 enum subroutine_type current_subroutine_type;
 enum var_type current_subroutine_return_type;
 char *current_subroutine_name;

 int current_subroutine_parameter_count;

 int if_count = 0;
 int while_count = 0;

 struct sym_table_entry {
    char *identifier;
    enum var_extent extent;
    char *type_name;
    int count;
 };

 #define MAX_VAR_COUNT 100

 typedef struct sym_table_entry sym_table_entry;
 typedef sym_table_entry sym_table[MAX_VAR_COUNT];

 /* we have only two levels of scope in Jack: class-level and subroutine-level. */
 static sym_table class_table;
 static sym_table subroutine_table;

 int class_table_size = 0;
 int subroutine_table_size = 0;

 /* forward declarations */
 int yylex ();
 void yyerror(char const *msg);

 int class_table_size_by_extent(sym_table table, const int table_size, enum var_extent extent);
 char *get_variable_name(char const *name);
 char *get_variable_type(char const *name);
 char *get_variable_name_by_table(char const *name, sym_table table, const int table_size);
 char *get_variable_type_by_table(char const *name, sym_table table, const int table_size);
 void add_var_to_table(char *identifier, sym_table table, int *table_size);
%}

%union {
    int number;
    char *string;
}

%token K_CLASS K_CONSTRUCTOR K_FUNCTION K_METHOD K_FIELD K_STATIC K_VAR K_INT K_CHAR K_BOOLEAN K_VOID K_TRUE K_FALSE K_NULL K_THIS K_LET K_DO K_IF K_ELSE K_WHILE K_RETURN;

%token S_LBRACE S_RBRACE S_LPAREN S_RPAREN S_LBRACKET S_RBRACKET S_DOT S_COMMA S_SEMICOLON S_PLUS S_MINUS S_MULT S_DIV S_OR S_EQ S_NOT S_LT S_GT S_AND S_QUOT;

%token <number> INTEGER;
%token <string> STRING IDENTIFIER;

%type <number> startIf startWhile ifBlock;
%type <string> op unaryOp subroutineCallName subroutineCallNameInsideClass subroutineCallClassVarName primitiveType;

%%

 /* Every Jack file is a single class.
  All class fields and static variables are declared first, followed by subroutines. */
class:
 K_CLASS className S_LBRACE classVarDecs subroutineDecs S_RBRACE

className:
 IDENTIFIER {
    current_class_name = $1;
 }

classVarDecs: /* empty */
 | classVarDecs classVarDec

classVarDec:
 classVarDecExtent classVarDecType classVarDecNames S_SEMICOLON

classVarDecExtent:
 K_STATIC  { current_var_extent = STATIC; }
 | K_FIELD { current_var_extent = FIELD;  }

classVarDecType:
 IDENTIFIER { current_var_type = $1; }
 | primitiveType { current_var_type = $1; }

classVarDecNames:
 IDENTIFIER { add_var_to_table($1, class_table, &class_table_size); }
 | classVarDecNames S_COMMA IDENTIFIER { add_var_to_table($3, class_table, &class_table_size); }


 /* A single Jack class can have multiple subroutines. These can be constructors, methods (which take an implicit this), or functions. */
subroutineDecs: /* empty */
 | subroutineDecs subroutineDec

subroutineDec:
 subroutineType subroutineReturnType subroutineName S_LPAREN parameterList S_RPAREN subroutineBody {
      subroutine_table_size = 0;
 }

subroutineType:
 K_CONSTRUCTOR { current_subroutine_type = CONSTRUCTOR; }
 | K_FUNCTION { current_subroutine_type = FUNCTION; }
 | K_METHOD {
    current_subroutine_type = METHOD;

    /* For methods, push an implicit 'this' to the stack. */
    current_var_extent = ARG;
    current_var_type = "";
    add_var_to_table("this", subroutine_table, &subroutine_table_size);
 }

subroutineReturnType:
 K_VOID
 | IDENTIFIER
 | primitiveType

subroutineName:
 IDENTIFIER {
    current_subroutine_name = $1;
 }

parameterList: /* empty */
 | nonEmptyParameterList

nonEmptyParameterList:
 parameter
 | nonEmptyParameterList S_COMMA parameter

parameter:
 parameterType parameterName

parameterType:
 IDENTIFIER {
    current_var_extent = ARG;
    current_var_type = $1;
 }
 | primitiveType {
    current_var_extent = ARG;
    current_var_type = $1;
 }

parameterName:
 IDENTIFIER {
    add_var_to_table($1, subroutine_table, &subroutine_table_size);
 }

subroutineBody:
 S_LBRACE subroutineVarDecs emitStartCode subroutineStatements S_RBRACE

emitStartCode:
 {
    /* emit function header, based on size of table, as it currently contains all the args */
    printf("function %s.%s %d\n", current_class_name, current_subroutine_name,
        class_table_size_by_extent(subroutine_table, subroutine_table_size, LOCAL));

    if (current_subroutine_type == CONSTRUCTOR) {
        /* allocate memory for class */
        printf("push constant %d\n", class_table_size_by_extent(class_table, class_table_size, FIELD));
        printf("call Memory.alloc 1\n");
        printf("pop pointer 0\n");
    } else if (current_subroutine_type == METHOD) {
        /* push the object to the 'this' position */
        printf("push argument 0\n");
        printf("pop pointer 0\n");
    }
 }

/* Similar to classes, Jack requires all variable declarations to come at the beginning of the subroutine. */
subroutineVarDecs: /* empty */
 | subroutineVarDecs K_VAR subroutineVarDecType subroutineVarDecNames S_SEMICOLON

subroutineVarDecType:
 IDENTIFIER {
    current_var_extent = LOCAL;
    current_var_type = $1;
 }
 | primitiveType {
    current_var_extent = LOCAL;
    current_var_type = $1;
 }

subroutineVarDecNames:
 subroutineVarDecName
 | subroutineVarDecNames S_COMMA subroutineVarDecName

subroutineVarDecName:
 IDENTIFIER {
    add_var_to_table($1, subroutine_table, &subroutine_table_size);
 }


/* statements */
subroutineStatements: /* empty */
 | subroutineStatements subroutineStatement

subroutineStatement:
 letStatement
 | ifStatement
 | whileStatement
 | doStatement
 | returnStatement

letStatement:
 K_LET IDENTIFIER S_EQ expression S_SEMICOLON {
    /* handle direct assignment (expression result we assign is top of stack) */
    printf("pop %s\n", get_variable_name($2));
 }
 | K_LET IDENTIFIER S_LBRACKET expression S_RBRACKET S_EQ expression S_SEMICOLON {
    /* handle indexed assignment (expression result we assign is top of stack) */
    printf("pop temp 0\n");
    printf("push %s\n", get_variable_name($2));
    printf("add\n");
    printf("pop pointer 1\n");
    printf("push temp 0\n");
    printf("pop that 0\n");
 }

ifStatement:
 ifBlock elseStatement {
    printf("label IF_END%d\n", $1);
 }

ifBlock:
 K_IF S_LPAREN expression S_RPAREN startIf subroutineStatements S_RBRACE {
    printf("goto IF_END%d\n", $5);
    printf("label IF_FALSE%d\n", $5);
    $$ = $5;
 }

startIf:
 S_LBRACE {
    printf("if-goto IF_TRUE%d\n", if_count);
    printf("goto IF_FALSE%d\n", if_count);
    printf("label IF_TRUE%d\n", if_count);
    $$ = if_count++; /* allows for nested ifs by sending current value back to ifStatement */
 }

elseStatement: /* empty */
 | K_ELSE S_LBRACE subroutineStatements S_RBRACE

whileStatement:
 whileHead S_LPAREN expression S_RPAREN startWhile subroutineStatements S_RBRACE {
    printf("goto WHILE_EXP%d\n", $5);
    printf("label WHILE_END%d\n", $5);
 }

whileHead:
 K_WHILE {
    printf("label WHILE_EXP%d\n", while_count);
 }

startWhile:
 S_LBRACE {
    printf("not\n");
    printf("if-goto WHILE_END%d\n", while_count);
    $$ = while_count++;
 }

doStatement:
 K_DO subroutineCall S_SEMICOLON {
    printf("pop temp 0\n"); /* throw away the return value of the subroutine as we don't use it */
 }

subroutineCall:
 subroutineCallNameInsideClass S_LPAREN subroutineCallExpressionList S_RPAREN {
    printf("call %s.%s %d\n" , current_class_name, $1, current_subroutine_parameter_count);
 }
 | subroutineCallClassVarName S_DOT subroutineCallName S_LPAREN subroutineCallExpressionList S_RPAREN {
    printf("call %s.%s %d\n" , $1, $3, current_subroutine_parameter_count);
 }

subroutineCallNameInsideClass:
 IDENTIFIER {
    printf("push pointer 0\n"); /* we're calling a method from inside a class, so push 'this' as an argument */
    current_subroutine_parameter_count = 1;
    $$ = $1;
 }

subroutineCallName:
 IDENTIFIER {
    $$ = $1;
 }

subroutineCallClassVarName:
 IDENTIFIER {
    char *var_name;
    if (var_name = get_variable_name($1)) {
        /* if we have a method call, push the object itself to the stack */
        printf("push %s\n", var_name);
        current_subroutine_parameter_count = 1;
        $$ = get_variable_type($1);
    } else {
        /* else the identifier is a class name, so just output the class name */
        current_subroutine_parameter_count = 0;
        $$ = $1;
    }
 }

subroutineCallExpressionList: /* empty */
 | nonEmptySubroutineCallExpressionList

nonEmptySubroutineCallExpressionList:
 subroutineCallExpression
 | nonEmptySubroutineCallExpressionList S_COMMA subroutineCallExpression

subroutineCallExpression:
 expression {
    current_subroutine_parameter_count++;
 }

returnStatement:
 K_RETURN returnExpression S_SEMICOLON {
    printf("return\n");
 }

returnExpression: /* empty */ {
    /* push a junk value for return void */
    printf("push constant 0\n");
 }
 | expression

/* expressions */
expression:
 term expressionRightSide

expressionRightSide: /* empty */
 | expressionRightSide op term {
    /* expressionRightSide has already been pushed,
       term is pushed in handling, now we add op to combine */
    printf("%s\n", $2);
 }

term:
 integerConstant /* handled inside */
 | stringConstant /* handled inside */
 | keywordConstant /* handled inside */
 | varNameInTerm /* handled inside */
 | varNameInTerm S_LBRACKET expression S_RBRACKET {
    /* varNameInTerm logic pushes varName value to stack,
       followed by expression pushing value we need to increment by,
       here we increment pointer with just an add statement,
       and dereference using the 'that' pointer. */
    printf("add\n");
    printf("pop pointer 1\n");
    printf("push that 0\n");
 }
 | subroutineCall /* handled inside*/
 | S_LPAREN expression S_RPAREN /* handled inside */
 | unaryOp term {
    /* term is handled and pushed to stack at this point */
    printf("%s\n", $1); /* unary op operates on result of term */
 }

integerConstant:
 INTEGER {
    if ($1 >= 32768 || $1 < -32768) {
        yyerror("Integer out of bounds!\n");
    } else if ($1 >= 0) {
        printf("push constant %d\n", $1);
    } else {
        printf("push constant %d\n", (-1 * $1));
        printf("neg\n");
    }
 }

stringConstant:
 STRING {
    /* create new string of length equal to length of string */
    printf("push constant %lu\n", strlen($1));
    printf("call String.new 1\n");
    /* for each char in string, call appendChar on new string */
    for (int i = 0; *($1 + i); i++){
        printf("push constant %d\n", *($1 + i));
        printf("call String.appendChar 2\n");
    }
    /* address of string will be top of stack at this point */
 }

keywordConstant:
 K_TRUE {
    printf("push constant 0\n");
    printf("not\n");
 }
 | K_FALSE {
    printf("push constant 0\n");
 }
 | K_NULL {
    printf("push constant 0\n");
 }
 | K_THIS {
    /* only used in 'return this' statement */
    printf("push pointer 0\n");
 }

varNameInTerm:
 IDENTIFIER {
    printf("push %s\n", get_variable_name($1));
 }

unaryOp:
 S_MINUS {
    $$ = "neg";
 }
 | S_NOT {
    $$ = "not";
 }

op:
 S_PLUS {
    $$ = "add";
 }
 | S_MINUS {
    $$ = "sub";
 }
 | S_MULT {
    $$ = "call Math.multiply 2"; /* use OS standard library */
 }
 | S_DIV {
    $$ = "call Math.divide 2"; /* use OS standard library */
 }
 | S_OR {
    $$ = "or";
 }
 | S_AND {
    $$ = "and";
 }
 | S_LT {
    $$ = "lt";
 }
 | S_GT {
    $$ = "gt";
 }
 | S_EQ {
    $$ = "eq";
 }

primitiveType:
 K_INT { $$ = "int"; }
 | K_CHAR { $$ = "char"; }
 | K_BOOLEAN { $$ = "boolean"; }

%%

char *get_variable_name(char const *name) {
    /* find variable in table, output its VM-level reference or return null pointer for undefined var */
    char *ret;

    if (ret = get_variable_name_by_table(name, subroutine_table, subroutine_table_size)) return ret;
    if (ret = get_variable_name_by_table(name, class_table, class_table_size)) return ret;

    return 0;
}

char *get_variable_name_by_table(char const *identifier, sym_table table, const int table_size) {
    sym_table_entry *curr_entry;

    static char ret[13];
    ret[0] = 0;

    char num[4] = {0};

    for (int i = 0; i < table_size; i++){
        curr_entry = &table[i];
        if (strcmp(curr_entry->identifier, identifier) == 0){
            switch (curr_entry->extent) {
                case STATIC: strcat(ret, "static"); break;
                case FIELD: strcat(ret, "this"); break;
                case ARG: strcat(ret, "argument"); break;
                case LOCAL: strcat(ret, "local"); break;
            }

            strcat(ret, " ");
            sprintf(num, "%d", curr_entry->count);
            strcat(ret, num);
            return ret;
        }
    }


    return 0;
}

char *get_variable_type(char const *name) {
    /* find variable in table, output its VM-level reference or return null for undefined var */
    char *ret;

    if (ret = get_variable_type_by_table(name, subroutine_table, subroutine_table_size)) return ret;
    if (ret = get_variable_type_by_table(name, class_table, class_table_size)) return ret;

    return 0;
}

char *get_variable_type_by_table(char const *identifier, sym_table table, const int table_size) {
    sym_table_entry *curr_entry;

    for (int i = 0; i < table_size; i++){
        curr_entry = &table[i];
        if (strcmp(curr_entry->identifier, identifier) == 0){
            return curr_entry->type_name;
        }
    }

    return 0;
}

int class_table_size_by_extent(sym_table table, const int table_size, enum var_extent extent) {
    int size = 0;
    sym_table_entry *curr_entry;

    for(int i = 0; i < table_size; i++) {
        curr_entry = &table[i];
        if (curr_entry->extent == extent) size++;
    }

    return size;
}

void add_var_to_table(char *identifier, sym_table table, int *table_size) {
    int count = 0;
    sym_table_entry *curr_entry;

    for (int i = 0; i < *table_size; i++) {
        curr_entry = &table[i];
        if (strcmp(curr_entry->identifier, identifier) == 0) {
            yyerror("Name already used...\n");
            return;
        }
        if (curr_entry->extent == current_var_extent) {
            count++;
        }
    }

    table[*table_size] = (sym_table_entry) {
       identifier,
       current_var_extent,
       current_var_type,
       count
    };

   (*table_size)++;
}

void yyerror(char const *msg){
    fprintf(stderr, "ERROR! %s\n", msg);
}

int main() {
    yyparse();

    return 0;
}
