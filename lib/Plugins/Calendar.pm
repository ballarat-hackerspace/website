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

package Plugins::Calendar;
use Mojo::Base 'Mojolicious::Plugin';

use Carp 'croak';
use Mojo::IOLoop;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::Util qw(dumper unquote url_escape);
use POSIX 'strftime';
use Time::Piece;

our $VERSION = '0.1';

has 'api_key';
has 'events';
has 'url';
has _ua => sub { Mojo::UserAgent->new };

my $events = [];

sub register {
  my ($self, $app, $config) = @_;

  my $id = $config->{id} // '';
  my $url = "https://www.googleapis.com/calendar/v3/calendars/$id/";

  $self->url($url);
  $self->api_key($config->{api_key} // 'bad');

  $app->log->info("Collecting calendar events from: $id");
  $self->_update_events;

  Mojo::IOLoop->recurring(10 * 60, sub {
    $app->log->info("Collecting calendar events from: $id");
    $self->_update_events;
  });

  $app->helper('events.list' => sub {
    my $c = shift;
    my $limit = shift // 10;

    return [] if $limit < 1;
    return $events if ($limit > @{$events});

    return [ @{$events}[0..$limit-1] ];
  });

  $app->helper('events.update' => sub {
  });
}

sub _update_events {
  my $self = shift;

  my $now = strftime("%FT00:00:00+1000", localtime);
  my $url = $self->url . sprintf("events/?maxResults=50&singleEvents=true&orderBy=startTime&timeMin=%s&key=%s", url_escape($now), $self->api_key);

  $self->_ua->get($url => sub {
    my ($ua, $tx) = @_;
    my ($data, $err) = _process_response($tx);

    return if $err;

    $events = [];

    foreach my $item (@{$data->{items} // []}) {
      push @{$events}, {
        title     => $item->{summary},
        startTime => Time::Piece->strptime($item->{start}{dateTime}, "%Y-%m-%dT%H:%M:%S+10:00"),
        endTime   => Time::Piece->strptime($item->{end}{dateTime}, "%Y-%m-%dT%H:%M:%S+10:00"),
        link      => $item->{htmlLink},
        location  => $item->{location},
      };
    }
  });
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


