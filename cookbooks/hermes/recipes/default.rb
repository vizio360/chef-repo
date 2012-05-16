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


nInstances = node[:hermes][:number_of_instances]

nInstances.times do |index|
    username = "HERMES-"+index.to_s
    homedir = "/home/"+username
    user username do
        action :create
        system true
        shell "/bin/false"
        home homedir
    end

    directory homedir+"/hermes" do
        mode 0755
        owner username
        recursive true
        action :create
    end

    git homedir+"/hermes" do
        repository "git://github.com/vizio360/messaggero.git"
        reference "zeus"
        action :sync
    end

=begin
    # deploying hermes in user homedir 
    deploy homedir+"/hermes" do
        repo "git://github.com/vizio360/messaggero.git"
        revision "zeus" # or "HEAD" or "TAG_for_1.0" or (subversion) "1234"
        user username
        shallow_clone true
        action :deploy # or :rollback
        scm_provider Chef::Provider::Git # is the default, for svn: Chef::Provider::Subversion
    end
=end
end
    
