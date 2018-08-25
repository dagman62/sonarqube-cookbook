#
# Cookbook:: sonarqube
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

platform = node['platform']

if platform == 'ubuntu' || platform == 'debian'
  package %w(postgresql postgresql-client postgresql-all wget ca-certificates pgadmin3) do 
    action :install
  end
elsif platform == 'centos' || platform == 'fedora'
  package %w(postgresql-server postgresql pgadmin4) do 
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

template '/tmp/admin.sh' do
  source 'admin.sh.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :dbuser       =>  node['sonarqube']['dbuser'],
    :dbpass       =>  node['sonarqube']['dbpass'],
    :dbname       =>  node['sonarqube']['dbname'],
    :dbadmin      =>  node['sonarqube']['dbadmin'],
    :dbadminpass  =>  node['sonarqube']['dbadminpass'],
  })
  action :create
end

execute 'Create Database and Users' do
  command 'bash /tmp/admin.sh | tee -a /tmp/users-done'
  action :run
  not_if { File.exist?('/tmp/users-done') }
end

cookbook_file '/tmp/pgadmin4.key' do
  source 'pgadmin4.key'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

execute 'Install Key' do
  command 'apt-key add /tmp/pgadmin4.key | tee -a /tmp/key-installed'
  action :run
  not_if { File.exist?('/tmp/key-installed') }
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

service 'postgresql' do
  action :reload
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
  chown -R sonar:sonar /opt/sonarqube-#{node['sonarqube']['version']}
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




