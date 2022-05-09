 %{
    #include <stdlib.h>
    #include <stdbool.h>
    #include <string.h>
    #include <stdio.h>
    #include "header.h"

    #define Trace(t)        printf(t)
    #define SYMTABLE_SIZE 20


    void yyerror(const char* msg)
    {
        fprintf(stderr, "Line %d ,ERROR: %s\n",linenum, msg);
    }

/* extern variable */
    extern FILE* yyin;

/* symbol type to string, use for printf */
    char* SymToStr(symtype s)
    {
        switch(s)
        {
            case Integer: return "int";
            case Float: return "float";
            case String: return "string";
            case Boolean: return "bool";
            case Procedure: return "Procedure";
            case Unknown: return "Unknown";
            case None: return "None";
            default: return "error";
        }
    }

/*type stack, use for type checking in expr */
    symtype typeStack[100];
    int typeTop = 0;

    symtype typepop()
    {
        if(typeTop == 0)
        {
            return None;
        }
        typeTop--;
        return typeStack[typeTop + 1];
    }

    void typepush(symtype s)
    {
        typeTop++;
        typeStack[typeTop] = s;
    }
         
/* procedure info */
   

    procInfo procList = NULL;

    procInfo insertProc(char* name)
    {
        procInfo temp ;
        if(procList == NULL)
        {
            procList = malloc(sizeof(struct proc_info));
            procList->procName = strdup(name);
            temp = procList;
        }
        else
        {
            temp = procList;
            while(temp->next != NULL)
            {
                if(temp->procName == name)
                {
                    yyerror("Procedure redefinition");
                    return NULL;
                }
                temp = temp->next;
            }
            temp->next = malloc(sizeof(struct proc_info));
            temp = temp->next;
            temp->procName = strdup(name);
        }
        temp->rt_type = None;
        temp->para_count = 0;
        temp->next = NULL;
        for(int i = 0; i < 100; i++)
        {
            temp->para_type[i] = None;
        }
        printf("insert a new process %s at %u\n", temp->procName, temp);
        return temp;
    }

    procInfo lookupProc(char* name)
    {
        procInfo temp = procList;

        while(temp != NULL)
        {
            if(strcmp(temp->procName, name) == 0)
            {
                return temp;
            }
            temp = temp->next;
        }
        yyerror("Can't find the procedure");
        printf("lookup a process %s at %u\n", temp->procName, temp);
        return NULL;
    }

    int addParaType(procInfo proc, symtype s)
    {
        if(proc->para_count == 100)
        {
            yyerror("Number of parameters is out of limit.");
            return 0;
        }
        proc->para_type[proc->para_count] = s;
        printf("add a new parameter , no.%d, type:%s in process %s\n", proc->para_count, SymToStr(s), proc->procName);
        proc->para_count++;
        return 1;

        
    }

    int checkParaType(procInfo proc, int index, symtype s)
    {
        if(proc->para_type[index] == s)
        {
            printf("Type match: (%s), (%s)\n", SymToStr(proc->para_type[index]), SymToStr(s));
            return 1;
        }
        else return 0;
    }    

/* symbol and symboltable */
    typedef struct s{
		char* name;
        bool is_const;
        bool is_array;
        symtype type;
        tokenValue value;
		struct s* next;
	}* symbol;

    typedef struct symtbl {
        symbol* table;
        struct symtbl* prev;
    }* symtbl_ptr;

    symtbl_ptr symtblstack_head = NULL;        /*symbol table's stack(use for scoping) */
    symtbl_ptr symtblstack_top = NULL;          /* top of the stack*/

 /* symboltable handling */
    symtbl_ptr create_symtbl()
    {
        
        symtbl_ptr ptr1 = malloc(sizeof(struct symtbl));
        ptr1->table = malloc(sizeof(symbol) * SYMTABLE_SIZE);
        for(int i = 0; i < SYMTABLE_SIZE; i++)
        {
            ptr1->table[i] = NULL;
        }
        ptr1->prev = NULL;
        printf("Create a new symbol table: %u\n",ptr1);
        return ptr1;
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
	symbol lookupsym(char* c)
    {
        int key = hash(c);
        symtbl_ptr tblptr = symtblstack_top;
        while(tblptr != NULL)
        {
            symbol symptr = tblptr->table[key];
            while(symptr != NULL)
            {
                
                if(strcmp(symptr->name, c) == 0)
                {
                    printf("Found %s, in table %u\n", symptr->name, tblptr);
                    return symptr;
                }
		        else symptr = symptr->next;
            }
            tblptr = tblptr->prev;
        }
        return NULL;
    }
	symbol insertsym(char* c)
    {
        if(strlen(c) == 0)
        {
            yyerror("Variable name is missed");
            return NULL;
        }
        int key = hash(c);
        if (symtblstack_top->table[key] == NULL)
        {
            symtblstack_top->table[key] = malloc(sizeof(struct s));
            symtblstack_top->table[key]->name = strdup(c);
            symtblstack_top->table[key]->next = NULL;
            printf("insert %s, in table %u\n", symtblstack_top->table[key]->name, symtblstack_top);
            return symtblstack_top->table[key];
        }
        else
        {
            symbol symptr = symtblstack_top->table[key];
            while(symptr->next != NULL)
            {
                if(strcmp(symptr->name, c) == 0)
                {
                    yyerror("Variable redeclaration");
                    return NULL;
                }
                symptr = symptr->next;
            }
            symbol temp = malloc(sizeof(struct s));
            temp->name = strdup(c);
            temp->next = NULL;
            symptr->next = temp;
            printf("insert %s, in table %u\n", temp->name, symtblstack_top);
            return temp;
        }
    }
	void dumpsymtbl(symbol* table)
    {
        printf("---dumping symbol table.---\n");
        for(int i = 0; i < SYMTABLE_SIZE; i++)
        {
            symbol ptr1 = table[i];
            symbol ptr2 = table[i];
            if(ptr1 == NULL)continue;
            printf("key:%d\t", i);
            while(ptr1 != NULL)
            {
                if(ptr1->is_array == true)
                {
                    switch(ptr1->type)
                    {
                        case Integer: free(ptr1->value.arrayValue.integerArray); break;
                        case Float: free(ptr1->value.arrayValue.floatArray); break;
                        case String: 
                            for(int i = 0; i < ptr1->value.arrayValue.length; i++)
                            {
                                free(ptr1->value.arrayValue.stringArray[i]);
                            }
                            free(ptr1->value.arrayValue.stringArray);
                        case Boolean: free(ptr1->value.arrayValue.booleanArray); break;
                    }
                }
                printf("%s, ", ptr1->name);
                ptr2 = ptr2->next;
                free(ptr1);
                ptr1 = ptr2;
            }
            printf("\n");
        }
        free(table);
        return;
    }
    
    /* scope handling */
    void enterscope()
    {
        printf("enter scope, old top ptr: %u, " , symtblstack_top);
        if(symtblstack_head == NULL)
        {
            symtblstack_head = create_symtbl();
            symtblstack_top = symtblstack_head;
        }
        else
        {
            symtbl_ptr temp = create_symtbl();
            temp->prev = symtblstack_top;
            symtblstack_top = temp;
        }
        printf("Current stack's top ptr : %u\n", symtblstack_top);
    }
    void leavescope()
    {
        printf("leave scope\n");
        dumpsymtbl(symtblstack_top->table);
        symtbl_ptr temp = symtblstack_top;
        symtblstack_top = symtblstack_top->prev;
        temp->prev = NULL;
        free(temp);
        printf("Current stack's top ptr : %u\n", symtblstack_top);
    }

/*global variable*/
    procInfo current_proc = NULL;   /*目前處理的procedure*/
    procInfo tempProc = NULL;       /*procedure暫存*/
     
    symtype temptype;       /*回傳值的type，用來做type checking*/ 
    
    int tempint = 0;



%}

/* precedence definition */
%left ASSIGN
%left OR
%left AND
%left NOT
%left LT MT ME LE EQ NE
%left '+' '-'
%left '*' '/'
%nonassoc UMINUS


/* yytype and token */
    %union {
        tokenValue value;
    }
    %token <value> IVAL FVAL SVAL BVAL IDENTIFIER
    %token '[' ']' '(' ')' '.'
    %token BEG BOOLEAN BREAK CHARACTER CASE CONTINUE CONSTANT DECLARE DO ELSE END READ
    %token EXIT FLOAT FOR IF IN INTEGER LOOP PRINT PRINTLN PROCEDURE PROGRAM RETURN STRING WHILE THEN

/* nonterminal type */
%type<value> expr
%type<value> stmt
%type<value> assign
%type<value> settype
%type<value> vc_declare
%type<value> program
%type<value> else
%type<value> vc_decl
%type<value> const_decl
%type<value> var_decl
%type<value> set_rt
%type<value> block
%type<value> parameter
%type<value> parameter_decl
%type<value> pdeclare



%start program
%%
program:        PROGRAM                 /*program declaration*/
                        {  
                            enterscope();
                        }
                    IDENTIFIER 
                        {
                            symbol temp = insertsym($3.stringValue);
                            temp->type = Procedure;
                            temp->is_array = false;
                        } 
                    vc_declare
                    pdeclare 
                    BEG
                    stmt 
                    END 
                    END IDENTIFIER 
                        {
                            leavescope();
                            if(strcmp($3.stringValue, $11.stringValue) != 0)
                            {
                                yyerror("Bad Identifier: program");
                            }
                        }
                ;

stmt:           IDENTIFIER              /* statment : Value assign operation */
                    ASSIGN expr ';' 
                    {
                        symbol temp = lookupsym($1.stringValue);
                        if(temp == NULL)yyerror("Variable Undeclared");
                        if(temp->is_array == true)yyerror("Assign Value to Array");
                        else if(temp->is_const == true)yyerror("Can't assign to a constant variable");
                        else if(temp->type == Integer && temptype == Float)
                        {
                            temp->value.integerValue = (int)$3.floatValue;
                            printf("Assign %d to %s\n", (int)$3.floatValue, temp->name);
                        } 
                        else if(temp->type == Float && temptype == Integer) 
                        {
                            temp->value.floatValue = (float)$3.integerValue;
                            printf("Assign %f to %s\n", (float)$3.integerValue, temp->name);
                        }
                        else if(temp->type == temptype)
                        {
                            switch(temp->type)
                            {
                                case Integer: temp->value.integerValue = $3.integerValue; printf("Assign %d to %s\n", $3.integerValue, temp->name); break;
                                case Float: temp->value.floatValue = $3.floatValue; printf("Assign %f to %s\n", $3.floatValue, temp->name); break;
                                case String: temp->value.stringValue = strdup($3.stringValue); printf("Assign \"%s\" to %s\n", $3.stringValue, temp->name); break;
                                case Boolean: temp->value.booleanValue = $3.booleanValue; printf("Assign %s to %s\n", $3.booleanValue? "true":"false", temp->name); break;
                            }
                            
                        }
                        else yyerror("Type unmatch");
                        temptype = Unknown;
                    } stmt                     
                | IDENTIFIER '[' expr ']' ASSIGN  {if(temptype != Integer)yyerror("Invalid type as index");} expr ';' /* statment : Array assign operation */
                    {
                        symbol temp = lookupsym($1.stringValue);
                        if(temp == NULL) yyerror("Variable Undeclared");
                        if(temp->is_array == false) yyerror("Target isn't an array");
                        if($3.integerValue >= temp->value.arrayValue.length)yyerror("Index out of rangeA");
                        if(temp->type == Integer && temptype == Float) 
                        {
                            temp->value.arrayValue.integerArray[$3.integerValue] = (int)$7.floatValue;
                            printf("Assign %d to %s[%d]\n", (int)$7.floatValue, temp->name, $3.integerValue);
                        }
                        else if(temp->type == Float && temptype == Integer)
                        {
                            temp->value.arrayValue.floatArray[$3.integerValue] = (float)$7.integerValue;
                            printf("Assign %d to %s[%d]\n", $7.integerValue, temp->name, $3.integerValue);
                        }
                        else if(temp->type == temptype)
                        {
                            
                            switch(temp->type)
                            {
                                case Integer: temp->value.arrayValue.integerArray[$3.integerValue] = $7.integerValue; printf("Assign %d to %s[%d]\n", $7.integerValue, temp->name, $3.integerValue); break;
                                case Float: temp->value.arrayValue.floatArray[$3.integerValue] = $7.floatValue; printf("Assign %f to %s[%d]\n", $7.floatValue, temp->name, $3.integerValue); break;
                                case String: temp->value.arrayValue.stringArray[$3.integerValue] = strdup($7.stringValue); printf("Assign \"%s\" to %s[%d]\n", $7.stringValue, temp->name, $3.integerValue); break;
                                case Boolean: temp->value.arrayValue.booleanArray[$3.integerValue] = $7.booleanValue; printf("Assign %s to %s[%d]\n", $7.booleanValue? "true":"false", temp->name, $3.integerValue); break;
                            }
                            
                        }
                        else yyerror("Type unmatch");
                        temptype = Unknown;
                    } stmt
                | expr ';' {temptype = Unknown;} stmt  /* statment : expression */
                | IF expr                               /* statment : if */
                    {
                        if(temptype != Boolean)yyerror("Condition expression isn't a boolean expression");
                    } THEN {enterscope();} block_stmt {leavescope();} else END IF';' {temptype = Unknown;} stmt 
                | WHILE expr                            /* statment : while */
                    {
                        if(temptype != Boolean)yyerror("Condition expression isn't a boolean expression");
                    } LOOP {enterscope();} block_stmt {leavescope();} END LOOP ';'  {temptype = Unknown;} stmt
                | FOR '(' IDENTIFIER IN expr            /* statment : for */
                        {
                            if(temptype ==Integer)tempint = $5.integerValue;
                            else yyerror("Not a integer: For loop condition");
                        } '.' '.' expr ')'
                        {
                            enterscope();
                            int tempint2;
                            if(temptype == Integer)tempint2 = $9.integerValue;
                            else yyerror("Not a integer: For loop condition");
                            symbol temp = lookupsym($3.stringValue);
                            if(temp == NULL)temp = insertsym($3.stringValue);
                            if(temp->type != Integer)yyerror("Can only be in Integer type");
                            if(tempint > tempint2)yyerror("Intialized value is bigger than terminated value");
                            $3.integerValue =  tempint;
                        } LOOP block_stmt {leavescope();} END LOOP ';'  {temptype = Unknown;} stmt
                | RETURN expr ';'                       /* statment : return */
                    {                      
                        if(temptype != current_proc->rt_type)
                        {
                            fprintf(stderr, "Error: type unmatch (%s) to (%s)\n", SymToStr(temptype), SymToStr(current_proc->rt_type)); 
                            yyerror("Not match");
                        } 
                    } stmt 
                | PRINT  expr ';'                       /* statment : Print */
                    {
                        switch(temptype)
                        {
                            case Integer: printf("%d",$2.integerValue); break;
                            case Float: printf("%f",$2.floatValue); break;
                            case String: printf("%s",$2.stringValue); break;
                            case Boolean: printf("%s", $2.booleanValue ? "true" : "false"); break;
                            default: yyerror("Can't print values of this type.");
                        }
                        temptype = Unknown;
                    } stmt
                | PRINTLN expr ';'                      /* statment : println */
                    {
                        switch(temptype)
                        {
                            case Integer: printf("%d\n",$2.integerValue); break;
                            case Float: printf("%f\n",$2.floatValue); break;
                            case String: printf("%s\n",$2.stringValue);; break;
                            case Boolean: printf("%s\n", $2.booleanValue ? "true" : "false"); break;
                            default: yyerror("Can't print values of this type.");
                        }
                        temptype = Unknown;
                    } stmt
                | READ IDENTIFIER ';' 
                    {
                        symbol temp = lookupsym($2.stringValue);
                        if(temp == NULL)yyerror("Not found the corresponding identifier");
                        temptype = Unknown;
                    } stmt              
                | ';' {temptype = Unknown;} stmt
                |
                ;

else:           ELSE block_stmt                         /* if condition not match (optimal)*/
                |
                ;

block_stmt:     vc_declare BEG {temptype = Unknown;} stmt END ';'   /*block or single statment, use for (if),(while),(for),(else)*/
                | IDENTIFIER 
                    ASSIGN expr ';' 
                    {
                        symbol temp = lookupsym($1.stringValue);
                        if(temp == NULL)yyerror("Variable Undeclared");
                        if(temp->is_array == true)yyerror("Assign Value to Array");
                        else if(temp->is_const == true)yyerror("Can't assign to a constant variable");
                        else if(temp->type == Integer && temptype == Float)
                        {
                            temp->value.integerValue = (int)$3.floatValue;
                            printf("Assign %d to %s\n", $3.floatValue, temp->name);
                        } 
                        else if(temp->type == Float && temptype == Integer) 
                        {
                            temp->value.floatValue = (float)$3.integerValue;
                            printf("Assign %f to %s\n", $3.integerValue, temp->name);
                        }
                        else if(temp->type == temptype)
                        {
                            switch(temp->type)
                            {
                                case Integer: temp->value.integerValue = $3.integerValue; printf("Assign %d to %s\n", $3.integerValue, temp->name); break;
                                case Float: temp->value.floatValue = $3.floatValue; printf("Assign %f to %s\n", $3.floatValue, temp->name); break;
                                case String: temp->value.stringValue = strdup($3.stringValue); printf("Assign \"%s\" to %s\n", $3.stringValue, temp->name); break;
                                case Boolean: temp->value.booleanValue = $3.booleanValue; printf("Assign %s to %s\n", $3.booleanValue? "true":"false", temp->name); break;
                            }
                            
                        }
                        else yyerror("Type unmatch");
                        temptype = Unknown;
                    }                     
                | IDENTIFIER '[' expr ']' ASSIGN  {if(temptype != Integer)yyerror("Invalid type as index");} expr ';'
                    {
                        symbol temp = lookupsym($1.stringValue);
                        if(temp == NULL) yyerror("Variable Undeclared");
                        if(temp->is_array == false) yyerror("Target isn't an array");
                        if($3.integerValue >= temp->value.arrayValue.length)yyerror("Index out of range");
                        if(temp->type == Integer && temptype == Float) 
                        {
                            temp->value.arrayValue.integerArray[$3.integerValue] = (int)$7.floatValue;
                            printf("Assign %d to %s[%d]\n", (int)$7.floatValue, temp->name, $3.integerValue);
                        }
                        else if(temp->type == Float && temptype == Integer)
                        {
                            temp->value.arrayValue.floatArray[$3.integerValue] = (float)$7.integerValue;
                            printf("Assign %d to %s[%d]\n", $7.integerValue, temp->name, $3.integerValue);
                        }
                        else if(temp->type == temptype)
                        {
                            
                            switch(temp->type)
                            {
                                case Integer: temp->value.arrayValue.integerArray[$3.integerValue] = $7.integerValue; printf("Assign %d to %s[%d]\n", $7.integerValue, temp->name, $3.integerValue); break;
                                case Float: temp->value.arrayValue.floatArray[$3.integerValue] = $7.floatValue; printf("Assign %f to %s[%d]\n", $7.floatValue, temp->name, $3.integerValue); break;
                                case String: temp->value.arrayValue.stringArray[$3.integerValue] = strdup($7.stringValue); printf("Assign \"%s\" to %s[%d]\n", $7.stringValue, temp->name, $3.integerValue); break;
                                case Boolean: temp->value.arrayValue.booleanArray[$3.integerValue] = $7.booleanValue; printf("Assign %s to %s[%d]\n", $7.booleanValue? "true":"false", temp->name, $3.integerValue); break;
                            }
                            
                        }
                        else yyerror("Type unmatch");
                        temptype = Unknown;
                    }
                | expr ';' {temptype = Unknown;}
                | IF expr 
                    {
                        if(temptype != Boolean)yyerror("Condition expression isn't a boolean expression");
                    } THEN {enterscope();} block_stmt {leavescope();} else END IF';' {temptype = Unknown;}  
                | WHILE expr 
                    {
                        if(temptype != Boolean)yyerror("Condition expression isn't a boolean expression");
                    } LOOP {enterscope();} block_stmt {leavescope();} END LOOP ';'  {temptype = Unknown;}
                | FOR '(' IDENTIFIER IN expr 
                        {
                            if(temptype ==Integer)tempint = $5.integerValue;
                            else yyerror("Not a integer: For loop condition");
                        } '.' '.' expr ')'
                        {
                            int tempint2;
                            if(temptype == Integer)tempint2 = $9.integerValue;
                            else yyerror("Not a integer: For loop condition");
                            symbol temp = lookupsym($3.stringValue);
                            if(temp->type != Integer)yyerror("Can only be in Integer type");
                            if(tempint > tempint2)yyerror("Intialized value is bigger than terminated value");
                            $3.integerValue =  tempint;
                            enterscope();
                        } LOOP block_stmt {leavescope();} END LOOP ';'  {temptype = Unknown;}
                | RETURN expr ';' 
                    {                       
                        if(temptype != current_proc->rt_type)
                        {
                            fprintf(stderr, "error: type unmatch (%s) to (%s)\n", SymToStr(temptype), SymToStr(current_proc->rt_type));
                            yyerror("Not match");
                        } 
                    } 
                | PRINT expr ';' 
                    {
                        switch(temptype)
                        {
                            case Integer: printf("%d",$2.integerValue); break;
                            case Float: printf("%f",$2.floatValue); break;
                            case String: printf("%s",$2.stringValue); break;
                            case Boolean: printf("%s", $2.booleanValue ? "true" : "false"); break;
                            default: yyerror("Can't print values of this type.");
                        }
                        temptype = Unknown;
                    }
                | PRINTLN expr ';' 
                    {
                        switch(temptype)
                        {
                            case Integer: printf("%d\n",$2.integerValue); break;
                            case Float: printf("%f\n",$2.floatValue); break;
                            case String: printf("%s\n",$2.stringValue);; break;
                            case Boolean: printf("%s\n", $2.booleanValue ? "true" : "false"); break;
                            default: yyerror("Can't print values of this type.");
                        }
                        temptype = Unknown;
                    }
                | READ IDENTIFIER ';'      
                    {
                        symbol temp = lookupsym($2.stringValue);
                        if(temp == NULL)yyerror("Not found the corresponding identifier");
                        temptype = Unknown;
                    }
                | ';' {temptype = Unknown;}
                |
                ;

arguments:      expr ','  /* formal parameter/actual parameter type checking */
                    {
                        if(!checkParaType(tempProc, tempint, temptype))yyerror("Type unmatch");
                        if(temptype == Unknown || temptype == None) yyerror("Not giving argument");
                        else tempint++;
                    } 
                    arguments
                |expr 
                    {
                        if(temptype == Unknown || temptype == None) yyerror("Not giving argument");
                        if(!checkParaType(tempProc, tempint, temptype))yyerror("Type unmatch");
                        else tempint++;
                    }
                ;

expr:           IDENTIFIER      /*function call (have at least 1 parameter)*/
                    {
                        tempProc = lookupProc($1.stringValue);
                        tempint = 0;
                    }
                    '(' arguments ')' 
                    {
                        printf("Call function: %s, return type: (%s)\n", tempProc->procName, SymToStr(tempProc->rt_type));
                        if(tempint < tempProc->para_count) 
                        {
                            fprintf(stderr, "Too few arguments for %s\n", tempProc->procName);
                            yyerror("Failed function calling");
                            temptype = None;
                        }
                        if(tempint > tempProc->para_count) 
                        {
                            fprintf(stderr, "Too much arguments for %s\n", tempProc->procName);
                            yyerror("Failed function calling");
                            temptype = None;
                        }
                        else temptype = tempProc->rt_type;
                    }            
                | expr '*' {typepush(temptype);} {printf("multi, ");} expr    /* operation * */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.integerValue = $1.integerValue * $5.integerValue;
                            temptype = Integer;
                        }
                        else if(temptype2 == Float && temptype == Integer)
                        {
                            $$.floatValue = $1.floatValue * $5.integerValue;
                            temptype = Float;
                        }
                        else if(temptype2 == Integer && temptype == Float)
                        {
                            $$.floatValue = $1.integerValue * $5.floatValue;
                            temptype = Float;
                        }
                        else if(temptype2 == Float && temptype == Float)
                        {
                            $$.floatValue = $1.floatValue * $5.floatValue;
                            temptype = Float;
                        }
                        else 
                        {
                            yyerror("Invalid type for (*) operator");
                            temptype = None;
                        }
                    }
                | expr '/' {typepush(temptype);} {printf("div, ");} expr      /* operation / */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.integerValue = $1.integerValue / $5.integerValue;
                            temptype = Integer;
                        }
                        else if(temptype2 == Float && temptype == Integer)
                        {
                            $$.floatValue = $1.floatValue / $5.integerValue;
                            temptype = Float;
                        }
                        else if(temptype2 == Integer && temptype == Float)
                        {
                            $$.floatValue = $1.integerValue / $5.floatValue;
                            temptype = Float;
                        }
                        else if(temptype2 == Float && temptype == Float)
                        {
                            $$.floatValue = $1.floatValue / $5.floatValue;
                            temptype = Float;
                        }
                        else 
                        {
                            yyerror("Invalid type for (/) operator");
                            temptype = None;
                        }
                    }
                | expr '+' {typepush(temptype);} {printf("add, ");} expr      /* operation + */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.integerValue = $1.integerValue + $5.integerValue;
                            temptype = Integer;
                        }
                        else if(temptype2 == Float && temptype == Integer)
                        {
                            $$.floatValue = $1.floatValue + $5.integerValue;
                            temptype = Float;
                        }
                        else if(temptype2 == Integer && temptype == Float)
                        {
                            $$.floatValue = $1.integerValue + $5.floatValue;
                            temptype = Float;
                        }
                        else if(temptype2 == Float && temptype == Float)
                        {
                            $$.floatValue = $1.floatValue + $5.floatValue;
                            temptype = Float;
                        }
                        else 
                        {
                            yyerror("Invalid type for (+) operator");
                            temptype = None;
                        }
                    }
                | expr '-' {typepush(temptype);} {printf("sub, ");} expr      /* operation - */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.integerValue = $1.integerValue - $5.integerValue;
                            temptype = Integer;
                        }
                        else if(temptype2 == Float && temptype == Integer)
                        {
                            $$.floatValue = $1.floatValue - $5.integerValue;
                            temptype = Float;
                        }
                        else if(temptype2 == Integer && temptype == Float)
                        {
                            $$.floatValue = $1.integerValue - $5.floatValue;
                            temptype = Float;
                        }
                        else if(temptype2 == Float && temptype == Float)
                        {
                            $$.floatValue = $1.floatValue - $5.floatValue;
                            temptype = Float;
                        }
                        else 
                        {
                            yyerror("Invalid type(s) for (-) operator");
                            temptype = None;
                        }
                    } 
                |'(' expr ')'                                                   /* operation () */
                    {
                        switch(temptype)
                        {
                            case Integer: $$.integerValue = $2.integerValue; temptype = Integer; break;
                            case Float: $$.floatValue = $2.floatValue; temptype = Float; break;
                            case Boolean: $$.booleanValue = $2.booleanValue; temptype = Boolean; break;
                            case String: $$.stringValue = strdup($2.stringValue); temptype = String; break;
                            default: yyerror("Invalid type for () operator"); temptype = None;
                        }
                    }
                | '-' expr  %prec UMINUS                                        /* operation unary minus */
                    {
                        switch(temptype)
                            {
                                case Integer: $$.integerValue = -$2.integerValue; temptype = Integer; break;
                                case Float: $$.floatValue = -$2.floatValue; temptype = Float; break;
                                default: temptype = None; yyerror("Invalid type for (-) operator");
                            }
                    }
                | expr AND {typepush(temptype);} expr                         /* operation and */
                    {
                        symtype temptype2 = typepop();
                        if(temptype == Boolean && temptype2 == Boolean)
                        {
                            $$.booleanValue = $1.booleanValue && $4.booleanValue; 
                            temptype = Boolean;
                        }
                        else
                        {
                            yyerror("Invalid type(s) for (AND) operator");
                            temptype = None;
                        }
                    }
                | expr OR {typepush(temptype);}expr                           /* operation or */
                    {
                        symtype temptype2 = typepop();
                        if(temptype == Boolean && temptype2 == Boolean)
                        {
                            $$.booleanValue = $1.booleanValue || $4.booleanValue; 
                            temptype = Boolean;
                        }
                        else
                        {
                            yyerror("Invalid type(s) for (OR) operator");
                            temptype = None;
                        }
                    }
                | NOT expr                                                      /* operation not */
                    {
                        if(temptype == Boolean)
                        {
                            $$.booleanValue = !$2.booleanValue; 
                            temptype = Boolean;
                        }
                        else 
                        {
                            yyerror("Invalid type for (NOT) operator");
                            temptype = None;
                        }
                    }
                |expr LT {typepush(temptype);} expr                           /* operation < */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.booleanValue = $1.integerValue < $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Integer)
                        {
                            $$.booleanValue = $1.floatValue < $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Integer && temptype == Float)
                        {
                            $$.booleanValue = $1.integerValue < $4.floatValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Float)
                        {
                            $$.booleanValue = $1.floatValue < $4.floatValue;
                            temptype = Boolean;
                        }
                        else 
                        {
                            yyerror("Invalid type(s) for (<) operator");
                            temptype = None;
                        }
                    }
                |expr MT {typepush(temptype);} expr                           /* operation > */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.booleanValue = $1.integerValue > $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Integer)
                        {
                            $$.booleanValue = $1.floatValue > $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Integer && temptype == Float)
                        {
                            $$.booleanValue = $1.integerValue > $4.floatValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Float)
                        {
                            $$.booleanValue = $1.floatValue > $4.floatValue;
                            temptype = Boolean;
                        }
                        else 
                        {
                            yyerror("Invalid type(s) for (>) operator");
                            temptype = None;
                        }
                    }
                |expr LE {typepush(temptype);} expr                           /* operation <= */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.booleanValue = $1.integerValue <= $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Integer)
                        {
                            $$.booleanValue = $1.floatValue <= $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Integer && temptype == Float)
                        {
                            $$.booleanValue = $1.integerValue <= $4.floatValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Float)
                        {
                            $$.booleanValue = $1.floatValue <= $4.floatValue;
                            temptype = Boolean;
                        }
                        else 
                        {
                            yyerror("Invalid type(s) for (<=) operator");
                            temptype = None;
                        }
                    }
                |expr ME {typepush(temptype);} expr                           /* operation >= */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.booleanValue = $1.integerValue >= $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Integer)
                        {
                            $$.booleanValue = $1.floatValue >= $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Integer && temptype == Float)
                        {
                            $$.booleanValue = $1.integerValue >= $4.floatValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Float)
                        {
                            $$.booleanValue = $1.floatValue >= $4.floatValue;
                            temptype = Boolean;
                        }
                        else 
                        {
                            yyerror("Invalid type(s) for (=>) operator");
                            temptype = None;
                        }
                    }
                |expr EQ {typepush(temptype);} expr                           /* operation = */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.booleanValue = $1.integerValue == $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Integer)
                        {
                            $$.booleanValue = $1.floatValue == $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Integer && temptype == Float)
                        {
                            $$.booleanValue = $1.integerValue == $4.floatValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Float)
                        {
                            $$.booleanValue = $1.floatValue == $4.floatValue;
                            temptype = Boolean;
                        }
                        else 
                        {
                            yyerror("Invalid type(s) for (=) operator");
                            temptype = None;
                        }
                    }
                |expr NE {typepush(temptype);} expr                           /* operation /= */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.booleanValue = $1.integerValue != $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Integer)
                        {
                            $$.booleanValue = $1.floatValue != $4.integerValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Integer && temptype == Float)
                        {
                            $$.booleanValue = $1.integerValue != $4.floatValue;
                            temptype = Boolean;
                        }
                        else if(temptype2 == Float && temptype == Float)
                        {
                            $$.booleanValue = $1.floatValue != $4.floatValue;
                            temptype = Boolean;
                        }
                        else 
                        {
                            yyerror("Invalid type(s) for (/=) operator");
                            temptype = None;
                        }
                    }
                | SVAL {$$.stringValue = strdup($1.stringValue);temptype = String;} /* string value */
                | BVAL {$$.booleanValue = $1.booleanValue; temptype = Boolean;}     /* boolean value */
                | IVAL {$$.integerValue = $1.integerValue; temptype = Integer; }    /* int value */
                | FVAL {$$.floatValue = $1.floatValue; temptype = Float; }          /* float value */
                |IDENTIFIER '['expr']'                                          /* array value */
                    {
                        symbol temp = lookupsym($1.stringValue);
                        if(temp == NULL)
                        {
                            yyerror("Variable undeclared");
                            temptype = None;
                        }
                        if(temp->is_array == false)
                        {
                            yyerror("Invalid assignment: array to value");
                            temptype = None;
                        }
                        if(temptype != Integer)
                        {
                            yyerror("Invalid index");
                            temptype = None;
                        }
                        if($3.integerValue >= temp->value.arrayValue.length)
                        {
                            yyerror("Index out of range");
                            temptype = None;
                        }
                        else
                        {
                            switch(temp->type)
                            {
                                case Integer: $$.integerValue = temp->value.arrayValue.integerArray[$3.integerValue]; temptype = Integer; break;
                                case Float: $$.floatValue = temp->value.arrayValue.floatArray[$3.integerValue]; temptype = Float; break;
                                case Boolean: $$.booleanValue = temp->value.arrayValue.booleanArray[$3.integerValue]; temptype = Boolean; break;
                                case String: $$.stringValue = strdup(temp->value.arrayValue.stringArray[$3.integerValue]); temptype = String; break;
                                default: yyerror("Bad variable"); temptype = None;
                            }
                        }   
                    }
                | IDENTIFIER                                                    /* vairable or function call (without parameter) */
                    {
                        symbol temp = lookupsym($1.stringValue);
                        if(temp == NULL)
                        {
                            yyerror("identifier undeclared");
                            temptype = None;
                        }
                        else if(temp->type == Procedure)
                        {
                            tempProc = lookupProc(temp->name);
                            if(tempProc == NULL)
                            {
                                yyerror("Some error happened while declaring procedure");
                                temptype = None;
                            }
                            else if(tempProc->para_count != 0)
                            {
                                yyerror("Not giving arguments to target function");
                                temptype = None;
                            }
                            else 
                            {
                                printf("Call function: %s, return type: (%s)\n", tempProc->procName, SymToStr(tempProc->rt_type));
                                temptype = tempProc->rt_type;
                            }
                        }
                        else if(temp->is_array == true)
                        {
                            yyerror("Invalid assignment: value to array");
                            temptype = None;
                        }
                        else
                        {
                            switch(temp->type)
                            {
                                case Integer: $$.integerValue = temp->value.integerValue; temptype = Integer; break;
                                case Float: $$.floatValue = temp->value.floatValue; temptype = Float; break;
                                case Boolean: $$.booleanValue = temp->value.booleanValue; temptype = Boolean; break;
                                case String: $$.stringValue = strdup(temp->value.stringValue); temptype = String; break;
                                default:yyerror("Bad variable"); temptype = None;
                            }
                        }
                    }
                | {temptype = None;}
                ;

