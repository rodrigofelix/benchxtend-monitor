benchxtend-monitor
==================

Set of scripts developed to support BenchXtend experiments to monitor and manage a cluster of database systems

## Configuration

1. Edit conf/monitor.rb to define major machines (for benchxtend and mongodb instance) and permission configs from Amazon EC2
2. Edit conf/conf.yml with your keys from Amazon EC2
3. Edit the machines of your pool (both those that will be running in the beginning and those that will be stopped) in the conf/[database] (like conf/cassandra)
4. Clone this repository in the Amazon EC2 where monitor and decision taker will be running
5. Copy metrics.sh to the home directory of each machine that will be monitored

## Running

1. Run ruby monitor.rb > monitor.out &
2. Use tail -f metrics/i-xxxxxx.metrics to check CPU and Memory of each running instance
3. Run run_decision.rb 
4. Follow up the output of run_decision.rb to see if machines are added or removed

## Auxiliary scripts

1. machinelogs.rb: reads the log files saved on /logs (that contains the moment on each machine was removed or added) and creates and extended log showing in each second what was the amount of machines. Time (in secs) representing the duration of the monitoring is a mandatory parameter.
2. token.rb: define tokens to evenly divide data range from cassandra. Number of machines is a mandatory parameter.
3. update_mongodb_hosts.rb: reads a file with instance IDs and domains and update /ets/hosts files of all running instances.
