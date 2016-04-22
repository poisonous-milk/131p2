/* File: parser.y
 * --------------
 * Bison input file to generate the parser for the compiler.
 *
 * pp2: your job is to write a parser that will construct the parse tree
 *      and if no parse errors were found, print it.  The parser should
 *      accept the language as described in specification, and as augmented
 *      in the pp2 handout.
 */

%{

/* Just like lex, the text within this first region delimited by %{ and %}
 * is assumed to be C/C++ code and will be copied verbatim to the y.tab.c
 * file ahead of the definitions of the yyparse() function. Add other header
 * file inclusions or C++ variable declarations/prototypes that are needed
 * by your code here.
 */
#include "scanner.h" // for yylex
#include "parser.h"
#include "errors.h"

void yyerror(const char *msg); // standard error-handling routine

%}

/* The section before the first %% is the Definitions section of the yacc
 * input file. Here is where you declare tokens and types, add precedence
 * and associativity options, and so on.
 */

/* yylval
 * ------
 * Here we define the type of the yylval global variable that is used by
 * the scanner to store attibute information about the token just scanned
 * and thus communicate that information to the parser.
 *
 * pp2: You will need to add new fields to this union as you add different
 *      attributes to your non-terminal symbols.
 */
%union {
    int integerConstant;
    bool boolConstant;
    float floatConstant;
    char identifier[MaxIdentLen+1]; // +1 for terminating null
    Decl * decl;
    FnDecl *fndecl;
    VarDecl * vardecl;
    Type * type;
    TypeQualifier *tq;
    Expr * expr;
    Stmt * stmt; 
    StmtBlock *stmtblock;
    List<Decl*> * declList;
    List<VarDecl*> * vdclist;
    List<Stmt*> *stmtList; 
}


/* Tokens
 * ------
 * Here we tell yacc about all the token types that we are using.
 * Bison will assign unique numbers to these and export the #define
 * in the generated y.tab.h header file.
 */
%token   T_Void T_Bool T_Int T_Float
%token   T_LessEqual T_GreaterEqual T_EQ T_NE T_LeftAngle T_RightAngle
%token   T_And T_Or
%token   T_Equal T_MulAssign T_DivAssign T_AddAssign T_SubAssign
%token   T_While T_For T_If T_Else T_Return T_Break
%token   T_Const T_Uniform T_Layout T_Continue T_Do
%token   T_Inc T_Dec T_Switch T_Case T_Default
%token   T_In T_Out T_InOut
%token   T_Mat2 T_Mat3 T_Mat4 T_Vec2 T_Vec3 T_Vec4
%token   T_Ivec2 T_Ivec3 T_Ivec4 T_Bvec2 T_Bvec3 T_Bvec4
%token   T_Uint T_Uvec2 T_Uvec3 T_Uvec4 T_Struct
%token   T_Semicolon T_Dot T_Colon T_Question T_Comma
%token   T_Dash T_Plus T_Star T_Slash
%token   T_LeftParen T_RightParen T_LeftBracket T_RightBracket T_LeftBrace T_RightBrace

%token   <identifier> T_Identifier
%token   <integerConstant> T_IntConstant
%token   <floatConstant> T_FloatConstant
%token   <boolConstant> T_BoolConstant

/* Non-terminal types
 * ------------------
 * In order for yacc to assign/access the correct field of $$, $1, we
 * must to declare which field is appropriate for the non-terminal.
 * As an example, this first type declaration establishes that the DeclList
 * non-terminal uses the field named "declList" in the yylval union. This
 * means that when we are setting $$ for a reduction for DeclList ore reading
 * $n which corresponds to a DeclList nonterminal we are accessing the field
 * of the union named "declList" which is of type List<Decl*>.
 * pp2: You'll need to add many of these of your own.
 */

%type <declList>  DeclList
%type <decl>      Decl
%type <vardecl>   VarDecl
%type <type>      TypeSpecifier
%type <tq>  	  TypeQualifier
%type <expr>	  Exp
%type <fndecl>	  FunctionPrototype
%type <fndecl>	  FunctionDeclarator
%type <fndecl>	  FunctionHeader
%type <fndecl>	  Function
%type <stmtblock> CompoundWithNoScope


%%
/* Rules
 * -----
 * All productions and actions should be placed between the start and stop
 * %% markers which delimit the Rules section.

 */
Program   :    DeclList     {
                                      @1;
                                      /* pp2: The @1 is needed to convince
                                       * yacc to set up yylloc. You can remove
                                       * it once you have other uses of @n*/
                                      Program *program = new Program($1);
                                      // if no errors, advance to next phase
                                      if (ReportError::NumErrors() == 0)
                                          program->Print(0);
                                    }
          ;

DeclList  	 :    DeclList Decl        { ($$=$1)->Append($2); }
		 |    Decl                 { ($$ = new List<Decl*>)->Append($1); }
          	 ;

Decl		:    VarDecl T_Semicolon{$$ = $1;}  
      		|    FunctionPrototype T_Semicolon {$$ = $1;}
		|    Function	{$$=$1;}					
          	;

