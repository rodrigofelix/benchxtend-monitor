# file with general auxiliary functions

require 'net/http'
gem 'net-ssh', '~> 2.1.4'
require 'net/ssh'

# prints a standard date before an output
def outputs(value)
  puts Time.now.strftime("[%d/%m/%Y %H:%M:%S]") + " " + value
end

def get_ec2_connection
  ec2 = AWS::EC2.new
  key_pair = ec2.key_pairs[KEYS_PAIR_NAME]
  
  outputs "Generated keypair #{key_pair.name}, fingerprint: #{key_pair.fingerprint}" if DEBUG

  # open SSH access
  group = ec2.security_groups[SECURITY_GROUP_ID]
  begin
    group.authorize_ingress(:tcp, 22, "0.0.0.0/0")
  rescue
  end
  
  outputs "Using security group: #{group.name}" if DEBUG
  
  return ec2
end

# removes an entry from a file and adds it in other file
def update_machine_files(instance_id, operation)
  add_to = (operation == "add") ? RUNNING_MACHINES_FILE : STOPPED_MACHINES_FILE
  remove_from = (operation == "add") ? STOPPED_MACHINES_FILE : RUNNING_MACHINES_FILE
 
  open(add_to, 'a') do |f|
    f.puts instance_id
  end
  
  lines = File.readlines(remove_from).map(&:chomp)
  open(remove_from, 'w') do |f|
    lines.each do |line|
      f.puts line unless line == instance_id
    end
  end
end

# saves in a file the number of machines running at the moment this function is called
def log_running_machines(machines, affected_machine)
  File.open(LOG_FILE, 'a+') do |file| 
    file.puts("#{DateTime.now.strftime(DATE_FORMAT)},#{Time.now.to_i - @start_time},#{machines},#{affected_machine}")
  end
end