package Orange3::Mini::Compute;

use strict;
use warnings;
use Carp ();

use Orange3::Mini::Util;
use Orange3::Generator;
use Orange3::Generator::Expect;
use Orange3::Generator::Program;
use Orange3::Runner::Compiler;
use Orange3::Runner::Executor;

sub new {
  my ( $class, $config, $vars, $assigns, %args ) = @_;

  bless {
    config    => $config,
    vars      => $vars,
    assigns   => $assigns,
    run       => $args{run},
    status    => $args{status},
    backup    => Orange3::Mini::Backup->new( $vars, $assigns ),
    generator => $args{run}->{generator},
    %args,
  }, $class;
}

sub dump_test {
  my ( $self, $assigns_i, $recompute ) = @_;

  $self->{backup}->_backup_var_and_assigns;
  for my $i ( $assigns_i .. $#{ $self->{assigns} } ) {
    my $assign_i = $self->{assigns}->[$i];
    if ( $recompute && Orange3::Mini::Util::_check_assign($assign_i) ) {
      if (
        (
             $recompute == 1
          && $self->_type_insadd_value_compute( $assign_i->{root} )
        )
        || ( $recompute == 2
          && $self->_type_value_compute( $assign_i->{root} ) )
        )
      {
        $self->{backup}->_restore_var_and_assigns;
        return 2;
      }
      else {
        $self->_tvar_update_after_compute($i);
      }
    }
  }
  return $self->_generate_and_test;
}

sub _type_value_compute {
  my ( $self, $assign_i_root ) = @_;
  $self->{generator}->type_compute($assign_i_root);
  Orange3::Generator::Expect::value_compute( $assign_i_root, $self->{vars},
    $self->{config}, $self->{status}->{avoide_undef} );
  return ( $assign_i_root->{out}->{val} eq "UNDEF" ) ? 2 : 0;
}

sub _type_insadd_value_compute {
  my ( $self, $assign_i_root ) = @_;
  $self->{generator}->type_compute($assign_i_root);
  $self->insadd_value($assign_i_root);
  Orange3::Generator::Expect::value_compute( $assign_i_root, $self->{vars},
    $self->{config}, $self->{status}->{avoide_undef} );
  return ( $assign_i_root->{out}->{val} eq "UNDEF" ) ? 2 : 0;
}

sub _tvar_update_after_compute {
  my ( $self, $i ) = @_;
  my $assign_i = $self->{assigns}->[$i];

# re-store the expected value of the expression that was minimized to the variable table
  $self->varset_val_reset( "t", $i, $assign_i->{root}->{out}->{type},
    'UNCHANGE', $assign_i->{root}->{out}->{val} );
  $self->reset_tvar_and_compute_exist( $i + 1, $i );
}

sub _insadd_value_preparation_compute {
  my ( $self, $ref_in0 ) = @_;

  if ( $ref_in0->{ref}->{ntype} eq 'op' ) {
    if ( $ref_in0->{print_value} == 0 ) {
      $self->{generator}->type_compute( $ref_in0->{ref} );
      Orange3::Generator::Expect::value_compute( $ref_in0->{ref},
        $self->{vars}, $self->{config}, $self->{status}->{avoide_undef} );
    }
  }
  elsif ( $ref_in0->{ref}->{ntype} eq 'var' ) { ; }
  else {
    Carp::croak("Unexpectedly ntype: $ref_in0->{ref}->{ntype}");
  }
  return $ref_in0->{ref}->{out}->{val};
}

sub _insadd_value_compute_value {
  my ( $self, $ref, $value0, $value ) = @_;
  my $type   = $ref->{in}->[1]->{ref}->{out}->{type};
  my $value1 = Math::BigInt->new(0);
  if    ( $ref->{otype} eq '+' ) { $value1 = $value - $value0; }
  elsif ( $ref->{otype} eq '*' ) { $value1 = $value / $value0; }
  else {
    Carp::croak(
      "\$ref->{ins_add} $ref->{ins_add} \$ref->{optype} $ref->{otype}");
  }
  my ( $s, $ty ) = split( / /, $type, 2 );
  if ( $s eq "unsigned" ) {
    my $types = $self->{config}->get('type');
    my $max   = Math::BigInt->new( $types->{$type}->{max} );
    $value1 = $value1 % ( $max + 1 );
  }
  return $value1;
}

sub _insadd_value_compute {
  my ( $self, $ref ) = @_;

  my $value  = $ref->{out}->{val};
  my $value0 = $self->_insadd_value_preparation_compute( $ref->{in}->[0] );
  if ( $value0 eq 'UNDEF' ) { $value = $value0; return; }
  my $value1  = $self->_insadd_value_compute_value( $ref, $value0, $value );
  my $type    = $ref->{in}->[1]->{ref}->{out}->{type};
  my $ins_var = $ref->{in}->[1]->{ref}->{var};
  $self->varset_val_reset( $ins_var->{name_type}, $ins_var->{name_num},
    $type, $value1, $value1, );
  $ins_var->{val}                      = $value1;
  $ins_var->{ival}                     = $value1;
  $ref->{in}->[1]->{ref}->{out}->{val} = $value1;
}

