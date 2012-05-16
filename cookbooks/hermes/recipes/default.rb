#
# Cookbook Name:: hermes
# Recipe:: default
#
# Copyright 2012, Example Com
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

# get the number of hermes instances to run
nInstances = node[:hermes][:number_of_instances]

nInstances.times do |index|
    username = "HERMES-"+index.to_s
    homedir = "/home/"+username
    # creating user
    user username do
        action :create
        system true
        shell "/bin/false"
        home homedir
    end

    # creating user home folder
    directory homedir+"/hermes" do
        mode 0755
        owner username
        recursive true
        action :create
    end

    # checking out Hermes
    git homedir+"/hermes" do
        repository "git://github.com/vizio360/messaggero.git"
        reference "zeus"
        action :sync
    end

    #
    # setup ulimit for user
    execute "set ulimit for user" do
        command "echo '#{username} hard nofile 200' >> /etc/security/limits.conf && echo '#{username} soft nofile 200' >> /etc/security/limits.conf"
        user "root"
        action :nothing
        not_if { node.attribute?(username+"_ulimit_set") }
    end

    ruby_block "ulimit has been set" do
        block do
            node.set[username+"_ulimit_set"] = true
            node.save
        end
        action :nothing
    end

end
    
