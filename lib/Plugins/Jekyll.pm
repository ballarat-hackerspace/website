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

use File::Basename qw(basename);
use File::Spec;
use Mojo::File;
use Mojo::Util qw(dumper trim);
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

has conf  => sub { +{} };
has files => sub { +[] };
has posts => sub { +[] };

sub register {
  my ($plugin, $app, $conf) = @_;

  # default values
  $conf->{directory}  ||= BLOG_DIR;
  $conf->{style}      ||= BLOG_STYLE;

  $plugin->conf($conf) if $conf;

  # prepare the cache
  $plugin->_cache_posts($conf->{directory});

  $app->log->info(sprintf('Processing Jekyll blogs at: %s (%s)', $conf->{directory}, $conf->{style}));

  $app->helper(blog_summary => sub {
    my $self = shift;
    my @posts = @{$plugin->posts};

    my %params = @_ > 1 ? @_ : ref $_[0] eq 'HASH' ? %{ $_[0] } : ();

    # parse any tags
    if ($params{tags} && @posts) {
      @posts = grep { _in_array($params{tags}, $_->{tags}) } @posts;
    }

    return \@posts;
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

    my $file = $plugin->_get_file($date, $slug);
    my $stash = $plugin->_parse_file($file);

    return $stash;
  });
}

sub _cache_posts {
  my $self = shift;
  my $path = shift;

  my @files = ();
  my @posts = ();

  if (opendir DIR, $path) {
    @files = readdir(DIR);
    closedir(DIR);

    # filter only valid filenames and sort to reverse chronological order
    @files = sort {$b cmp $a}
               grep { /^\d{4}-\d{2}-\d{2}-[^\.]+\.[A-Za-z]+/ } @files;

    # parse files and filter valid parses only
    @files = grep { $self->_parse_file($_, content => 0)->{status} == 200 } @files;
    @posts = map { $self->_parse_file($_, content => 0) } @files;
  }

  $self->files(\@files);
  $self->posts(\@posts);
}

sub _get_file {
  my ($self, $date, $slug) = @_;

  # convert form YYYYMMDD to Jekyll form
  if ($date =~ m/(\d{4})(\d{2})(\d{2})/) {
    $date = "$1-$2-$3"
  }
  # convert form YYMMDD to Jekyll form
  elsif ($date =~ m/(\d{2})(\d{2})(\d{2})/) {
    $date = "20$1-$2-$3" ;
  }

  my $prefix = "$date-$slug.";

  my ($file) = grep { m/^$prefix/ } @{$self->files};

  return $file;
}

sub _parse_file {
  my ($self, $filename) = (shift, shift);

  my %params = @_ > 1 ? @_ : ref $_[0] eq 'HASH' ? %{ $_[0] } : ();

  # defaults
  $params{content} //= 1;
  $params{excerpt} //= 1;

  # build our path
  my $path = Mojo::File->new($self->conf->{directory}, $filename);

  # ensure the path exists
  return { status => 404, bytes => undef } unless -r $path->to_string;

  # slurp
  my $bytes = $path->slurp;

  # ensure header exists
  return { status => 500, bytes => undef } unless $bytes =~ m/---(.*)---\r?\n/s;

  my $stash = Load($1);
  $bytes =~ s/---.*---\r?\n//s;

  # initiliase some members
  $stash->{content} = '';
  $stash->{excerpt} = '';
  $stash->{style} = 'unknown';

  # load filename implied details
  my $file = $path->basename;

  if ($file =~ m/^(\d{4}-\d{2}-\d{2})-([^\.]+)\.(\w+)/) {
    $stash->{date} = Time::Piece->strptime($1, "%Y-%m-%d");
    $stash->{slug} = $2;
    $stash->{extension} = lc $3;
    $stash->{style} = TYPE_MAP->{lc $3} // 'unknown';
  }

  # split tags
  $stash->{tags} = [ map { trim $_ } split /,/, $stash->{tags} ] if $stash->{tags};

  # grab excerpt as appropriate
  if ($params{excerpt} != 0) {
    $stash->{excerpt} = trim $1 if $bytes =~ m/(.*)<!--more-->\r?\n/s;

    if ($stash->{style} eq 'markdown') {
      $stash->{excerpt} = markdown($stash->{excerpt});
    }
    elsif ($stash->{style} eq 'text') {
      $stash->{excerpt} = '<pre>'.$stash->{excerpt}.'</pre>';
    }
  }

  # store content as appropriate
  if ($params{content} != 0) {
    $stash->{content} = trim $bytes;

    if ($stash->{style} eq 'markdown') {
      $stash->{content} = markdown($stash->{content});
    }
    elsif ($stash->{style} eq 'text') {
      $stash->{content} = '<pre>'.$stash->{content}.'</pre>';
    }
  }

  $stash->{status} = 200;

  return $stash;
}

# short circuit grep
sub _sgrep(&@) {
  my $t = shift @_;
  for (@_) { return 1 if &$t };
  return 0;
}

# check for element in array
sub _in_array {
  my $n = shift;
  my @h = ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
  return scalar(_sgrep { $n eq $_ } @h);
}

1;
