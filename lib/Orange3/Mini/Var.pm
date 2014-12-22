package Orange3::Mini::Var;

use strict;
use warnings;
use Carp ();

use Orange3::Mini::Backup;
use Orange3::Mini::Util;
use Orange3::Mini::Compute;

sub new {
  my ( $class, $config, $vars, $assigns, %args ) = @_;

  bless {
    config       => $config,
    vars         => $vars,
    assigns      => $assigns,
    run          => $args{run},
    status       => $args{status},
    backup       => Orange3::Mini::Backup->new( $vars, $assigns ),
    minimize_var => undef,
    %args,
  }, $class;
}

sub _unused_var_non_display {
  my $self = shift;

  my $assigns_tmp = [];
  my $varset_tmp  = [];

  $self->{backup}->_backup_var_and_assigns;

  # Variables that are not used do not appear (Organization of used)
  my $obj = Orange3::Generator::Program->new( $self->{config} );
  $obj->reset_varset_used( $self->{vars}, $self->{run}->{generator}->{roots} );

  # my $ans = $self->_generate_and_test;
  my $ans = $self->_dump_test( 0, 0 );
  if ( $ans == 1 ) {
    ;
  }
  elsif ( $ans == 0 ) {
    $self->{backup}->_restore_var_and_assigns;
  }
  return $ans;
}

sub _minimize_var_value_first_init {
  my $self = shift;
  my $v    = $self->{minimize_var}->{current_v};
  $self->{minimize_var}->{last_success_val} = Math::BigInt->new( $v->{ival} );
}

sub _minimize_var_value_set {
  my $self     = shift;
  my $v        = $self->{minimize_var}->{current_v};
  my $assign_i = $self->{assigns}->[ $v->{name_num} ];
  my $name     = $v->{name_type} . $v->{name_num};
  my $try_val  = $self->{minimize_var}->{try_val};
  $self->_print("MODIFIED : $name -> {value} = '$v->{ival}' => '$try_val'");

  if ( $v->{name_type} eq 'x'
    || $v->{name_type} eq 'k'
    || ( $v->{name_type} eq 't' && !$assign_i->{print_value} ) )
  {
    $v->{val} = $self->{minimize_var}->{try_val};
  }
  $v->{ival} = $self->{minimize_var}->{try_val};

  $self->_put_assign_var( $self->{minimize_var}->{assign_var_locate}, $v );
}

sub _minimize_var_value_test_and_judge {
  my $self = shift;

  $self->{minimize_var}->{current_val} = $self->{minimize_var}->{try_val};

  my $test = $self->_minimize_var_value_test;

  if ( $test == 1 ) {
    $self->{minimize_var}->{last_success_val} =
      $self->{minimize_var}->{current_val};
  }
  elsif ( $test == 0 || $test == 2 ) {
    $self->{backup}->_restore_var_and_assigns;
    $self->{minimize_var}->{last_fail_val} =
      $self->{minimize_var}->{current_val};
  }
  return ( $test == 1 ) ? 1 : 0;
}

sub _minimize_var_constant_value_first_try_val_set {
  my $self = shift;
  if ( $self->{minimize_var}->{last_success_val} > 1 ) {
    $self->{minimize_var}->{try_val} = Math::BigInt->new(1);
  }
  elsif ( $self->{minimize_var}->{last_success_val} < -1 ) {
    $self->{minimize_var}->{try_val} = Math::BigInt->new(-1);
  }
  else {
    die
      "unknown : last_success_val $self->{minimize_var}->{last_success_val}\n";
  }
}

sub _minimize_var_value_first {
  my $self = shift;
  $self->_minimize_var_value_first_init;
  $self->_minimize_var_constant_value_first_try_val_set;
  $self->{backup}->_backup_var_and_assigns;
  $self->_minimize_var_value_set;
  return $self->_minimize_var_value_test_and_judge;
}

sub _minimize_var_value_second_and_after_change {
  my $self = shift;
  $self->_minimize_var_constant_value_decide_try_val;
  $self->{backup}->_backup_var_and_assigns;
  $self->_minimize_var_value_set;
  return $self->_minimize_var_value_test_and_judge;
}

sub _minimize_var_constant_value_decide_try_val {
  my $self = shift;

  my $current_val      = $self->{minimize_var}->{current_val};
  my $last_fail_val    = $self->{minimize_var}->{last_fail_val};
  my $last_success_val = $self->{minimize_var}->{last_success_val};

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

  $self->{minimize_var}->{try_val} = $try_val;
}