/*  variable and constant declaration */
vc_declare:       DECLARE vc_decl                                           /* (constant) variable declaration */
                |
                ;

vc_decl:         const_decl vc_decl                                         /* (constant) variable declaration */
                | var_decl vc_decl                                          /* variable declaration */
                |
                ;
                
const_decl:     IDENTIFIER                                                  /* constant variable declaration */
                    ':' CONSTANT settype
                        {
                            symbol temp = insertsym($1.stringValue);
                            temp->type = temptype;
                            temp->is_const = true;
                            temp->is_array = false;
                        } 
                    assign ';'
                        {
                            symbol temp = lookupsym($1.stringValue);
                            if(temptype == Unknown) yyerror("Doesn't assign value to constant variable.");
                            else if(temp->type == temptype || temp->type == Unknown)    /*var type和assign type相同或無限制type但有assign值 直接賦值*/
                            {
                                temp->type = temptype;
                                switch(temptype)
                                {
                                    case Integer: temp->value.integerValue = $6.integerValue; break;
                                    case Float: temp->value.floatValue = $6.floatValue; break;
                                    case String: temp->value.stringValue = strdup($6.stringValue); break;
                                    case Boolean: temp->value.booleanValue = $6.booleanValue; break;
                                    default: ;
                                }
                            }
                            printf("Declare: %s settype : %s,setvalue : %s, constant? true\n", temp->name, SymToStr(temp->type), SymToStr(temptype));
                        }
                ;

