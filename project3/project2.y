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
        proc->para_count++;
        return 1;

        
    }

    int checkParaType(procInfo proc, int index, symtype s)
    {
        if(proc->para_type[index] != s)
        {
            printf("Line%d Error: Type unmatch: (%s), (%s)\n",linenum, SymToStr(proc->para_type[index]), SymToStr(s));
            return 0;
        }
        else return 1;
    }    

/* symbol and symboltable */
    typedef struct s{
		char* name;
        int index;
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

    bool is_global = true;
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
                    
                    if(tblptr->prev == NULL)is_global = true;
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
                printf("(%s, %d, %s), ", ptr1->name, ptr1->index, SymToStr(ptr1->type));
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
    }
    void leavescope()
    {
        dumpsymtbl(symtblstack_top->table);
        symtbl_ptr temp = symtblstack_top;
        symtblstack_top = symtblstack_top->prev;
        temp->prev = NULL;
        free(temp);
    }


/* condition label handling */

    int cond_stack[100] = {0};
    int top = -1;   
    int max_cond = 0;

    void labelpush()
    {
        if(top == 99)yyerror("Out of range: condition loop");
        else
        {
            top++;
            cond_stack[top] = max_cond;
            max_cond++;
        }
        return;
    }
    void labelpop()
    {
        if(top == -1)yyerror("Out of range: condition loop");
        else
        {
            top--;
        }
    }

/*global variable*/
    procInfo current_proc = NULL;   /*目前處理的procedure*/
    procInfo tempProc = NULL;       /*procedure暫存*/
     
    symtype temptype;       /*回傳值的type，用來做type checking*/ 
    
    int tempint = 0;
    int index_counter = 0;
    int label_counter = 0;

    FILE *targetfile;
    char* filename;


%}

/* precedence definition */
%left ASSIGN
%left OR
%left AND
%left NOT
%left LT MT ME LE EQ NE
%left '+' '-'
%left '*' '/' '%'
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
%type<value> glassign
%type<value> glsettype
%type<value> glvar_decl
%type<value> glconst_decl



%start program
%%
program:        PROGRAM                 /*program declaration*/
                        {  
                            enterscope();
                            fprintf(targetfile, "class %s {\n", filename);
                        }
                    IDENTIFIER 
                        {
                            symbol temp = insertsym($3.stringValue);
                            temp->type = Procedure;
                            temp->is_array = false;
                        } 
                    glvc_declare
                    pdeclare 
                    BEG {
                        fprintf(targetfile, "method public static void main(java.lang.String[])\n");
                        fprintf(targetfile, "max_stack 15\n");
                        fprintf(targetfile, "max_locals 15\n");
                        fprintf(targetfile, "{\n");
                    }
                    stmt 
                    END ';'
                        {
                            fprintf(targetfile, "return\n");
                            fprintf(targetfile, "}\n");
                        }
                    END IDENTIFIER 
                        {
                            leavescope();
                            if(strcmp($3.stringValue, $14.stringValue) != 0)
                            {
                                yyerror("Bad Identifier: program");
                            }
                            
                            fprintf(targetfile, "}\n");
                        }
                ;



glvc_declare:       DECLARE glvc_decl                                           /* (constant) variable declaration */
                |
                ;

glvc_decl:         glconst_decl glvc_decl                                         /* (constant) variable declaration */
                | glvar_decl glvc_decl                                          /* variable declaration */
                |
                ;
                
glconst_decl:     IDENTIFIER                                                  /* constant variable declaration */
                    ':' CONSTANT glsettype
                        {
                            symbol temp = insertsym($1.stringValue);
                            temp->type = temptype;
                            temp->is_const = true;
                            temp->index = index_counter;
                            index_counter++;
                            temp->is_array = false;

                            
                        } 
                    glassign ';'
                        {
                            symbol temp = lookupsym($1.stringValue);
                            if(temptype == Unknown) yyerror("Doesn't assign value to constant variable.");
                            else if(temp->type == temptype || temp->type == Unknown)    /*var type和assign type相同或無限制type但有assign值 直接賦值*/
                            {
                                temp->type = temptype;
                                switch(temptype)
                                {
                                    case Integer: 
                                        temp->value.integerValue = $6.integerValue;
                                        fprintf(targetfile, "field static %s %s = %d\n", SymToStr(temp->type), $1.stringValue, temp->value.integerValue);
                                        break;
                                    case Float:
                                        temp->value.floatValue = $6.floatValue; 
                                        break;
                                    case String: 
                                        temp->value.stringValue = strdup($6.stringValue); 
                                        fprintf(targetfile, "field static %s %s = %d\n", SymToStr(temp->type), $1.stringValue, temp->value.stringValue);
                                        break;
                                    case Boolean: 
                                        temp->value.booleanValue = $6.booleanValue; 
                                        fprintf(targetfile, "field static %s %s = %d\n", SymToStr(temp->type), $1.stringValue, temp->value.booleanValue);
                                        break;
                                    default: ;
                                }
                            }
                        }
                ;

