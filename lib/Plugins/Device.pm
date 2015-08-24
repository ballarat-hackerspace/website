#
# Licensed to the Apache Software Foundation (ASF) under one or or more
# contributor license agreements. See the NOTICE file distributed with this
# work for additional information regarding copyright ownership. The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#

package Plugins::Device;
use Mojo::Base 'Mojolicious::Plugin';

use Carp 'croak';
use DBI;
use Mojo::Util qw(dumper sha1_sum);
use Time::Piece;

our $VERSION = '0.1';

has 'db'  => sub { return DBI->connect(shift->dsn, '', ''); };
has 'dsn';

sub register {
  my ($self, $app, $config) = @_;

  $config->{db}  //= '/tmp/bhack.db';
  $config->{arp} //= '/usr/bin/arp';
  $self->dsn('dbi:SQLite:dbname='.$config->{db});

  # conditionally build table
  $self->db->do("
    CREATE TABLE IF NOT EXISTS devices (
      id      INTEGER PRIMARY KEY AUTOINCREMENT,
      email   CHAR(128) NOT NULL DEFAULT '',
      name    CHAR(128) NOT NULL DEFAULT '',
      uuid    CHAR(40) NOT NULL UNIQUE,
      meta    TEXT NOT NULL DEFAULT '{}',
      created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ");

  $app->helper('device.is_whitelisted' => sub {
    my $c = shift;
    my $db = $self->db;

    my $uuid = $c->signed_cookie('bhack.uuid');
    my $sth = $db->prepare('SELECT * FROM devices WHERE uuid=?');
    my $devices = !!($sth->execute($uuid)) ? $sth->fetchall_arrayref({}) : undef;

    return @{$devices} ? $devices->[0] : undef
  });

  $app->helper('device.add' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};

    my $db = $self->db;

    my $sth = $db->prepare('INSERT INTO devices (email, name, uuid) VALUES (?, ?, ?)');
    return !!$sth->execute($args->{email}, $args->{device}, $args->{uuid});
  });

  $app->helper('device.find' => sub {
    my $c = shift;
    my $db = $self->db;
    my $sth = $db->prepare('SELECT * FROM devices;');
    my $devices = !!($sth->execute) ? $sth->fetchall_arrayref({}) : undef;

    return $devices;
  });

  $app->helper('device.remove' => sub {
    my $c = shift;
    my $id = shift;

    return unless $id;

    my $db = $self->db;
    my $sth = $db->prepare('DELETE FROM devices WHERE id=?');
    return !!$sth->execute($id);
  });

  $app->helper('device.uuid' => sub {
    my $c = shift;

    # ensure we've set a uuid cookie from here on out
    my $uuid = $c->signed_cookie('bhack.uuid');

    # generate uuid if not set
    unless($uuid) {
      $uuid = sha1_sum sprintf '%s-device-%s', rand, gmtime->epoch;
      $c->signed_cookie('bhack.uuid' => $uuid);
    }

    return $uuid;
  });
}

1;

