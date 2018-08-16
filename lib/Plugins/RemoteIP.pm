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

package Plugins::RemoteIP;
use Mojo::Base 'Mojolicious::Plugin';

use NetAddr::IP;

our $VERSION = '0.1';

sub register {
  my ($self, $app, $config) = @_;

  $config->{order} ||= ['x-real-ip', 'x-forwarded-for', 'tx'];

  $app->helper(remote_ip => sub {
    my $c = shift;

    my $ip = $c->req->headers->header('X-Real-IP') //
             $c->req->headers->header('X-Forwarded-For') //
             $c->tx->remote_address;

    return NetAddr::IP->new((split /[, ]/, $ip)[0]);
  });
}

1;
