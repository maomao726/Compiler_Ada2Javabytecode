scanner: header.h project1.l project2.y 
	bison -d -y project2.y
	lex project1.l
	gcc lex.yy.c y.tab.c -ll -ly

clean: 
	rm -f lex.yy.c y.tab.h y.tab.c
