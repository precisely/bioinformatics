# This script is meant to avoid hammering the output with repeating lines. When
# it detects that it just printed a line of output, it does not print it again.
# Instead, it counts the number of times the line has repeated and prints that
# number instead.

BEGIN {
   prev = "";
   repeats = 0;
}

!NF { print; next; };

$0 == prev {
   repeats += 1;
   prev = $0;
   next;
}

$0 != prev {
   if (repeats > 0) {
      print " ---> repeats:", repeats+1;
   }
   print;
   prev = $0;
   repeats = 0;
}
