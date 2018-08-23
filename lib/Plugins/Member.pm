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

package Plugins::Member;
use Mojo::Base 'Mojolicious::Plugin';

#
# This plugin depends on plugins ::Device and ::TidyHQ
#

use Carp 'croak';
use DBI;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util 'dumper';
use Time::Piece;

our $VERSION = '0.1';
our $DEFAULT_LIFETIME = 31 * 60 * 60; # 31 days

has 'db'  => sub { return DBI->connect(shift->dsn, '', '', {RaiseError => 1}); };
has 'dsn';
has 'uuid';

sub register {
  my ($self, $app, $config) = @_;

  my $db = $config->{db} // '/tmp/bhack.db';
  $self->dsn("dbi:SQLite:dbname=$db");

  # conditionally build table
  $self->db->do("
    CREATE TABLE IF NOT EXISTS members (
      email              CHAR(128) NOT NULL PRIMARY KEY,
      name               CHAR(128),
      avatar_url         CHAR(128),

      membership         CHAR(32),
      membership_expires TIMESTAMP,

      waiver_sign        INTEGER DEFAULT 0,
      waiver_signed      TIMESTAMP,

      data               TEXT NOT NULL DEFAULT '{}',
      meta               TEXT NOT NULL DEFAULT '{}',
      created            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ");

  $app->helper('member.create' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    my $email = $args->{email};

    unless ($email eq '' || length($email) > 128 || $email !~ m/[^@]+@[^\.]+\..+}/) {
      warn 'FAIL';
      return undef;
    }

    my $now = gmtime->epoch;

    my $name = $args->{name};
    my $avatar_url = $args->{avatar_url};

    my $membership = $args->{membership};
    my $membership_expires = $args->{membership_expires};

    my $waiver_sign = $args->{waiver_sign} // 0;
    my $waiver_signed = $waiver_sign ? $now->strftime('%F %T') : undef;

    my $data = encode_json($args->{data} // {});
    my $meta = encode_json($args->{meta} // {});

    my $sth = $db->prepare('INSERT INTO members (name, email, avatar_url, membership, membership_expires, waiver_sign, waiver_signed, data, meta) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)');

    return !!$sth->execute($name, $email, $avatar_url, $membership, $membership_expires, $waiver_sign, $waiver_signed, $data, $meta);
  });

  $app->helper('member.find' => sub {
    my $c = shift;
    my $args = @_%2 ? shift : {@_};
    my $db = $self->db;

    my $email = $args->{email};

    my $sql = 'SELECT * FROM members WHERE email=?';

    my $sth = $db->prepare($sql);
    $sth->execute($email);

    my $members = $sth->fetchall_arrayref({});
    $sth->finish;

    if (@{$members} == 1) {
      my $member = $members->[0];
      $member->{data} = decode_json $member->{data};
      $member->{meta} = decode_json $member->{meta};

      return $member;
    }

    return undef;
  });

  $app->helper('member.login' => sub {
    my ($c, $email, $password) = @_;

    my $promise = $c->tidyhq->login(email => $email, password => $password)->then(sub {
      my $tidyhq = shift;

      my $member = $c->member->find(email => $email);

      unless ($member) {
        my $now = gmtime->epoch;

        my $ret = $c->member->create(
          email => $email,
          meta => {
            tidyhq => $tidyhq,
            logins => 1,
            last_login => $now
          }
        );

        my $member = $c->member->find(email => $email);

        return Mojo::Promise->new->reject('Unable to create new membership.') unless ($member);
      }

      $c->session(user => $email);

      return Mojo::Promise->new->resolve($member);
    });
  });

  $app->helper('member.logout' => sub {
    my $c = shift;

    # clear our session member identifier
    $c->session(user => undef);

    # logout of any tidyhq sessions
    $c->tidyhq->logout;

    # logout of any pateron sessions
  });

  $app->helper('member.current.has_active_membership' => sub {
    my $c = shift;
  });

  $app->helper('member.current.is_gatekeeper' => sub {
    my $c = shift;
  });

  $app->helper('member.current.is_not_dooropener' => sub {
    my $c = shift;

    my $bhack = $c->stash('bhack');

    return {'code' => 4001, 'error' => 'Inactive Membership'   } unless $c->tidyhq->has_active_membership({tidyhq => $bhack});
    return {'code' => 4002, 'error' => 'Insuffienct Membership'} unless $c->tidyhq->in_group('full-time members', {tidyhq => $bhack});
    return {'code' => 4003, 'error' => 'Unregistered Device'   } unless $c->device->is_whitelisted;

    return undef;
  });
}

1;


