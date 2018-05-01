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

package Plugins::TidyHQ;
use Mojo::Base 'Mojolicious::Plugin';

use Carp 'croak';
use Mojo::JSON qw(encode_json);
use Mojo::UserAgent;
use Mojo::Util qw(b64_encode dumper);
use Time::Piece;

our $VERSION = '0.1';

use constant {
  TIDYHQ_SESSION_KEY => 'tidyhq',
};

has _ua   => sub { Mojo::UserAgent->new };

sub register {
  my ($self, $app, $config) = @_;

  my $url = Mojo::URL->new(sprintf 'https://%s.tidyhq.com/', $config->{organisation});

  $app->log->info('TidyHQ proxy registered for: ' . $url);

  $self->{url} = $url;
  $self->{config} = $config;

  $self->{proxy} = {
    members => {},
    tidyhq  => {}
  };

  $app->helper('tidyhq.has_active_membership' => sub {
    my ($c, $options) = @_;

    $options //= {};

    my $tidyhq = $options->{tidyhq} // $c->session(TIDYHQ_SESSION_KEY) // {};

    # check token expiry
    if ($tidyhq->{token_expiry} && $tidyhq->{token_expiry} <= gmtime->epoch) {
      delete $c->session->{TIDYHQ_SESSION_KEY()};
      $tidyhq = {};
    }

    if (my $uid = $tidyhq->{id}) {
      my $user = $self->proxy_user_get($uid);
      my $now = gmtime;

      for my $membership ( @{$user->{memberships} // []} ) {
        next unless $membership->{status} eq 'activated';

        #my $end_date = Time::Piece->strptime($membership->{end_date}, '%Y-%m-%d');
        return 1 if ($membership->{end_date} - $now) > 0;
      }
    }

    return 0;
  });

  $app->helper('tidyhq.in_group' => sub {
    my ($c, $group, $options) = @_;

    $options //= {};

    return undef unless $group;

    my $tidyhq = $options->{tidyhq} // $c->session(TIDYHQ_SESSION_KEY) // {};

    # check token expiry
    if ($tidyhq->{token_expiry} && $tidyhq->{token_expiry} <= gmtime->epoch) {
      delete $c->session->{TIDYHQ_SESSION_KEY()};
      $tidyhq = {};
    }

    if (my $uid = $tidyhq->{id}) {
      my $user = $self->proxy_user_get($uid);

      return !!grep { $_ eq $group } @{$user->{contact}{groups} // []};
    }

    return 0;
  });

  $app->helper('tidyhq.is_authenticated' => sub {
    my $c = shift;

    my $tidyhq = $c->session(TIDYHQ_SESSION_KEY) // {};

    # check token expiry
    if ($tidyhq->{token_expiry} && $tidyhq->{token_expiry} <= gmtime->epoch) {
      delete $c->session->{TIDYHQ_SESSION_KEY()};
      $tidyhq = {};
    }

    return $tidyhq->{id};
  });

  $app->helper('tidyhq.user' => sub {
    my $session = shift->session(TIDYHQ_SESSION_KEY) // {};
    my $user = $self->proxy_user_get($session->{id});
    return $user;
  });

  $app->helper('tidyhq.user.groups' => sub {
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $c = shift;
    my $args = @_%2 ? shift : {@_};

    my $tidyhq = $c->session(TIDYHQ_SESSIONKEY());

    if ($cb) {
      return $c->delay(
        sub {
          my ($delay) = @_;
          $self->_ua->get($url->path('/api/v1/contacts/me/groups') => {Authorization => "Bearer $tidyhq->{token}"} => $delay->begin);
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

  $app->helper('tidyhq.login' => sub {
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

          my $user = $self->proxy_user_get($data->{id});

          $user->{token}        = $delay->data('token');
          $user->{token_expiry} = gmtime->epoch + 7200; # 2 hour token life

          warn dumper 'USER', $user;

          # store all in session
          $c->session(TIDYHQ_SESSION_KEY() => $user);

          # store in bhack session
          my $bhack = $c->stash('bhack');
          my $bhack_tidyhq = {
            email_address => $user->{email_address},
            first_name    => $user->{first_name},
            groups        => $user->{groups},
            id            => $user->{id},
            last_name     => $user->{last_name},
            nick_name     => $user->{nick_name},
            memberships   => $user->{memberships},
          };

          $bhack = {%{$bhack}, %{$bhack_tidyhq}};

          $c->stash('bhack' => $bhack);

          $c->$cb($err, $user);
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

  $app->helper('tidyhq.logout' => sub {
    delete shift->session->{TIDYHQ_SESSION_KEY()};
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

  # no data is an error in and of itself
  $err = $data ? '' : $err || 'Unknown error';

  return ($data, $err);
}

sub proxy_auth_token {
  my $self = shift;

  my $config = $self->{config};
  my $tidyhq = $self->{proxy}{tidyhq};
  my $url = $self->{url};

  if (! defined $tidyhq->{token_expiry} || $tidyhq->{token_expiry} <= gmtime->epoch) {

    my $params = {
      client_id     => $config->{client_id},
      client_secret => $config->{client_secret},
      grant_type    => 'password',
      username      => $config->{proxy_email},
      password      => $config->{proxy_password},
    };

    my $tx = $self->_ua->post($url->path('/oauth/token'), form => $params);

    my ($data, $err) = process_response($tx);

    return undef if $err;

    # delay store token for final session store
    $self->{proxy}{tidyhq} = {
      token        => $data->{'access_token'},
      token_expiry => gmtime->epoch + 7200,  # 2 hour token life
    };
  }

  return $self->{proxy}{tidyhq}{token};
}

sub proxy_user_get {
  my $self = shift;
  my $uid  = shift;

  return undef unless $uid;

  my $url = $self->{url};
  my $user = $self->{members}{$uid};

  # update if not existing
  unless($user) {
    my $token = $self->proxy_auth_token;

    my $headers = {Authorization => "Bearer $token"};

    my $path = sprintf '/api/v1/contacts/%d', $uid;
    my $tx = $self->_ua->get($url->path($path) => $headers);
    my ($data, $err) = process_response($tx);

    return undef if $err;

    $user->{id}      = $data->{id};
    $user->{contact} = $data;

    $path = sprintf '/api/v1/contacts/%d/groups', $data->{id};
    $tx = $self->_ua->get($url->path($path) => $headers);
    ($data, $err) = process_response($tx);

    if (!!grep { $_->{label} eq 'Members' } @{$data}) {
      $user->{contact}{groups} = [map { lc $_->{label} } @{$data}];
    }

    $tx = $self->_ua->get($url->path('/api/v1/membership_levels') => $headers);
    ($data, $err) = process_response($tx);

    return undef if $err;

    my $membership_levels = {};
    map { $membership_levels->{$_->{id}} = lc $_->{name}} @{$data};

    $path = sprintf '/api/v1/contacts/%d/memberships', $uid;
    $tx =  $self->_ua->get($url->path($path) => $headers);
    ($data, $err) = process_response($tx);

    # check we are in the group label "Members"
    if (!$err && !!@{$data}) {
      my $memberships = [];

      for my $m (@{$data}) {
        push @{$memberships}, {
          end_date => Time::Piece->strptime($m->{end_date}, '%Y-%m-%d'),
          name     => $membership_levels->{$m->{membership_level_id}},
          status   => $m->{state},
        };
      }

      # add groups to data and store all in session
      $user->{memberships} = $memberships;
      $self->{members}{$uid} = $user;
    }
  }

  return $user;
}

1;
