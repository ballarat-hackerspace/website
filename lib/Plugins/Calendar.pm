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
has 'url';
has '_events';
has '_ua' => sub { Mojo::UserAgent->new };

my $events = [];

sub register {
  my ($plugin, $app, $config) = @_;

  my $id = $config->{id} // '';
  my $api_key = $config->{api_key} // 'bad';
  my $update_interval = $config->{update_interval} // 10 * 60;

  my $url = "https://www.googleapis.com/calendar/v3/calendars/$id/";

  $plugin->url($url);
  $plugin->api_key($api_key);

  $app->log->info("Collecting Google calendar events every $update_interval seconds from: $id");
  $plugin->_update_gcal_events;

  Mojo::IOLoop->recurring($update_interval, sub {
    $app->log->info("Collecting Google calendar events from: $id");
    $plugin->_update_gcal_events;
  });

  $app->helper('events.list' => sub {
    my $c = shift;
    my $limit = shift // 10;

    # return empty for poor limit ranges
    return [] if $limit < 1;

    # return all if limit is higher than our count
    return $events if ($limit > @{$events});

    return [@{$events}[0..$limit-1]];
  });
}

sub _update_gcal_events {
  my $self = shift;

  my $now = localtime;

  my $time_min = strftime("%FT00:00:00+1000", localtime);
  my $url = $self->url . sprintf("events/?maxResults=50&singleEvents=true&orderBy=startTime&timeMin=%s&key=%s", url_escape($time_min), $self->api_key);

  $self->_ua->get($url => sub {
    my ($ua, $tx) = @_;
    my ($data, $err) = _process_response($tx);

    return if $err;

    $events = [];

    foreach my $item (@{$data->{items} // []}) {
      $item->{start}{dateTime} =~ s/([+-]\d\d):(\d\d)/$1$2/;
      $item->{end}{dateTime} =~ s/([+-]\d\d):(\d\d)/$1$2/;

      my $start_time = localtime(Time::Piece->strptime($item->{start}{dateTime}, "%Y-%m-%dT%H:%M:%S%z")->epoch);
      my $end_time = localtime(Time::Piece->strptime($item->{end}{dateTime}, "%Y-%m-%dT%H:%M:%S%z")->epoch);

      my $tags = [ grep { $_ } split(/\n?#/, $item->{description} // '') ];

      push @{$events}, {
        end_time    => $end_time,
        in_progress => ($start_time <= $now) && ($now <= $end_time),
        is_complete => ($now > $end_time),
        link        => $item->{htmlLink},
        location    => $item->{location},
        now         => $now,
        start_time  => $start_time,
        tags        => $tags,
        title       => $item->{summary},
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


