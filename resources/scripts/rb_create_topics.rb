#!/usr/bin/env ruby

require 'yaml'
require 'getopt/std'

# -------------------------- #
#          Constants         #
# -------------------------- #
# Default Kafka Topic Definition Path
KTD_PATH="/etc/kafka"
# Default Yaml file name
YAML_FILE="topics_definitions.yml"
# Target Path
TARGET=KTD_PATH+"/"+YAML_FILE
# Zookeeper Host
ZK_HOST="zookeeper.service"

# Debug mode: if true, it shows output, else not output
$debug=true

opt = Getopt::Std.getopts("htq")

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

# It shows a message tagged as 'ERRO' (Red color)
def error(text)
  if $debug
    printf("[ \e[31m ERRO \e[0m ] : %s\n", text)
  end
end

# It shows usage message
def usage()
  logit "rb_create_topics.rb [-h][-t <topic>]"
  logit "    -h         -> Show this help"
  logit "    -q         -> Quiet mode"
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

# Check whether file exists
if File.exists?(TARGET)
  info "Loading file : " + TARGET

  # Load file from target path (See constants)
  config=YAML.load_file(TARGET)

  # Create topics
  info "Creating topics..."

  config["topics"].each { |topic|

    # Get topic name, partitions and replication factor from definition file
    topic_name=topic[0]
    partitions=topic[1]["partitions"]
    replication=topic[1]["replication"]

    info "Creating topic #{topic_name} with #{partitions} partition/s and replication factor #{replication}"

    # Run kafka-topics command and save output
    output=`kafka-topics --create --topic #{topic_name} --partitions #{partitions} --replication-factor #{replication} --zookeeper #{ZK_HOST}`

    # If result of previous command is 0 (no errors)
    if $?.to_s.split(" ")[3].to_i == 0
      info output
    else
      error "Error to create topic #{topic_name}\n"
      logit output + "\n"
    end

  }# End topic creation

else
  error "File \"" + YAML_FILE + "\" not found in: " + KTD_PATH
end # End check file condition
