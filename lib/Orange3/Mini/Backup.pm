package Orange3::Mini::Backup;

use strict;
use warnings;
use Carp ();

sub new {
  my ( $class, $vars, $assigns ) = @_;

  bless {
    vars    => $vars,
    assigns => $assigns,
    data    => undef,
  }, $class;

}

sub _restore_var_and_assigns {
  my $self = shift;
  $self->_restore_var;
  $self->_restore_assigns;
}

sub _restore_var {
  my $self       = shift;
  my $varset_tmp = $self->{data}->{varset_tmp};
  $self->copy_varset( $varset_tmp, $self->{vars} );
}

sub _restore_assigns {
  my $self        = shift;
  my $assigns_tmp = $self->{data}->{assigns_tmp};
  $self->copy_assigns( $assigns_tmp, $self->{assigns} );
}

sub _restore_assign_number {
  my ( $self, $number ) = @_;
  my $assigns_tmp = $self->{data}->{assigns_tmp};
  $self->{assigns}->[$number]->{root} = $assigns_tmp->[$number]->{root};
  $self->copy_assign_number( $assigns_tmp, $self->{assigns}, $number );
}

sub _backup_var_and_assigns {
  my $self = shift;
  $self->_backup_var;
  $self->_backup_assigns;
}

sub _backup_var {
  my $self = shift;
  if ( defined $self->{data}->{varset_tmp} ) {
    undef $self->{data}->{varset_tmp};
  }
  my $varset_tmp = [];
  $self->copy_varset( $self->{vars}, $varset_tmp );
  $self->{data}->{varset_tmp} = $varset_tmp;
}

sub _backup_assigns {
  my $self = shift;
  if ( defined $self->{data}->{assigns_tmp} ) {
    undef $self->{data}->{assigns_tmp};
  }
  my $assigns_tmp = [];
  $self->copy_assigns( $self->{assigns}, $assigns_tmp );
  $self->{data}->{assigns_tmp} = $assigns_tmp;
}

sub remove_var_and_assigns {
  my $self = shift;
  if ( defined $self->{data}->{assigns_tmp} ) {
    undef $self->{data}->{assigns_tmp};
  }
  if ( defined $self->{data}->{varset_tmp} ) {
    undef $self->{data}->{varset_tmp};
  }
}

sub copy_assigns {
  my ( $self, $assigns, $clone_assigns ) = @_;

  foreach my $i ( 0 .. $#{$assigns} ) {
    $self->copy_assign_number( $assigns, $clone_assigns, $i );
  }
}

sub copy_assign_number {
  my ( $self, $assigns, $clone_assigns, $i ) = @_;
  my $assign_i = $assigns->[$i];
  if ( Orange3::Mini::Util::_check_assign($assign_i) ) {
    $clone_assigns->[$i]->{val}             = $assign_i->{val};
    $clone_assigns->[$i]->{type}            = $assign_i->{type};
    $clone_assigns->[$i]->{print_statement} = $assign_i->{print_statement};
    $clone_assigns->[$i]->{root}            = {}
      unless ( defined( $clone_assigns->[$i]->{root} ) );
    $self->copy_assign( $assigns->[$i]->{root}, $clone_assigns->[$i]->{root} );
  }
  elsif ( !$assign_i->{print_value} ) {
    $clone_assigns->[$i]->{root}            = {};
    $clone_assigns->[$i]->{print_statement} = $assign_i->{print_statement};
    $clone_assigns->[$i]->{val}             = $assign_i->{val};
    $clone_assigns->[$i]->{type}            = $assign_i->{type};
  }
  else {
    Carp::croak("\$assigns->[$i]->{print_value} : $assign_i->{print_value}");
  }
}

sub _bigint_dumper {
  my $val = shift;

  my $content;

  #  if (ref $val eq 'Math::BigInt') {
  #      my $sign = $val->sign;
  #      my $value = $val->babs->bstr; # destructive...
  #
  #      $content = Math::BigInt->new('$val');
  #  }
  #  else {
  $content = "$val";

  #  }

  return $content;
}

sub copy_assign {
  my ( $self, $ref, $ref_clone ) = @_;

  $ref_clone->{out} = {} unless ( defined( $ref_clone->{out} ) );
  $ref_clone->{out}->{type} = "$ref->{out}->{type}";
  $ref_clone->{out}->{val}  = _bigint_dumper( $ref->{out}->{val} );
  $ref_clone->{ntype}       = "$ref->{ntype}";
  if ( $ref->{ntype} eq 'op' ) {
    $ref_clone->{otype} = "$ref->{otype}";
    if ( defined( $ref->{ins_add} ) ) {
      $ref_clone->{ins_add} = "$ref->{ins_add}";

    }
    elsif ( defined( $ref_clone->{ins_add} ) ) {
      delete $ref_clone->{ins_add};
    }
    foreach my $i ( 0 .. $#{ $ref->{in} } ) {
      $ref_clone->{in}->[$i] = {} unless ( defined( $ref_clone->{in}->[$i] ) );
      $ref_clone->{in}->[$i]->{print_value} = "$ref->{in}->[$i]->{print_value}";
      $ref_clone->{in}->[$i]->{type}        = "$ref->{in}->[$i]->{type}";
      $ref_clone->{in}->[$i]->{val} = _bigint_dumper( $ref->{in}->[$i]->{val} );
      $ref_clone->{in}->[$i]->{ref} = {}
        unless ( defined( $ref_clone->{in}->[$i]->{ref} ) );
      $self->copy_assign( $ref->{in}->[$i]->{ref},
        $ref_clone->{in}->[$i]->{ref} );
    }
  }
  elsif ( $ref->{ntype} eq 'var' ) {
    $ref_clone->{var} = {} unless ( defined( $ref_clone->{var} ) );
    $ref_clone->{var}->{type}      = "$ref->{var}->{type}";
    $ref_clone->{var}->{val}       = _bigint_dumper( $ref->{var}->{val} );
    $ref_clone->{var}->{ival}      = _bigint_dumper( $ref->{var}->{ival} );
    $ref_clone->{var}->{name_type} = "$ref->{var}->{name_type}";
    $ref_clone->{var}->{name_num}  = "$ref->{var}->{name_num}";
    $ref_clone->{var}->{class}     = "$ref->{var}->{class}";
    $ref_clone->{var}->{modifier}  = "$ref->{var}->{modifier}";
    $ref_clone->{var}->{scope}     = "$ref->{var}->{scope}";
  }
  else { Carp::croak("$ref->{ntype}"); }
}

sub copy_varset {
  my ( $self, $varset, $clone_varset ) = @_;

  foreach my $i ( 0 .. $#{$varset} ) {
    $clone_varset->[$i] = {} unless ( defined( $clone_varset->[$i] ) );
    $clone_varset->[$i]->{type}      = "$varset->[$i]->{type}";
    $clone_varset->[$i]->{ival}      = "$varset->[$i]->{ival}";
    $clone_varset->[$i]->{val}       = "$varset->[$i]->{val}";
    $clone_varset->[$i]->{name_type} = "$varset->[$i]->{name_type}";
    $clone_varset->[$i]->{name_num}  = "$varset->[$i]->{name_num}";
    $clone_varset->[$i]->{class}     = "$varset->[$i]->{class}";
    $clone_varset->[$i]->{modifier}  = "$varset->[$i]->{modifier}";
    $clone_varset->[$i]->{scope}     = "$varset->[$i]->{scope}";
    $clone_varset->[$i]->{used}      = "$varset->[$i]->{used}";
  }
}

1;

