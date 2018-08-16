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

package Plugins::Meta;
use Mojo::Base 'Mojolicious::Plugin';

use Carp 'croak';
use DBI;
use Mojo::JSON qw(decode_json encode_json);
use Time::Piece;

our $VERSION = '0.1';

has 'db'  => sub { return DBI->connect(shift->dsn, '', ''); };
has 'dsn';
has 'uuid';

sub register {
  my ($self, $app, $config) = @_;

  $config->{db}  //= '/tmp/bhack.db';
  $self->dsn('dbi:SQLite:dbname='.$config->{db});

  # conditionally build table
  $self->db->do("
    CREATE TABLE IF NOT EXISTS meta (
      id       INTEGER PRIMARY KEY AUTOINCREMENT,
      stream   CHAR(128) NOT NULL DEFAULT '',
      type     CHAR(16) NOT NULL DEFAULT '',
      lifetime INTEGER NOT NULL DEFAULT 2419200,
      data     TEXT NOT NULL DEFAULT '{}',
      meta     TEXT NOT NULL DEFAULT '{}',
      created  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ");

  $app->helper('meta.publish' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    $args->{lifetime} //= 2419200;  # 28 days
    $args->{stream} //= 'common';
    $args->{type} //= '';

    my $sth = $db->prepare('INSERT INTO meta (stream, type, lifetime, data, meta) VALUES (?, ?, ?, ?, ?)');
    return !!$sth->execute(
      $args->{stream},
      $args->{type},
      $args->{lifetime},
      encode_json($args->{data}),
      encode_json($args->{meta})
    );
  });

  $app->helper('meta.find' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    my $filter = [];
    my $filter_arg = [];

    if ($args->{stream}) {
      push @{$filter}, 'stream=?';
      push @{$filter_arg}, $args->{stream};
    }

    if ($args->{type}) {
      push @{$filter}, 'type=?';
      push @{$filter_arg}, $args->{type};
    }

    my $where = @{$filter} ? ' WHERE ' . join(' AND ', @{$filter}) : '';
    my $limit = $args->{limit} ? ' ORDER BY updated DESC LIMIT ' . $args->{limit} : '';
    my $sql = 'SELECT * FROM meta' . $where . $limit;

    my $sth = $db->prepare($sql, @{$filter_arg});
    my $data = [];

    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
      $row->{data} = decode_json $row->{data};
      $row->{meta} = decode_json $row->{meta};

      push @{$data}, $row;
    };
    $sth->finish;

    return $data;
  });
}

1;


