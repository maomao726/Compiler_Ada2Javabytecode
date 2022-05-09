%{
	#include <stdio.h>
	#include <stdbool.h>
	#include <string.h>
	#include "header.h"
	#include "y.tab.h"

	#define LIST     strcat(buf,yytext)
	#define token(t) {LIST; printf("<%s>\n",t);}
	#define tokenInteger(t,i) {LIST; printf("<%s:%d>\n",#t,i);}
	#define tokenString(t,s) {LIST; printf("<%s:%s>\n",#t,s);}

	#define MAX_LINE_LENG 256
	#define NIL -1

	extern YYSTYPE yylval;
	int linenum = 1;






	char c[2] = {'0', '\0'};
	char buf[MAX_LINE_LENG];
%}

%%
"(" {LIST; return *yytext;}
")"	{LIST;  return *yytext;}
","	{LIST;  return *yytext;}
":"	{LIST;  return *yytext;}
"."	{LIST;  return *yytext;}
";"	{LIST;  return *yytext;}
"["	{LIST;  return *yytext;}
"]"	{LIST;  return *yytext;}

"+"|"-"|"*"|"/"	{LIST; return *yytext;}
"%"				{LIST; return *yytext;}
"<"				{LIST; return LT;}
">" 			{LIST; return MT;}
"<="			{LIST; return LE;}
"=>"			{LIST; return ME;}
"="				{LIST; return EQ;}
"/="			{LIST; return NE;}
"and"			{LIST; return AND;}
"or"			{LIST; return OR;}
"not"			{LIST; return NOT;}
":="			{LIST; return ASSIGN;}


"begin"		{LIST; return BEG;}
"boolean"	{LIST; return BOOLEAN;}
"break"		{LIST; return BREAK;}
"character"	{LIST; return CHARACTER;}
"case"		{LIST; return CASE;}
"continue"	{LIST; return CONTINUE;}
"constant"	{LIST; return CONSTANT;}
"declare"	{LIST; return DECLARE;}
"do"		{LIST; return DO;}
"else"		{LIST; return ELSE;}
"end"		{LIST; return END;}
"exit"		{LIST; return EXIT;}
"float"		{LIST; return FLOAT;}
"for"		{LIST; return FOR;}
"if"		{LIST; return IF;}
"in"		{LIST; return IN;}
"integer"	{LIST; return INTEGER;}
"loop"		{LIST; return LOOP;}
"print"		{LIST; return PRINT;}
"println"	{LIST; return PRINTLN;}
"procedure"	{LIST; return PROCEDURE;}
"program"	{LIST; return PROGRAM;}
"return"	{LIST; return RETURN;}
"string"	{LIST; return STRING;}
"while"		{LIST; return WHILE;}
"then"		{LIST; return THEN;}
"read"		{LIST; return READ;}

"true"		{LIST; yylval.value.booleanValue = true; return BVAL;}
"false"		{LIST; yylval.value.booleanValue = false; return BVAL;}

"\""	{
		LIST;
		char str[MAX_LINE_LENG] = "";
		c[0] = input();
		while(1)	{
			strcat(buf, c);
			if(c[0] == '"'){
				
				char temp = input();
				if (temp != '\"')
				{
					unput(temp);
					yytext[0] = '\0';
					break;
				}
				else
				{
					strcat(buf,"\"");

				}
			} 
			else if (c[0] == '\n'){
				printf("%d: %s\n", linenum++, buf);
				buf[0] = '\0';
			}
			strcat(str, c);
			c[0] = input();		
		}			
		yylval.value.stringValue = strdup(str);
		return SVAL;
	}

[a-zA-Z][a-zA-Z0-9]*	{
		LIST;
		yylval.value.stringValue = strdup(yytext);
		return IDENTIFIER;
	}
[0-9]+[a-zA-Z][a-zA-z0-9]*	{
		LIST;
        printf("%d:%s\n", linenum+1, buf);
        printf("bad token:'%s'\n",yytext);
        exit(-1);
	}
[+-]?[0-9]+"."[0-9]+|[+-]?[0-9]+"."[0-9]+[Ee][+-]?[0-9]+	{
		LIST;
		yylval.value.floatValue = atof(yytext);
		return FVAL;
	}
	

[1-9][0-9]*|"0"	{
		LIST;
		yylval.value.integerValue = atoi(yytext);
		return IVAL;
	}

"\n"    {
		LIST;
		printf("%d: %s\n", linenum++, buf);
		buf[0] = '\0';
		}

[ \t\r]*  {LIST;}

"{"	{
		LIST;
		c[0] = input();
		while(c[0] != '}'){
			strcat(buf,c);
			if (c[0] == '\n'){
					printf("%d: %s\n", linenum++, buf);
					buf[0] = '\0';
			}
			c[0] = input();
			}
		strcat(buf,c);
	}

"--"	{
		LIST;
		c[0] = input();
		while(c[0] != '\n'){
			strcat(buf,c);
			c[0] = input();
			}
		unput(c[0]);
	}
	

.   {
		LIST;
		printf("%d:%s\n", linenum+1, buf);
		printf("bad character:'%s'\n",yytext);
		exit(-1);
	}


%%



		
