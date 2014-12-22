package Orange3::Mini::Constant;

use strict;
use warnings;
use Carp ();

use Orange3::Mini::Backup;
use Orange3::Mini::Util;
use Orange3::Mini::Compute;

sub new {
  my ( $class, $config, $vars, $assigns, %args ) = @_;

  bless {
    config        => $config,
    vars          => $vars,
    assigns       => $assigns,
    run           => $args{run},
    status        => $args{status},
    backup        => Orange3::Mini::Backup->new( $vars, $assigns ),
    minimize_cons => undef,
    %args,
  }, $class;
}

sub _minimize_constant {
  my $self = shift;

  my $update = 0;
  $self->{minimize_cons}->{final} = 0;
  for my $i ( 0 .. $#{ $self->{assigns} } ) {
    $self->{minimize_cons}->{current_assign_i} = $i;
    if ( Orange3::Mini::Util::_check_assign( $self->{assigns}->[$i] ) ) {
      $update =
        $self->_minimize_constant_assign_recursively(
        $self->{assigns}->[$i]->{root} ) ? 1 : $update;
    }
  }
  return $update;
}

sub _minimize_constant_final {
  my $self = shift;

  my $update = 0;
  $self->{minimize_cons}->{final} = 1;
  for my $i ( 0 .. $#{ $self->{assigns} } ) {
    $self->{minimize_cons}->{current_assign_i} = $i;
    if ( Orange3::Mini::Util::_check_assign( $self->{assigns}->[$i] ) ) {
      $update =
        $self->_minimize_constant_assign_recursively(
        $self->{assigns}->[$i]->{root} ) ? 1 : $update;
    }
  }
  return $update;
}

sub _minimize_constant_assign_recursively {
  my ( $self, $ref ) = @_;
  my $update = 0;
  if ( $ref->{ntype} eq 'op' ) {
    for my $r ( @{ $ref->{in} } ) {
      if ( $r->{print_value} == 0 ) {
        $update =
          $self->_minimize_constant_assign_recursively( $r->{ref} ) ? 1 : 0;
      }
      else {
        $self->_set_minimize_constant_from_current_r($r);
        $update = $self->_minimize_constant_value ? 1 : $update;
        $update = $self->_minimize_constant_type  ? 1 : $update;
      }
    }
  }
  return $update;
}

sub _set_minimize_constant_from_current_r {
  my ( $self, $r ) = @_;
  if ( defined $self->{minimize_cons}->{current_r} ) {
    undef $self->{minimize_cons}->{current_r};
  }
  $self->{minimize_cons}->{current_r} = $r;
}

sub _minimize_constant_value_first_try_val_set {
  my $self = shift;
  if ( $self->{minimize_cons}->{last_success_val} > 1 ) {
    $self->{minimize_cons}->{try_val} = Math::BigInt->new(1);
  }
  elsif ( $self->{minimize_cons}->{last_success_val} < -1 ) {
    $self->{minimize_cons}->{try_val} = Math::BigInt->new(-1);
  }
  else {
    die
      "unknown : last_success_val $self->{minimize_cons}->{last_success_val}\n";
  }
}

sub _minimize_constant_value_first_init {
  my $self = shift;
  my $r    = $self->{minimize_cons}->{current_r};
  $self->{minimize_cons}->{last_success_val} =
    ( $r->{print_value} == 1 )
    ? Math::BigInt->new( abs $r->{ref}->{out}->{val} )
    : ( $r->{print_value} == 2 ) ? Math::BigInt->new( abs $r->{val} )
    :                              undef;
}

sub _minimize_constant_value_set {
  my $self    = shift;
  my $r       = $self->{minimize_cons}->{current_r};
  my $try_val = $self->{minimize_cons}->{try_val};
  if ( $r->{print_value} == 1 ) {
    $self->_print(
"MODIFIED : ($r->{type})($r->{ref}->{out}->{val}) => ($r->{type})($try_val)"
    );
    $r->{ref}->{out}->{val} = $self->{minimize_cons}->{try_val};
  }
  elsif ( $r->{print_value} == 2 ) {
    $self->_print(
      "MODIFIED : ($r->{type})($r->{val}) => ($r->{type})($try_val)");
    $r->{val} = $self->{minimize_cons}->{try_val};
  }
  else { die; }
}

