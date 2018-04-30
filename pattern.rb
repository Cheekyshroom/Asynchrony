#!/usr/bin/env ruby

class String
  def lower?
    self.downcase == self
  end
end

# match a, pattern => bindings | false
def match a, pattern, out = {}
  return false if a.length != pattern.length
  pattern.length.times do |i|
    if pattern[i].class == Array
      if a[i].class == Array
        res = match a[i], pattern[i], out
        return false if not res
      else
        return pattern[i][0] == :op
      end
    else
      if not (pattern[i].class == Symbol or pattern[i].lower?) or
          pattern[i] == '_' or
          /\$/.match(pattern[i])
        if out[pattern[i]] and pattern[i] != '_'
          return false if a[i] != out[pattern[i]]
        else
          out[pattern[i]] = a[i]
        end
      else
        return false if a[i] != pattern[i]
      end
    end
  end
  return out
end

# pattern, [count] => pattern, conversion, count
def to_pnf pattern, conversions = {}, count = 0
  p = pattern.map do |e|
    if e.class == Array
      res, conversionsp, i = to_pnf e, conversions, count
      conversions = conversionsp
      count = i
      res
    else
      if not (e.class == Symbol or e.lower?) or
          e == '_' or
          /\$/.match(e)
        if not conversions[e]
          conversions[e] = "P_#{count}"
          count += 1
        end
        conversions[e]
      else
        e
      end
    end
  end
  [p, conversions, count]
end

def usage_from_pnf usage, conversions
  usage.map do |e|
    if e.class == Array
      usage_from_pnf e, conversions
    else
      if conversions[e] then conversions[e] else e end
    end
  end
end

def body_usage_from_pnf body, conversions
  body = body.clone
  conversions.each do |k, v|
    body.gsub! k, v
  end
  body
end
