#!/usr/bin/ruby

#######################################################################
## Copyright (c) 2014 ENEO Tecnología S.L.
## This file is part of redBorder.
## redBorder is free software: you can redistribute it and/or modify
## it under the terms of the GNU Affero General Public License License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
## redBorder is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU Affero General Public License License for more details.
## You should have received a copy of the GNU Affero General Public License License
## along with redBorder. If not, see <http://www.gnu.org/licenses/>.
########################################################################

begin

  require 'chef'
  require "uuidtools"
  require 'rubygems'
  require 'zk'
  require 'yaml'
  require 'json'
  require 'syslog/logger'
  require "getopt/std"

rescue LoadError => e
  puts e
  exit 1
end

ADMINPATH="/admin"
CONTROLLERPATH="/controller"
REASSIGN_PATH="#{ADMINPATH}/reassign_partitions"
PREFERED_PATH="#{ADMINPATH}/preferred_replica_election"

def logit(text)
  printf("%s\n", text)
  @log.info text and !@debug
end

def usage
  printf "rb_reassign_partitions.rb [-h][-p partitions][-r replicas][-e][-d]\n"
  printf "   -e            -> execute\n"
  printf "   -h            -> print this help\n"
  printf "   -d            -> debug\n"
  printf "   -l            -> force leader election\n"
  printf "   -g            -> force select replica election\n"
  printf "   -p partitions -> desired partitions (optional)\n"
  printf "   -r replicas   -> desired replicas   (optional)\n"
  printf "   -t topic      -> actuate only for this topic (optional)\n"
  printf "   -b broker_list -> broker list to use instead of total one. Example: 0,1\n"
  printf "   -n scale up   -> use this option when you add new brokers and try to increase the partitions.\n"
  exit 0
end

def topic_path(topic)
  "/brokers/topics/#{topic}"
end

def partitions_path(topic)
  "#{topic_path(topic)}/partitions"
end

def partition_path(topic, partition)
  "#{partitions_path(topic)}/#{partition}"
end

def partition_path_state(topic, partition)
  "#{partition_path(topic, partition)}/state"
end

def get_partitions(zk, topic)
  zk.children(partitions_path(topic)).map{|k| k.to_i}.sort.uniq
end

def max_partitions(partitions)
  max = partitions.map { |_, v| v.size }.max
  i = partitions.select { |_, v| v.size == max }.keys.sample
  [max, i]
end

def min_partitions(partitions, exclude_partition)
  excludes = partitions.select { |_,v| !v.include?(exclude_partition)}
  min = excludes.map { |_, v| v.size }.min
  i = excludes.select { |_, v| v.size == min }.keys.sample
  [min, i]
end

@log = Syslog::Logger.new 'rb_kafka_reassign_partitions'
@desired_partitions=1

opt = Getopt::Std.getopts("ehdlgr:p:t:b:n")
usage unless opt["h"].nil?
@debug = !opt["d"].nil?
@execute = !opt["e"].nil?
@desired_replicas = opt["r"].nil? ? 0 : opt["r"].to_i
@desired_replicas = 0 if (@desired_replicas<0)
@desired_partitions = opt["p"].nil? ? 0 : opt["p"].to_i
@force_leader= opt["l"]
broker_list=opt["b"].split(",").map{|x| x.to_i} if opt["b"]

if opt["t"]
  if opt["t"].class==Array
    @topics = []
    opt["t"].each do |k|
      @topics<<k
    end
  elsif opt["t"].respond_to?"split"
    @topics=opt["t"].split(",")
  else
    @topics=[opt["t"].to_s]
  end
else
  @topics = nil
end


Chef::Config.from_file("/etc/chef/client.rb")
Chef::Config[:node_name]  = "admin"
Chef::Config[:client_key] = "/etc/chef/admin.pem"
#Chef::Config[:client_key] = "/etc/chef-server/admin.pem"     #TODO should we add it?
Chef::Config[:http_retry_count] = 5

if !File.directory?('/tmp/kafka_reassing')
  Dir.mkdir '/tmp/kafka_reassing'
end

zk_host="zookeeper.service:2181"

if opt["g"]
  system("/usr/bin/kafka-preferred-replica-election --zookeeper #{zk_host}")
