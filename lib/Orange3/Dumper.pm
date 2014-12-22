package Orange3::Dumper;

use strict;
use warnings;

use Carp ();
use Math::BigInt;

sub new {
  my ( $class, %args ) = @_;

  for my $key (qw(vars roots)) {
    unless ( exists $args{$key} ) {
      Carp::croak("Missing mandatory parameter: $key");
    }
  }

  my $vars  = delete $args{vars};
  my $roots = delete $args{roots};

  bless {
    vars  => $vars,
    roots => $roots,
    %args
  }, $class;
}

sub all {
  my ( $self, %args ) = @_;

  my @params;
  for my $key ( keys %args ) {
    push @params, "$key => $args{$key},";
  }
  return join "\n", "+{", @params, $self->_vars, $self->_roots, "}";
}

sub vars_and_roots {
  my $self = shift;

  return join "\n", $self->_vars, $self->_roots;
}

sub _vars {
  my $self = shift;

  my $varset = $self->{vars};

  my $s      = "vars => [\n";
  my $indent = ' ';
  my $n      = "\n";

  for my $i ( 0 .. $#{$varset} ) {
    $s .= "{\n";
    my $v = $varset->[$i];
    $s .= $indent . "'type'=>'$v->{type}'," . $n;
    if ( ref $v->{val} ne 'Math::BigInt' ) {
      $s .= $indent . "'ival'=>'$v->{ival}'," . $n;
    }
    else {
      $s .= $indent . "'ival'=>" . _bigint_dumper( $v->{ival} ) . "," . $n;
    }
    if ( ref $v->{val} ne 'Math::BigInt' ) {
      $s .= $indent . "'val'=>'$v->{val}'," . $n;
    }
    else {
      $s .= $indent . "'val'=>" . _bigint_dumper( $v->{val} ) . "," . $n;
    }
    $s .= $indent . "'name_type'=>'$v->{name_type}'," . $n;
    $s .= $indent . "'name_num'=>'$v->{name_num}'," . $n;
    $s .= $indent . "'class'=>'$v->{class}'," . $n;
    $s .= $indent . "'modifier'=>'$v->{modifier}'," . $n;
    $s .= $indent . "'scope'=>'$v->{scope}'," . $n;
    $s .= $indent . "'used'=>'$v->{used}'," . $n;
    $s .= "}," . $n;
  }

  $s .= "],";

  return $s;
}

sub _bigint_dumper {
  my $val = shift;

  #    my $sign = $val->sign;
  #    my $value = $val->babs->bstr; # destructive...

#    my $content = "bless({'value'=>[$value], 'sign'=>'$sign'}, 'Math::BigInt')";
  my $content = "'$val'";

  return $content;
}

sub _roots {
  my $self = shift;

  my $roots = $self->{roots};

  my $s          = "roots => [\n";
  my $indent     = ' ';
  my $new_indent = ' ';
  my $indent1    = $indent . $new_indent x 2;
  my $n          = "\n";

  for my $i ( 0 .. $#{$roots} ) {
    if ( $roots->[$i]->{st_type} eq 'assign' ) {
      $s .= '{' . $n;
      $s .= $indent . "'val'=>'$roots->[$i]->{val}'," . $n;
      $s .= $indent . "'type'=>'$roots->[$i]->{type}'," . $n;
      $s .= $indent . "'st_type'=>'$roots->[$i]->{st_type}'," . $n;
      $s .=
        $indent . "'print_statement'=>'$roots->[$i]->{print_statement}'," . $n;
      $s .= $indent . "'var'=>{" . $n;
      $s .= $indent1 . "'type'=>'$roots->[$i]->{var}->{type}'," . $n;
      if ( ref $roots->[$i]->{var}->{ival} ne 'Math::BigInt' ) {
        $s .= $indent1 . "'ival'=>'$roots->[$i]->{var}->{ival}'," . $n;
      }
      else {
        $s .=
            $indent1
          . "'ival'=>"
          . _bigint_dumper( $roots->[$i]->{var}->{ival} ) . ","
          . $n;
      }
      if ( ref $roots->[$i]->{var}->{val} ne 'Math::BigInt' ) {
        $s .= $indent1 . "'val'=>'$roots->[$i]->{var}->{val}'," . $n;
      }
      else {
        $s .=
            $indent1
          . "'val'=>"
          . _bigint_dumper( $roots->[$i]->{var}->{val} ) . ","
          . $n;
      }
      $s .= $indent1 . "'name_type'=>'$roots->[$i]->{var}->{name_type}'," . $n;
      $s .= $indent1 . "'name_num'=>'$roots->[$i]->{var}->{name_num}'," . $n;
      $s .= $indent1 . "'class'=>'$roots->[$i]->{var}->{class}'," . $n;
      $s .= $indent1 . "'modifier'=>'$roots->[$i]->{var}->{modifier}'," . $n;
      $s .= $indent1 . "'scope'=>'$roots->[$i]->{var}->{scope}'," . $n;
      $s .= $indent . "}," . $n;
      $s .= $indent . "'root' => {" . $n;

      if ( $roots->[$i]->{print_statement} ) {
        $s .= _root_dumper( $roots->[$i]->{root}, $indent );
      }
      $s .= $indent . "}," . $n;
      $s .= '},' . $n;
    }
    else {
      $s .= 'undef;' . $n;
    }
  }

  $s .= "],";

  return $s;
}

