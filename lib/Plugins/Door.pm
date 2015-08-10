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

package Plugins::Door;
use Mojo::Base 'Mojolicious::Plugin';

use Carp 'croak';
use Mojo::UserAgent;
use Mojo::Util qw(dumper);
use Time::Piece;

our $VERSION = '0.1';

has 'url';
has _ua => sub { Mojo::UserAgent->new };

sub register {
  my ($self, $app, $config) = @_;

  $self->url(Mojo::URL->new($config->{url} // "http://boiler.bhack:8080/"));

  $app->helper('door.close' => sub { $self->_process_request(shift, 'close', @_) });
  $app->helper('door.enter' => sub { $self->_process_request(shift, 'enter', @_) });
  $app->helper('door.open'  => sub { $self->_process_request(shift, 'open',  @_) });
}

sub _process_request {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my ($self, $c, $mode) = (shift, shift, shift);
  my $args = @_%2 ? shift : {@_};

  my $mac = $args->{mac} // '00:00:00:00:00:00';

  if ($cb) {
    return $c->delay(
      sub {
        my ($delay) = @_;

        $self->_ua->get($self->url->path($mode)->query(mac => $mac) => $delay->begin);
      },
      sub {
        my ($delay, $tx) = @_;
        my ($data, $err) = _process_response($tx);

        $c->$cb($err ? 500 : 200, $err // $data);
      },
    );
  }
  else {
    my $tx = $self->_ua->get($self->url->path($mode)->query(mac => $mac));
    my ($data, $err) = _process_response($tx);

    return ($err ? 500 : 200, $err // $data);
  }
}

sub _process_response {
  my $tx = shift;
  my ($data, $err);

  if ($err = $tx->error) {
    $err = $err->{message} || $err->{code};
  }
  elsif ($tx->res->headers->content_type =~ m!^(application/json|text/javascript)(;\s*charset=\S+)?$!) {
    $data = $tx->res->json;
  }

  # no data is an error of itself
  $err = $data ? '' : $err || 'Unknown error';

  return ($data, $err);
}

1;

