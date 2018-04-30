# A little stack based calculator, not written the best
# (And mainly just written to see if we could write linked matches
#  on linked lists nicely)

{stack, {null}};

/EOF/ -> {read};
/\+/ -> {instruction, add}:add;
/\-/ -> {instruction, sub}:sub;
/swap/ -> {instruction, swap}:swap;
/pop/ -> {instruction, pop}:pop;
/disp/ -> {instruction, display}:display;
/push *([^ ]+) */ -> {instruction, {push, $1}}:push;

add({instruction, add}, {stack, {A, {B, Next}}}) ->
  {stack, {A + B, Next}};

sub({instruction, sub}, {stack, {A, {B, Next}}}) ->
  {stack, {A - B, Next}};

swap({instruction, swap}, {stack, {A, {B, Next}}}) ->
  {stack, {B, {A, Next}}};

pop({instruction, pop}, {stack, {Top, Next}}) ->
    {stack, Next}
  | {print, ("Top is: " . Top)}
  : print;

push({instruction, {push, N}}, {stack, Old}) ->
  {stack, {N, Old}};

display({stack, Old}, {instruction, display}) ->
    {stack, Old}
  | {print, {stack, Old}}
  : print;

print({print, Data}) ->
  [puts 'Data'];

finish({read}, {stack, Data}, !{instruction, _}) ->
    {print, ("Result stack is: " . Data)}
  | {quit}
  : quit 
  | print;

finish;

/quit/ -> {quit}:quit;
quit({quit}, !{print, _}) -> [exit];