sub _minimize_var_constant_value_decide_try_val {
  my $self = shift;

  my $current_val      = $self->{minimize_cons}->{current_val};
  my $last_fail_val    = $self->{minimize_cons}->{last_fail_val};
  my $last_success_val = $self->{minimize_cons}->{last_success_val};

  my $case = 0;
  if ( $current_val > 0 && $last_fail_val > 0 ) {
    if    ( $current_val > $last_success_val )  { $case = 1; }    # Impossible
    elsif ( $current_val == $last_success_val ) { $case = 2; }
    elsif ( $current_val < $last_success_val )  { $case = 3; }
  }
  elsif ( $current_val < 0 && $last_fail_val < 0 ) {
    if    ( $current_val < $last_success_val )  { $case = 1; }    # Impossible
    elsif ( $current_val == $last_success_val ) { $case = 2; }
    elsif ( $current_val > $last_success_val )  { $case = 3; }
  }
  else {
    die
"\$current_val < 0 && \$last_fail_val < 0 => $current_val < 0 && $last_fail_val < 0";
  }

  my $two = Math::BigInt->new(2);
  my $try_val;

  if ( $case == 1 ) { die; }
  elsif ( $case == 2 ) {
    $try_val = $current_val - ( ( $current_val - $last_fail_val ) / $two );
  }
  elsif ( $case == 3 ) {
    $try_val = $current_val + ( ( $last_success_val - $current_val ) / $two );
  }
  else { die; }

  $self->{minimize_cons}->{try_val} = $try_val;
}

sub _minimize_constant_value_first {
  my $self = shift;
  $self->_minimize_constant_value_first_init;
  $self->_minimize_constant_value_first_try_val_set;
  $self->{backup}->_backup_var_and_assigns;
  $self->_minimize_constant_value_set;
  return $self->_minimize_constant_value_test_and_judge;
}

sub _minimize_constant_value_second_and_after_change {
  my $self = shift;
  $self->_minimize_var_constant_value_decide_try_val;
  $self->{backup}->_backup_var_and_assigns;
  $self->_minimize_constant_value_set;
  return $self->_minimize_constant_value_test_and_judge;
}

sub _minimize_constant_value_second_and_after {
  my $self   = shift;
  my $update = 0;
  my $difference;
  do {
    $difference = abs( $self->{minimize_cons}->{last_success_val} -
        $self->{minimize_cons}->{last_fail_val} );
    if ( $difference > 1 ) {
      $update =
        $self->_minimize_constant_value_second_and_after_change ? 1 : $update;
    }
  } while ( $difference != 1 );
  return $update;
}

sub _minimize_constant_value_changeabl {
  my $self = shift;
  my $r    = $self->{minimize_cons}->{current_r};
  return (
    (
      $r->{ref}->{ntype} eq 'var'
        && (
        (
            !$self->{minimize_cons}->{final}
          && $r->{ref}->{var}->{name_type} ne 'k'
        )
        || $self->{minimize_cons}->{final}
        )
    )
      || $r->{ref}->{ntype} eq 'op'
  ) ? 1 : 0;
}

sub _minimize_constant_value {
  my $self   = shift;
  my $r      = $self->{minimize_cons}->{current_r};
  my $update = 0;

  my $difference =
    ( $r->{print_value} == 1 )
    ? Math::BigInt->new( abs $r->{ref}->{out}->{val} )
    : ( $r->{print_value} == 2 ) ? Math::BigInt->new( abs $r->{val} )
    :                              undef;
  if    ( !$self->_minimize_constant_value_changeabl ) { ; }
  elsif ( !defined $difference )                       { die; }
  elsif ( $difference > 1 ) {
    $update = $self->_minimize_constant_value_first;
    if ( !$update ) {
      $update = $self->_minimize_constant_value_second_and_after ? 1 : 0;
    }
  }
  return $update;
}

