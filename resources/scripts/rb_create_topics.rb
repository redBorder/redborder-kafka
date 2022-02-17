#!/usr/bin/env ruby

require 'yaml'
require 'getopt/std'
require 'zk'

# ---------------------------#
#          Constants         #
# -------------------------- #
# Default Kafka Topic Definition Path
KTD_PATH="/etc/kafka"
# Default Yaml file name
YAML_FILE="topics_definitions.yml"
# Target Path
TARGET=KTD_PATH+"/"+YAML_FILE
# Zookeeper Host
ZK_HOST="zookeeper.service"

# Debug mode: if true, it shows output, else not output
$debug=true

opt = Getopt::Std.getopts("ht:q")

# It shows a simple untagged message
def logit(text)
  if $debug
    printf("%s\n", text)
  end
end

# It shows a message tagged as 'INFO' (Default color)
def info(text)
  if $debug
    printf("[  INFO  ] : %s\n", text)
  end
end

# It shows a message tagged as 'ERROR' (Red color)
def error(text)
  if $debug
    printf("[ \e[31m ERROR \e[0m ] : %s\n", text)
  end
end

# It shows a message tagged as 'SUCCESS' (Green color)
def success(text)
  if $debug
    printf("[ \e[32m SUCCESS \e[0m ] : %s\n", text)
  end
end

# get the current topics to the zookeeper
def get_current_topics

  begin
    zk = `consul catalog services | grep -i zookeeper`
    raise("Something went wrong with Consul. Zookeeper service is not registered.") if (zk.eql? "")
  rescue RuntimeError => e
    error(e)
    puts "Exiting.."
    exit 0
  end

  zk_host="zookeeper.service:2181"

  zk = ZK.new(zk_host) rescue nil

  if zk.nil?
    error "Cannot connect with #{zk_host} to retrieve current topics or there are not topics created yet."
    exit 1
  else
    begin
      zk.children("/brokers/topics").sort.uniq
    rescue
      error "There was a problem connecting with zk."
      exit 1
    end
  end
end

# It shows usage message
def usage()
  logit "rb_create_topics.rb [-h][-t <topic>]"
  logit "    -h         -> Show this help"
  logit "    -q         -> Quiet mode"
  logit "    -t         -> topic"
end

# If "h" flag is set, It will print usage and exit with code 0
if opt["h"]
  usage
  exit 0
end

# If "q" flag is set, It will set to quiet mode (no output)
if opt["q"]
  $debug=false
end

# Get current topics
current_topics = get_current_topics

# Check whether file exists
if File.exists?(TARGET)

  # Load file from target path (See constants)
  config=YAML.load_file(TARGET)

  if opt["t"].nil?
    default_topics = config["topics"]
  else
    topic = opt["t"].to_s.strip
    default_topics = [topic]
  end
  partitions=config["partitions"]
  replication=config["replication"]

  # make array of new topics to be created and reassign
  topics_to_be_created =  default_topics - current_topics

  if topics_to_be_created.empty?
    info "There is no new topics to be created. Exiting...\n"
    exit 0
  end

  info "Creating kafka topics...\n"

  info "Topics to be created:\n"
  puts topics_to_be_created
  puts

  topics_to_be_created.each { |topic|

    info "Creating topic #{topic} with #{partitions} partition/s and replication factor #{replication}."

    # Run kafka-topics command and save output
    output=`kafka-topics --create --topic #{topic} --partitions #{partitions} --replication-factor #{replication} --zookeeper #{ZK_HOST}`

    # If result of previous command is 0 (no errors)
    if $?.to_s.split(" ")[3].to_i == 0

      success "Topic created!\n"
    else
      if output.include? "available brokers: 0"
        brokers=0
        info "There are no available brokers. Waiting for them to be ready again..."
        while brokers.to_i < "#{replication}".to_i do
          brokers=`zkCli.sh ls /brokers/ids quit 2>/dev/null | grep WatchedEvent -A 1 | grep -v WatchedEvent -c`
        end
        success "Brokers are ready!"
        output=`kafka-topics --create --topic #{topic} --partitions #{partitions} --replication-factor #{replication} --zookeeper #{ZK_HOST}`
        if $?.to_s.split(" ")[3].to_i == 0
          success "Topic created!\n"
        else
          error "Error creating topic #{topic}...\n"
          logit output + "\n"
        end
      else
        error "Error creating topic #{topic}...\n"
        logit output + "\n"
      end
    end

  }# End topic creation
  success "End of topic creation \n"

  info "Reassigning kafka partitions..."
  `/usr/lib/rvm/rubies/ruby-2.2.4/bin/ruby /usr/lib/redborder/scripts/rb_reassign_partitions.rb -de -p #{partitions}`

  if $?.to_s.split(" ")[3].to_i == 0
    success "Partitions were reassigned!"
  else
    error "There was an error reassigning partitions"
  end

else
  error "File \"" + YAML_FILE + "\" not found in: " + KTD_PATH
end # End check file condition