sub _minimize_var_value_test {
  my $self      = shift;
  my $assigns_i = 0;
  my $recompute = $self->{minimize_var}->{final} ? 2 : 1;   # Recalculation flag
  return $self->_dump_test( $assigns_i, $recompute );
}

sub _minimize_var_value_second_and_after {
  my $self   = shift;
  my $v      = $self->{minimize_var}->{current_v};
  my $update = 0;
  my $difference;
  do {
    $difference = abs( $self->{minimize_var}->{last_success_val} -
        $self->{minimize_var}->{last_fail_val} );
    if ( $difference > 1 ) {
      $update =
        $self->_minimize_var_value_second_and_after_change ? 1 : $update;
    }
  } while ( $difference != 1 );
  return $update;
}

sub _minimize_var_value {
  my $self       = shift;
  my $v          = $self->{minimize_var}->{current_v};
  my $update     = 0;
  my $difference = Math::BigInt->new( abs $v->{ival} );
  if ( !$self->{minimize_var}->{final} && $v->{name_type} eq 'k' ) { ; }
  elsif ( $difference > 1 ) {
    $update = $self->_minimize_var_value_first;
    if ( !$update ) {
      $update = $self->_minimize_var_value_second_and_after ? 1 : 0;
    }
  }
  return $update;
}

sub _set_minimize_var_from_current_v {
  my ( $self, $v ) = @_;
  if ( defined $self->{minimize_var}->{current_v} ) {
    undef $self->{minimize_var}->{current_v};
  }
  $self->{minimize_var}->{current_v} = $v;
}

sub _minimize_var_type_test {
  my $self      = shift;
  my $assigns_i = 0;
  my $recompute = $self->{minimize_var}->{final} ? 2 : 1;
  return $self->_dump_test( $assigns_i, $recompute );
}

sub _minimize_var_type_test_and_judge {
  my $self   = shift;
  my $update = 0;
  my $v      = $self->{minimize_var}->{current_v};
  $self->_put_assign_var( $self->{minimize_var}->{assign_var_locate}, $v );

  if ( $self->_minimize_var_type_test == 1 ) {
    if ( $self->{minimize_var}->{before_type} eq $v->{type} ) {
      $self->{backup}->_restore_var_and_assigns;
    }
    else {
      $update = 1;
    }
  }
  else {
    $self->{backup}->_restore_var_and_assigns;
  }
  return $update;
}

sub _minimize_var_type_change {
  my $self       = shift;
  my $v          = $self->{minimize_var}->{current_v};
  my $changeable = 0;
  my $name       = $v->{name_type} . $v->{name_num};
  my $bt         = $self->{minimize_var}->{before_type} = $v->{type};
  my $bv         = $self->{minimize_var}->{before_ival} = $v->{ival};
  my ( $at, $av ) = $self->int_ification( $bt, $bv );
  if ( $bt eq $at ) { return $changeable; }
  else {
    $self->_print("MODIFIED : $name -> {type} = '$bt' => '$at'");
    $self->_print("MODIFIED : $name -> {value} = '$bv' => '$av'\n")
      if ( $bv != $av );
    $self->{backup}->_backup_var_and_assigns;
    $v->{type}  = $at;
    $v->{val}   = $av;
    $v->{ival}  = $av;
    $changeable = 1;
  }
  return $changeable;
}

sub _minimize_var_type_testable {
  my $self     = shift;
  my $testable = 0;
  my $v        = $self->{minimize_var}->{current_v};
  if ( $v->{name_type} eq 't' ) { ; }
  elsif ( ( $v->{type} ne 'signed int' && $v->{type} ne 'unsigned int' ) ) {
    $testable = 1;
  }
  return $testable;
}

sub _minimize_var_type {
  my $self   = shift;
  my $v      = $self->{minimize_var}->{current_v};
  my $update = 0;
  while ( $self->_minimize_var_type_testable ) {
    if ( $self->_minimize_var_type_change
      && $self->_minimize_var_type_test_and_judge )
    {
      $update = 1;
    }
    else { last; }
  }
  return $update;
}

