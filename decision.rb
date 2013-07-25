# Decision Taker - BenchXtend
#
# this scripts reads monitoring files and take decisions
# to add or remove new machines on the EC2 cluster
# 
# Created by Rodrigo Felix
# Created at Feb 14th, 2013

require File.expand_path(File.dirname(__FILE__) + '/conf/aws')
require File.expand_path(File.dirname(__FILE__) + '/conf/monitor')
require File.expand_path(File.dirname(__FILE__) + '/utils/common')
require File.expand_path(File.dirname(__FILE__) + '/utils/cassandra')
require File.expand_path(File.dirname(__FILE__) + '/utils/mongodb')

def check_requisites
  ec2 = get_ec2_connection
  
  # checks if the benchxtend machine is running
  if ec2.instances[BENCHXTEND_INSTANCE_ID].status != :running
    outputs "Benchxtend is not running!"
    exit 1
  end
  
  # TODO: includes a confirmation if it was set the seeds IPs in the hosts
  # property in the Benchxtend machine
  
  if DATABASE_TYPE == "mongodb"
    
  elsif DATABASE_TYPE == "cassandra"
    # checks if seeds are running
    seeds = File.readlines(File.dirname(__FILE__) + '/' + CASSANDRA_SEEDS).map(&:chomp)
    seeds.each do |seed|
      if ec2.instances[seed].status != :running
        outputs "Seed #{seed} is not running!"
        exit 1
      end
    end
    
    # TODO: checks if properties are set on the seeds
    
    # TODO: checks if cassandra is running on the seeds
    
    # TODO: checks if the keyspace and column family are created
  end
end

def run

  # auxiliary variables to decide if adding or removing machines
  add_machines = 0
  remove_machines = 0
  
  # reads the list of active machines
  running_machines = File.readlines(RUNNING_MACHINES_FILE).map(&:chomp)

  # reads all files of metrics, considering that all are 
  # related to the same cluster
  Dir.glob('metrics/*.metrics') do |file|
    # gets last 10 metrics gathered
    lines = `tail -n 10 #{file}`

    cpu_counter = 0
    # memory_counter = 0

    last_values = lines.split("\n")
    last_values.each do |line|
      metrics = line.split(",")
   
      if metrics.count == 4 
        # increases the counter if the machine is overloaded
        cpu_counter += 1 if metrics[2].to_f > MAX_CPU
        # memory_counter += 1 if metrics[3].to_f > MAX_MEMORY

        # decreases the counter if the machine is idle
        cpu_counter -= 1 if metrics[2].to_f < MIN_CPU
        # memory_counter -= 1 if metrics[3].to_f < MIN_MEMORY
      else
        outputs "Wrong entry in file #{file}: #{line}"
      end
    end

    # takes a preliminary decision on adding or removing a machine
    # considering the individual metrics of a single machine
    if cpu_counter >= 7 # || memory_counter >= 7
      add_machines += 1
    elsif cpu_counter <= -7 # || memory_counter <= -7
      remove_machines += 1
    end
  end

  # takes the decision after analyzing all metrics files
  if add_machines >= (running_machines.count * 0.5)
    outputs "Decided to add 1 machine"
    if running_machines.count == MAX_MACHINES
      outputs "[WARNING] Cannot add machine since the maximum amount was reached"
    else 
      outputs "Starting adding process..."
      add
    end
  end

  if remove_machines >= (running_machines.count * 0.5)
    outputs "Decided to remove 1 machine"
    if running_machines.count == MIN_MACHINES
      outputs "[WARNING] Cannot remove machine since the minimum amount was reached"
    else
      outputs "Starting removing process..."
      remove
    end
  end

  # otherwise
  if add_machines < (running_machines.count * 0.5) && remove_machines < (running_machines.count * 0.5)
    outputs "No need to add or remove machines"
  end
end