# re-calculate the value of the variable that was made by ins_add
sub insadd_value {
  my ( $self, $ref ) = @_;

  if ( $ref->{ntype} eq 'op' ) {
    for my $r ( @{ $ref->{in} } ) {
      if ( $r->{print_value} == 0 ) {
        $self->insadd_value( $r->{ref} );
      }
    }
    if ( defined $ref->{ins_add} && $ref->{out}->{val} ne 'UNDEF' ) {
      $self->_insadd_value_compute($ref);
    }
  }
  elsif ( $ref->{ntype} eq 'var' ) {
    $ref->{out}->{val} = $ref->{var}->{val};
  }
}

sub varset_val_reset {
  my ( $self, $name_type, $name_num, $type, $ival, $val ) = @_;
  for my $var ( @{ $self->{vars} } ) {
    if ( $name_type eq $var->{name_type} && $name_num eq $var->{name_num} ) {
      $var->{type} = $type eq 'UNCHANGE' ? $var->{type} : $type;
      $var->{ival} = $ival eq 'UNCHANGE' ? $var->{ival} : $ival;
      $var->{val}  = $val eq 'UNCHANGE'  ? $var->{val}  : $val;
      my $types = $self->{config}->get('type');
      my $max   = Math::BigInt->new( $types->{ $var->{type} }->{max} );
      my $min   = Math::BigInt->new( $types->{ $var->{type} }->{min} );
      if    ( $var->{ival} < $min ) { $var->{ival} = $min; }    #ZANTEI
      elsif ( $max < $var->{ival} ) { $var->{ival} = $max; }    #ZANTEI
      last;
    }
  }
}

sub _tval_compute_assigns {
  my ( $self, $modify_t_num ) = @_;

  #    my $modify_t_set = [$modify_t_num];
  #    do {
  #        my $modify_t_num = $modify_t_num;
  my $exist;
  for my $i ( ( $modify_t_num + 1 ) .. ( @{ $self->{assigns} } - 1 ) ) {
    my $assign_i = $self->{assigns}->[$i];
    if ( Orange3::Mini::Util::_check_assign($assign_i)
      && $self->reset_tvar_and_compute_exist( $i, $modify_t_num ) )
    {
      $exist = 1;

      #                unshift @$modify_t_set, $i;
      #                if($self->_type_insadd_value_compute($assign_i->{root})){
      #                    return 2;   # UNDEF is occurd.
      #                }
    }
  }
  if ($exist) {
    for my $i ( ( $modify_t_num + 1 ) .. ( @{ $self->{assigns} } - 1 ) ) {
      my $assign_i = $self->{assigns}->[$i];
      if ( $self->_type_insadd_value_compute( $assign_i->{root} ) ) {
        return 2;    # UNDEF is occurd.
      }
    }
  }

  #    }
  #    while (defined($modify_t_set->[0]));
  return 0;
}

sub tval_compute {
  my ( $self, $i ) = @_;

  # return UNDEF ? 2 : 0;
  # return EXIST ? 1 : 0;
  return $self->_tval_compute_assigns($i);
}

# re-store the var from the variable table in var present in the assign
sub reset_tvar_and_compute_exist {
  my ( $self, $begin_number, $number ) = @_;

  my $assign_var_locate = [];
  my $name              = 't' . $number;
  my $exist =
    $self->_search_range_assigns_var( $begin_number, $name,
    $assign_var_locate );

  for my $var ( @{ $self->{vars} } ) {
    my $var_name = $var->{name_type} . $var->{name_num};
    if ( $var_name eq $name ) {
      $self->_put_assign_var( $assign_var_locate, $var );
    }
  }
  return $exist;
}

sub _search_range_assigns_var {
  my ( $self, $begin_number, $name, $assign_var_locate ) = @_;

  my $assigns     = $self->{assigns};
  my $exist_total = 0;

  for my $i ( $begin_number .. $#{$assigns} ) {
    my $assign_i = $assigns->[$i];
    if ( Orange3::Mini::Util::_check_assign($assign_i) ) {
      my $s     = '$assigns->[' . $i . ']->{root}';
      my $exist = $self->_search_assign_var( $assigns->[$i]->{root},
        $name, $s, $assign_var_locate );
      $exist_total += $exist;
    }
  }
  return $exist_total;
}

sub _generate_and_test {
  my $self = shift;

  if (
    defined $self->{status}->{mode}
    && ( $self->{status}->{mode} eq 'optimize'
      || $self->{status}->{mode} eq 'volatile' )
    )
  {
    return $self->_vol_generate_and_test;    # volatile minimize
  }
  else {
    my $time_out = $self->{status}->{time_out};
    eval {
      local $SIG{ALRM} = sub { die "timeout" };
      alarm($time_out);
      $self->_generate_test_program;
      $self->_compile;
      if ( $self->{generate_test}->{compile_error_msg} eq 0 ) {
        $self->_execute;
      }
      my $timeleft = alarm(0);
    };
    alarm(0);
    if ( $@ =~ /timeout/ ) {
      $self->_print("WARNING: TIMEOUT! ($time_out [s])");
      $self->{status}->{program} = "FAILED MINIMIZE. (TIME OUT)";
      return 0;
    }
    return $self->_judgement_and_print;
  }
}

