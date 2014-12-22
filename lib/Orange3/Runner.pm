package Orange3::Runner;

use strict;
use warnings;

use Carp ();
use POSIX;
use File::Basename;
use File::Copy ();
use File::Path ();
use File::Spec ();
use Getopt::Long qw/:config posix_default no_ignore_case bundling auto_help/;

use Orange3::Config;
use Orange3::Dumper;
use Orange3::Generator;
use Orange3::Generator::Program;
use Orange3::Log;
use Orange3::Runner::Compiler;
use Orange3::Runner::Executor;

use constant MAX_TEST_COUNT => 10000000;

sub new {
  my ( $class, $scriptdir ) = @_;
  bless {
    count       => undef,
    config      => undef,
    config_file => undef,
    start_seed  => 0,
    start_time  => undef,
    time        => undef,
    log_dir     => 'LOG',
    scriptdir   => $scriptdir,
  }, $class;
}

sub parse_options {
  my $self = shift;

  local @ARGV = @_;

  GetOptions(
    "c|config:s" => \$self->{config_file},
    "h|help"     => \$self->{help},
    "n:i"        => \$self->{count},
    "s|seed:i"   => \$self->{start_seed},
    "t|time:f"   => \$self->{time},
  ) or _usage();

  if ( $self->{count} && $self->{time} ) {
    Carp::croak("Cannot enable 'count' and 'time' option");
  }

  if ( $self->{help} ) {
    _usage();
  }

  $self->{argv} = [@ARGV];
}

sub run {
  my $self = shift;

  $self->_validate;
  $self->_load_config_file;
  $self->_init;

  my @ng_seeds = ();

  my ( $start_seed, $count, $time ) =
    ( $self->{start_seed}, $self->{count}, $self->{time} );

  for my $seed ( $start_seed .. $start_seed + $count - 1 ) {
    srand($seed);
    $self->{seed} = $seed;
    if ( $self->_randomtest ) {
      push @ng_seeds, $seed;
    }
    if ( defined $self->{time}
      && ( time - $self->{start_time} ) / 3600 > $self->{time} )
    {
      last;
    }
  }
  my $seed_sum = $self->{seed} - $start_seed + 1;
  my $time_sum = ( time - $self->{start_time} ) / 3600;
  $time_sum = sprintf( "%.1f", $time_sum );
  my $ng_seed_sum = @ng_seeds;
  my $print       = "NG_SEED => @ng_seeds\n";
  $print .= "NG / SEED : $ng_seed_sum / $seed_sum ($time_sum [h])\n";
  Orange3::Log->new(
    name => "orange3.log",
    dir  => $self->{log_dir}
  )->print($print);
  print "$print";
}

sub _validate {
  my $self = shift;

  unless ( $self->{time} || $self->{count} ) {
    $self->{count} = 1;
  }

  if ( $self->{time} ) {
    $self->{count} = MAX_TEST_COUNT;
  }
}

sub _load_config_file {
  my $self = shift;

  my $config_file = $self->{config_file};
  if ( defined($config_file) ) {
    if ( -e $config_file ) {
      $self->{config} = Orange3::Config->new($config_file);
      $self->{config}->_check_config;
    }
    else {
      Carp::croak("$config_file does not exist");
    }
  }
  else {
    print "--config option: none,\n";
    $config_file = ".orangerc.cnf";
    my $base = $self->{scriptdir};
    if ( -e "$base/.orangerc.cnf" ) {
      $config_file = $self->{config_file} = "$base/.orangerc.cnf";
      $self->{config} = Orange3::Config->new($config_file);
      $self->{config}->_check_config;
      print "Load default config file at $config_file\n";
    }
    elsif ( -e "./config/$config_file" ) {
      $self->{config_file} = $config_file = "./config/$config_file";
      $self->{config} = Orange3::Config->new($config_file);
      $self->{config}->_check_config;
      print "Load default config file at $config_file\n";
    }
    else {
      Carp::croak("Load default config file, but .orangerc.cnf does not exist");
    }

  }

  my $file = $config_file;
  $file =~ s/\.cnf$//;
  my $compiler_cnf = "$file-compiler.cnf";
  my $executor_cnf = "$file-executor.cnf";
  if ( -e $compiler_cnf ) {
    $self->{compiler} = do $compiler_cnf;
  }
  if ( -e $executor_cnf ) {
    $self->{executor} = do $executor_cnf;
  }
}

