
require File.expand_path(File.dirname(__FILE__) + '/conf/aws')
require File.expand_path(File.dirname(__FILE__) + '/conf/monitor')
require File.expand_path(File.dirname(__FILE__) + '/utils/common')

ec2 = get_ec2_connection

# TODO: removes all metrics files before starting
@start_time = Time.now.to_i

while true
  # reads the list of active machines
  running_machines = File.readlines(RUNNING_MACHINES_FILE)
  
  running_machines.each do |machine|
    instance = ec2.instances[machine.chomp]
    begin
      # puts "Connecting to machine #{machine.chomp}"
      values = `ssh -o "StrictHostKeyChecking=no" -i #{PEM_FILE} ubuntu@#{instance.ip_address} 'bash -s' < metrics.sh`
      values = "#{DateTime.now.strftime(DATE_FORMAT)},#{Time.now.to_i - @start_time}," + values
      File.open("metrics/#{machine.chomp}.metrics", 'a+') { |file| file.puts(values) }
      outputs "Metrics collected in #{machine.chomp}"
    rescue SystemCallError, Timeout::Error => e
      # port 22 might not be available immediately after the instance finishes launching
      sleep 1
      retry
    end
  end
  
  # puts "Sleeping for few seconds..."
  sleep MONITOR_TIME_INTERVAL
end