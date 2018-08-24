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

package Plugins::Badge;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util 'dumper';

use Carp 'croak';
use DBI;
use List::Util 'min';
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
    CREATE TABLE IF NOT EXISTS badges (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      title     CHAR(128) NOT NULL DEFAULT '',
      image_url TEXT NOT NULL DEFAULT '',
      criteria  TEXT NOT NULL DEFAULT '',
      category  CHAR(16) NOT NULL DEFAULT '',
      lifetime  INTEGER DEFAULT 0,
      meta      TEXT NOT NULL DEFAULT '{}',
      created   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  ");

  $app->helper('badges.add' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    my $title= $args->{title} // '';

    if ($title eq '') {
      return undef;
    }

    my $image_url = $args->{image_url} // '';
    my $category = $args->{category} // '';
    my $criteria = $args->{criteria} // '';
    my $lifetime = $args->{lifetime};

    my $meta = encode_json($args->{meta});

    my $sth = $db->prepare('INSERT INTO badges (title, image_url, criteria, category, lifetime, meta) VALUES (?, ?, ?, ?, ?, ?)');

    return !!$sth->execute($title, $image_url, $criteria, $category, $lifetime, $meta);
  });

  $app->helper('badges.find' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    my $itemsPerPage = ($args->{itemsPerPage} // 1000)+0;
    my $page = ($args->{page} // 0)+0;
    my $offset = $itemsPerPage * $page;

    my $filter = [];
    my $filter_arg = [];

    if (exists($args->{title})) {
      push @{$filter}, 'title=?';
      push @{$filter_arg}, $args->{title};
    }

    if (exists($args->{category})) {
      push @{$filter}, 'category=?';
      push @{$filter_arg}, $args->{category};
    }

    my $where = @{$filter} ? ' WHERE ' . join(' AND ', @{$filter}) : '';
    my $limit = " ORDER BY updated DESC LIMIT $itemsPerPage OFFSET $offset";
    my $sql = 'SELECT * FROM badges' . $where . $limit;
    my $sql_count = 'SELECT COUNT(id) FROM badges' . $where;

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

  $app->helper('meta.to_csv' => sub {
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


