package Orange3::Mini::Executor;

use strict;
use warnings;

use Carp ();

use Orange3::Mini::Minimize;
use Orange3::Util;

sub new {
  my ( $class, %args ) = @_;

  bless {
    config  => $args{config},
    vars    => $args{content}->{vars},
    assigns => [],
    run     => {
      compiler  => $args{compiler},
      executor  => $args{executor},
      generator => Orange3::Generator->new(
        vars   => $args{content}->{vars},
        roots  => $args{content}->{roots},
        config => $args{config},
      ),
    },
    status => {
      avoide_undef => 0,
      debug        => $args{debug},
      time_out     => $args{time_out},
      exp_size     => $args{content}->{expression_size},
      root_size    => $args{content}->{root_size},
      var_size     => $args{content}->{var_size},
      option       => $args{content}->{option},
      program      => undef,
      header       => undef,
      mini_dir     => $args{mini_dir},
      file         => $args{file},
    },
    %args
  }, $class;

}

sub execute {
  my $self = shift;
  print "$self->{status}->{file}:\n";
  $self->_make_assigns;
  $self->_print("\n****** NEXT MINIMIZE: $self->{status}->{file} ******");
  my $guard    = Orange3::Util::Chdir->new( $self->{mini_dir} );
  my $minimize = Orange3::Mini::Minimize->new(
    $self->{config}, $self->{vars}, $self->{assigns},
    run    => $self->{run},
    status => $self->{status},
  );
  $minimize->new_minimize;
  $self->_log( $self->{status}->{file} );
  $self->_message;
  $self->_print("\n****** PREV MINIMIZE: $self->{status}->{file} ******\n");
}

sub _make_assigns {
  my $self  = shift;
  my $roots = $self->{run}->{generator}->{roots};
  foreach my $i ( 0 .. $#{$roots} ) {

    # ===> zantei
    if ( defined $roots->[$i]->{root}
      && $roots->[$i]->{st_type} eq 'assign'
      && !defined $roots->[$i]->{name_num} )
    {
      $roots->[$i]->{name_num} = $i;
    }
    if ( !defined $roots->[$i]->{print_statement} ) {
      $roots->[$i]->{print_statement} = 1;
    }
    if ( !defined $roots->[$i]->{var} ) {
      $roots->[$i]->{var} = $self->_zantei_var_tansaku($i);
    }

    # <===
    $self->_make_assigns_from_st( $roots->[$i] );
  }
}

sub _zantei_var_tansaku {
  my ( $self, $i ) = @_;
  for my $v ( @{ $self->{vars} } ) {
    if ( $v->{name_type} eq "t" && $v->{name_num} eq $i ) {
      return $v;
    }
  }
}

sub _make_assigns_from_st {
  my ( $self, $st ) = @_;
  if ( $st->{print_statement} && $st->{st_type} eq 'assign' ) {
    push @{ $self->{assigns} }, $self->_generate_assign_set($st);
    $st->{assigns_num} = $#{ $self->{assigns} };
  }
}

sub _generate_assign_set {
  my ( $self, $st ) = @_;

  return +{
    root            => $st->{root},
    val             => $st->{val},
    type            => $st->{type},
    print_statement => $st->{print_statement},
    var             => $st->{var},
  };
}

sub _message {
  my $self = shift;
  if ( !defined $self->{status}->{program}
    || $self->{status}->{program} =~ /TIME OUT/ )
  {
    select STDOUT;
    print "FAILED MINIMIZE. (maybe TIME OUT.)\n";
  }
  elsif ( $self->{status}->{program} =~ /FAILED/ ) {
    print $self->{status}->{program} . "\n";
  }
  else {
    print $self->{status}->{program} . "\n";
  }
}

sub _log {
  my ( $self, $file_name ) = @_;

  my $roots = $self->{run}->{generator}->{roots};
  my $to    = $file_name;
  $to =~ s/\.pl$//;

  my $header  = $self->{status}->{header};
  my $program = $self->{status}->{program};

  $header  = ( defined $header )  ? $header  : "";
  $program = ( defined $program ) ? $program : "FAILED MINIMIZE.";

  Orange3::Log->new(
    name => "$to\_mini.c",
    dir  => "./",
  )->print( $header . $program );

  my $content = Orange3::Dumper->new(
    vars  => $self->{vars},
    roots => $roots,
    )->all(
    expression_size => $self->{status}->{exp_size},
    root_size       => $self->{status}->{root_size},
    var_size        => $self->{status}->{var_size},
    option          => $self->{status}->{option}
    );

  Orange3::Log->new(
    name => "$to\_mini.pl",
    dir  => "./",
  )->print($content);

}

sub _print {
  my ( $self, $body ) = @_;
  Orange3::Mini::Util::print( $self->{status}->{debug}, $body );
}

1;