def add
  # auxiliary aws variables
  instance = nil
  
  # gets the list of stopped machines
  stopped_machines = File.readlines(STOPPED_MACHINES_FILE).map(&:chomp)

  ec2 = get_ec2_connection

  # gets the first stopped machine, if there is one
  unless stopped_machines.count == 0
    instance = ec2.instances[stopped_machines[0]]

    unless instance.status == :running
      instance.start

      sleep 5 while instance.status != :running
      outputs "Launched instance #{instance.id}, status: #{instance.status}"
    end
      
    # updates the files containing running and stopped machines
    update_machine_files(instance.id, "add")
      
    # reloads list of running machines
    running_machines = File.readlines(RUNNING_MACHINES_FILE).map(&:chomp)
    
    # saves the number of machines running at this moment
    log_running_machines(running_machines.size, instance.id)
    
    if DATABASE_TYPE == "mongodb"
      domains = get_mongodb_domains
      
      begin
        Net::SSH.start(instance.ip_address, "ubuntu", :keys => [File.dirname(__FILE__) + '/' + PEM_FILE]) do |ssh|
          # stops mongodb service, if it is running
          outputs "Stopping mongodb of #{instance.ip_address}"
          ssh.exec!("sudo service mongodb stop")
          outputs "[OK] mongodb stopped"
          
          # remove all data stored in the node
          outputs "Removing data"
          ssh.exec!("sudo rm #{MONGODB_DATA_PATH}/ycsb*")
          outputs "[OK] data successfully removed"
          
          # updates /etc/hosts of just added nodes
          outputs "Updating /etc/hosts of all running machines"
          update_domains(ec2, running_machines, domains)
          outputs "[OK] /etc/hosts successfully updated"
          
          # start mongodb service
          outputs "Starting mongodb of #{instance.ip_address}"
          ssh.exec!("sudo service mongodb start")
          outputs "[OK] mongodb started"
        end
        
        # saves the number of machines running at this moment
        log_running_machines(running_machines.size, instance.id)
      rescue SystemCallError, Timeout::Error => e
        # port 22 might not be available immediately after the instance finishes launching
        sleep 1
        retry
      end
      
    elsif DATABASE_TYPE == "cassandra"
      # retrieves list of seeds
      seeds_ids = File.readlines(File.dirname(__FILE__) + '/' + CASSANDRA_SEEDS).map(&:chomp)
      
      # array to store the IPs of the seeds
      seeds = Array.new
      
      # gets the seeds IPs, considering they are already running
      seeds_ids.each do |id|
        if ec2.instances[id].status == :running
          seeds << ec2.instances[id].private_ip_address 
        else
          outputs "[ERROR] Seed #{id} is not running"
        end
      end

      if seeds.count > 0
        # commented since this is necessary only for cassandra < 1.2
        # if you are testing cassandra < 1.2 uncomment the following lines
        
        # calculate the new tokens since a new machine was added
        # tokens = calculate_tokens(running_machines.count)
        
        # if(running_machines.count == 3)
        #   token = calculate_tokens(running_machines.count + 1)[1]
        # elsif(running_machines.count == 4)
        #   token = calculate_tokens(running_machines.count).last
        # end
          
        # opens ssh connection
        begin
          Net::SSH.start(instance.ip_address, "ubuntu", :keys => [File.dirname(__FILE__) + '/' + PEM_FILE]) do |ssh|
            outputs "Remove all data stored in the Cassandra node"
            ssh.exec!("rm -Rf /var/lib/cassandra/data/*")
            ssh.exec!("rm -Rf /var/lib/cassandra/commitlog/*")
            ssh.exec!("rm -Rf /var/lib/cassandra/saved_caches/*")
            outputs "[OK] All data successfully removed"
              
            outputs "Setting seeds on cassandra.yml"
            ssh.exec!("sed -i -e 's/- seeds: .*/- seeds: \"#{seeds.join(',')}\"/g' /home/ubuntu/cassandra/conf/cassandra.yaml")
            outputs "[OK] seeds successfully set"

            outputs "Setting listen_address on cassandra.yml"
            ssh.exec!("sed -i -e 's/listen_address: .*/listen_address: #{instance.private_ip_address}/g' /home/ubuntu/cassandra/conf/cassandra.yaml")
            outputs "[OK] listen_address successfully set"
            
            # commented since this is necessary only for cassandra < 1.2
            # if you are testing cassandra < 1.2 uncomment the following lines
            # outputs "Setting initial_token on cassandra.yml"
            # ssh.exec!("sed -i -e 's/initial_token: .*/initial_token: #{token}/g' /home/ubuntu/cassandra/conf/cassandra.yaml")
            # outputs "[OK] initial_token successfully set"

            outputs "Starting cassandra..."
            ssh.exec!("/home/ubuntu/cassandra/bin/cassandra") { |ch, stream, data| outputs data }
            outputs "[OK] Cassandra successfully started"

            # saves the number of machines running at this moment
            log_running_machines(running_machines.size, instance.id)
            
            # lets benchxtend know about the new machine
            update_benchxtend(ec2, running_machines)
            
            # update cassandra tokens except first one and last one
            # update_tokens(running_machines, tokens, [0, running_machines.count - 1])            
          end
        rescue SystemCallError, Timeout::Error => e
          # port 22 might not be available immediately after the instance finishes launching
          sleep 1
          retry
        end
      else
        outputs "[ERROR] No seed is running or was set in the #{CASSANDRA_SEEDS} file"
      end
    end
  else
    outputs "[WARNING] A machine was requested to be add, but there is no available one."
  end
  
  outputs "Machine added"
