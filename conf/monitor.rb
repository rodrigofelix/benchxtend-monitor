# flag to enable some debug messages
DEBUG = false

# minimum amount of machines that must be on at any time
# for cassandra, it is advisable to set this number equals to seeds number
MIN_MACHINES = 3

# maximum amount of machines running at same time
# important to set this if you have limitations in your environment
MAX_MACHINES = 10

# log file to store number of machines in each moment
LOG_FILE = 'logs/' + Time.now.to_i.to_s + '.log'

# maximum usage values (from 0 to 1) for these resources
MAX_CPU = 0.6
MAX_MEMORY = 0.6

# maximum usage values (from 0 to 1) for these resources
MIN_CPU = 0.2
MIN_MEMORY = 0.2

# format used in the log (advisable not to change)
DATE_FORMAT = "%d/%m/%Y %H:%M:%S"

# time in seconds to call the monitor (advisable not to change)
MONITOR_TIME_INTERVAL = 5

# time in seconds to call the decisor (advisable to be 10x the monitor time)
DECISOR_TIME_INTERVAL = 60

# time in seconds decisor will sleep after adding or removing a machine
CHANGE_CLUSTER_INTERVAL = 60

# path to the workload file used by the BenchXtend
WORKLOAD = "/home/ubuntu/configs/workload3"

# type of database to be started when a machine is added
# possible types: cassandra, mongodb
DATABASE_TYPE = "mongodb"

if DATABASE_TYPE == "cassandra"
  # sets security properties to connect to the EC2 instances
  KEYS_PAIR_NAME = "your_pair_name"
  SECURITY_GROUP_ID = "your_sec_group"
  PEM_FILE = "your_permission_file.pem"
elsif DATABASE_TYPE == "mongodb"
  # sets security properties to connect to the EC2 instances
  KEYS_PAIR_NAME = "your_pair_name"
  SECURITY_GROUP_ID = "your_sec_group"
  PEM_FILE = "your_permission_file.pem"
end

# files containing the instances IDs of machines under execution and stopped
RUNNING_MACHINES_FILE = "conf/#{DATABASE_TYPE}/running_machines.conf"
STOPPED_MACHINES_FILE = "conf/#{DATABASE_TYPE}/stopped_machines.conf"

# instance ID where the benchxtend tool is running
BENCHXTEND_INSTANCE_ID = "i-xxxxxxxx"

# path where the cassandra seeds file is located
CASSANDRA_SEEDS = 'conf/cassandra-seeds.conf'

# path where the mongodb 'seeds' (ie. machines that cannot be removed) file is located
MONGODB_SEEDS = 'conf/mongodb-seeds.conf'

# path where the cassandra domains file is located
MONGODB_DOMAINS = 'conf/mongodb-domains.conf'

# mongodb machine to where queries will be sent by BenchXtend
MONGODB_PRIMARY_INSTANCE_ID = "i-xxxxxxxx"

MONGODB_DATA_PATH = "/srv/mongodb"