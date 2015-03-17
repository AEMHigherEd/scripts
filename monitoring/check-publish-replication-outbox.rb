require 'net/smtp'
require 'rest_client'

#  
# Ron Santos - SFU, IT Services, 17/03/2015
#
# Check's the number of submissions in /var/replication/outbox for the given AEM publish instance waiting to be reverse replicated
# If the total number of submissions is greater than the highmark (default is 100), an email will be sent
#
# Requirements:
#    1. Set AEM admin password as an environment variable called AEM_PASSWORD_PRODUCTION or run `export AEM_PASSWORD_PRODUCTION="admin_password"` before running the script
#    2. Change the mailto to an email address where alerts will be sent
#    3. Change the script_host to the server that will be running this script
#    4. Change the smtp_server to your STMP server
#
# Usage:   ruby check-publish-replication-outbox.rb <instance> [highmark]
# Example: ruby check-publish-replication-outbox.rb localhost:4502 200
#



def mailto
  "changeme@school.edu"
end

def username
  "admin"
end

def password
  ENV['AEM_PASSWORD_PRODUCTION']
end

def script_host
  "localhost@localhost.com"
end

def smtp_server
  "localhost"
end

def replication_outbox_path
  "/var/replication/outbox"
end  

def default_high_mark
  100
end

def invalid_path?(name)
  name.nil? || name.first.include?(":")
end 

def outbox_count(nodes)
  count = 0
  nodes.each do |node|
    unless invalid_path?(node)      
      count += 1   
    end
  end  
  count
end

def check_outbox(instance, path)  
  begin
    url = "http://#{username}:#{password}@#{instance}#{path}.1.json"
    resp = RestClient.get URI.encode(url)
    nodes = JSON.parse resp
  rescue => e
    p "Error retrieving outbox for #{url}"
  end 
end

def send_email(instance, to, count)
  message = <<EOF
From: AEM <#{script_host}>
To: #{to}
Subject: Reverse replication may be broken or infinite loop

  Total number of nodes under #{replication_outbox_path} is #{count} on #{instance}

EOF

  Net::SMTP.start(smtp_server) do |smtp|
    smtp.send_message message, script_host, to
  end
end

if ARGV.first.nil?
  p "Usage: ruby check-publish-replication-outbox.rb <instance>"
  p "Example: ruby check-publish-replication-outbox localhost:4502"
  exit
end

instance = ARGV.first
highmark = default_high_mark
highmark = ARGV[1] unless ARGV[1].nil?
total = 0

main_outbox = check_outbox instance, replication_outbox_path

main_outbox.each do |node|
  unless invalid_path?(node)
    s = node.first.index(/\d/)
    e = node.first.rindex(/\d/)
    path = node.first[s..e]
    child_nodes = check_outbox(instance, "#{replication_outbox_path}/#{path}")
    total += outbox_count(child_nodes)
    send_email(instance, mailto, total) if total > highmark     
  end  
end

p "Total in the replication queue is #{total}"

