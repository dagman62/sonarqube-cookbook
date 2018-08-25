#
# Cookbook:: sonarqube
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

platform = node['platform']

if platform == 'ubuntu' || platform == 'debian'
  package %w(postgresql-10 postgresql-client-10 wget ca-certificates) do 
    action :install
  end
elsif platform == 'centos' || platform == 'fedora'
  package %w(postgresql10-server postgresql10) do 
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
  createuser -U postgres -SDRw sonar
  createdb -U postgres -O sonar sonar
  EOH
  action :run
end

if platform == 'ubuntu' || platform == 'debian'
  bash 'Configure and Install PgAdmin' do
    code <<-EOH
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    sudo apt-get update
    sudo apt-get upgrade
    EOH
    action :run
  end
  package 'pgadmin4' do
    action :install
  end
elsif platform == 'centos' || platform == 'fedora'
  bash 'Install pgAdmin' do
    code <<-EOH
    rpm -Uvh https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm
    yum update -y
    EOH
    action :run
  end
  package 'pgadmin4' do
    action :install
  end
else
  log 'This platform is not supported' do
    level :info
  end
end

if platform == 'ubuntu' || platform == 'debian'
  cookbook_file '/etc/postgresql/10/main/pg_hba.conf' do
    source 'pg_hba.conf'
    owner 'root'
    group 'root'
    mode '0640'
    action :create
  end
  cookbook_file '/etc/postgresql/10/main/postgresql.conf' do
    source 'postgresql.conf'
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end
end




