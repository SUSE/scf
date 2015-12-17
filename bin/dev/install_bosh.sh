#!/bin/bash
set -e

sudo apt-get update

sudo apt-get install -y build-essential ruby ruby-dev libxml2-dev \
  libsqlite3-dev libxslt1-dev libpq-dev libmysqlclient-dev zlib1g-dev

gem install bundler --no-ri --no-rdoc
gem install bosh_cli --no-ri --no-rdoc
