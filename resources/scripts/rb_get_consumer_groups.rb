#!/usr/bin/env ruby
########################################################################    
## Copyright (c) 2024 ENEO Tecnología S.L.
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

require 'zk'
require 'yaml'
require 'json'
require 'getopt/std'

zk_host='zookeeper.service:2181'

begin 
  zk = ZK.new(zk_host)
  if zk.nil?
    $stderr.puts "ERROR: Cannot connect with #{zk_host}!!"
  elsif zk.exists?('/consumers')
    zk.children('/consumers').sort.uniq.each do |x|
      $stdout.puts x
    end
  end
rescue => e
  $stderr.puts "ERROR: Exception on #{zk_host}"
  $stderr.puts "#{e}\n\t#{e.backtrace.join("\n\t")}" if @debug
ensure
  zk.close if zk && !zk.closed? 
end