sub _minimize_var_nonrecompute_test {
  my $self      = shift;
  my $assigns_i = 0;
  my $recompute = 0;
  return $self->_dump_test( $assigns_i, $recompute );
}

sub _minimize_var_class_test_and_judge {
  my $self   = shift;
  my $v      = $self->{minimize_var}->{current_v};
  my $update = 0;
  if ( $self->_minimize_var_nonrecompute_test == 1 ) {
    $update = 1;
  }
  else {
    $v->{class} = $self->{minimize_var}->{class};
    $self->{backup}->_restore_var_and_assigns;    # Unnecessary?
  }
  return $update;
}

sub _minimize_var_class_changeable {
  my $self       = shift;
  my $v          = $self->{minimize_var}->{current_v};
  my $name       = $v->{name_type} . $v->{name_num};
  my $changeable = 0;
  if ( $v->{class} eq '' ) { return $changeable; }
  else {
    $self->{backup}->_backup_var_and_assigns;     # Unnecessary?
    $self->{minimize_var}->{class} = $v->{class};
    $self->_print("MODIFIED : $name -> {class} = '$v->{class}' => ''");
    $v->{class} = '';
    $self->_put_assign_var( $self->{minimize_var}->{assign_var_locate}, $v )
      ;                                           # Unnecessary?
    $changeable = 1;
  }
  return $changeable;
}

sub _minimize_var_class {
  my $self = shift;
  return $self->_minimize_var_class_changeable
    ? $self->_minimize_var_class_test_and_judge
    : 0;
}

sub _minimize_var_modifier_test_and_judge {
  my $self   = shift;
  my $v      = $self->{minimize_var}->{current_v};
  my $update = 0;
  if ( $self->_minimize_var_nonrecompute_test == 1 ) {
    $update = 1;
  }
  else {
    $v->{modifier} = $self->{minimize_var}->{modifier};
    $self->{backup}->_restore_var_and_assigns;    # Unnecessary?
  }
  return $update;
}

sub _minimize_var_modifier_changeable_none {
  my $self       = shift;
  my $v          = $self->{minimize_var}->{current_v};
  my $name       = $v->{name_type} . $v->{name_num};
  my $changeable = 0;
  if ( $v->{modifier} eq '' ) { return $changeable; }
  else {
    $self->{backup}->_backup_var_and_assigns;     # Unnecessary?
    $self->{minimize_var}->{modifier} = $v->{modifier};
    $self->_print("MODIFIED : $name -> {modifier} = '$v->{modifier}' => ''");
    $v->{modifier} = '';
    $self->_put_assign_var( $self->{minimize_var}->{assign_var_locate}, $v )
      ;                                           # Unnecessary?
    $changeable = 1;
  }
  return $changeable;
}

sub _minimize_var_modifier_changeable_const {
  my $self       = shift;
  my $v          = $self->{minimize_var}->{current_v};
  my $name       = $v->{name_type} . $v->{name_num};
  my $changeable = 0;
  if    ( $v->{modifier} eq 'const' ) { return $changeable; }
  elsif ( $v->{name_type} eq 't' )    { return $changeable; }
  else {
    $self->{backup}->_backup_var_and_assigns;    # Unnecessary?
    $self->{minimize_var}->{modifier} = $v->{modifier};
    $self->_print(
      "MODIFIED : $name -> {modifier} = '$v->{modifier}' => 'const'");
    $v->{modifier} = 'const';
    $self->_put_assign_var( $self->{minimize_var}->{assign_var_locate}, $v )
      ;                                          # Unnecessary?
    $changeable = 1;
  }
  return $changeable;
}

sub _minimize_var_modifier_changeable_volatile {
  my $self       = shift;
  my $v          = $self->{minimize_var}->{current_v};
  my $name       = $v->{name_type} . $v->{name_num};
  my $changeable = 0;
  if ( $v->{modifier} eq 'volatile' ) { return $changeable; }
  else {
    $self->{backup}->_backup_var_and_assigns;    # Unnecessary?
    $self->{minimize_var}->{modifier} = $v->{modifier};
    $self->_print(
      "MODIFIED : $name -> {modifier} = '$v->{modifier}' => 'volatile'");
    $v->{modifier} = 'volatile';
    $self->_put_assign_var( $self->{minimize_var}->{assign_var_locate}, $v )
      ;                                          # Unnecessary?
    $changeable = 1;
  }
  return $changeable;
}

