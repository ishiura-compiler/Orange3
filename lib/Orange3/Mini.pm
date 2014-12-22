package Orange3::Mini;

use strict;
use warnings;

use Carp ();
use File::Basename;
use File::Copy ();
use File::Path ();
use File::Spec ();
use Getopt::Long qw/:config posix_default no_ignore_case bundling auto_help/;
use Math::BigInt;

use Orange3::Config;
use Orange3::Log;
use Orange3::Mini::Executor;
use Orange3::Util;

use Data::Dumper;

sub new {
  my ( $class, %args ) = @_;

  bless {
    config   => undef,
    help     => undef,
    log_dir  => undef,
    time_out => undef,
    debug    => undef,
    mini_dir => 'MINI',
    %args
  }, $class;
}

sub parse_options {
  my $self = shift;

  local @ARGV = @_;

  # default
  $self->{time_out} = 7;
  $self->{debug}    = 0;

  GetOptions(
    "h|help"       => \$self->{help},
    "t|time-out=i" => \$self->{time_out},
    "d|debbug"     => \$self->{debug},
  ) or _usage();

  _usage() if $self->{help};

  $self->{argv} = [@ARGV];
}

sub run {
  my $self = shift;

  $self->_check_argument;
  $self->_collect_targets;
  $self->_init;

  for my $file ( @{ $self->{target_files} } ) {
    my $guard = Orange3::Util::Chdir->new( $self->{target_directory} );
    $self->{content} = do $file or Carp::croak("Cannot load $file");

    Orange3::Mini::Executor->new(
      content  => $self->{content},
      config   => $self->{config},
      compiler => $self->{compiler},
      debug    => $self->{debug},
      executor => $self->{executor},
      mini_dir => $self->{mini_dir},
      option   => $self->{content}->{option},
      time_out => $self->{time_out},
      file     => $file,
    )->execute;
  }
}

sub _check_argument {
  my $self = shift;

  for my $path ( @{ $self->{argv} } ) {
    if ( Orange3::Util::is_file($path) ) {
      $self->{target_file} = $path;
    }
    elsif ( Orange3::Util::is_dir($path) ) {
      $self->{target_directory} = $path;
    }
    else {
      Carp::croak("Invalid path $path");
    }
  }
}

sub _collect_targets {
  my $self = shift;

  my @files;
  if ( $self->{target_file} ) {
    $self->{target_directory} = dirname( $self->{target_file} );
  }
  elsif ( $self->{target_directory} ) {
    my $guard = Orange3::Util::Chdir->new( $self->{target_directory} );
    @files = glob "error*_*.pl";
    @files = map { $_->[0] }
      sort { $a->[1] <=> $b->[1] }
      map { [ $_, /^error(\d+)_(.+).pl/ ] } @files;
    if ( !@files ) {
      Carp::croak("There are no targets");
    }
  }
  else {
    Carp::croak("There are no targets");
  }
  $self->{target_files} = @files ? \@files : [ basename $self->{target_file} ];
}

sub _init {
  my $self = shift;

  $self->_load_configs;

  $self->{log_dir} =
    File::Spec->catdir( $self->{target_directory}, $self->{mini_dir} );

  unless ( -d $self->{log_dir} ) {
    File::Path::mkpath( [ $self->{log_dir} ], 0, oct(777) );
  }
}

sub _load_configs {
  my $self = shift;

  my $config_file =
    File::Spec->catfile( $self->{target_directory}, 'orange3.cnf' );
  $self->{config} = Orange3::Config->new($config_file);

  my $compiler_cnf =
    File::Spec->catfile( $self->{target_directory}, 'orange3-compiler.cnf' );
  my $executor_cnf =
    File::Spec->catfile( $self->{target_directory}, 'orange3-executor.cnf' );

  $self->{compiler} = do $compiler_cnf if -e $compiler_cnf;
  $self->{executor} = do $executor_cnf if -e $executor_cnf;
}

sub _usage {
  die <<'...';
Usage: mini [options] [File|Directory]

Options:
    -h,--help     show this help message
    -d,--debug    print more info of debug
    -t,--time-out one test timeout (sec) [default 7 (sec)]
...
}

1;
