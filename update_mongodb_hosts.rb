require File.expand_path(File.dirname(__FILE__) + '/conf/aws')
require File.expand_path(File.dirname(__FILE__) + '/conf/monitor')
require File.expand_path(File.dirname(__FILE__) + '/utils/common')
require File.expand_path(File.dirname(__FILE__) + '/utils/mongodb')

ec2 = get_ec2_connection
running_machines = File.readlines(RUNNING_MACHINES_FILE).map(&:chomp)
domains = get_mongodb_domains

# updates /etc/hosts of just added nodes
outputs "Updating /etc/hosts of all running machines"
update_domains(ec2, running_machines, domains)
outputs "[OK] /etc/hosts successfully updated"