Function	:    FunctionPrototype CompoundWithNoScope{($$=$1)->SetFunctionBody($2);}
	 	;

VarDecl		:	TypeSpecifier T_Identifier	
		{
			Identifier *i=new Identifier(@2,$2);
			$$=new VarDecl(i,$1);
		}
	 	| 	TypeSpecifier T_Identifier T_Equal Exp
		{
			Identifier *i=new Identifier(@2,$2);
			$$=new VarDecl(i,$1,$4);
		}
	  	|	TypeQualifier TypeSpecifier T_Identifier T_Equal Exp
		{
			Identifier *i=new Identifier(@3,$3);
			$$=new VarDecl(i,$2,$1,$5);
		}
		|	TypeQualifier TypeSpecifier T_Identifier T_LeftBracket Exp T_RightBracket
		{
			Identifier *i=new Identifier(@3,$3);
			Type * t=new ArrayType(@2,$2);
			$$=new VarDecl(i,t,$1);
		} 
		|	TypeSpecifier  T_Identifier T_LeftBracket Exp T_RightBracket
		{
			Identifier *i=new Identifier(@2,$2);
			Type * t=new ArrayType(@1,$1);
			$$=new VarDecl(i,t);
		}
	  	;

TypeQualifier	:	T_Const	{$$ = TypeQualifier::constTypeQualifier;}    
		|	T_In	{$$ = TypeQualifier::inTypeQualifier;} 
		|	T_Out	{$$ = TypeQualifier::outTypeQualifier;} 
		|	T_Uniform	{$$ = TypeQualifier::uniformTypeQualifier;} 
		;

TypeSpecifier   :	T_Void	{$$ = Type::voidType;}
	        |	T_Float	{$$ = Type::floatType;}
		|	T_Int	{$$ = Type::intType;}
		|	T_Uint	{$$ = Type::uintType;}  
            	|	T_Bool	{$$ = Type::boolType;}
            	|	T_Vec2	{$$ = Type::vec2Type;}
            	|	T_Vec3	{$$ = Type::vec3Type;}
            	|	T_Vec4	{$$ = Type::vec4Type;}
            	|	T_Bvec2	{$$ = Type::bvec2Type;}
            	|	T_Bvec3	{$$ = Type::bvec3Type;}
            	|	T_Bvec4	{$$ = Type::bvec4Type;}
            	|	T_Ivec2	{$$ = Type::ivec2Type;}
            	|	T_Ivec3	{$$ = Type::ivec3Type;}
            	|	T_Ivec4	{$$ = Type::ivec4Type;}
		|	T_Uvec2	{$$ = Type::uvec2Type;}
            	|	T_Uvec3	{$$ = Type::uvec3Type;}
            	|	T_Uvec4	{$$ = Type::uvec4Type;}		
            	|	T_Mat2	{$$ = Type::mat2Type;}
            	|	T_Mat3	{$$ = Type::mat3Type;}
            	|	T_Mat4	{$$ = Type::mat4Type;}
            	;

FunctionPrototype	:	FunctionDeclarator T_RightParen	{$$=$1;}
			;

FunctionDeclarator	:	FunctionHeader	{$$=$1;}	
  			/*|	FunctionHeadWithParam {$$=$1;}*/		   
			;

FunctionHeader		:	TypeSpecifier T_Identifier T_LeftParen 
			{
				Identifier* i=new Identifier(@2,$2);
				List<VarDecl*> *p=new List<VarDecl*>;
				$$=new FnDecl(i,$1,p);
			}
			;

CompoundWithNoScope	:	T_LeftBrace T_RightBrace
		    	{
				List<VarDecl*> *d=new List<VarDecl*>;
				List<Stmt*> *s=new List<Stmt*>;
				$$=new StmtBlock(d,s); 
			}
		    		
		    	;
Exp		:	T_IntConstant	{$$ = new IntConstant(@1, $1);}
     		|	T_FloatConstant	{$$ = new FloatConstant(@1, $1);}
		|	T_BoolConstant	{$$ = new BoolConstant(@1, $1);}
		|	T_LeftParen Exp T_RightParen	{$$=$2;}
		;
%%

/* The closing %% above marks the end of the Rules section and the beginning
 * of the User Subroutines section. All text from here to the end of the
 * file is copied verbatim to the end of the generated y.tab.c file.
 * This section is where you put definitions of helper functions.
 */

/* Function: InitParser
 * --------------------
 * This function will be called before any calls to yyparse().  It is designed
 * to give you an opportunity to do anything that must be done to initialize
 * the parser (set global variables, configure starting state, etc.). One
 * thing it already does for you is assign the value of the global variable
 * yydebug that controls whether yacc prints debugging information about
 * parser actions (shift/reduce) and contents of state stack during parser.
 * If set to false, no information is printed. Setting it to true will give
 * you a running trail that might be helpful when debugging your parser.
 * Please be sure the variable is set to false when submitting your final
 * version.
 */
void InitParser()
{
   PrintDebug("parser", "Initializing parser");
   yydebug = false;
}
