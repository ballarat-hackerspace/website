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

package Mojo::MQTT::Message;

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Util 'dumper';

use constant {
  MQTT_CONNECT     => 0x1,
  MQTT_CONNACK     => 0x2,
  MQTT_PUBLISH     => 0x3,
  MQTT_PUBACK      => 0x4,
  MQTT_PUBREC      => 0x5,
  MQTT_PUBREL      => 0x6,
  MQTT_PUBCOMP     => 0x7,
  MQTT_SUBSCRIBE   => 0x8,
  MQTT_SUBACK      => 0x9,
  MQTT_UNSUBSCRIBE => 0xa,
  MQTT_UNSUBACK    => 0xb,
  MQTT_PINGREQ     => 0xc,
  MQTT_PINGRESP    => 0xd,
  MQTT_DISCONNECT  => 0xe,

  MQTT_QOS_AT_MOST_ONCE  => 0x0,
  MQTT_QOS_AT_LEAST_ONCE => 0x1,
  MQTT_QOS_EXACTLY_ONCE  => 0x2,

  MQTT_CONNECT_ACCEPTED                              => 0,
  MQTT_CONNECT_REFUSED_UNACCEPTABLE_PROTOCOL_VERSION => 1,
  MQTT_CONNECT_REFUSED_IDENTIFIER_REJECTED           => 2,
  MQTT_CONNECT_REFUSED_SERVER_UNAVAILABLE            => 3,
  MQTT_CONNECT_REFUSED_BAD_USER_NAME_OR_PASSWORD     => 4,
  MQTT_CONNECT_REFUSED_NOT_AUTHORIZED                => 5,

};

our $TYPES = {
  connect   => MQTT_CONNECT,
  pingreq   => MQTT_PINGREQ,
  publish   => MQTT_PUBLISH,
  subscribe => MQTT_SUBSCRIBE,

  2  => MQTT_CONNACK,
  3  => MQTT_PUBLISH,
  9  => MQTT_SUBACK,
  13 => MQTT_PINGRESP,
};

our $MQTT_PROTO_ID_V3 = [0x00, 0x06, 0x4d, 0x51, 0x49, 0x73, 0x64, 0x70, 0x03];
our $MQTT_PROTO_ID_V4 = [0x00, 0x04, 0x4d, 0x51, 0x54, 0x54, 0x04];

sub new {
  my ($class, $type) = (shift, shift);

  my $args = shift // {};

  die "$type message is not currently supported." unless exists $TYPES->{$type};

  $args->{type} = $TYPES->{$type};

  # sanitise
  if ($args->{type} == MQTT_CONNECT) {
    $args->{mqtt_version}  //= 4;
    $args->{keep_alive}    //= 60;
    $args->{clean_session} //= 1;

    die 'client_id is required for connect message.' unless $args->{client_id};
  }
  elsif ($args->{type} == MQTT_PUBLISH) {
  }
  elsif ($args->{type} == MQTT_SUBSCRIBE) {
    $args->{message_id} //= 1;
    $args->{qos} //= MQTT_QOS_AT_MOST_ONCE;

    die 'topics is required for subscribe message.' unless ref($args->{topics}) eq 'ARRAY';
  }

  return $class->SUPER::new($args);
}

sub new_from_bytes {
  my ($class, $bytes) = @_;

  my $message = $class->_decode($bytes);

  return undef unless $message;

  return $class->new($message->{type} => $message);
}

sub _decode {
  my ($self, $bytes) = @_;

  return undef if length $bytes < 2;

  my $b = unpack 'C', $bytes;

  my $type = ($b & 0xf0) >> 4;
  my $info = ($b & 0x0f);

  my $message = {
    type => $type
  };

  my $offset = 1;
  my $multiplier = 1;
  my $rem_length = 0;
  my $d;

  do {
    $d = unpack 'C', substr $bytes, $offset++, 1;
    $rem_length += ($d & 0x7f) * $multiplier;
    $multiplier *= 128;
  } while ($d & 0x80);

  my $end = $offset + $rem_length;

  if ($type == MQTT_CONNACK) {
    my $flags = unpack 'C', substr $bytes, $offset++, 1;

    $message->{session_present} = 1 if ($flags & 0x01);
    $message->{return_code} = unpack 'C', substr $bytes, $offset++, 1;
  }
  elsif ($type == MQTT_PUBLISH) {
    my $qos = ($info >> 1) & 0x03;

    my $l = unpack 'n', substr $bytes, $offset, 2;
    $offset += 2;

    my $topic = substr $bytes, $offset, $l;
    $offset += $l;

    # if QoS 1 or 2 there will be a messageIdentifier
    if ($qos > 0) {
      $message->{message_id} = unpack 'n', substr $bytes, $offset+=2, 2;
    }

    $message->{retained} = $info & 0x01;
    $message->{duplicate} = $info & 0x08;
    $message->{qos} = $qos;

    my $data = substr $bytes, $offset, $end-$offset;

    $message->{topic} = $topic;
    $message->{data} = $data;
  }

  return $message;
}