sub _root_dumper {
  my ( $ref, $indent ) = @_;

  my $s          = '';
  my $new_indent = ' ';
  my $indent1    = $indent . $new_indent x 2;
  my $indent2    = $indent . $new_indent x 3;
  my $indent3    = $indent . $new_indent x 4;
  my $n          = "\n";

  $s .= $indent . "'out'=>{" . $n;
  if ( ref $ref->{val} ne 'Math::BigInt' ) {
    $s .= $indent1 . "'val'=>'$ref->{out}->{val}'," . $n;
  }
  else {
    $s .=
      $indent1 . "'val'=>" . _bigint_dumper( $ref->{out}->{val} ) . "," . $n;
  }
  $s .= $indent1 . "'type'=>'$ref->{out}->{type}'," . $n;
  $s .= $indent . "}," . $n;

  $s .= $indent . "'ntype'=>'$ref->{ntype}'," . $n;

  if ( $ref->{ntype} eq 'op' ) {
    $s .= $indent . "'otype'=>'$ref->{otype}'," . $n;
    $s .= $indent . "'ins_add'=>'$ref->{ins_add}'," . $n
      if ( defined( $ref->{ins_add} ) );
    $s .= $indent . "'in'=>[" . $n;
    for my $r ( @{ $ref->{in} } ) {
      $s .= $indent1 . "{" . $n;
      $s .= $indent2 . "'print_value'=>$r->{print_value}," . $n;
      if ( ref $r->{val} ne 'Math::BigInt' ) {
        $s .= $indent2 . "'val'=>'$r->{val}'," . $n;
      }
      else {
        $s .= $indent2 . "'val'=>" . _bigint_dumper( $r->{val} ) . "," . $n;
      }
      $s .= $indent2 . "'type'=>'$r->{type}'," . $n;
      $s .= $indent2 . "'ref'=>{" . $n;
      $s .= _root_dumper( $r->{ref}, $indent3 );
      $s .= $indent2 . "}," . $n;
      $s .= $indent1 . "}," . $n;
    }
    $s .= $indent . "]," . $n;
  }
  elsif ( $ref->{ntype} eq 'var' ) {
    $s .= $indent . "'var'=>{" . $n;
    $s .= $indent1 . "'type'=>'$ref->{var}->{type}'," . $n;
    if ( ref $ref->{var}->{ival} ne 'Math::BigInt' ) {
      $s .= $indent1 . "'ival'=>'$ref->{var}->{ival}'," . $n;
    }
    else {
      $s .=
          $indent1
        . "'ival'=>"
        . _bigint_dumper( $ref->{var}->{ival} ) . ","
        . $n;
    }
    if ( ref $ref->{var}->{val} ne 'Math::BigInt' ) {
      $s .= $indent1 . "'val'=>'$ref->{var}->{val}'," . $n;
    }
    else {
      $s .=
        $indent1 . "'val'=>" . _bigint_dumper( $ref->{var}->{val} ) . "," . $n;
    }
    $s .= $indent1 . "'name_type'=>'$ref->{var}->{name_type}'," . $n;
    $s .= $indent1 . "'name_num'=>'$ref->{var}->{name_num}'," . $n;
    $s .= $indent1 . "'class'=>'$ref->{var}->{class}'," . $n;
    $s .= $indent1 . "'modifier'=>'$ref->{var}->{modifier}'," . $n;
    $s .= $indent1 . "'scope'=>'$ref->{var}->{scope}'," . $n;
    $s .= $indent . "}," . $n;
  }
  else {
    Carp::croak("$ref->{ntype} is undefined");
  }

  return $s;
}

1;