glvar_decl:       IDENTIFIER                                                  /* variable declaration */
                    glsettype
                        {
                            symbol temp = insertsym($1.stringValue);
                            temp->type = temptype;
                            temp->index = index_counter;
                            index_counter++;
                            temp->is_const = false;
                            temp->is_array = false;
                        }
                    glassign  ';'
                        {
                            symbol temp = lookupsym($1.stringValue);
                            if(temptype == Unknown && temp->type == Unknown)    /*皆無限制，預設為int*/
                            {
                                temp->type = Integer;
                                temp->value.integerValue = 0;
                                fprintf(targetfile, "field static %s %s\n", SymToStr(temp->type), $1.stringValue);
                            }
                            else if(temp->type == temptype || temp->type == Unknown)    /*var type和assign type相同或無限制type但有assign值 直接賦值*/
                            {
                                temp->type = temptype;
                                switch(temptype)
                                {
                                    case Integer: 
                                        temp->value.integerValue = $4.integerValue;
                                        fprintf(targetfile, "field static %s %s = %d\n", SymToStr(temp->type), $1.stringValue, temp->value.integerValue); 
                                        break;
                                    case Float: 
                                        temp->value.floatValue = $4.floatValue;
                                        fprintf(targetfile, "field static %s %s = %d\n", SymToStr(temp->type), $1.stringValue, temp->value.floatValue);
                                        break;
                                    case String: 
                                        temp->value.stringValue = strdup($4.stringValue);
                                        fprintf(targetfile, "field static %s %s = %d\n", SymToStr(temp->type), $1.stringValue, temp->value.stringValue); 
                                        break;
                                    case Boolean: 
                                        temp->value.booleanValue = $4.booleanValue; 
                                        fprintf(targetfile, "field static %s %s = %d\n", SymToStr(temp->type), $1.stringValue, temp->value.booleanValue);
                                        break;
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
                                fprintf(targetfile, "field static %s %s\n", SymToStr(temp->type), $1.stringValue);
                            }
                            else if(temptype == Integer && temp->type == Float) /*type convertion : int and float*/
                            {
                                temp->value.floatValue = (float)$4.integerValue;
                                fprintf(targetfile, "field static %s %s = %f\n", SymToStr(temp->type), $1.stringValue, temp->value.floatValue);
                            }
                            else if(temptype == Float && temp->type == Integer)
                            {
                                temp->value.integerValue = (int)$4.floatValue;
                                fprintf(targetfile, "field static %s %s = %d\n", SymToStr(temp->type), $1.stringValue, temp->value.integerValue);
                            }
                            else {yyerror("variable declaration failed.");}
                            
                        }
                | IDENTIFIER glsettype
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
                    }
                ;
                    
glsettype:        ':'  INTEGER    {temptype = Integer;}                       /* set variable type while declaration */
                |':'  FLOAT    {temptype = Float;}
                |':'  STRING    {temptype = String;}  
                |':'  BOOLEAN    {temptype = Boolean;}             
                |   {temptype = Unknown;}
                ;

glassign:         ASSIGN IDENTIFIER                                                /* set variable value while declaration */ 
                        {
                            symbol temp = lookupsym($2.stringValue);
                            if(temp == NULL) yyerror("id not found");
                            if(temp->type == None) yyerror("Assignment Failed");
                            else 
                            {
                                switch(temp->type)
                                {
                                    case Integer: $$.integerValue = temp->value.integerValue; break;
                                    case Float: $$.floatValue = temp->value.floatValue; break;
                                    case String: $$.stringValue = strdup(temp->value.stringValue); break;
                                    case Boolean: $$.booleanValue = temp->value.booleanValue; break;
                                }
                            }
                        }
                |ASSIGN IVAL
                    {
                         $$.integerValue = $2.integerValue;
                         temptype = Integer;
                    }
                |ASSIGN SVAL
                    {
                         $$.integerValue = strdup($2.stringValue);
                         temptype = String;
                    }
                |ASSIGN BVAL
                    {
                         $$.integerValue = $2.booleanValue;
                         temptype = Boolean;
                    }
                |   {temptype = Unknown;}
                ;




