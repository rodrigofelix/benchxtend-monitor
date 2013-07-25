def tokens(nodes)
  result = Array.new
  for i in 0..(nodes-1)
    result.push(2 ** 127 / nodes * i)
  end
  return result
end

if ARGV.count < 1
  puts "ERROR: number of nodes must be provided"
  exit
end

result = tokens(ARGV[0].to_i)
result.each do |token|
  puts token
end
