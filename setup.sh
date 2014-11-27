#!/bin/sh

sudo chown -R $USER /usr/lib/node_modules && \
sudo chown -R $USER /usr/bin && \
npm install -g grunt-cli && \
\
rm -rf ~/workspace && \
mkdir ~/workspace && \
cd ~/workspace && \
\
git clone http://github.com/OpenLMIS/open-lmis/ && \
cd open-lmis && \
git submodule init && \
git submodule update && \
\
psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'p@ssw0rd'" && \
gradle setupdb seed && \
\
dropdb -U postgres open_lmis && createdb -U postgres open_lmis && psql -U postgres open_lmis < /vagrant/db_dump.sql