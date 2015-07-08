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

package Plugins::Jekyll;
use Mojo::Base 'Mojolicious::Plugin';

use Data::Dumper;
use File::Basename qw(basename);
use File::Spec;
use Mojo::Util qw(slurp trim);
use Text::MultiMarkdown qw(markdown);
use Time::Piece;
use YAML::Tiny;

use constant TYPE_MAP => {
  html  => 'html',
  md    => 'markdown',
  txt   => 'text',
};

use constant DEBUG      => $ENV{MOJO_JEKYLL_DEBUG} || 0;
use constant BLOG_DIR   => './blog';
use constant BLOG_STYLE => 'markdown';

our $VERSION = '1.1';

has conf => sub { +{} };

sub register {
  my ($plugin, $app, $conf) = @_;

  # default values
  $conf->{directory}  ||= BLOG_DIR;
  $conf->{style}      ||= BLOG_STYLE;

  $plugin->conf($conf) if $conf;

  $app->helper(blog_summary => sub {
    my $self = shift;
    my @entries = ();

    if (opendir DIR, $conf->{directory}) {
      my @files = readdir(DIR);
      closedir(DIR);

      # filter only valid filenames and sort in reverse
      @files = sort {$b cmp $a}
                 grep { /^\d{4}-\d{2}-\d{2}-[^\.]+\.\w+/ } @files;

      # parse files and filter valid parses only
      @entries = grep { $_->{status} == 200 }
                   map { $self->blog_parse_file($_, content => 0) } @files;
    }


    return \@entries;
  });


  $app->helper(blog_parse_entry => sub {
    my ($self, $date, $slug) = @_;

    # convert form YYYYMMDD to Jekyll form
    if ($date =~ m/(\d{4})(\d{2})(\d{2})/) {
      $date = "$1-$2-$3"
    }
    # convert form YYMMDD to Jekyll form
    elsif ($date =~ m/(\d{2})(\d{2})(\d{2})/) {
      $date = "20$1-$2-$3" ;
    }

    my $stash = $self->blog_parse_file("$date-$slug.md");

    return $stash;
  });

  $app->helper(blog_parse_file => sub {
    my ($self, $filename) = (shift, shift);

    my %params = @_ > 1 ? @_ : ref $_[0] eq 'HASH' ? %{ $_[0] } : ();

    # defaults
    $params{content} //= 1;
    $params{excerpt} //= 1;

    # build our path
    my $path = File::Spec->catpath(undef, $conf->{directory}, $filename);

    # ensure the path exists
    return { status => 404, bytes => undef } unless -r $path;

    # slurp
    my $bytes = slurp $path;

    # ensure header exists
    return { status => 500, bytes => undef } unless $bytes =~ m/---(.*)---\r?\n/s;

    my $stash = Load($1);
    $bytes =~ s/---.*---\r?\n//s;

    $stash->{style} = 'unknown';

    # load filename implied details
    my $file = basename($path);

    if ($file =~ m/^(\d{4}-\d{2}-\d{2})-([^\.]+)\.(\w+)/) {
      $stash->{date} = Time::Piece->strptime($1, "%Y-%m-%d");
      $stash->{slug} = $2;
      $stash->{extension} = lc $3;
      $stash->{style} = TYPE_MAP->{lc $3} // 'unknown';
    }

    # grab excerpt as appropriate
    if ($params{excerpt} != 0) {
      $stash->{excerpt} = trim $1 if $bytes =~ m/(.*)<!--more-->\r?\n/s;

      if ($stash->{style} eq 'markdown') {
        $stash->{excerpt} = markdown($stash->{excerpt});
      }
    }

    # store content as appropriate
    if ($params{content} != 0) {
      $stash->{content} = trim $bytes;

      if ($stash->{style} eq 'markdown') {
        $stash->{content} = markdown($stash->{content});
      }
    }

    $stash->{status} = 200;

    return $stash;
  });
}

1;
