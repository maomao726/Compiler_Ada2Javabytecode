{ This test program computes the Nth Fibonacci number
    using recursion and iteration. }

program computeFib

-- global variables
declare
  n: constant := 8;

-- iterative function
procedure itFibonacci (n: integer) return integer
declare
  Fn: integer;
  FNminus1: integer;
  temp: integer;

begin
  Fn := 1;
  FNminus1 := 1;
  if (Fn > 2) then
    begin
      while (n > 2) loop
    begin
      temp := Fn;
      Fn := Fn + FNminus1;
      FNminus1 := temp;
      n := n - 1;
    end;
      end loop;
    end;
  else
    begin
      if (Fn = 1) then
         print "Fn = 1";
      end if;
    end;
  end if;
  return Fn;
end;
end itFibonacci;

-- main program 
begin
  print "N: ";
  println n;
  print "Result of iterative computation:";
  println itFibonacci(n);
  println 5 % 2 * 30 + 2 * 3;
end;
end computeFib