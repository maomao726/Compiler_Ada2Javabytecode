
/* token value */
typedef struct Arr
{
    int length;
    union {
        int* integerArray;
        double* floatArray;
        char** stringArray;
        bool* booleanArray;
    };
} Array;

typedef struct token
{
    union {
        int integerValue;
        double floatValue;
        char* stringValue;
        bool booleanValue;
        Array arrayValue;
    } ;
} tokenValue;

typedef enum symtype symtype;
enum   symtype {
    Integer,
    Float,
    String,
    Boolean,
    Procedure,
    Unknown,
    None
}; 

 typedef struct proc_info
    {
        char* procName;
        symtype rt_type;
        int para_count;
        symtype para_type[100];
        struct proc_info* next;
    }* procInfo;
extern int linenum;
