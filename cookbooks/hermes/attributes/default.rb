default[:amazon][:meta_data_ws] = "http://169.254.169.254/latest/meta-data/"
default[:hermes][:gems] = [{:name => "rest-client", :version => "1.6.7"}]
default[:hermes][:number_of_instances] = 25
default[:hermes][:starting_port] = 8101
default[:hermes][:max_connection] = 20
default[:hermes][:servertype] = "tcpsockets"
default[:hermes][:branch] = "foreman"
