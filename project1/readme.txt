(1)symbol table儲存方式
	本作業中symbol table的儲存方式為hash table，id進到hash()得到key，並以linked list存入table中。故在印出時只會印出key，並依照存入對應linked list的順序印出id。如：key 10: n, fn,，代表在symbol table中"10"這個key有n以及fn兩個id。
	在這份作業中key的範圍為0~19。

(2)檔案開啟方式
	這份作業是將欲開啟的檔名作為main()的參數傳入，故須在以指令開啟時同時打上檔名，若沒有附上檔案，則會進入逐行分析的一般模式。另外，本作業一次只能開啟一個檔案，即使附上了多個檔案也只會讀入第一個檔案做分析。

	若想進入逐行分析模式，請輸入：./scanner
	若想分析某檔案，請輸入：./scanner [filename]