end

def remove
  # auxiliary aws variables
  instance = nil
  
  # reads the list of active machines
  running_machines = File.readlines(RUNNING_MACHINES_FILE).map(&:chomp)
  
  # gets the list of cassandra seeds
  seeds = File.readlines(File.dirname(__FILE__) + '/' + ((DATABASE_TYPE == "cassandra") ? CASSANDRA_SEEDS : MONGODB_SEEDS)).map(&:chomp)
    
  # remove the seeds to not to be stopped
  available_to_remove = running_machines - seeds

  ec2 = get_ec2_connection
    
  unless running_machines.count <= 0 || available_to_remove.count <= 0
    # selects a random node, that is not a seed, to be removed
    instance = ec2.instances[available_to_remove.choice]
  else
    outputs "[WARNING] A machine was requested to be removed, but there is no available one."
    return 
  end
  
  if DATABASE_TYPE == "mongodb"
    begin
      Net::SSH.start(instance.ip_address, "ubuntu", :keys => [File.dirname(__FILE__) + '/' + PEM_FILE]) do |ssh|
        # saves the number of machines running at this moment
        log_running_machines(running_machines.size, instance.id)
        
        # stops mongodb service, if it is running
        outputs "Stopping mongodb of #{instance.private_ip_address}"
        ssh.exec!("sudo service mongodb stop")
        outputs "[OK] mongodb stopped"
      end
    rescue SystemCallError, Timeout::Error => e
      # port 22 might not be available immediately after the instance finishes launching
      sleep 1
      retry
    end

    unless instance.status == :stopped
      instance.stop

      # updates the files containing running and stopped machines
      update_machine_files(instance.id, "remove")

      # reloads list of running machines
      running_machines = File.readlines(RUNNING_MACHINES_FILE).map(&:chomp)
        
      sleep 5 while instance.status != :stopped
      outputs "Stopped instance #{instance.id}, status: #{instance.status}"
    end
      
    # saves the number of machines running at this moment
    log_running_machines(running_machines.size, instance.id)

  elsif DATABASE_TYPE == "cassandra"
    begin
      Net::SSH.start(instance.ip_address, "ubuntu", :keys => [File.dirname(__FILE__) + '/' + PEM_FILE]) do |ssh|
        # saves the number of machines running at this moment
        log_running_machines(running_machines.size, instance.id)
        
        # lets benchxtend know in advance about the machine to be removed, considering 
        # the machine is going to be removed correctly. this may minimize the number of
        # threads from benchxtend that will try to send queries to a machine that is already removed
        update_benchxtend(ec2, (running_machines - [instance.id]))
        
        outputs "Decomissions the node"
        ssh.exec!("/home/ubuntu/cassandra/bin/nodetool decommission") { |ch, stream, data| outputs data }
        outputs "[OK] Node successfully decommissioned"
      end
    rescue SystemCallError, Timeout::Error => e
      # port 22 might not be available immediately after the instance finishes launching
      sleep 1
      retry
    end
      
    unless instance.status == :stopped
      instance.stop

      # updates the files containing running and stopped machines
      update_machine_files(instance.id, "remove")

      # reloads list of running machines
      running_machines = File.readlines(RUNNING_MACHINES_FILE).map(&:chomp) 
      
      sleep 5 while instance.status == :stopping
      outputs "Stopped instance #{instance.id}, status: #{instance.status}"
    end
      
    # saves the number of machines running at this moment
    log_running_machines(running_machines.size, instance.id)  
  end
  
  # renames the metrics of the removed machine not to be 
  # considered by the decision maker anymore
  `mv metrics/#{instance.id}.metrics metrics/#{instance.id}.metrics.#{Time.now.to_i.to_s}`
  
  outputs "Machine removed"
end

# sets the start timestamp
@start_time = Time.now.to_i

# checks if preliminary conditions are being satisfied
# check_requisites

# creates log file and writes the start time
File.open(LOG_FILE, 'a+') { |file| file.puts("Start time,#{DateTime.now.strftime(DATE_FORMAT)},#{@start_time}") }
