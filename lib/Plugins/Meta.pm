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
use Mojo::Util 'dumper';
use Time::Piece;

our $VERSION = '0.1';
our $DEFAULT_LIFETIME = 31 * 60 * 60; # 31 days

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
      stream   CHAR(32) NOT NULL DEFAULT '',
      type     CHAR(16) NOT NULL DEFAULT '',
      lifetime INTEGER NOT NULL DEFAULT $DEFAULT_LIFETIME,
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

    my $stream = $args->{stream} // '';

    # valid stream names are '' and [0-9a-zA-Z]{1,16}
    unless ($stream eq '' || $stream =~ m/[0-9a-zA-Z]{1,32}/) {
      return undef;
    }

    my $lifetime = $args->{lifetime} // $DEFAULT_LIFETIME;
    my $type = $args->{type} // '';
    my $created = $args->{timestamp} // gmtime->epoch;
    my $data = encode_json($args->{data});
    my $meta = encode_json($args->{meta});

    my $sth = $db->prepare('INSERT INTO meta (stream, type, lifetime, data, meta, created) VALUES (?, ?, ?, ?, ?, ?)');

    return !!$sth->execute($stream, $type, $lifetime, $data, $meta, $created);
  });

  $app->helper('meta.find' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    my $itemsPerPage = ($args->{itemsPerPage} // 1000)+0;
    my $page = ($args->{page} // 0)+0;
    my $offset = $itemsPerPage * $page;

    my $filter = [];
    my $filter_arg = [];

    if (exists($args->{stream})) {
      push @{$filter}, 'stream=?';
      push @{$filter_arg}, $args->{stream};
    }

    if (exists($args->{type})) {
      push @{$filter}, 'type=?';
      push @{$filter_arg}, $args->{type};
    }

    my $where = @{$filter} ? ' WHERE ' . join(' AND ', @{$filter}) : '';
    my $limit = " ORDER BY updated DESC LIMIT $itemsPerPage OFFSET $offset";
    my $sql = 'SELECT stream,type,data,meta,STRFTIME("%s", updated) AS timestamp FROM meta' . $where . $limit;
    my $sql_count = 'SELECT COUNT(id) FROM meta' . $where;

    my $sth = $db->prepare($sql_count);
    my $totalItems = !!$sth->execute(@{$filter_arg}) ? $sth->fetchrow_arrayref->[0] : 0;
    $sth->finish;

    $sth = $db->prepare($sql);
    my $data = {
      itemsPerPage => $itemsPerPage,
      totalItems => $totalItems,
      page => $page,
      items => []
    };

    $sth->execute(@{$filter_arg});
    while (my $row = $sth->fetchrow_hashref) {
      $row->{data} = decode_json $row->{data};
      $row->{meta} = decode_json $row->{meta};

      push @{$data->{items}}, $row;
    };
    $sth->finish;

    return $data;
  });

  $app->helper('meta.streams' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    my $itemsPerPage = ($args->{itemsPerPage} // 1000)+0;
    my $page = ($args->{page} // 0)+0;
    my $offset = $itemsPerPage * $page;

    my $limit = " LIMIT $itemsPerPage OFFSET $offset";
    my $sql = 'SELECT DISTINCT(stream) AS stream FROM meta ORDER BY stream' . $limit;
    my $sql_count = 'SELECT COUNT(DISTINCT(stream)) AS stream FROM meta ORDER BY stream' . $limit;

    my $sth = $db->prepare($sql_count);
    my $totalItems = !!$sth->execute ? $sth->fetchrow_arrayref->[0] : 0;
    $sth->finish;

    my $sth = $db->prepare($sql);
    my $data = {
      itemsPerPage => $itemsPerPage,
      totalItems => $totalItems,
      page => $page,
      items => []
    };

    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
      push @{$data->{items}}, $row->{stream};
    };
    $sth->finish;

    return $data;
  });

  $app->helper('meta.to_csv' => sub {
    my $c = shift;
    my $data = shift;

    my $csv = "stream,type,data,timestamp\n";

    for my $row (@{$data}) {
      $csv .= join(',', $row->{stream}, $row->{type}, encode_json($row->{data}), $row->{timestamp}) . "\n";
    }

    return $csv;
  });
}

1;


