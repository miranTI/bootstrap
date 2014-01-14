#!/usr/bin/env bash

# http://www.postgresql.org/download/linux/ubuntu/
# http://stackoverflow.com/questions/84882/sudo-echo-something-etc-privilegedfile-doesnt-work-is-there-an-alterna
sudo sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y postgresql-9.3
sudo sed -i 's/md5$/trust/g' /etc/postgresql/9.3/main/pg_hba.conf
sudo sed -i 's/127\.0\.0\.1\/32/all/g' /etc/postgresql/9.3/main/pg_hba.conf
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/9.3/main/postgresql.conf
sudo /etc/init.d/postgresql restart

# The chosen LC_CTYPE setting requires encoding "LATIN1" error
# http://ezekielbinion.com/blog/making-rake-dbcreate-postgres-behave/
# http://www.postgresql.org/docs/9.0/interactive/app-psql.html
psql -U postgres -h localhost -d template1 -c "UPDATE pg_database SET datallowconn = TRUE where datname = 'template0';"
psql -U postgres -h localhost -d template0 -c "UPDATE pg_database SET datistemplate = FALSE where datname = 'template1';"
psql -U postgres -h localhost -d template0 -c "drop database template1;"
psql -U postgres -h localhost -d template0 -c "create database template1 with template = template0 encoding = 'UNICODE'  LC_CTYPE = 'en_US.UTF-8' LC_COLLATE = 'C';"
psql -U postgres -h localhost -d template0 -c "UPDATE pg_database SET datistemplate = TRUE where datname = 'template1';"
psql -U postgres -h localhost -d template1 -c "UPDATE pg_database SET datallowconn = FALSE where datname = 'template0';"