else
  begin
    zk = ZK.new(zk_host)

    if zk.nil?
      logit "    - ERROR: Cannot connect with #{zk_host}!!"
    elsif zk.exists?(REASSIGN_PATH)
      logit "    - ERROR: Other instance if reassignating partitions. Please wait."
    elsif zk.exists?(PREFERED_PATH)
      logit "    - ERROR: Other instance if choosing the leaders. Please wait."
    else
      logit "* Zookeeper: #{zk_host}"  if @debug
      logit "    - Discovered:" if @debug
      topics=zk.children("/brokers/topics").sort.uniq
      if @debug
        logit "        > Topics found (total: #{topics.size}):"
        topics.each do |x|
          logit "            - #{x}"
        end
      end

      #get available brokers
      brokerids = zk.children("/brokers/ids").map{|k| k.to_i}.sort.uniq
      if broker_list
        brokerids=brokerids.select{|x| broker_list.include?x}
      end

      if brokerids.size>0
        zk.create(ADMINPATH, "null") if !zk.exists?(ADMINPATH)

        if brokerids.size==1
          @desired_replicas = 1
        elsif brokerids.size==2 and @desired_replicas==0
          @desired_replicas = 1
        else
          @desired_replicas = 2 if @desired_replicas==0
          if @desired_replicas==0
            if brokerids.size==1
              @desired_replicas = 1
            else
              @desired_replicas = 2
            end
          end
        end

        if @desired_partitions==0
          if zk.exists?("/druid") and zk.exists?("/druid/announcements")
            array = zk.children("/druid/announcements").map{|k| k.to_s}.sort.uniq.shuffle
            realtimes = []
            array.shuffle.each do |x|
              if x.end_with?":8084"
                realtimes << x
              end
            end
            @desired_partitions = [ [ brokerids.size * 2, realtimes.size ].min , 2 ].max
          else
            @desired_partitions = brokerids.size * 2
          end
        end

        @desired_replicas = brokerids.size if @desired_replicas>brokerids.size

        logit "        > Brokers ids: #{brokerids.join(",")}  (total: #{brokerids.size})" if @debug

        if @debug
          zktdata,stat = zk.get(CONTROLLERPATH)
          zktdata = YAML.load(zktdata)
          logit "        > Controller on broker #{zktdata["brokerid"]}"
        end

        relocate_data_zk = {}
        relocate_data_zk["partitions"] = []
        topic_details = {}
        index=0

        topics.each do |topic|
          if ((!@topics.nil? and @topics.include?topic) or @topics.nil?)
            logit "    - Topic: #{topic}" if @debug

            if topic.start_with?"__"
              real_desired_partitions = 1
            else
              real_desired_partitions = @desired_partitions
            end

            if zk.exists?(partitions_path(topic))
              partitions = get_partitions(zk, topic)
              current_partitions = partitions.size
              logit "        > Partitions : #{partitions.join(",")}  (total: #{partitions.size})" if @debug

              if partitions.size < real_desired_partitions
                logit "        > Desired partitions: #{real_desired_partitions}. Current partitions: #{partitions.size}. Creating #{real_desired_partitions-partitions.size} partitions for #{topic}"
                if @execute
                  topic_details[topic] = {}
                  topic_details[topic]["partitions"] = real_desired_partitions

                  system("/usr/bin/kafka-topics --zookeeper \"#{zk_host}\" --partition #{real_desired_partitions} --topic \"#{topic}\" --alter ")
                  partitions = get_partitions(zk, topic)
                  logit "        > New Partitions : #{partitions.join(",")}  (total: #{partitions.size})" if @debug
                else
                  last_p=partitions.last
                  (real_desired_partitions-partitions.size).times do
                    last_p=last_p+1
                    partitions<<last_p
                  end
                  logit "        > New Partitions : #{partitions.join(",")}  (total: #{partitions.size}) (dry-run)" if @debug
                end
              end

              if partitions.size<real_desired_partitions
                logit "        > ERROR: The current partitions (#{partitions.size}) don't correspond with the desired one (#{real_desired_partitions}) (#{topic} - zk: #{zk_host})"
              else
                relocate_data =  {}

                if opt['n'].nil?
                  partitions.each { |p| relocate_data[p.to_s]=[] }
                  for i in 1..@desired_replicas do
                    relocate_data.each do |p, array|
                      while array.include? brokerids[index]
                        index=index+1
                        index=0 if index>=brokerids.length
                      end
                      array<<brokerids[index]
                      index=index+1
                      index=0 if index>=brokerids.length
                    end
                  end
                else
                  brokers_partitions = {}
                  partitions = get_partitions(zk, topic)

                  if(current_partitions < (real_desired_partitions))
                    partitions_to_move = (current_partitions .. (real_desired_partitions - 1)).to_a
                    partitions_to_move_aux = partitions_to_move.clone
                    partitions.each do |partition|
                      zktdata,stat = zk.get("/brokers/topics/#{topic}/partitions/#{partition}/state")
                      brokers = JSON.parse(zktdata)["isr"]

                      brokers.each do |broker|
                        brokers_partitions[broker] ||= []
                        brokers_partitions[broker] << partition
                      end
                    end

                    computing = true

                    while (computing) do
                      max, brokerMax = max_partitions(brokers_partitions)
                      partitions_to_move.each do |partition|
                        min, brokerMin = min_partitions(brokers_partitions, partition)
                        if !(brokerMin.nil?)
                          if !(max == min || (max -1) == min)
                            if(brokers_partitions[brokerMax].include? partition)
                              if(!brokers_partitions[brokerMin].include? partition)
                                partitions_to_move_aux.delete(partition)
                                brokers_partitions[brokerMax].delete(partition)
                                brokers_partitions[brokerMin] << partition
                              end
                            end
                            partitions_to_move = partitions_to_move_aux.clone
                            computing = true
                          else
                            computing = false
                          end
                        else
                          computing = false
                        end
                      end

                      sleep 5
                    end

                    for partition in current_partitions..(real_desired_partitions - 1) do
                      brokers_ids = brokers_partitions.select{|_,v| v.include?(partition)}.keys.sort.reverse
                      relocate_data.merge!(partition => brokers_ids)
                    end
                  else
                    logit "    - Topic #{topic} has #{real_desired_partitions} partitions or more!"
                    exit 0
                  end

                end

                logit "        > Desired partitions replicas: #{relocate_data.to_json}" if @debug

                #Get current data
                same=true
                error=false
                zktdata,stat = zk.get(topic_path(topic))
                zktdata = YAML.load(zktdata)
                if zktdata["partitions"].nil?
                  logit "ERROR: This topic has no readable partitions (#{topic}) on #{zk_host}"
                  error=true
                else
                  same=false if zktdata["partitions"]!=relocate_data
                end

                if same
                  logit "        > Remote zk has the same replicas configured" if @debug and !error
                else
                  relocate_data.each do |pid, rep|
                    relocate_data_zk["partitions"] << {"topic"=>topic, "partition"=>pid.to_i, "replicas"=>rep.map{|x| x.to_i}.uniq }
                  end

                  logit "        > Current partitions replicas: #{zktdata["partitions"].to_json} " if @debug
                end
              end
            else
              logit "ERROR: Topic \"#{topic}\" not found on #{zk_host}  (#{partitions_path(topic)})"
            end
          end
        end
        # if topic_details.size>0  #TODO check this
        #   role = Chef::Role.load("manager")
        #   role.override_attributes["redBorder"] = {} if role.override_attributes["redBorder"].nil?
        #   role.override_attributes["redBorder"]["manager"] = {} if role.override_attributes["redBorder"]["manager"].nil?
        #   role.override_attributes["redBorder"]["manager"]["kafka"] = {} if role.override_attributes["redBorder"]["manager"]["kafka"].nil?
        #   role.override_attributes["redBorder"]["manager"]["kafka"]["topics"] = {} if role.override_attributes["redBorder"]["manager"]["kafka"]["topics"].nil?
        #   topic_details.each do |t, v|
        #     role.override_attributes["redBorder"]["manager"]["kafka"]["topics"][t] = {} if role.override_attributes["redBorder"]["manager"]["kafka"]["topics"][t].nil?
        #     role.override_attributes["redBorder"]["manager"]["kafka"]["topics"][t]["partitions"] = v["partitions"].to_i
        #     role.override_attributes["redBorder"]["manager"]["kafka"]["topics"][t]["replicas"]   = @desired_replicas.to_i
        #   end
        #   logit "ERROR: Cannot save partitions into role manager"  if !role.save
        # end

        if relocate_data_zk["partitions"].size>0
          logit "    - Write: #{relocate_data_zk.to_json}  #{@execute ? "" : "(dry-run)"}" if @debug
          if @execute
            json_file = "/tmp/kafka_reassing/#{UUIDTools::UUID.random_create.to_s}"
            File.open("#{json_file}", 'w'){|f| f.write(relocate_data_zk.to_json) }
            logit "Executing /usr/bin/kafka-reassign-partitions.sh --zookeeper #{zk_host} --reassignment-json-file #{json_file} --execute"
            system("/usr/bin/kafka-reassign-partitions.sh --zookeeper #{zk_host} --reassignment-json-file #{json_file} --execute")
            counter=0
            while zk.exists?(REASSIGN_PATH) and counter<30 do
              sleep 1
              counter=counter+1
            end
            File.delete("#{json_file}")
          end
        end

        if @force_leader or (relocate_data_zk["partitions"].size>0 and @execute)
          logit "    - Force leader election" if @force_leader
          zk.create(PREFERED_PATH, relocate_data_zk.to_json)
          counter=0
          while zk.exists?(PREFERED_PATH) and counter<30 do
            sleep 1
            counter=counter+1
          end
        end
      else
        logit "There are no available brokers on #{zk_host}"
      end
    end
  rescue => e
    logit "ERROR: Exception on #{zk_host}"
    puts "#{e}\n\t#{e.backtrace.join("\n\t")}" if @debug
  ensure
    if !zk.nil? and !zk.closed?
      zk.close
      logit "    - Closed connection with #{zk_host}" if @debug
    end
  end
end
