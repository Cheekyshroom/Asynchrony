{a};
{a};
{a};
{remove};
remove;

{count, 0};

remove({remove}, {count, N}, !{a}) ->
    {print, ("removal is done: " . N)}
  : quit
  | print;

remove({remove}, {a}, {count, N}) ->
    {print, "removed one"}
  | {remove}
  | {count, N + 1}
  : remove
  | print;

print({print, Data}) ->
  [puts 'Data'];

quit(!{a}, !{print, _}) -> [exit];
