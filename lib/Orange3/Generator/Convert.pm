package Orange3::Generator::Convert;

# Generator/Convert
# To reverse the comparison operator for the undefined behavior avoidance
# (division by zero, zero remainder calculation measures)
sub change_relational_operators {
  my ($n)     = @_;
  my $in1_ref = $n->{in}->[1]->{ref};
  my $otype   = $in1_ref->{otype};

  if    ( $otype eq '<' )  { $n->{in}->[1]->{ref}->{otype} = '>='; }
  elsif ( $otype eq '>' )  { $n->{in}->[1]->{ref}->{otype} = '<='; }
  elsif ( $otype eq '<=' ) { $n->{in}->[1]->{ref}->{otype} = '>'; }
  elsif ( $otype eq '>=' ) { $n->{in}->[1]->{ref}->{otype} = '<'; }
  elsif ( $otype eq '==' ) { $n->{in}->[1]->{ref}->{otype} = '!='; }
  elsif ( $otype eq '!=' ) { $n->{in}->[1]->{ref}->{otype} = '=='; }
  else                     { die; }

}

sub change_div_to_mod {
  my ($n)     = @_;
  my $in1_ref = $n->{in}->[1]->{ref};
  my $otype   = $in1_ref->{otype};

  if ( $otype eq '/' ) { $n->{in}->[1]->{ref}->{otype} = '%'; }
  else                 { die; }

}

# Four arithmetic operations for the undefined behavior avoidance,
# the shift operator to reverse (overflow measures)
sub change_arithmetic_operators {
  my ($n) = @_;
  my $otype = $n->{otype};

  if    ( $otype eq '+' )  { $n->{otype} = '-'; }
  elsif ( $otype eq '-' )  { $n->{otype} = '+'; }
  elsif ( $otype eq '*' )  { $n->{otype} = '/'; }
  elsif ( $otype eq '/' )  { $n->{otype} = '*'; }
  elsif ( $otype eq '<<' ) { $n->{otype} = '>>'; }
  elsif ( $otype eq '>>' ) { $n->{otype} = '<<'; }
  else                     { die; }

}

# Because of undefined behavior avoidance,
#  to change the value of the analysis leaves
sub change_value {
  my ( $n, $min, $max, $varset ) = @_;
  my $n_ref          = $n->{ref};
  my $ref_type       = $n_ref->{out}->{type};
  my $val            = &random_range( $max, $min, $ref_type );
  my $num_new_var    = scalar @$varset;
  my $rand_classes   = rand @CLASSES;
  my $rand_modifiers = rand @MODIFIERS;
  my $scopes         = rand @SCOPES;

  my $new_var = {
    name_type => "x",
    name_num  => $num_new_var,
    type      => $ref_type,
    ival      => $val,
    val       => $val,
    class     => $CLASSES[$rand_classes],
    modifier  => $MODIFIERS[$rand_modifiers],
    scope     => $SCOPES[$scopes],
    used      => 1,
  };

  push @$varset, $new_var;

  $n->{ref}->{var}         = $new_var;
  $n->{ref}->{out}->{type} = $new_var->{type};
  $n->{ref}->{out}->{val}  = $new_var->{val};
}

1;
