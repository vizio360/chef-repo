#
# Cookbook Name:: hermes
# Recipe:: default
#
# Copyright 2012, 2bitcc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#

# installing all the gems necessary
node[:hermes][:gems].each do |gem|
    gem_package gem[:name] do
        if gem[:version] && !gem[:version].empty?
            version gem[:version]
        end
        if gem[:source]
            source gem[:source]
        end
        action :install
    end
end

require 'rubygems'
require 'rest_client'
require 'json'
require 'uuidtools'



if not node.attribute?("number_of_instances") 
    # get the number of hermes instances to run
    nInstances = node[:hermes][:number_of_instances]
    node.set["number_of_instances"] = nInstances 
    node.save
else
    nInstances = node["number_of_instances"]
end
    




# getting EC2 instance information
# FIXME maybe add 3 attempts to get the data before exiting


$ec2InfoWS = node[:amazon][:meta_data_ws]

def getInstanceMetaData(data)
    begin
        response = RestClient.get $ec2InfoWS + data
        return response.body
    rescue => e
        puts "problem while getting #{data} : #{e}"
        puts "amazon:meta_data_ws = " + $ec2InfoWS
        exit FALSE
    end
end

instanceInfo = {}
instanceInfo["instance-id"] = getInstanceMetaData("instance-id")
instanceInfo["public-hostname"] = getInstanceMetaData("public-hostname")
instanceInfo["instance-type"] = getInstanceMetaData("instance-type")

puts "EC2 instance info"
instanceInfo.each_pair {|key, value| puts key+" => "+value}

# we now need to PUT the instance info to ZEUS
data = {:ip => instanceInfo["public-hostname"], :type => instanceInfo["instance-type"]} 
begin
    response = RestClient.put node[:zeus][:endPoint] + "machine/" + instanceInfo["instance-id"], data.to_json, {:content_type => :json }
    case response.code
    when 200
        puts "Machine #{instanceInfo["instance-id"]} updated!"
    when 201
        puts "Machine #{instanceInfo["instance-id"]} created!"
    end
rescue => e
    puts "problem while registering the machine: #{e}"
    exit FALSE
end


##########



superuser = "zeus"
# creating super user
user superuser do
    action :create
    system true
    shell "/bin/false"
end


nInstances.times do |index|

    username = "HERMES-"+(index+1).to_s
    homedir = "/home/"+username
    # creating user
    user username do
        action :create
        system true
        shell "/bin/false"
        home homedir
    end

    # creating group with the same name as the user
    group username do
        action :create
        members [username]
    end

    # creating user home folder
    directory homedir do
        mode "0755"
        owner username
        group username
        recursive true
        action :create
    end
    
    directory homedir+"/var" do
        owner username
        group username
        recursive true
        action :create
    end
    directory homedir+"/var/log" do
        owner username
        group username
        recursive true
        action :create
    end

    directory homedir+"/hermes_plugins" do
        mode "0555"
        owner username
        group username
        recursive true
        action :create
    end

    directory homedir+"/hermes_plugins_live" do
        mode "0555"
        owner username
        group username
        recursive true
        action :create
    end

    remote_file homedir+"/hermes.tar.gz" do
        source "http://dl.dropbox.com/u/4656840/hermes.tar.gz"
        owner username
        mode "0600"
    end

    execute "extract hermes files" do
        command "tar -zxf hermes.tar.gz"
        cwd homedir
        user username
    end

    execute "changing mode to all hermes subfolders" do
        command "find #{homedir}/hermes -type d -exec chmod 750 {} \\;"
        user "root"
    end

    execute "changing owner and group to the hermes folder" do
        command "chown -R #{superuser}:#{username} #{homedir}/hermes"
        user "root"
    end
    
    # creating the config file for Hermes
    template homedir+"/hermes/config.json" do
        source "hermes.conf.erb"
        owner superuser
        group username
        mode "0740"
        action :create
        variables(
            :uuid => UUIDTools::UUID.random_create,
            :servertype => node[:hermes][:servertype],
            :port => node[:hermes][:starting_port] + index,
            :logFolder => homedir+"/var/log",
            :maxConnections => node[:hermes][:maxConnections],
            :amazonMetaDataWS => $ec2InfoWS,
            :zeusEndPoint => node[:zeus][:endPoint]
        )
        not_if { node.attribute?(username+"_not_first_run") }
    end

    # setup startup script
    template homedir+"/hermes/startup.sh" do
        source "startup.sh.erb"
        owner superuser
        group username
        action :create
        mode "0750"
        variables(
            :delay => index * 5 # wait 5 seconds between services
        )
        not_if { node.attribute?(username+"_not_first_run") }
    end


    # setup ulimit for user
    execute "set ulimit for user" do
        command "echo '#{username} hard nofile 200' >> /etc/security/limits.conf && echo '#{username} soft nofile 200' >> /etc/security/limits.conf"
        user "root"
        action :run
        not_if { node.attribute?(username+"_not_first_run") }
    end

    # create .init folder for upstart user jobs
    directory homedir+"/.init" do
        mode "0750"
        owner username
        group username
        recursive true
        action :create
        not_if { node.attribute?(username+"_not_first_run") }
    end

    # creating the upstart conf file
    template homedir+"/.init/#{username}.conf" do
        source "upstart.conf.erb"
        owner username
        group username
        action :create
        not_if { node.attribute?(username+"_not_first_run") }
    end

    # run upstart service
    execute "start upstart service" do
        command "sudo -u #{username} start #{username}"
        cwd homedir
        action :run
        not_if { node.attribute?(username+"_not_first_run") }
    end

    ruby_block "set not first run flag" do
        block do
            node.set[username+"_not_first_run"] = true
            node.save
        end
        action :nothing
    end
end