sub _minimize_var_modifier {
  my $self   = shift;
  my $update = 0;
  if ( $self->_minimize_var_modifier_changeable_none ) {
    if ( $self->_minimize_var_modifier_test_and_judge ) { $update = 1; }
    elsif ( $self->_minimize_var_modifier_changeable_volatile
      && $self->_minimize_var_modifier_test_and_judge )
    {
      $update = 1;
    }
    elsif ( $self->_minimize_var_modifier_changeable_const
      && $self->_minimize_var_modifier_test_and_judge )
    {
      $update = 1;
    }
    else { $update = 0; }
  }
  return $update;
}

sub _minimize_var_scope_test_and_judge {
  my $self   = shift;
  my $v      = $self->{minimize_var}->{current_v};
  my $update = 0;
  if ( $self->_minimize_var_nonrecompute_test == 1 ) {
    $update = 1;
  }
  else {
    $v->{scope} = $self->{minimize_var}->{scope};
    $self->{backup}->_restore_var_and_assigns;    # Unnecessary?
  }
  return $update;
}

sub _minimize_var_scope_changeable {
  my $self       = shift;
  my $v          = $self->{minimize_var}->{current_v};
  my $name       = $v->{name_type} . $v->{name_num};
  my $changeable = 0;
  if ( $v->{scope} eq 'LOCAL' ) { return $changeable; }
  else {
    $self->{backup}->_backup_var_and_assigns;     # Unnecessary?
    $self->{minimize_var}->{scope} = $v->{scope};
    $self->_print("MODIFIED : $name -> {scope} = '$v->{scope}' => 'LOCAL'");
    $v->{scope} = 'LOCAL';
    $self->_put_assign_var( $self->{minimize_var}->{assign_var_locate}, $v )
      ;                                           # Unnecessary?
    $changeable = 1;
  }
  return $changeable;
}

sub _minimize_var_scope {
  my $self = shift;
  return $self->_minimize_var_scope_changeable
    ? $self->_minimize_var_scope_test_and_judge
    : 0;
}

# Minimization for the dump file
sub _minimize_var {
  my $self   = shift;
  my $update = 0;
  $self->{minimize_var}->{final} = 0;
  $self->_unused_var_non_display;
  for my $v ( @{ $self->{vars} } ) {
    if ( $v->{used} == 1 ) {
      $self->_set_minimize_var_from_current_v($v);

      # Check for the presence of variables that appear in the formula
      my $name = $v->{name_type} . $v->{name_num};
      $self->{minimize_var}->{assign_var_locate} = [];
      $self->_search_assigns_var( $name,
        $self->{minimize_var}->{assign_var_locate} );
      $update = $self->_minimize_var_value    ? 1 : $update;
      $update = $self->_minimize_var_type     ? 1 : $update;
      $update = $self->_minimize_var_class    ? 1 : $update;
      $update = $self->_minimize_var_modifier ? 1 : $update;
      $update = $self->_minimize_var_scope    ? 1 : $update;
    }
  }
  return $update;
}

sub _minimize_var_final {
  my $self   = shift;
  my $update = 0;
  $self->{minimize_var}->{final} = 1;
  $self->_unused_var_non_display;
  for my $v ( @{ $self->{vars} } ) {
    if ( $v->{used} == 1 ) {
      $self->_set_minimize_var_from_current_v($v);

      # Check for the presence of variables that appear in the formula
      my $name = $v->{name_type} . $v->{name_num};
      $self->{minimize_var}->{assign_var_locate} = [];
      $self->_search_assigns_var( $name,
        $self->{minimize_var}->{assign_var_locate} );
      $update = $self->_minimize_var_value ? 1 : $update;
      $update = $self->_minimize_var_type  ? 1 : $update;
    }
  }
  return $update;
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

sub _search_assigns_var {
  my ( $self, $name, $assign_var_locate ) = @_;

  return Orange3::Mini::Util::search_assigns_var( $self->{assigns}, $name,
    $assign_var_locate );
}

sub _put_assign_var {
  my ( $self, $assign_var_locate, $v ) = @_;

  Orange3::Mini::Util::put_assign_var( $self->{assigns}, $assign_var_locate,
    $v );
}

sub _print {
  my ( $self, $body ) = @_;
  Orange3::Mini::Util::print( $self->{status}->{debug}, $body );
}

1;