stmt:           IDENTIFIER              /* statment : Value assign operation */
                    ASSIGN expr ';' 
                    {
                        is_global = false;
                        symbol temp = lookupsym($1.stringValue);
                        if(temp == NULL)yyerror("Variable Undeclared");
                        if(temp->is_array == true)yyerror("Assign Value to Array");
                        else if(temp->is_const == true)yyerror("Can't assign to a constant variable");
                        else if(temp->type == Integer && temptype == Float)
                        {
                            temp->value.integerValue = (int)$3.floatValue;
                            if(is_global)
                            {
                                fprintf(targetfile, "putstatic int %s.%s\n",filename, temp->name);
                            }
                            else
                            {
                                fprintf(targetfile, "istore %d\n", temp->index);
                            }
                        } 
                        else if(temp->type == Float && temptype == Integer) 
                        {
                            temp->value.floatValue = (float)$3.integerValue;
                        }
                        else if(temp->type == temptype)
                        {
                            switch(temp->type)
                            {
                                case Integer: 
                                    temp->value.integerValue = $3.integerValue; 
                                    if(is_global)
                                    {
                                        fprintf(targetfile, "putstatic int %s.%s\n",filename, temp->name);
                                    }
                                    else
                                    {
                                        fprintf(targetfile, "istore %d\n", temp->index);
                                    }
                                    break;
                                case Float: temp->value.floatValue = $3.floatValue; break;
                                case String: temp->value.stringValue = strdup($3.stringValue);  break;
                                case Boolean: temp->value.booleanValue = $3.booleanValue; break;
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
                        }
                        else if(temp->type == Float && temptype == Integer)
                        {
                            temp->value.arrayValue.floatArray[$3.integerValue] = (float)$7.integerValue;
                        }
                        else if(temp->type == temptype)
                        {
                            
                            switch(temp->type)
                            {
                                case Integer: temp->value.arrayValue.integerArray[$3.integerValue] = $7.integerValue; break;
                                case Float: temp->value.arrayValue.floatArray[$3.integerValue] = $7.floatValue; break;
                                case String: temp->value.arrayValue.stringArray[$3.integerValue] = strdup($7.stringValue); break;
                                case Boolean: temp->value.arrayValue.booleanArray[$3.integerValue] = $7.booleanValue;  break;
                            }
                            
                        }
                        else yyerror("Type unmatch");
                        temptype = Unknown;
                    } stmt
                | expr ';' {temptype = Unknown;} stmt  /* statment : expression */
                | IF expr                               /* statment : if */
                    {
                        labelpush();
                        
                        if(temptype != Boolean)yyerror("Condition expression isn't a boolean expression");
                    } THEN 
                    {
                        fprintf(targetfile, "ifeq LFalse%d\n", cond_stack[top]);                    
                        enterscope();
                    } block_stmt 
                    {
                        fprintf(targetfile, "goto LExit%d\n", cond_stack[top]);
                        leavescope();
                    } else END IF';' 
                    {
                        temptype = Unknown;
                        fprintf(targetfile, "LExit%d:\n", cond_stack[top]);
                        fprintf(targetfile, "nop\n");
                        labelpop();
                        
                    } stmt 
                | WHILE 
                    {
                        labelpush();
                        
                        fprintf(targetfile, "LBegin%d:\n", cond_stack[top]);
                    }expr                            /* statment : while */
                    {
                        if(temptype != Boolean)yyerror("Condition expression isn't a boolean expression");
                    } LOOP 
                    {
                        enterscope();
                        fprintf(targetfile, "ifeq LExit%d\n", cond_stack[top]);
                    } block_stmt 
                    {
                        leavescope();
                    } END LOOP ';'  
                    {
                        fprintf(targetfile, "goto LBegin%d\n", cond_stack[top]);
                        temptype = Unknown;
                        fprintf(targetfile, "LExit%d:\n", cond_stack[top]);
                        fprintf(targetfile, "nop\n");
                        labelpop();
                        
                    } stmt
                | FOR '(' IDENTIFIER IN IVAL            /* statment : for */
                        {
                            
                            enterscope();
                            is_global = false;
                            symbol temp = lookupsym($3.stringValue);
                            if(temp == NULL)
                            {
                                temp = insertsym($3.stringValue);
                                temp->type = Integer;
                                temp->index = index_counter;
                                temp->is_const = false;
                                index_counter++;
                            }
                            if(temp->type != Integer)yyerror("Can only be in Integer type");
                            fprintf(targetfile, "sipush %d\n", $5.integerValue);
                            if(is_global)
                            {
                                if(temp->is_const)yyerror("can't assign to a constant variable.");
                                else fprintf(targetfile, "putstatic int %s.%s\n",filename, temp->name);
                            }
                            else
                            {
                                fprintf(targetfile, "istore %d\n", temp->index);
                            }                        
                        } '.' '.' IVAL ')'
                        {
                            labelpush();
                            
                            fprintf(targetfile, "LBegin%d:\n", cond_stack[top]);
                            is_global = false;
                            symbol temp = lookupsym($3.stringValue);
                            if(is_global)
                            {
                                if(temp->is_const)yyerror("can't assign to a constant variable.");
                                else fprintf(targetfile, "getstatic int %s.%s\n",filename, temp->name);
                            }
                            else
                            {
                                fprintf(targetfile, "iload %d\n", temp->index);
                            }
                            fprintf(targetfile, "sipush %d\n", $9.integerValue);
                            fprintf(targetfile, "isub\n");
                            fprintf(targetfile, "ifeq LExit%d\n", cond_stack[top]);
                        } LOOP
                        block_stmt 
                         END LOOP ';'  
                        {
                            temptype = Unknown;
                            is_global = false;
                            symbol temp = lookupsym($3.stringValue);
                            if(is_global)
                            {
                                if(temp->is_const)yyerror("can't assign to a constant variable.");
                                else fprintf(targetfile, "getstatic int %s.%s\n",filename, temp->name);
                            }
                            else
                            {
                                fprintf(targetfile, "iload %d\n", temp->index);
                            }
                            fprintf(targetfile, "sipush 1\n");
                            if($5.integerValue < $9.integerValue)fprintf(targetfile, "iadd\n");
                            else fprintf(targetfile, "isub\n");
                            if(is_global)
                            {
                                if(temp->is_const)yyerror("can't assign to a constant variable.");
                                else fprintf(targetfile, "putstatic int %s.%s\n",filename, temp->name);
                            }
                            else
                            {
                                fprintf(targetfile, "istore %d\n", temp->index);
                            }
                            fprintf(targetfile, "goto LBegin%d\n", cond_stack[top]);
                            fprintf(targetfile, "LExit%d:\n", cond_stack[top]);
                            fprintf(targetfile, "nop\n");
                            labelpop();
                            
                            
                            leavescope();
                        
                        } stmt
                | RETURN expr ';'                       /* statment : return */
                    {                      
                        if(temptype != current_proc->rt_type)
                        {
                            fprintf(stderr, "Error: type unmatch (%s) to (%s)\n", SymToStr(temptype), SymToStr(current_proc->rt_type)); 
                            yyerror("Not match");
                        } 
                        else if(temptype == None)
                        {
                            fprintf(targetfile, "return\n");
                        }
                        else
                        {
                            fprintf(targetfile, "ireturn\n");
                        }
                    } stmt 
                | PRINT {fprintf(targetfile, "getstatic java.io.PrintStream java.lang.System.out\n");} expr ';'                       /* statment : Print */
                    {
                        switch(temptype)
                        {
                            case Integer:
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.print(int)\n"); 
                                break;
                            case Float: break;
                            case String: 
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.print(java.lang.String)\n");
                                break;
                            case Boolean: 
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.print(boolean))\n"); 
                                break;
                            default: yyerror("Can't print values of this type.");
                        }
                        temptype = Unknown;
                    } stmt
                | PRINTLN {fprintf(targetfile, "getstatic java.io.PrintStream java.lang.System.out\n");} expr ';'                      /* statment : println */
                    {
                        switch(temptype)
                        {
                            case Integer:
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.println(int)\n"); 
                                break;
                            case Float:  break;
                            case String: 
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.println(java.lang.String)\n");
                                break;
                            case Boolean: 
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.println(boolean)\n"); 
                                break;
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

else:           ELSE {
                        enterscope();
                        fprintf(targetfile, "LFalse%d:\n", cond_stack[top]);
                    } block_stmt {leavescope();}                         /* if condition not match (optimal)*/
                | {fprintf(targetfile, "LFalse%d:\n", cond_stack[top]);
                    fprintf(targetfile, "goto LExit%d\n", cond_stack[top]);
                    }
                ;

block_stmt:     vc_declare BEG {temptype = Unknown;} stmt END ';'   /*block or single statment, use for (if),(while),(for),(else)*/
                | IDENTIFIER 
                    ASSIGN expr ';' 
                    {
                        is_global = false;
                        symbol temp = lookupsym($1.stringValue);
                        if(temp == NULL)yyerror("Variable Undeclared");
                        if(temp->is_array == true)yyerror("Assign Value to Array");
                        else if(temp->is_const == true)yyerror("Can't assign to a constant variable");
                        else if(temp->type == Integer && temptype == Float)
                        {
                            temp->value.integerValue = (int)$3.floatValue;
                           
                            if(is_global)
                            {
                                fprintf(targetfile, "putstatic int %s.%s\n",filename, temp->name);
                            }
                            else
                            {
                                fprintf(targetfile, "istore %d\n", temp->index);
                            }
                        } 
                        else if(temp->type == Float && temptype == Integer) 
                        {
                            temp->value.floatValue = (float)$3.integerValue;
                            
                        }
                        else if(temp->type == temptype)
                        {
                            switch(temp->type)
                            {
                                case Integer: 
                                    temp->value.integerValue = $3.integerValue; 
                                    if(is_global)
                                    {
                                        fprintf(targetfile, "putstatic int %s.%s\n",filename, temp->name);
                                    }
                                    else
                                    {
                                        fprintf(targetfile, "istore %d\n", temp->index);
                                    }
                                    break;
                                case Float: temp->value.floatValue = $3.floatValue; break;
                                case String: temp->value.stringValue = strdup($3.stringValue); break;
                                case Boolean: temp->value.booleanValue = $3.booleanValue; break;
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
                        }
                        else if(temp->type == Float && temptype == Integer)
                        {
                            temp->value.arrayValue.floatArray[$3.integerValue] = (float)$7.integerValue;
                        }
                        else if(temp->type == temptype)
                        {
                            
                            switch(temp->type)
                            {
                                case Integer: temp->value.arrayValue.integerArray[$3.integerValue] = $7.integerValue; break;
                                case Float: temp->value.arrayValue.floatArray[$3.integerValue] = $7.floatValue; break;
                                case String: temp->value.arrayValue.stringArray[$3.integerValue] = strdup($7.stringValue); break;
                                case Boolean: temp->value.arrayValue.booleanArray[$3.integerValue] = $7.booleanValue; break;
                            }
                            
                        }
                        else yyerror("Type unmatch");
                        temptype = Unknown;
                    }
                | expr ';' {temptype = Unknown;}
                | IF expr                               /* statment : if */
                    {
                        labelpush();
                        
                        if(temptype != Boolean)yyerror("Condition expression isn't a boolean expression");
                    } THEN 
                    {
                        fprintf(targetfile, "ifeq LFalse%d\n", cond_stack[top]);                    
                        enterscope();
                    } block_stmt 
                    {
                        fprintf(targetfile, "goto LExit%d\n", cond_stack[top]);
                        leavescope();
                    } else END IF';' 
                    {
                        temptype = Unknown;
                        fprintf(targetfile, "LExit%d:\n", cond_stack[top]);
                        fprintf(targetfile, "nop\n");
                        labelpop();
                        
                    } 
                | WHILE 
                    {
                        labelpush();
                        
                        fprintf(targetfile, "LBegin%d:\n", cond_stack[top]);
                    }expr                            /* statment : while */
                    {
                        if(temptype != Boolean)yyerror("Condition expression isn't a boolean expression");
                    } LOOP 
                    {
                        enterscope();
                        fprintf(targetfile, "ifeq LExit%d\n", cond_stack[top]);
                    } block_stmt 
                    {
                        leavescope();
                    } END LOOP ';'  
                    {
                        fprintf(targetfile, "goto LBegin%d\n", cond_stack[top]);
                        temptype = Unknown;
                        fprintf(targetfile, "LExit%d:\n", cond_stack[top]);
                        fprintf(targetfile, "nop\n");
                        labelpop();
                        
                    }
                | FOR '(' IDENTIFIER IN IVAL            /* statment : for */
                        {
                            enterscope();
                            is_global = false;
                            symbol temp = lookupsym($3.stringValue);
                            if(temp == NULL)
                            {
                                temp = insertsym($3.stringValue);
                                temp->type = Integer;
                                temp->index = index_counter;
                                temp->is_const = false;
                                index_counter++;
                            }
                            if(temp->type != Integer)yyerror("Can only be in Integer type");
                            fprintf(targetfile, "sipush %d\n", $5.integerValue);
                            if(is_global)
                            {
                                if(temp->is_const)yyerror("can't assign to a constant variable.");
                                else fprintf(targetfile, "putstatic int %s.%s\n",filename, temp->name);
                            }
                            else
                            {
                                fprintf(targetfile, "istore %d\n", temp->index);
                            }                        
                        } '.' '.' IVAL ')'
                        {
                            labelpush();
                            
                            fprintf(targetfile, "LBegin%d:\n", cond_stack[top]);
                            is_global = false;
                            symbol temp = lookupsym($3.stringValue);
                            if(is_global)
                            {
                                if(temp->is_const)yyerror("can't assign to a constant variable.");
                                else fprintf(targetfile, "getstatic int %s.%s\n",filename, temp->name);
                            }
                            else
                            {
                                fprintf(targetfile, "iload %d\n", temp->index);
                            }
                            fprintf(targetfile, "sipush %d\n", $9.integerValue);
                            fprintf(targetfile, "isub\n");
                            fprintf(targetfile, "ifeq LExit%d\n", cond_stack[top]);
                        } LOOP
                        block_stmt 
                         END LOOP ';'  
                        {
                            temptype = Unknown;
                            is_global = false;
                            symbol temp = lookupsym($3.stringValue);
                            if(is_global)
                            {
                                if(temp->is_const)yyerror("can't assign to a constant variable.");
                                else fprintf(targetfile, "getstatic int %s.%s\n",filename, temp->name);
                            }
                            else
                            {
                                fprintf(targetfile, "iload %d\n", temp->index);
                            }
                            fprintf(targetfile, "sipush 1\n");
                            if($5.integerValue < $9.integerValue)fprintf(targetfile, "iadd\n");
                            else fprintf(targetfile, "isub\n");
                            if(is_global)
                            {
                                if(temp->is_const)yyerror("can't assign to a constant variable.");
                                else fprintf(targetfile, "putstatic int %s.%s\n",filename, temp->name);
                            }
                            else
                            {
                                fprintf(targetfile, "istore %d\n", temp->index);
                            }
                            fprintf(targetfile, "goto LBegin%d\n", cond_stack[top]);
                            fprintf(targetfile, "LExit%d:\n", cond_stack[top]);
                            fprintf(targetfile, "nop\n");
                            labelpop();
                            
                            leavescope();
                        
                        }
                | RETURN expr ';' 
                    {                       
                        if(temptype != current_proc->rt_type)
                        {
                            fprintf(stderr, "error: type unmatch (%s) to (%s)\n", SymToStr(temptype), SymToStr(current_proc->rt_type));
                            yyerror("Not match");
                        } 
                        else if(temptype == None)
                        {
                            fprintf(targetfile, "return\n");
                        }
                        else
                        {
                            fprintf(targetfile, "ireturn\n");
                        }
                    } 
                | PRINT {fprintf(targetfile, "getstatic java.io.PrintStream java.lang.System.out\n");} expr ';'                       /* statment : Print */
                    {
                        switch(temptype)
                        {
                            case Integer:
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.print(int)\n"); 
                                break;
                            case Float:break;
                            case String: 
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.print(java.lang.String)\n");
                                break;
                            case Boolean: 
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.print(boolean)\n"); 
                                break;
                            default: yyerror("Can't print values of this type.");
                        }
                        temptype = Unknown;
                    }
                | PRINTLN {fprintf(targetfile, "getstatic java.io.PrintStream java.lang.System.out\n");} expr ';'                      /* statment : println */
                    {
                        switch(temptype)
                        {
                            case Integer:
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.println(int)\n"); 
                                break;
                            case Float: break;
                            case String: 
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.println(java.lang.String)\n");
                                break;
                            case Boolean: 
                                fprintf(targetfile, "invokevirtual void java.io.PrintStream.println(boolean)\n"); 
                                break;
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
                        else 
                        {
                            
                            tempint++;
                        }
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
                        else 
                        {
                            temptype = tempProc->rt_type;
                            if(tempProc->rt_type != None)fprintf(targetfile, "invokestatic %s %s.%s(", SymToStr(tempProc->rt_type),filename, tempProc->procName);
                            else fprintf(targetfile, "invokestatic void %s.%s(",filename, tempProc->procName);
                            int count = 0;
                            while(count != tempProc->para_count)
                            {
                                if(count + 1 == tempProc->para_count)
                                {
                                    fprintf(targetfile, "%s", SymToStr(tempProc->para_type[count]));
                                    break;
                                }
                                fprintf(targetfile, "%s, ", SymToStr(tempProc->para_type[count]));
                                count++;
                            }
                            fprintf(targetfile, ")\n");
                        }
                    }            
                | expr '*' {typepush(temptype);} {;} expr    /* operation * */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.integerValue = $1.integerValue * $5.integerValue;
                            temptype = Integer;
                            fprintf(targetfile, "imul\n");
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
                | expr '/' {typepush(temptype);} {;} expr      /* operation / */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.floatValue = $1.integerValue / $5.integerValue;
                            temptype = Float;
                            fprintf(targetfile, "idiv\n");
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
                | expr '+' {typepush(temptype);} {;} expr      /* operation + */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.integerValue = $1.integerValue + $5.integerValue;
                            temptype = Integer;
                            fprintf(targetfile, "iadd\n");
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
                | expr '-' {typepush(temptype);} {;} expr      /* operation - */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.integerValue = $1.integerValue - $5.integerValue;
                            temptype = Integer;
                            fprintf(targetfile, "isub\n");
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
                | expr '%' {typepush(temptype);} {;} expr      /* operation - */
                    {
                        symtype temptype2 = typepop();
                        if(temptype2 == Integer && temptype == Integer)
                        {
                            $$.integerValue = $1.integerValue % $5.integerValue;
                            temptype = Integer;
                            fprintf(targetfile, "irem\n");
                        }
                        else 
                        {
                            yyerror("Invalid type(s) for (%) operator");
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
                                case Integer: 
                                    $$.integerValue = -$2.integerValue; 
                                    temptype = Integer; 
                                    fprintf(targetfile, "ineg\n");
                                    break;
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
                            fprintf(targetfile, "iand\n");
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
                            fprintf(targetfile, "ior\n");
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
                            fprintf(targetfile, "ixor\n");
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
                            fprintf(targetfile, "isub\n");
                            fprintf(targetfile, "iflt L%d\n", label_counter);
                            label_counter++;
                            fprintf(targetfile, "iconst_0\n");
                            fprintf(targetfile, "goto L%d\n", label_counter );
                            fprintf(targetfile, "L%d:\niconst_1\n", label_counter-1);
                            fprintf(targetfile, "L%d:\n", label_counter);
                            label_counter++;
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
                            fprintf(targetfile, "isub\n");
                            fprintf(targetfile, "ifgt L%d\n", label_counter);
                            label_counter++;
                            fprintf(targetfile, "iconst_0\n");
                            fprintf(targetfile, "goto L%d\n", label_counter );
                            fprintf(targetfile, "L%d:\niconst_1\n", label_counter - 1);                            
                            fprintf(targetfile, "L%d:\n", label_counter );
                            label_counter++;
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
                            fprintf(targetfile, "isub\n");
                            fprintf(targetfile, "ifle L%d\n", label_counter);
                            label_counter++;
                            fprintf(targetfile, "iconst_0\n");
                            fprintf(targetfile, "goto L%d\n", label_counter);
                            fprintf(targetfile, "L%d:\niconst_1\n", label_counter - 1);
                            fprintf(targetfile, "L%d:\n", label_counter);
                            label_counter++;
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
                            fprintf(targetfile, "isub\n");
                            fprintf(targetfile, "ifge L%d\n", label_counter);
                            label_counter++;
                            fprintf(targetfile, "iconst_0\n");
                            fprintf(targetfile, "goto L%d\n", label_counter);
                            fprintf(targetfile, "L%d:\niconst_1\n", label_counter-1);                            
                            fprintf(targetfile, "L%d:\n", label_counter );
                            label_counter++;
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
                            fprintf(targetfile, "isub\n");
                            fprintf(targetfile, "ifeq L%d\n", label_counter);
                            label_counter++;
                            fprintf(targetfile, "iconst_0\n");
                            fprintf(targetfile, "goto L%d\n", label_counter );
                            fprintf(targetfile, "L%d:\n iconst_1\n", label_counter - 1);                            
                            fprintf(targetfile, "L%d:\n", label_counter);
                            label_counter++;
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
                            $$.booleanValue = $1.integerValue == $4.integerValue;
                            temptype = Boolean;
                            fprintf(targetfile, "isub\n");
                            fprintf(targetfile, "ifne L%d\n", label_counter);
                            label_counter++;
                            fprintf(targetfile, "iconst_0\n");
                            fprintf(targetfile, "goto L%d\n", label_counter);
                            fprintf(targetfile, "L%d:\n iconst_1\n", label_counter - 1);                            
                            fprintf(targetfile, "L%d:\n", label_counter);
                            label_counter++;
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
                | SVAL 
                    {
                        $$.stringValue = strdup($1.stringValue);
                        temptype = String;
                        fprintf(targetfile, "ldc \"%s\"\n", $1.stringValue);
                    } /* string value */
                | BVAL 
                    {
                        $$.booleanValue = $1.booleanValue; 
                        temptype = Boolean;
                        fprintf(targetfile, "iconst_%d\n", $1.booleanValue);
                    }     /* boolean value */
                | IVAL 
                    {
                        $$.integerValue = $1.integerValue; 
                        temptype = Integer; 
                        fprintf(targetfile, "sipush %d\n", $1.integerValue);
                    }    /* int value */
                | FVAL 
                    {
                        $$.floatValue = $1.floatValue; 
                        temptype = Float; 
                    }          /* float value */
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
                        is_global = false;
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
                                if(tempProc->rt_type != None)fprintf(targetfile, "invokestatic %s %s.%s()\n", SymToStr(tempProc->rt_type),filename, tempProc->procName);
                                else fprintf(targetfile, "invokestatic void %s.%s()\n",filename, tempProc->procName);
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
                                case Integer: 
                                    $$.integerValue = temp->value.integerValue; 
                                    temptype = Integer; 
                                    if(is_global)
                                    {
                                        if(temp->is_const)fprintf(targetfile, "sipush %d\n", temp->value.integerValue);
                                        else fprintf(targetfile, "getstatic int %s.%s\n",filename, temp->name);
                                    }
                                    else {fprintf(targetfile, "iload %d\n", temp->index);}
                                    break;
                                case Float: $$.floatValue = temp->value.floatValue; temptype = Float; break;
                                case Boolean: 
                                    $$.booleanValue = temp->value.booleanValue; 
                                    temptype = Boolean; 
                                    if(is_global)
                                    {
                                        if(temp->is_const)fprintf(targetfile, "iconst_%d\n", temp->value.booleanValue);
                                        else fprintf(targetfile, "getstatic int %s.%s\n",filename, temp->name);
                                    }
                                    else {fprintf(targetfile, "iload %d\n", temp->index);}
                                    break;
                                case String: 
                                    $$.stringValue = strdup(temp->value.stringValue); temptype = String; 
                                    fprintf(targetfile, "ldc \"%s\"\n", temp->value.stringValue);
                                    break;
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

vc_decl:        var_decl vc_decl                                     /* (constant) variable declaration */
                |
                ;                                         /* variable declaration */

var_decl:       IDENTIFIER                                                  /* variable declaration */
                    settype
                        {
                            symbol temp = insertsym($1.stringValue);
                            temp->type = temptype;
                            temp->is_const = false;
                            temp->is_array = false;
                            temp->index = index_counter;
                            index_counter++;
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
                                    case Integer: 
                                        temp->value.integerValue = $4.integerValue; 
                                        fprintf(targetfile, "sipush %d\n", $4.integerValue);
                                        fprintf(targetfile, "istore %d\n", temp->index);
                                        break;
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
                                fprintf(targetfile, "sipush %d\n", (int)$4.integerValue);
                                fprintf(targetfile, "istore %d\n", temp->index);
                            }
                            else {yyerror("variable declaration failed.");}
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
                    }
                ;
                    
settype:        ':'  INTEGER    {temptype = Integer;}                       /* set variable type while declaration */
                |':'  FLOAT    {temptype = Float;}
                |':'  STRING    {temptype = String;}  
                |':'  BOOLEAN    {temptype = Boolean;}             
                |   {temptype = Unknown;}
                ;

assign:         ASSIGN IDENTIFIER                                                /* set variable value while declaration */ 
                        {
                            symbol temp = lookupsym($2.stringValue);
                            if(temp == NULL) yyerror("id not found");
                            if(temp->type == None) yyerror("Assignment Failed");
                            else 
                            {
                                switch(temp->type)
                                {
                                    case Integer: $$.integerValue = temp->value.integerValue; break;
                                    case Float: $$.floatValue = temp->value.floatValue; break;
                                    case String: $$.stringValue = strdup(temp->value.stringValue); break;
                                    case Boolean: $$.booleanValue = temp->value.booleanValue; break;
                                }
                            }
                        }
                |ASSIGN IVAL
                    {
                         $$.integerValue = $2.integerValue;
                         temptype = Integer;
                    }
                |ASSIGN SVAL
                    {
                         $$.integerValue = strdup($2.stringValue);
                         temptype = String;
                    }
                |ASSIGN BVAL
                    {
                         $$.integerValue = $2.booleanValue;
                         temptype = Boolean;
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
                        index_counter = 0;
                                          
                    }
                    parameter_decl set_rt
                        {
                            if(current_proc->rt_type != None)fprintf(targetfile, "method public static %s %s(", SymToStr(current_proc->rt_type), current_proc->procName);
                            else fprintf(targetfile, "method public static void %s(", current_proc->procName);
                            int count = 0;
                            while(count != current_proc->para_count)
                            {
                                if(count + 1 == current_proc->para_count)
                                {
                                    fprintf(targetfile, "%s", SymToStr(current_proc->para_type[count]));
                                    break;
                                }
                                fprintf(targetfile, "%s, ", SymToStr(current_proc->para_type[count]));
                                count++;
                            }
                            fprintf(targetfile, ")\n");
                            fprintf(targetfile, "max_stack 15\n");
                            fprintf(targetfile, "max_locals 15\n");
                            fprintf(targetfile, "{\n");
                        } 
                    block
                        {
                            fprintf(targetfile, "}\n");
                            if(temptype == Unknown && current_proc->rt_type != None)yyerror("Not return value");
                            else if(temptype == Unknown && current_proc->rt_type == None);
                            else if(current_proc->rt_type != temptype)yyerror("Return type isn't match");
                        }
                    END IDENTIFIER ';'
                        {    
                            if(strcmp($2.stringValue, $10.stringValue) != 0) yyerror("Bad procedure name");
                            leavescope();
                        }
                    pdeclare
                |   
                ;

parameter_decl: '(' IDENTIFIER                                              /* formal parameter declaration */
                        settype
                        {
                            symbol temp = insertsym($2.stringValue);
                            temp->index = index_counter;
                            index_counter++;
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
                            temp->index = index_counter;
                            index_counter++;
                            if(temptype == Unknown)yyerror("parameter without setting type");
                            else temp->type = temptype;
                            addParaType(current_proc, temptype);
                        } 
                    parameter
                |
                ;

set_rt:         RETURN INTEGER {temptype = Integer; current_proc->rt_type = Integer; } /*ser return type */
                |RETURN FLOAT {temptype = Float; current_proc->rt_type = Float;}
                |RETURN BOOLEAN {temptype = Boolean; current_proc->rt_type = Boolean;}
                |RETURN STRING {temptype = String; current_proc->rt_type = String;}
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
    filename = strtok(argv[1], ".");
    char* savename = strdup(filename);
    strcat(savename,".jasm");
    targetfile = fopen(savename,"w+");
    /* perform parsing */
    if (yyparse() == 1)                 /* parsing */
        yyerror("Parsing error !");     /* syntax error */

    fclose(targetfile);
}