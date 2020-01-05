/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int left_parent=0;
%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
ASSIGN		<-
LE		<=
INT_CONST	[0-9]+
STR_CONST	\"(\\.|[^"\\])*\"	
%x str
%x comment
%x line_comment

%%

 /*
  *  Nested comments
  */

 /* 
 * error message for unmatch left/right pare
 * (* (*ccc *) class Main() -> ERROR "EOF in comment"
 * (* ccc*) *) -> ERROR "Unmatched *)"
 * must reset to INITIAL when handling EOF, or the flex will trigger the EOF rule infintely
  */
<INITIAL,comment>"(*"	{BEGIN(comment);left_parent++;}
<comment>"*)"	{
		left_parent--;
		if(left_parent==0){
			BEGIN(INITIAL);		
			}
		}
<comment><<EOF>>	{BEGIN(INITIAL);cool_yylval.error_msg = "EOF in comment";return ERROR;}
<comment>.	{}
<comment>\n	{curr_lineno++;}

<INITIAL>"--"	{BEGIN(line_comment);}
<line_comment>.	{}
<line_comment>\n	{BEGIN(INITIAL);curr_lineno++;}

"*)"	{cool_yylval.error_msg = "Unmatched *)";return ERROR;}

 /*
  *  The multiple-character operators.
  */

{ASSIGN}	{return (ASSIGN); }
{DARROW}	{ return (DARROW); }
{LE}	{ return (LE); }
	
 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class)	{return (CLASS);}
(?i:else)	{return (ELSE); }
(?i:if)	{return (IF); }
(?i:fi)	{return (FI); }
(?i:in)	{return (IN); }
(?i:inherits)	{return (INHERITS); }
(?i:let)	{return (LET); }
(?i:loop)	{return (LOOP); }
(?i:pool)	{return (POOL); }
(?i:then)	{return (THEN); }
(?i:while)	{return (WHILE); }
(?i:case)	{return (CASE); }
(?i:esac)	{return (ESAC); }
(?i:of)	{return (OF); }
(?i:new)	{return (NEW); }
(?i:isvoid)	{return (ISVOID); }
(?i:not)	{return (NOT); }
(?i:error)	{return (ERROR); }
(?i:let)	{return (LET_STMT); }

t(?i:rue) {cool_yylval.boolean=1;return (BOOL_CONST);}
f(?i:alse) {cool_yylval.boolean=0;return (BOOL_CONST);}


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

<INITIAL>\"	string_buf_ptr = string_buf;BEGIN(str);

<str>\" {
	BEGIN(INITIAL);
	if(string_buf_ptr >= string_buf + MAX_STR_CONST){
		cool_yylval.error_msg = "String constant too long";
		return ERROR;
	}
	char* buf_ptr = string_buf;
 	while(buf_ptr < string_buf_ptr)
	{
		if(*buf_ptr == '\0'){
 			cool_yylval.error_msg = "String contains null character";
			return ERROR;
		}
		buf_ptr++;
	}
	*string_buf_ptr = '\0';
	cool_yylval.symbol=stringtable.add_string(string_buf);return (STR_CONST);
	}

<str><<EOF>> {
	BEGIN(INITIAL);
	cool_yylval.error_msg = "EOF in string constant";
	return ERROR;
	}
<str>\n {
	/*only allow \\\n for multi-line string*/
	BEGIN(INITIAL);
	curr_lineno++;
	cool_yylval.error_msg = "Unterminated string constant";
	return ERROR;
	}

<str>\\n  *string_buf_ptr++ = '\n';
<str>\\t  *string_buf_ptr++ = '\t';
<str>\\b  *string_buf_ptr++ = '\b';
<str>\\f  *string_buf_ptr++ = '\f';

<str>\\\n *string_buf_ptr++ = yytext[1];curr_lineno++;
<str>\\. *string_buf_ptr++ = yytext[1];

<str>[^\\\n\"]	{
         *string_buf_ptr++ = yytext[0];
	}

 /*
 * OTHER rules
  */

[A-Z][a-zA-Z_0-9]*       {cool_yylval.symbol=idtable.add_string(yytext);return (TYPEID);} 
[a-z][a-zA-Z_0-9]*      {cool_yylval.symbol=idtable.add_string(yytext);return (OBJECTID);} 
[0-9]+	{cool_yylval.symbol=inttable.add_string(yytext);return (INT_CONST);}

[+/\-\*=<\.\~,;:()@{}]	{return (yytext[0]);}
\n	{curr_lineno++;}
[ \t\r\f\v]+	{}

.	{cool_yylval.error_msg=yytext;return ERROR;}

%%