sub encode {
  my $self = shift;

  my $first = ($self->{type} & 0x0f) << 4;

  # calculate length header and payload
  my $rem_length = 0;
  my $topic_length = [];
  my $destination_length = 0;
  my $will_message_payload;

  $rem_length += 2 if $self->{message_id};

  if ($self->{type} == MQTT_CONNECT) {
    # mqtt version
    if ($self->{mqtt_version} == 3) {
      $rem_length += scalar @{$MQTT_PROTO_ID_V3} + 3;
    }
    elsif ($self->{mqtt_version} == 4) {
      $rem_length += scalar @{$MQTT_PROTO_ID_V4} + 3;
    }

    # client id
    $rem_length += length($self->{client_id}) + 2;

    # will message
    if ($self->{will}) {
      $rem_length += $self->{will}{destination_name} + 2;
      $rem_length += $self->{will}{payload} + 2;

      $will_message_payload = $self->{will}{payload};
    }

    if ($self->{username}) {
      $rem_length += $self->{username} + 2;
    }

    if ($self->{password}) {
      $rem_length += $self->{password} + 2;
    }
  }
  elsif ($self->{type} == MQTT_SUBSCRIBE) {
    # Qos = 1;
    $first |= 0x02;

    for my $topic (@{$self->{topics}}) {
      $rem_length += length($topic) + 2;

    }

    $rem_length += scalar @{$self->{topics}}; # 1 byte per topic QoS
  }

  my $mbi = _encodeMBI($rem_length);
  my $buffer = [];

  push @{$buffer}, $first;
  push @{$buffer}, @{$mbi};

  if ($self->{type} == MQTT_CONNECT) {
    if ($self->{mqtt_version} == 3) {
      push @{$buffer}, @{$MQTT_PROTO_ID_V3};
    }
    elsif ($self->{mqtt_version} == 4) {
      push @{$buffer}, @{$MQTT_PROTO_ID_V4};
    }

    my $flags = 0;

    $flags = 0x02 if $self->{clean_session};

    if ($self->{will}) {
      $flags = 0x04;
      $flags |= $self->{will}{qos} << 3;
      $flags |= 0x20 if $self->{will}{retain};
    }

    $flags |= 0x80 if $self->{username};
    $flags |= 0x40 if $self->{password};

    push @{$buffer}, $flags;
    push @{$buffer}, unpack 'C*', pack('n', $self->{keep_alive});
  }

  push @{$buffer}, unpack 'C*', pack('n', $self->{message_id}) if $self->{message_id};

  if ($self->{type} == MQTT_CONNECT) {
    push @{$buffer}, _encodeString($self->{client_id});

    if ($self->{will}) {
      push @{$buffer}, unpack 'C*', $self->{will}{destination_name};
      push @{$buffer}, pack('n', length $self->{will}{payload});
      push @{$buffer}, unpack 'C*', $self->{will}{payload};
    }

    push @{$buffer}, unpack 'C*', $self->{username} if $self->{username};
    push @{$buffer}, unpack 'C*', $self->{password} if $self->{password};
  }
  elsif ($self->{type} == MQTT_SUBSCRIBE) {
    for my $topic (@{$self->{topics}}) {
      push @{$buffer}, _encodeString($topic);
      push @{$buffer}, $self->{qos};
    }
  }

  return pack 'C*', @{$buffer};
}

sub _encodeMBI {
  my $n = shift;

  my $buffer = [];

  do {
    my $d = $n % 128;
    $n = $n >> 7;
    $d |= 0x80 if $n > 0;
    push @{$buffer}, $d;
  } while ($n > 0 && @{$buffer} < 4);

  return $buffer;
}

sub _encodeString {
  my $s = shift;

  my @buffer;

  push @buffer, unpack 'C*', pack 'n', length $s;
  push @buffer, unpack 'C*', $s;

  return @buffer;
}

1;
