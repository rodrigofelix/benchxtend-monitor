
# retrieves the list of pairs instance_id,domain of the mongodb instances
def get_mongodb_domains
  domains = Hash.new
  File.readlines(MONGODB_DOMAINS).map(&:chomp).each do |line|
    values = line.split(",")
    domains[values[0].chomp] = values[1].chomp unless line.empty?
  end
  
  return domains
end

# updates the /etc/hosts file of an instance
def update_domains(ec2, running_machines, domains)
  running_machines.each do |update_machine|
    update_instance = ec2.instances[update_machine.chomp]
    begin
      Net::SSH.start(update_instance.ip_address, "ubuntu", :keys => [File.dirname(__FILE__) + '/../' + PEM_FILE]) do |ssh| 
        domains.each do |key, domain|
          if running_machines.include?(key)
            instance = ec2.instances[key]
            ssh.exec!("sudo sed -i -e 's/.* #{domain}/#{instance.private_ip_address} #{domain}/g' /etc/hosts")
          else
            # comments the line since the machine is not running
            ssh.exec!("sudo sed -i -e 's/.* #{domain}/#0.0.0.0 #{domain}/g' /etc/hosts")
          end
        end
      end
    rescue SystemCallError, Timeout::Error => e
      # port 22 might not be available immediately after the instance finishes launching
      sleep 1
      retry
    end
  end
end