var_decl:       IDENTIFIER                                                  /* variable declaration */
                    settype
                        {
                            symbol temp = insertsym($1.stringValue);
                            temp->type = temptype;
                            temp->is_const = false;
                            temp->is_array = false;
                        }
                    assign  ';'
                        {
                            symbol temp = lookupsym($1.stringValue);
                            if(temptype == Unknown && temp->type == Unknown)    /*皆無限制，預設為int*/
                            {
                                temp->type = Integer;
                                temp->value.integerValue = 0;
                            }
                            else if(temp->type == temptype || temp->type == Unknown)    /*var type和assign type相同或無限制type但有assign值 直接賦值*/
                            {
                                temp->type = temptype;
                                switch(temptype)
                                {
                                    case Integer: temp->value.integerValue = $4.integerValue; break;
                                    case Float: temp->value.floatValue = $4.floatValue; break;
                                    case String: temp->value.stringValue = strdup($4.stringValue); break;
                                    case Boolean: temp->value.booleanValue = $4.booleanValue; break;
                                }
                            }
                            else if(temptype == Unknown)                            /*有限制var type但沒assign，預設為0*/
                            {
                                switch(temp->type)
                                {
                                    case Integer: temp->value.integerValue = 0; break;
                                    case Float: temp->value.floatValue = 0; break;
                                    case String: temp->value.stringValue = ""; break;
                                    case Boolean: temp->value.booleanValue = false; break;
                                }
                            }
                            else if(temptype == Integer && temp->type == Float) /*type convertion : int and float*/
                            {
                                temp->value.floatValue = (float)$4.integerValue;
                            }
                            else if(temptype == Float && temp->type == Integer)
                            {
                                temp->value.integerValue = (int)$4.floatValue;
                            }
                            else {yyerror("variable declaration failed.");}
                            printf("Declare : %s settype : %s,setvalue : %s, constant? false\n", temp->name, SymToStr(temp->type), SymToStr(temptype));
                        }
                | IDENTIFIER settype
                    {
                        if(temptype == Unknown)yyerror("Array must set a type");
                        symbol temp = insertsym($1.stringValue);
                        temp->type = temptype;
                        temp->is_const = false;
                        temp->is_array = true;
                    } '[' IVAL ']' ';'
                    {
                        symbol temp = lookupsym($1.stringValue);
                        temp->value.arrayValue.length = $5.integerValue;
                        switch(temp->type)
                        {
                            case Integer: 
                                temp->value.arrayValue.integerArray = malloc(sizeof(int) * $5.integerValue);
                                for(int i = 0; i < temp->value.arrayValue.length; i++)
                                {
                                    temp->value.arrayValue.integerArray[i] = 0;
                                }
                                break;
                            case Float:
                                temp->value.arrayValue.floatArray = malloc(sizeof(float) * $5.integerValue);
                                for(int i = 0; i < temp->value.arrayValue.length; i++)
                                {
                                    temp->value.arrayValue.floatArray[i] = 0;
                                }
                                break;
                            case Boolean:
                                temp->value.arrayValue.booleanArray = malloc(sizeof(bool) * $5.integerValue);
                                for(int i = 0; i < temp->value.arrayValue.length; i++)
                                {
                                    temp->value.arrayValue.booleanArray[i] = false;
                                }
                                break;  
                            case String:
                                temp->value.arrayValue.stringArray = malloc(sizeof(char*) * $5.integerValue);
                                for(int i = 0; i < temp->value.arrayValue.length; i++)
                                {
                                    temp->value.arrayValue.stringArray[i] = "";
                                }
                                break;  
                        }
                        printf("Create %s array, length: %d\n", SymToStr(temp->type), temp->value.arrayValue.length);
                    }
                ;
                    
