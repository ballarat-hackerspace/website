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

package Plugins::Stream;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util 'dumper';

use Carp 'croak';
use DBI;
use List::Util 'min';
use Time::Piece;

our $VERSION = '0.1';
our $DEFAULT_LIFETIME = 31 * 24 * 60 * 60; # 31 days

has 'db'  => sub { return DBI->connect(shift->dsn, '', '', {sqlite_unicode => 1}); };
has 'dsn';
has 'uuid';

sub register {
  my ($self, $app, $config) = @_;

  $config->{db}  //= '/tmp/bhack.db';
  $self->dsn('dbi:SQLite:dbname='.$config->{db});

  # conditionally build table
  $self->db->do("
    CREATE TABLE IF NOT EXISTS streams (
      id       INTEGER PRIMARY KEY AUTOINCREMENT,
      stream   CHAR(32) NOT NULL DEFAULT '',
      origin   CHAR(32) NOT NULL DEFAULT '',
      type     CHAR(16) NOT NULL DEFAULT '',
      private  INTEGER NOT NULL DEFAULT 0,
      lifetime INTEGER NOT NULL DEFAULT $DEFAULT_LIFETIME,
      data     TEXT NOT NULL DEFAULT '{}',
      meta     TEXT NOT NULL DEFAULT '{}',
      created  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ");

  $app->helper('stream.publish' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    my $stream = $args->{stream} // '';

    # valid stream names are '' and [0-9a-zA-Z]{1,16}
    unless ($stream =~ m/[0-9a-zA-Z]{1,32}/) {
      return undef;
    }

    my $data = $args->{data};

    my $origin = $args->{origin} // '';
    my $type = $args->{type} // (ref $data eq 'HASH' ? 'json' : '');

    my $lifetime = min($args->{lifetime} // $DEFAULT_LIFETIME, $DEFAULT_LIFETIME);

    my $created = $args->{timestamp} // gmtime->strftime('%F %T');
    $data = encode_json($data) if $type eq 'json';
    my $meta = encode_json($args->{meta} // {});

    my $sth = $db->prepare('INSERT INTO streams (stream, origin, type, lifetime, data, meta, created) VALUES (?, ?, ?, ?, ?, ?, ?)');

    return !!$sth->execute($stream, $origin, $type, $lifetime, $data, $meta, $created);
  });

  $app->helper('stream.find' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    my $fetch = $args->{fetch} // 10;
    my $filter = [];
    my $filter_arg = [];

    if (exists($args->{stream})) {
      push @{$filter}, 'stream=?';
      push @{$filter_arg}, $args->{stream};
    }

    if (exists($args->{origin})) {
      push @{$filter}, 'origin=?';
      push @{$filter_arg}, $args->{origin};
    }

    if (exists($args->{type})) {
      push @{$filter}, 'type=?';
      push @{$filter_arg}, $args->{type};
    }

    my $where = '';

    if (@{$filter} and ref($args->{relative}) eq 'ARRAY') {
      $where = ' WHERE ' . join(' AND ', @{$filter}) . ' AND (timestamp, id) < (?, ?)';
      push @{$filter_arg}, @{$args->{relative}};
    }
    elsif (@{$filter}) {
      $where = ' WHERE ' . join(' AND ', @{$filter});
    }
    elsif (ref($args->{relative}) eq 'ARRAY') {
      $where = ' WHERE (timestamp, id) < (?, ?)';
      push @{$filter_arg}, @{$args->{relative}};
    }

    my $limit = " ORDER BY created DESC, id DESC LIMIT $fetch";
    my $sql = 'SELECT id, stream, type, private, data, meta, STRFTIME("%s", created) AS timestamp FROM streams' . $where . $limit;

    my $data = {
      items => []
    };

    my $sth = $db->prepare($sql);
    my $last_id;

    $sth->execute(@{$filter_arg});
    while (my $row = $sth->fetchrow_hashref) {
      # attempt a JSON decode by default
      eval {
        $row->{data} = decode_json $row->{data};
      };

      $row->{timestamp} += 0;
      $row->{meta} = decode_json $row->{meta};

      $last_id = delete $row->{id};
      push @{$data->{items}}, $row;
    };

    $sth->finish;

    my $last = $data->{items}->[-1];
    $data->{relative} = [$last->{timestamp}, $last_id] if $last;

    return $data;
  });

  $app->helper('stream.last_values' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    my $fetch = $args->{fetch} // 10;

    my $limit = " ORDER BY created DESC, id DESC LIMIT $fetch";
    my $sql = 'SELECT id, stream, type, private, data, meta, STRFTIME("%s", created) AS timestamp FROM streams GROUP BY stream' . $limit;

    my $data = {
      items => []
    };

    my $sth = $db->prepare($sql);
    my $last_id;

    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
      # attempt a JSON decode by default
      eval {
        $row->{data} = decode_json $row->{data};
      };

      $row->{timestamp} += 0;
      $row->{meta} = decode_json $row->{meta};

      $last_id = $row->{id};
      push @{$data->{items}}, $row;
    };

    $sth->finish;

    my $last = $data->{items}->[-1];
    $data->{relative} = [$last->{timestamp}, $last_id] if $last;

    return $data;
  });

  $app->helper('stream.streams' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    my $itemsPerPage = ($args->{itemsPerPage} // 1000)+0;
    my $page = ($args->{page} // 0)+0;
    my $offset = $itemsPerPage * $page;

    my $limit = " LIMIT $itemsPerPage OFFSET $offset";
    my $sql = 'SELECT DISTINCT(stream) AS stream FROM streams ORDER BY stream' . $limit;
    my $sql_count = 'SELECT COUNT(DISTINCT(stream)) AS stream FROM streams ORDER BY stream' . $limit;

    my $sth = $db->prepare($sql_count);
    my $totalItems = !!$sth->execute ? $sth->fetchrow_arrayref->[0] : 0;
    $sth->finish;

    $sth = $db->prepare($sql);
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


  $app->helper('stream.delete' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    return !!$db->do("DELETE FROM streams");
  });

  $app->helper('stream.to_csv' => sub {
    my $c = shift;
    my $data = shift;

    my $csv = "stream,type,data,timestamp\n";

    for my $row (@{$data->{items}}) {
      $csv .= join(',', $row->{stream}, $row->{type}, encode_json($row->{data}), $row->{timestamp}) . "\n";
    }

    return $csv;
  });
}

1;


