#!/usr/bin/env ruby

#
# Please don't look at this file
#
# Please :)

require 'set'
require './pattern'

def tuple? s
  / *({.*}) */.match(s)
end

def input? s
  /\/([^\/]+)\/ *(->|=>) *(.+) */.match(s)
end

def combiner? s
  / *([^(]+)\(([^)]*)\) *((?:when .+?->)|(?:->)) *(.+)/.match(s)
end

def op? s
  / *(\(.*\)) */.match(s) or
    /(?: *(.*) *(\+|\-|\*|\/|=) *(.*))/.match(s)
end

def parseRec s, i = 0, start = '{', terminator = '}', seperator = ',', marker = :tuple
  out = []
  ci = i
  mi = i
  negate = false
  while ci < s.length
    if s[ci] == '!'
      negate = true
    elsif s[ci] == start
      res, ni = parseRec s, ci + 1
      if negate
        out << [:negate, [marker, res]]
      else
        out << [marker, res]
      end
      mi = ni+1
      ci = ni
    elsif s[ci] == terminator
      if s[mi..ci-1] != ""
        out << parseExpr(s[mi..ci-1].gsub(/ */, ''), 0)
      end
      return [out, ci]
    elsif s[ci] == seperator
      if s[mi..ci-1] != ""
        out << parseExpr(s[mi..ci-1].gsub(/ */, ''), 0)
      end
      mi = ci+1
    end
    ci += 1
  end
  [out, ci]
end

def parseGuard s, conversion = {}
  if s == '->'
    [:guard, []]
  else
    condition = /when *(.*)\->/.match(s)[1]
    [:guard, usage_from_pnf(parseExpr(condition), conversion)]
  end
end

def parseBody s, conversion = {}
  data, combiners = s.split(/: */)
  data = data.split(/ *\| */).map {|d| parseExpr(d)}
  [:body,
   usage_from_pnf(data, conversion),
   usage_from_pnf(if combiners then combiners.split(/, */).map {|c| parseExpr(c)} else [] end, conversion)]
end

$ops = Set.new ['+', '-', '&', '|', '!', '~', '/', '%', '*', '=', '.']
def parseOp s, i = 0
  s = s.gsub(/ */, '')
  out = []
  ci = i
  while i < s.length
    case s[i]
    when '('
      a, ni = parseOp(s, i + 1)
      i = ni + 1
      ci = ni + 1
      out << a
    when ')'
      out << parseExpr(s[ci..i-1]) if s[ci..i-1] != ""
      break
    else
      if $ops.include? s[i]
        out << parseExpr(s[ci..i-1]) if s[ci..i-1] != ""
        out << s[i]
        ci = i+1
      elsif i == s.length - 1
        out << parseExpr(s[ci..i]) if s[ci..i] != ""
      end
      i += 1
    end
  end
  if out.length == 1
    [*out, i]
  else
    [[:op] + out, i]
  end
end

def parseExpr s, l=0
  input = input? s
  combiner = combiner? s
  tuple = tuple? s
  op = op? s
  if input
    [:input, {type: if input[2] == '->' then :quiet else :loud end},
             Regexp.new(input[1]),
             parseBody(input[3])]
  elsif combiner
    data = {:name => combiner[1], :type => :normal}
    params, conversion = to_pnf(parseRec(combiner[2])[0])
    guards = parseGuard(combiner[3], conversion)
    evalBody = /\[(.+)\]/.match(s)
    if evalBody
      # if this combiner evaluates arbitrary ruby
      data[:type] = :eval
      body = body_usage_from_pnf(evalBody[1], conversion)
      [:combiner, data, params, guards, body, []]
    else
      body = parseBody(combiner[4], conversion)
      newCombiners = (body[2].map {|b| b.split(/ *\| */)}).flatten
      [:combiner, data, params, guards, if body[1] == "" then nil else body[1] end, newCombiners]
    end
  elsif tuple
    if l == 0
      parseRec(s)[0][0]
    else
      parseRec(s)[0]
    end
  elsif op
    parseOp(s)[0]
  elsif /string([0-9]+)/.match(s)
    $literals[/string([0-9]+)/.match(s)[1].to_i]
  else
    if /,/.match(s)
      s.split(/, */)
    else
      if s.to_f != 0.0
        s.to_f
      elsif s == '0'
        s.to_f
      else
        s
      end
    end
  end
end

def parse s
  out = []
  s = " " + s

  $literals = {}
  strings = s.scan(/"([^"]*)"/).map {|e| e[0]}

  strings.each {|c|
    s.gsub!(/"#{c}"/, "string#{$literals.keys.length}")
    $literals[$literals.keys.length] = c
  }

  s.gsub!(/^#.*$/, ' ')
  s.gsub!(/\n/, ' ')
  s.gsub!(/ +/, ' ')
  toplevel = s.split(';')
  toplevel.each do |expr|
    if expr != "" and expr[0] != '#'
      out << parseExpr(expr[1, expr.length])
    end
  end
  out
end
