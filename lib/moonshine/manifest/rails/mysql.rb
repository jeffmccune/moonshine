module Moonshine::Manifest::Rails::Mysql

  # Installs <tt>mysql-server</tt> from apt and enables the <tt>mysql</tt>
  # service
  def mysql_server
    package 'mysql-server', :ensure => :installed
    service 'mysql', :ensure => :running, :require => [
      package('mysql-server'),
      package('mysql')
    ]
  end

  # Install the <tt>mysql</tt> rubygem and dependencies
  def mysql_gem
    package "libmysqlclient15-dev", :ensure => :installed
    package "mysql", :ensure => :installed, :provider => :gem, :require => package("libmysqlclient15-dev")
  end

  # GRANT the database user specified in the current <tt>database_environment</tt>
  # permisson to access the database with the supplied password
  def mysql_user
    grant =<<EOF
GRANT ALL PRIVILEGES 
ON #{database_environment.database}.*
TO #{database_environment.username}@localhost
IDENTIFIED BY '#{database_environment.password}';
FLUSH PRIVILEGES;
EOF

    exec "mysql_user",
      :command => mysql_query(grant),
      :unless => mysql_query("show grants for #{database_environment.username}@localhost;"),
      :require => exec('mysql_database'),
      :before => exec('rake tasks'),
      :notify => exec('rails_bootstrap')
  end

  # Create the database from the current <tt>database_environment</tt>
  def mysql_database
    exec "mysql_database",
      :command => mysql_query("create database #{database_environment.database};"),
      :unless => mysql_query("show create database #{database_environment.database};"),
      :require => service('mysql')
  end

  # Noop <tt>/etc/mysql/debian-start</tt>, which does some nasty table scans on
  # MySQL start.
  def mysql_fixup_debian_start
    file '/etc/mysql/debian-start',
      :ensure => :present,
      :content => "#!/bin/bash\nexit 0",
      :mode => '755',
      :owner => 'root',
      :require => package('mysql-server')
  end

private

  # Internal helper to shell out and run a query. Doesn't select a database.
  def mysql_query(sql)
    "/usr/bin/mysql -u root -p -e \"#{sql}\""
  end

end