#!/usr/bin/env ruby

require 'yaml'
require 'getopt/std'
require 'zk'
require 'getopt/long'
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

  zk_host=ZK_HOST + ":2181"

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
  logit "rb_create_topics [-h][-t <topic>]"
  logit "    -h         -> Show this help"
  logit "    -q         -> Quiet mode (optional)"
  logit "    -t         -> topic (optional)"
  logit "Example: rb_create_topics -t"
end


# Check whether file exists
if File.exists?(TARGET)

  # Load file from target path (See constants)
  config=YAML.load_file(TARGET)

  #------------------------------Options-----------------------------#
  # If "h" flag is set, It will print usage and exit with code 0
  if opt["h"]
    usage
    exit 0
  end

  # Debug mode: if true, it shows output, else not output
  # If "q" flag is set, It will set to quiet mode (no output)
  if opt["q"]
    $debug=false
  else
    $debug=true
  end

  if opt["t"].nil?
    default_topics = config["topics"]
  else
    topic = opt["t"].to_s.strip
    default_topics = [topic]
  end
  partitions=config["partitions"]
  replication=config["replication"]
  #--------------------------End of options--------------------------#

  # Get current topics
  current_topics = get_current_topics

  # make array of new topics to be created and reassign
  topics_to_be_created =  default_topics - current_topics

  if !topics_to_be_created.empty?

    info "Creating kafka topics...\n"

    info "Topics to be created:\n"
    puts topics_to_be_created

    topics_to_be_created.each { |topic|

      info "Creating topic #{topic} with #{partitions} partition/s and replication factor #{replication}."

      # Run kafka-topics command and save output
      output=`kafka-topics --create --topic #{topic} --partitions #{partitions} --replication-factor #{replication} --zookeeper #{ZK_HOST}`

      # If result of previous command is 0 (no errors)
      if $?.to_s.split(" ")[3].to_i == 0
        success "Topic created!\n"
      else
        error "Error creating topic #{topic}...\n"
        logit output + "\n"
      end
    }

  else
    info "There is no new topics to be created. \n"
  end
  # End topic creation
  success "End of topic creation \n" if !topics_to_be_created.empty?

  info "Reassigning kafka partitions..."
  if $debug
    system("rb_reassign_partitions -de -p #{partitions}")
  else
    system("rb_reassign_partitions  -e -p #{partitions}")
  end

  if $?.to_s.split(" ")[3].to_i == 0
    success "Partitions were reassigned!"
  else
    error "There was an error reassigning partitions"
  end

else
  error "File \"" + YAML_FILE + "\" not found in: " + KTD_PATH
end # End check file condition