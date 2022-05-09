%{
	#include <stdio.h>
	#define LIST     strcat(buf,yytext)
	#define token(t) {LIST; printf("<%s>\n",t);}
	#define tokenInteger(t,i) {LIST; printf("<%s:%d>\n",#t,i);}
	#define tokenString(t,s) {LIST; printf("<%s:%s>\n",#t,s);}

	#define MAX_LINE_LENG 256
	#define SYMTABLE_SIZE 20
	#define NIL -1

	typedef struct s{
		char* name;
		struct s* next;
	}* symbol;


	void create();
	int hash(char* c);
	int lookup(char* c);
	int insert(char* c);
	void dump();

	symbol* symtable = NULL;
	int linenum = 1;
	char c[2] = {'0', '\0'};
	char buf[MAX_LINE_LENG];
%}

%%
"(" {token("'('");}
")"	{token("')'");}
","	{token("','");}
":"	{token("':'");}
"."	{token("'.'");}
";"	{token("';'");}
"["	{token("'['");}
"]"	{token("']'");}

"+"|"-"|"*"|"/"	{tokenString(Arithmetic_operator, yytext);}
"%"	{tokenString(Remainder_operator, yytext);}
"<"|"<="|">"|">="|"="|"/="	{tokenString(Relational_operator, yytext);}
"and"|"or"|"not"	{tokenString(Logical_operator, yytext);}
":="	{tokenString(Assignment_operator, yytext);}


"begin"|"boolean"|"break"|"character"|"case"|"continue"|"constant"|"declare"|"do"|"else"|"end"|"exit"|"float"|"for"|"if"|"in"|"integer"|"loop"|"print"|"println"|"procedure"|"program"|"return"|"string"|"while"|"then"	{
		int i = 0;
		char temp[MAX_LINE_LENG];
		for (; yytext[i] != '\0'; i++)
		{
			temp[i] = yytext[i] - 32;
		}
		temp[i] = '\0';
		token(temp);
	}

"true"|"false"	{tokenString(Boolean, yytext);}

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
		tokenString(String, str);
	}

[a-zA-Z][a-zA-Z0-9]*	{
		insert(yytext);
		tokenString(Identifier, yytext);
	}
[0-9]+[a-zA-Z][a-zA-z0-9]*	{
		LIST;
        printf("%d:%s\n", linenum+1, buf);
        printf("bad token:'%s'\n",yytext);
        exit(-1);
	}
[+-]?[0-9]+"."[0-9]+|[+-]?[0-9]+"."[0-9]+[Ee][+-]?[0-9]+	{
		tokenString(Real, yytext);
	}
	

[1-9][0-9]*	{
		int temp = 0;
		for (int i = 0; yytext[i] != '\0'; i++){
			temp =temp * 10 + (yytext[i] - '0');
		}
		tokenInteger(Integer, temp);
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

void create()
{
	symtable = (symbol*) malloc(sizeof(symbol) * SYMTABLE_SIZE);
	for(int i = 0; i < SYMTABLE_SIZE; i++)
	{
		symtable[i] = NULL;
	}
}

int hash(char* c)
{

	int key = 0;
	for(int i = 0; c[i] != '\0'; i++)
	{
		key = (key * 2 + (int)c[i]) % SYMTABLE_SIZE;
	}
	return key;
}

int lookup(char* c)
{
	int key = hash(c);
	symbol ptr1 = symtable[key];
	while(ptr1 != NULL)
	{
		if(strcmp(ptr1->name, c) == 0)return key;
		else ptr1 = ptr1->next;
	}
	return NIL;
}

int insert(char* c)
{
	int key = hash(c);
	if (symtable[key] == NULL)
	{

		symtable[key] = malloc(sizeof(struct s));
		symtable[key]->name = malloc(sizeof(char) * yyleng);
		strcpy(symtable[key]->name, c);
		symtable[key]->next = NULL;
		return key;
	}
	symbol ptr1 = symtable[key]->next;
	symbol ptr2 = symtable[key];
	if(strcmp(ptr2->name, c) == 0)return key;
	while(ptr1 != NULL)
	{
		ptr2 = ptr1;
		ptr1 = ptr1->next;
		if(strcmp(ptr2->name, c) == 0)return key;
	}
	ptr1 = malloc(sizeof(struct s));
	ptr1->name = malloc(sizeof(char) * yyleng);
	strcpy(ptr1->name, c);
	ptr1->next = NULL;
	ptr2->next = ptr1;
	return key;
}
void dump()
{

	printf("\nSymbolTable:\n");
	for(int i = 0; i < SYMTABLE_SIZE; i++)
	{
		symbol ptr1 = symtable[i];
		symbol ptr2 = symtable[i];
		if(ptr1 == NULL)continue;
		printf("key:%d\t", i);
		while(ptr1 != NULL)
		{
			printf("%s, ", ptr1->name);
			ptr2 = ptr2->next;
			free(ptr1);
			ptr1 = ptr2;
		}
		printf("\n");
	}
	free(symtable);
	return;
}

void main(int argc, char** argv)
{
	
	FILE    *fptr;
	create();
	if(argc == 2)
	{
        	if (!(fptr = fopen("input.txt", "r")))
        	{
            	printf("Can't find the file.");
            	return;
        	}
        yyin = fptr;
	yylex();
        fclose(fptr);
	}
        else{yylex();}
 
	dump();
}
		
