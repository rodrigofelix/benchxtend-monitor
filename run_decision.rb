require 'decision.rb'

# reads argument to define it is going to be executed automatically or manually
automatic = true
if ARGV[0] && ARGV[0] == 'manual'
  puts "Script set to run in manual mode"
  automatic = false
  
  if ARGV[1] 
    if ARGV[1] == "add"
      add
    elsif ARGV[1] == "remove"
      remove
    end
  end
end

# calls the me"thod run until the user stops the script
while automatic
  sleep DECISOR_TIME_INTERVAL
  run
end