settype:        ':'  INTEGER    {temptype = Integer;}                       /* set variable type while declaration */
                |':'  FLOAT    {temptype = Float;}
                |':'  STRING    {temptype = String;}  
                |':'  BOOLEAN    {temptype = Boolean;}             
                |   {temptype = Unknown;}
                ;

assign:         ASSIGN expr                                                 /* set variable value while declaration */ 
                        {
                            if(temptype == Unknown) yyerror("Assign but no value");
                            if(temptype == None) yyerror("Assignment Failed");
                            else 
                            {
                                switch(temptype)
                                {
                                    case Integer: $$.integerValue = $2.integerValue; break;
                                    case Float: $$.floatValue = $2.floatValue; break;
                                    case String: $$.stringValue = strdup($2.stringValue); break;
                                    case Boolean: $$.booleanValue = $2.booleanValue; break;
                                }
                            }
                        }
                |   {temptype = Unknown;}
                ;

/*procedure declaration*/
pdeclare:       PROCEDURE IDENTIFIER                                        /* procedure declaration */
                    {
                        current_proc = insertProc($2.stringValue);  
                        symbol temp = insertsym($2.stringValue);
                        temp->type = Procedure;
                        temp->is_array = false;
                        enterscope();                     
                    }
                    parameter_decl set_rt
                    block
                        {
                            if(temptype == Unknown && current_proc->rt_type != None)yyerror("Not return value");
                            else if(temptype == Unknown && current_proc->rt_type == None);
                            else if(current_proc->rt_type != temptype)yyerror("Return type isn't match");
                        }
                    END IDENTIFIER ';'
                        {    
                            if(strcmp($2.stringValue, $9.stringValue) != 0) yyerror("Bad procedure name");
                            leavescope();
                        }
                    pdeclare
                |   
                ;

