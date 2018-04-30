#!/usr/bin/env ruby

require 'set'
require './pattern'
require './parse'

# Something about disorderly folds... physical map reduce...

# This'd be nicer with a jump table or whatnot :)
def unArithmetic data, bindings
  if data.class == Array and
     data.length > 0
    if data[0] == :op and data.length == 4
      op = unArithmetic(data[2], bindings)
      l = unArithmetic(data[1], bindings)
      r = unArithmetic(data[3], bindings)
      case op
      when '+' then l.to_f + r.to_f
      when '-' then l.to_f - r.to_f
      when '&' then l and r
      when '|' then l or r
      when '/' then l.to_f / r.to_f
      when '%' then l.to_f % r.to_f
      when '*' then l.to_f * r.to_f
      when '=' then l == r
      when '<' then l.to_f < r.to_f
      when '>' then l.to_f > r.to_f
      when '~' then l != r
      when '.' then "#{l}#{r}"
      end
    else
      data.map {|a| unArithmetic a, bindings}
    end
  else
    if bindings[data]
      bindings[data]
    else
      data
    end
  end
end

def evaluate body_data, body_combiners, bindings
  # take the body, eval arithmetic
  # then produce combiners and data
  [if body_data then unArithmetic(body_data, bindings) else [] end, body_combiners]
end

def pickData combiner, data
  potentialCombiners = $namedCombiners[combiner]
  return nil if not potentialCombiners
  potentialCombiners.each do |combiner|
    out = []
    bindings = {} # we need to make this fold over all the successful matches (but not the unsuccessful ones)
    datap = data.clone
    elements = combiner[2]
    elements.each do |pattern|
      if pattern[0] == :negate
        existing = data.select {|a| match(a, pattern[1])}
        next if existing.length != 0
        out << pattern
      else
        potentials = datap.select {|a| match(a, pattern)}
        next if potentials.length == 0
        selected = potentials[rand(potentials.length)]
        out << selected # replace this and the following line with nicer hash merge / removal
        datap.delete_at(datap.find_index(selected)) 
      end
    end
    bindings = match out, elements
    next if not bindings
    if combiner[3][1].length > 0
      next if not unArithmetic(combiner[3][1], bindings)
    end
    return (
      (out.length == elements.length and bindings) and
        [combiner, datap, bindings]
    )
  end
  nil
end

def remove array, index
  if index == 0 
    array[1..array.length]
  else
    array[0..index-1] + array[index+1..array.length]
  end
end

def pick data, combiners
  # pick a combiner / data that works for it (ex: fulfills pattern and guard)
  # [combiner, bindings, data', combiners']
  return nil if combiners.length < 1
  i = rand combiners.length 
  combiner, datap, bindings = pickData combiners[i], data
  return nil if not combiner
  [combiner, bindings, datap, remove(combiners, i)]
end

def matchingInput line, inputs
  # finds a matching input and returns its bindings
  matching = inputs.select {|input| input[2].match(line)}
  return nil if matching.length == 0
  [matching[0],
   (matching[0][2].match(line)
     .to_a[1..-1]
     .inject([1, {}]) do |a, b|
       b = b.to_f if b == "0" or b.to_f != 0.0
       a[1]["$#{a[0]}"] = b
       [a[0] + 1, a[1]]
     end
   )[1]]
end

def step data, combiners, inputs
  begin
    line = $stdin.read_nonblock(4096)
    line.split(/\n/).inject([data, combiners]) do |out, line|
      input, bindings = matchingInput(line, inputs)
      addedData, addedCombiners = evaluate input[3][1], input[3][2], bindings
      [out[0] + addedData, out[1] + addedCombiners]
    end
  rescue
    combiner, bindings, datap, combinersp = pick data, combiners
    return nil if not combiner
    addedData, addedCombiners =
      if combiner[1][:type] == :eval
        toEval = combiner[4]
        bindings.each {|k, v| toEval = toEval.gsub(k, v.to_s)}
        eval(toEval)
        [[], []]
      else
        evaluate combiner[4], combiner[5], bindings
      end
    [datap + addedData, combinersp + addedCombiners]
  end
end

program = parse(
  if ARGV.length == 1
    IO.read(ARGV[0])
  else
    $stdin.read
  end
)

$namedCombiners = {}
temp = program.select {|e| e and e.length > 1 and e[0] == :combiner}
temp.each do |c|
  if $namedCombiners[c[1][:name]] 
    $namedCombiners[c[1][:name]] << c
  else
    $namedCombiners[c[1][:name]] = [c]
  end
end

combiners = program.select {|e| e and e.class != Array and e != ""}
data = program.select {|e| e and e.length > 1 and e[0] == :tuple}
inputs = program.select {|e| e and e.length > 1 and e[0] == :input}

while true do
  res = step(data, combiners, inputs)
  if res
    data, combiners = res
  end
end

