#
# Cookbook:: sonarqube
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

platform = node['platform']

if platform == 'ubuntu' || platform == 'debian'
  package %w(postgresql postgresql-client) do 
    action :install
  end
elsif platform == 'centos' || platform == 'fedora'
  package %w(postgresql postgresql-server) do 
    action :install
  end
else
  log 'This platform is not supported for this cookbook' do
    level :info
  end
  exit
end

execute 'Initialize The Database' do
  command 'postgresql-setup initdb | tee -a /tmp/db-initialized'
  action :run
  not_if { File.exist?('/tmp/db-initialized') }
end

service 'postgresql' do
  action [:start, :enable]
end

bash 'Create Database User and Grants' do
  code <<-EOH
  su - postgres
  psql -c "create database sonar"
  psql -c "create user sonar with password 'sonar'"
  psql -c "grant all privileges on database sonar to sonar"
  EOH
  action :run
end