sub _copy_config {
  my $self = shift;

  my $file = $self->{config_file};

  $file =~ s/\.cnf$//;

  my %config_files = (
    basic    => $self->{config_file},
    compiler => "$file-compiler.cnf",
    executor => "$file-executor.cnf",
  );
  my %target_paths = (
    basic    => File::Spec->catfile( $self->{log_dir}, 'orange3.cnf' ),
    compiler => File::Spec->catfile( $self->{log_dir}, 'orange3-compiler.cnf' ),
    executor => File::Spec->catfile( $self->{log_dir}, 'orange3-executor.cnf' ),
  );

  for my $key ( keys %config_files ) {
    File::Copy::copy( $config_files{$key}, $target_paths{$key} )
      or Carp::croak("Cannot copy to $target_paths{$key}");
  }
}

sub _randomtest {
  my $self = shift;

  my $config = $self->{config};

  my $test_ng = 0;

  my ( $varset, $roots ) = $self->_generate_vars_and_roots;

  my $generator = Orange3::Generator::Program->new($config);
  $generator->generate_program( $varset, $roots );

  for my $option ( @{ $config->get('options') } ) {
    my $compiler = Orange3::Runner::Compiler->new(
      compile => $self->{compiler}->{compile},
      config  => $config,
      option  => $option,
    );
    $compiler->run();

    my $executor = Orange3::Runner::Executor->new(
      config  => $self->{config},
      execute => $self->{executor}->{execute},
    );
    if ( $compiler->error_msg eq 0 ) {    #TODO msg should be undef or ''
      $executor->run;
    }

    if ( $compiler->error_msg ne 0 || $executor->error != 0 ) {
      my $header = $self->_error_header(
        $compiler->command, $compiler->error_msg,
        $executor->command, $executor->error_msg,
      );
      my $seed = $self->{seed};
      Orange3::Log->new(
        name => "error$seed\_$option.c",
        dir  => $self->{log_dir}
      )->print( $header . $generator->program );

      my $content = Orange3::Dumper->new(
        vars  => $varset,
        roots => $roots,
        )->all(
        expression_size => $self->{generator}->expression_size,
        root_size       => $self->{generator}->root_max,
        var_size        => $self->{generator}->var_max,
        option          => $option
        );

      Orange3::Log->new(
        name => "error$seed\_$option.pl",
        dir  => $self->{log_dir}
      )->print($content);

      $test_ng = 1;
    }
    else {
      print " ";
    }
  }
  if ( $test_ng == 0 ) {
    print "\n";
  }
  return $test_ng;
}

sub _init {
  my $self = shift;

  $self->{start_time} = time;

  my $base = _log_name( $self->{start_time} );
  $self->{log_dir} = File::Spec->catfile( $self->{log_dir}, $base );

  unless ( -d $self->{log_dir} ) {
    File::Path::mkpath( [ $self->{log_dir} ], 0, oct(777) );
  }

  $self->_copy_config();
}

sub _generate_vars_and_roots {
  my $self = shift;

  $self->{generator} = Orange3::Generator->new(
    seed   => $self->{seed},
    config => $self->{config},
  );
  $self->{generator}->run;

  return ( $self->{generator}->{vars}, $self->{generator}->{roots} );
}

sub _error_header {
  my (
    $self,            $compile_command, $compile_message,
    $execute_command, $execute_message
  ) = @_;

  my ( $expression_size, $root_max, $var_max ) = (
    $self->{generator}->expression_size,
    $self->{generator}->root_max,
    $self->{generator}->var_max
  );

  my $header_message = "";
  if ( defined $compile_command ) {
    chomp($compile_command);
    $header_message .= "\$ $compile_command\n";
  }
  if ( defined $compile_message ) {
    chomp($compile_message);
    $header_message .= "$compile_message\n";
  }
  if ( defined $execute_command ) {
    chomp($execute_command);
    $header_message .= "\$ $execute_command\n";
  }
  if ( defined $execute_message ) {
    chomp($execute_message);
    $header_message .= "$execute_message\n";
  }

  my $header = <<"...";
/*
SIZE=$expression_size NUM=$root_max, VAR_NUM=$var_max

$header_message

*/
...

  return $header;
}

sub _log_name {
  my $time = shift;

  #    my ($sec, $min, $hour, $mday, $mon, $year) = localtime($time);
  #    $year += 1900;
  #    $mon  += 1;
  #    return "${year}${mon}${mday}-${hour}${min}${sec}";
  return POSIX::strftime "%Y%m%d-%H%M%S", localtime($time);
}

sub _usage {
  die <<USAGE;
Usage: perl script/orange3 -c [config file] [options]

config file:
  This file specifies target dependent parameters (see README.md
  for the details).
  If omitted, the parameters are read from the default config file
  "./config/orangerc.cnf".

options:
  -t  TIME    The maximum execution time [hour].
  -n  NUM     The number of programs to be tested.
  -s  SEED    The initial seed number.
  -h          display this help and exit.


Usage: perl script/mini.pl [file|directory]

option:
  [file|directory]   Input error*.pl.zip.

USAGE
}

1;
