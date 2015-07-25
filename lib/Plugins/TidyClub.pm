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

package Plugins::TidyClub;
use Mojo::Base 'Mojolicious::Plugin';

use Carp 'croak';
use Mojo::UserAgent;
use Mojo::Util qw(dumper);
use Time::Piece;

our $VERSION = '0.1';

use constant {
  TIDYCLUB_SESSION_KEY => 'tidyclub',
};

has _ua => sub { Mojo::UserAgent->new };

sub register {
  my ($self, $app, $config) = @_;

  my $url = Mojo::URL->new(sprintf 'https://%s.tidyclub.com/', $config->{organisation});

  $app->helper('tidyclub.is_authenticated' => sub {
    my $c = shift;

    my $tc = $c->session(TIDYCLUB_SESSION_KEY) // {};

    # check token expiry
    if ($tc->{token_expiry} && $tc->{token_expiry} <= gmtime->epoch) {
      delete $c->session->{TIDYCLUB_SESSION_KEY()};
      $tc = {};
    }

    return $tc->{id};
  });

  $app->helper('tidyclub.user' => sub {
    return shift->session(TIDYCLUB_SESSION_KEY) // {};
  });

  $app->helper('tidyclub.user.groups' => sub {
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $c = shift;
    my $args = @_%2 ? shift : {@_};

    my $tc = $c->session(TIDYCLUB_SESSIONKEY());

    if ($cb) {
      return $c->delay(
        sub {
          my ($delay) = @_;
          $self->_ua->get($url->path('/api/v1/contacts/me/groups') => {Authorization => "Bearer $tc->{token}"} => $delay->begin);
        },
        sub {
          my ($delay, $tx) = @_;
          my ($data, $err) = process_reponse($tx);

          $c->$cb($err, $data);
        }
      );
    }
    else {
    }
  });

  $app->helper('tidyclub.login' => sub {
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $c = shift;
    my $args = @_%2 ? shift : {@_};

    my $params = {
      client_id     => $config->{client_id},
      client_secret => $config->{client_secret},
      grant_type    => 'password',
      password      => $args->{password},
      username      => $args->{email},
    };

    if ($cb) {
      return $c->delay(
        sub {
          my ($delay) = @_;
          $self->_ua->post($url->path('/oauth/token'), form => $params => $delay->begin);
        },
        sub {
          my ($delay, $tx) = @_;
          my ($data, $err) = process_response($tx);

          return $c->$cb($err, '') if $err;

          # delay store token for final session store
          $delay->data(token => $data->{access_token});

          $self->_ua->get($url->path('/api/v1/contacts/me') => {Authorization => "Bearer $data->{access_token}"} => $delay->begin);
        },
        sub {
          my ($delay, $tx) = @_;
          my ($data, $err) = process_response($tx);

          return $c->$cb($err, '') if $err;

          $data->{token}        = $delay->data('token');
          $data->{token_expiry} = gmtime->epoch + 7200; # 2 hour token life

          $delay->data(tidyclub => $data);

          my $path = sprintf '/api/v1/contacts/%d/groups', $data->{id};

          $self->_ua->get($url->path($path) => {Authorization => "Bearer $data->{token}"} => $delay->begin);
        },
        sub {
          my ($delay, $tx) = @_;
          my ($data, $err) = process_response($tx);

          # check we are in the group label "Members"
          if (!$err && !!grep { $_->{label} eq 'Members' } @{$data}) {
            $c->session(TIDYCLUB_SESSION_KEY() => $delay->data('tidyclub'));
          }

          $c->$cb($err, $data);
        },
      );
    }
    else {
      my $tx = $self->_ua->post($url, form => $params);
      my ($data, $err) = process_response($tx);

      die $err if $err;

      return $data;
    }
  });

  $app->helper('tidyclub.logout' => sub {
    delete shift->session->{TIDYCLUB_SESSION_KEY()};
  });
}

sub process_response {
  my $tx = shift;
  my ($data, $err);

  if ($err = $tx->error) {
    $err = $err->{message} || $err->{code};
  }
  elsif ($tx->res->headers->content_type =~ m!^(application/json|text/javascript)(;\s*charset=\S+)?$!) {
    $data = $tx->res->json;
  }
  else {
    $data = Mojo::Parameters->new($tx->res->body)->to_hash;
  }

  # no data is an error of itself
  $err = $data ? '' : $err || 'Unknown error';

  return ($data, $err);
}

1;
