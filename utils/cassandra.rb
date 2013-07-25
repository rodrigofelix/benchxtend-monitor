
# calculate cassandra tokens given a number of nodes
def calculate_tokens(nodes)
  result = []
  for i in 0..(nodes-1)
    result << 2 ** 127 / nodes * i
  end
  return result
end

# update cassandra tokens of running machines
def update_tokens(machines, tokens, exceptions)
  ec2 = get_ec2_connection
  
  # connects to each running machine and updates their tokens using nodetool move
  machines.each_index do |i|
    instance = ec2.instances[machines[i]]
    unless exceptions.include? i
      begin
        Net::SSH.start(instance.ip_address, "ubuntu", :keys => [File.dirname(__FILE__) + '/../' + PEM_FILE]) do |ssh| 
          outputs "Changing token of #{machines[i]}"
          ssh.exec!("/home/ubuntu/cassandra/bin/nodetool move #{tokens[i]}")
          outputs "[OK] Token of #{machines[i]} successfully set to #{tokens[i]}"

          outputs "Cleaning up #{machines[i]}"
          ssh.exec!("/home/ubuntu/cassandra/bin/nodetool cleanup")
          outputs "Clean up of #{machines[i]} successfully finished"
        end
      rescue SystemCallError, Timeout::Error => e
        # port 22 might not be available immediately after the instance finishes launching
        sleep 1
        retry
      end
    end
  end
end

# updates the list of hosts used by Cassandra DB Binding of BenchXtend
def update_benchxtend(ec2, hosts)
  instance = ec2.instances[BENCHXTEND_INSTANCE_ID]
  
  # opens ssh connection
  begin
    Net::SSH.start(instance.ip_address, "ubuntu", :keys => [File.dirname(__FILE__) + '/../' + PEM_FILE]) do |ssh|
      outputs "Updates the list of hosts in the workload properties file of BenchXtend"
      # TODO: receiving the workload file as a parameter instead of hard-coded
      ssh.exec!("sed -i -e 's/hosts=.*/hosts=#{hosts.map {|x| ec2.instances[x].private_ip_address}.join(',')}/g' #{WORKLOAD}")
      outputs "[OK] Hosts successfully updated"
    end
  rescue SystemCallError, Timeout::Error => e
    # port 22 might not be available immediately after the instance finishes launching
    sleep 1
    retry
  end
end