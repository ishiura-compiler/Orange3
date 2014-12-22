package Orange3;
use 5.008001;
use strict;
use warnings;

our $VERSION = "3.00";



1;
__END__

=encoding utf-8

=head1 NAME

Orange3 - Randomtest of C compilers

=head1 About "Orange3"

Orange3 is a system to test validity of C compilers by randomly
generated programs.  It currently aims at testing optimization
regarding arithmetic expressions.

Orange3 has been developed by the following persons at the compiler
team of Ishiura Laboratory, School of science and Technology, Kwansei
Gakuin University <ishiura-compiler@ml.kwansei.ac.jp>

=head1 AUTHOR

Ishiura Lab. E<lt>ishiura-compiler@ml.kwansei.ac.jpE<gt>

 Mr. Atsushi Hashimoto
 Ms. Eriko Nagai
 Mr. Ryo Nakamura
 Prof. Nagisa Ishiura

=head1 INSTALLATION

Please try the following command sequence.

 $ perl Build.PL
 $ ./Build
 $ ./Build test
 $ ./Build install

 * Internet connection is required.
 * If error occurs during installation, please remove Orange3 and re-download.
 * If copy error occurs during installation, please retry.

=head1 CONFIGURATION FILES OF Orange3

To use orange3, users need to specify settings in the three
configuration files.  In the case of the “i386_Cygwin” target.
for example, the configuration files are:

 * i386-cygwin-gcc.cnf          (general settings) 
 * i386-cygwin-gcc-compiler.cnf (compilation settings)
 * i386-cygwin-gcc-executor.cnf (execution settings)

We are sorry but the detailed manuals for composing the configuration
files are under construction.  Please copy & edit the above files.
For most of the compilers and execution environments with standard
I/O support, you just need to edit several lines.

=head1 SYNOPSIS

An "orange3" command repeats the process of generating a test program
and compile & executes it.  The number of tests or time for testing
should be specified.

 $ orange3 [-c config file] [options]

 * OPTION
 
  -c <FILE>|--config=<FILE> : Config File. (must)
                              Default: <root>/.orangerc.cnf
  -n <Number>               : Number of tesing. 
                              Default: 1
  -s <Number>               : Seed number of Starting
                              Default: 0
  -t <Number>               : Time (hour) of testing.
                              Cannot specify -s and -n option simultaneously.
  -h                        : Help

If an error is detected, Error File Set is saved to the following
directories. 

  Directory      : ./LOG/<START_TIME>/
  
  Error File Set : Report File (*.log),
                   Config File (*.cnf),
                   Seed information File  (*.pl),
                   Detected error C source File (*.c)

=head1 MINIMIZATION OF ERROR FILE

Orange3 can reduce programs that detected errors by Orange3's minimizer.

=head1 SYNOPSIS OF Orange3's MINIMIZER

"File" is a seed information file saved by orange3.  If "Directory" is
specified, add the Files in the directory and processed.

    $ orange3-minimizer <File|Directory>

=head1 LICENSE

Copyright (C) Ishiura Lab.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