sub _minimize_constant_type_change {
  my $self       = shift;
  my $r          = $self->{minimize_cons}->{current_r};
  my $changeable = 0;
  my $bt         = $self->{minimize_cons}->{before_type};
  my $bv         = $self->{minimize_cons}->{before_ival};
  my ( $at, $av ) = $self->int_ification( $bt, $bv );
  if ( $bt eq $at ) { return $changeable; }
  else {
    $self->_print("MODIFIED : ($bt)$bv => ($at)$av");
    $self->{backup}->_backup_var_and_assigns;
    if ( $r->{print_value} == 1 ) {
      $r->{ref}->{out}->{type} = $at;
      $r->{ref}->{out}->{val}  = $av;
    }
    elsif ( $r->{print_value} == 2 ) {
      $r->{type} = $at;
      $r->{val}  = $av;
    }
    $changeable = 1;
  }
  return $changeable;
}

sub _minimize_constant_type_testable {
  my $self     = shift;
  my $testable = 0;
  my $r        = $self->{minimize_cons}->{current_r};
  my $bt =
      ( $r->{print_value} == 1 ) ? $r->{ref}->{out}->{type}
    : ( $r->{print_value} == 2 ) ? $r->{type}
    :                              undef;
  my $bv =
      ( $r->{print_value} == 1 ) ? $r->{ref}->{out}->{val}
    : ( $r->{print_value} == 2 ) ? $r->{val}
    :                              undef;

  if ( ( $bt ne 'signed int' && $bt ne 'unsigned int' ) ) {
    $self->{minimize_cons}->{before_type} = $bt;
    $self->{minimize_cons}->{before_ival} = $bv;
    $testable                             = 1;
  }
  return $testable;
}

sub _minimize_constant_type_test {
  my $self      = shift;
  my $assigns_i = $self->{minimize_cons}->{current_assign_i};
  my $recompute = $self->{minimize_cons}->{final} ? 2 : 1;
  return $self->_dump_test( $assigns_i, $recompute );
}

sub _minimize_constant_type_test_and_judge {
  my $self   = shift;
  my $update = 0;
  my $r      = $self->{minimize_cons}->{current_r};

  if ( $self->_minimize_constant_type_test == 1 ) {
    if ( $self->{minimize_cons}->{before_type} eq $r->{type} ) {
      $self->{backup}->_restore_var_and_assigns;
    }
    else { $update = 1; }
  }
  else {
    $self->{backup}->_restore_var_and_assigns;
  }
  return $update;
}

sub _minimize_constant_type {
  my $self   = shift;
  my $r      = $self->{minimize_cons}->{current_r};
  my $update = 0;
  while ( $self->_minimize_constant_type_testable ) {
    if ( $self->_minimize_constant_type_change
      && $self->_minimize_constant_type_test_and_judge )
    {
      $update = 1;
    }
    else { last; }
  }
  return $update;
}

sub _minimize_constant_value_test {
  my $self      = shift;
  my $assigns_i = $self->{minimize_cons}->{current_assign_i};
  my $recompute = $self->{minimize_cons}->{final} ? 2 : 1;
  return $self->_dump_test( $assigns_i, $recompute );
}

sub _minimize_constant_value_test_and_judge {
  my $self = shift;

  $self->{minimize_cons}->{current_val} = $self->{minimize_cons}->{try_val};

  my $test = $self->_minimize_constant_value_test;

  if ( $test == 1 ) {
    $self->{minimize_cons}->{last_success_val} =
      $self->{minimize_cons}->{current_val};
  }
  elsif ( $test == 0 || $test == 2 ) {
    $self->{backup}->_restore_var_and_assigns;
    $self->{minimize_cons}->{last_fail_val} =
      $self->{minimize_cons}->{current_val};
  }
  return ( $test == 1 ) ? 1 : 0;
}

sub int_ification {
  my ( $self, $type, $val ) = @_;

  return Orange3::Mini::Util::int_ification( $self->{config}, $type, $val );
}

sub _dump_test {
  my ( $self, $assigns_i, $recompute ) = @_;

  return Orange3::Mini::Compute->new(
    $self->{config}, $self->{vars}, $self->{assigns},
    run    => $self->{run},
    status => $self->{status},
  )->dump_test( $assigns_i, $recompute );
}

sub _print {
  my ( $self, $body ) = @_;
  Orange3::Mini::Util::print( $self->{status}->{debug}, $body );
}

1;