sub _assign_put {
  my $self = shift;
  for my $i ( 0 .. $#{ $self->{assigns} } ) {
    my $assign_i = $self->{assigns}->[$i];
    if ( Orange3::Mini::Util::_check_assign($assign_i) ) {
      $assign_i->{var}->{val} = $assign_i->{val} =
        $assign_i->{root}->{out}->{val};
      $assign_i->{var}->{type} = $assign_i->{type} =
        $assign_i->{root}->{out}->{type};
    }
  }
}

sub _put_roots_from_assign {
  my $self  = shift;
  my $roots = $self->{generator}->{roots};

  foreach my $i ( 0 .. $#{$roots} ) {
    if ( $roots->[$i]->{st_type} eq 'assign' ) {
      my $assigns_num = $roots->[$i]->{assigns_num};

      #        if ($self->{assigns}->[$assigns_num]->{print_statement}) {
      $roots->[$i]->{root} = $self->{assigns}->[$assigns_num]->{root};
      $roots->[$i]->{val}  = $self->{assigns}->[$assigns_num]->{val};
      $roots->[$i]->{type} = $self->{assigns}->[$assigns_num]->{type};
      $roots->[$i]->{var}  = $self->{assigns}->[$assigns_num]->{var};
      $roots->[$i]->{print_statement} =
        $self->{assigns}->[$assigns_num]->{print_statement};

      #        }
      #        else {
      #            undef $roots->[$i]->{root};
      #        }
    }
  }
}

sub _generate_test_program {
  my $self = shift;
  $self->_assign_put;
  $self->_put_roots_from_assign;
  my $generator = Orange3::Generator::Program->new( $self->{config} );
  $generator->generate_program( $self->{vars}, $self->{generator}->{roots} );
  $self->{generate_test}->{program} = $generator->program;
}

sub _compile {
  my $self     = shift;
  my $compiler = Orange3::Runner::Compiler->new(
    compile => $self->{run}->{compiler}->{compile},
    config  => $self->{config},
    option  => $self->{status}->{option},
  );
  if ( $self->{status}->{debug} ) {
    $compiler->run;
  }
  else {
    open my $fh, '>', '/dev/null' or die;
    my $stdout_fh = select $fh;
    $compiler->run;
    select $stdout_fh;
  }
  $self->{generate_test}->{compile_error_msg} = $compiler->error_msg;
  $self->{generate_test}->{compile_command}   = $compiler->command;
}

sub _execute {
  my $self     = shift;
  my $executor = Orange3::Runner::Executor->new(
    config  => $self->{config},
    execute => $self->{run}->{executor}->{execute},
  );
  if ( $self->{status}->{debug} ) {
    $executor->run;
  }
  else {
    open my $fh, '>', '/dev/null' or die;
    my $stdout_fh = select $fh;
    $executor->run;
    select $stdout_fh;
  }
  $self->{generate_test}->{execute_error_msg} = $executor->error_msg;
  $self->{generate_test}->{execute_command}   = $executor->command;
  $self->{generate_test}->{execute_error}     = $executor->error;
}

sub _judgement_and_print {
  my $self = shift;

  if ( !$self->{generate_test}->{execute_error} ) {
    $self->_print("");
  }
  if ( $self->{generate_test}->{compile_error_msg} ne 0
    || $self->{generate_test}->{execute_error} != 0 )
  {
    $self->_error_header;
    $self->{status}->{program} = $self->{generate_test}->{program};
    return 1;
  }
  return 0;
}

sub _error_header {
  my $self = shift;

  my $compile_command = $self->{generate_test}->{compile_command};
  my $compile_message = $self->{generate_test}->{compile_error_msg};
  my $execute_command = $self->{generate_test}->{execute_command};
  my $execute_message = $self->{generate_test}->{execute_error_msg};

  my ( $expression_size, $assign_max, $var_max ) = (
    $self->{status}->{exp_size},
    $self->{status}->{root_size},
    $self->{status}->{var_size}
  );

  if ( $compile_message eq '0' )    { $compile_message = ""; }
  if ( !defined($execute_command) ) { $execute_command = ""; }
  if ( !defined($execute_message) ) { $execute_message = ""; }

  my $header = <<"...";
/*
( E_SIZE, NUM_ROOT, NUM_VAR ) = ( $expression_size, $assign_max, $var_max )
\$ $compile_command
$compile_message

\$ $execute_command
$execute_message
*/
...

  $self->{status}->{header} = $header;
}

sub _search_assign_var {
  my ( $self, $ref, $name, $s, $assign_var_locate ) = @_;

  return Orange3::Mini::Util::search_assign_var( $ref, $name, $s,
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

