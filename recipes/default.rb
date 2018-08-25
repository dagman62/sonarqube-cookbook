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
  createuser -U postgres -SDRw #{node['sonarqube']['dbuser']}
  createdb -U postgres -O #{node['sonarqube']['dbuser']} #{node['sonarqube']['dbname']}
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

remote_file '/tmp/sonarqube.zip' do
  source "https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-#{node['sonarqube']['version']}.zip"
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

user "#{node['sonarqube']['user']}" do
  comment 'Sonarqube Service Account'
  shell '/usr/sbin/nologin'
  action :create
end

group "#{node['sonarqube']['group']}" do
  action :create
end

bash 'Extract Sonarqube' do
  code <<-EOH
  unzip /tmp/sonarqube.zip -d /opt
  chmod -R sonar:sonar /opt/sonarqube-#{node['sonarqube']['version']}
  touch /tmp/sonar-extracted
  EOH
  action :run
  not_if { File.exist?('/tmp/sonar-extracted') }
end

link "#{node['sonarqube']['homedir']}" do
  to "/opt/sonarqube-#{node['sonarqube']['version']}"
  link_type :symbolic
end

template "#{node['sonarqube']['homedir']}/conf/sonar.properties" do
  source 'sonar.properties.erb'
  owner 'sonar'
  group 'sonar'
  mode '0755'
  variables ({
    :dbuser   =>  node['sonarqube']['dbuser'],
    :dbpass   =>  node['sonarqube']['dbpass'],
    :dbname   =>  node['sonarqube']['dbname'],
    :homedir  =>  node['sonarqube']['homedir'],
  })
  action :create
end

template '/etc/systemd/system/sonar.service' do
  source 'sonar.service.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :user     =>  node['sonarqube']['user'],
    :group    =>  node['sonarqube']['group'],
    :homedir  =>  node['sonarqube']['homedir'], 
  })
  action :create
end

service 'sonar' do
  action [:start, :enable]
end