parameter_decl: '(' IDENTIFIER                                              /* formal parameter declaration */
                        settype
                        {
                            symbol temp = insertsym($2.stringValue);
                            if(temptype == Unknown)yyerror("parameter without setting type");
                            else temp->type = temptype;
                            addParaType(current_proc, temptype);
                        } parameter ')'
                |
                ;

parameter:      ';' IDENTIFIER                                              /* used while more than 1 formal parameter */
                    settype
                        {
                            symbol temp = insertsym($2.stringValue);
                            if(temptype == Unknown)yyerror("parameter without setting type");
                            else temp->type = temptype;
                            addParaType(current_proc, temptype);
                        } 
                    parameter
                |
                ;

set_rt:         RETURN INTEGER {temptype = Integer; current_proc->rt_type = Integer; printf("set return type:%s for procedure %s\n", SymToStr(current_proc->rt_type), current_proc->procName);} /*ser return type */
                |RETURN FLOAT {temptype = Float; current_proc->rt_type = Float; printf("set return type:%s for procedure %s\n", SymToStr(current_proc->rt_type), current_proc->procName);}
                |RETURN BOOLEAN {temptype = Boolean; current_proc->rt_type = Boolean; printf("set return type:%s for procedure %s\n", SymToStr(current_proc->rt_type), current_proc->procName);}
                |RETURN STRING {temptype = String; current_proc->rt_type = String; printf("set return type:%s for procedure %s\n", SymToStr(current_proc->rt_type), current_proc->procName);}
                | {temptype = Unknown; current_proc->rt_type = None;}
                ;

block:          vc_declare BEG {temptype = Unknown;} stmt END ';' ;         /* procedure block */

%%
void main(int argc, char** argv)
{
    /* open the source program file */
    if (argc != 2) {
        printf ("Usage: sc filename\n");
        exit(1);
    }
    yyin = fopen(argv[1], "r");         /* open input file */

    /* perform parsing */
    if (yyparse() == 1)                 /* parsing */
        yyerror("Parsing error !");     /* syntax error */
}