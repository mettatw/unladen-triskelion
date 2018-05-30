#!/usr/bin/env perl
# Test for builtin plugin
#***************************************************************************
#  Copyright 2014-2017, mettatw <mettatw@users.noreply.github.com>
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#***************************************************************************
use warnings; use strict; use v5.14;

use FindBin qw($Bin);
use lib "$Bin/local/lib/perl5";

use Test2::V0;
use Test2::Tools::Spec ':ALL';
spec_defaults case => (iso => 1, async => 1);

my $pathTestData = "$Bin/data-mod-builtin";
$ENV{'PERL5LIB'} = "$pathTestData/lib:$ENV{'PERL5LIB'}";
$ENV{'PATH'} = "$Bin/../bin:$ENV{'PATH'}";

use lib "$Bin"; # for CommonTest
use CommonTest;

describe 'The builtin module' => sub {

  before_case 'Fallback Input' => sub {
    my $self = shift;
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion -r $pathTestData )];
    $self->{'exitcode'} = 0;
  };

  # ====== method: assign ======

  case 'should assign' => sub {
    my $self = shift;
    $self->{'input'} = "!%: assign('aaa', 'bbb')\n[% \$aaa %]\n!%: assign('aaa', 'ccc')\n[% \$aaa %]";
    $self->{'answer'} = "bbb\nccc";
  };

  # ====== method: getPath/getPathTop ======

  case 'should getPath on pure stdin input' => sub {
    my $self = shift;
    $self->{'input'} = '!%: getPath()';
    $self->{'answer'} = '/<string>';
  };

  case 'should getPath given pathname' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, qq(-n dir1/relfile);
    $self->{'input'} = '!%: getPath()';
    $self->{'answer'} = '/dir1/relfile';
  };

  case 'should getPathTop on pure stdin input' => sub {
    my $self = shift;
    $self->{'input'} = '!%: include "dir1/getpathtop"';
    $self->{'answer'} = '/<string>';
  };

  case 'should getPathTop given pathname' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, qq(-n dir2/relfile);
    $self->{'input'} = '!%: include "dir1/getpathtop"';
    $self->{'answer'} = '/dir2/relfile';
  };

  # ====== method: getDir/getDirTop ======

  case 'should getDir on pure stdin input' => sub {
    my $self = shift;
    $self->{'input'} = '!%: getDir()';
    $self->{'answer'} = '/';
  };

  case 'should getDir given pathname' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, qq(-n dir1/relfile);
    $self->{'input'} = '!%: getDir()';
    $self->{'answer'} = '/dir1';
  };

  case 'should getPathTop on pure stdin input' => sub {
    my $self = shift;
    $self->{'input'} = '!%: include "dir1/getdirtop"';
    $self->{'answer'} = '/';
  };

  case 'should getPathTop given pathname' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, qq(-n dir2/relfile);
    $self->{'input'} = '!%: include "dir1/getdirtop"';
    $self->{'answer'} = '/dir2';
  };

  # ====== method: canonicalizePath ======

  case 'should canonicalizePath on pure stdin input' => sub {
    my $self = shift;
    $self->{'input'} = '!%: canonicalizePath("dir2/dir3")';
    $self->{'answer'} = '/dir2/dir3';
  };

  case 'should canonicalizePath given pathname' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, qq(-n dir1/relfile);
    $self->{'input'} = '!%: canonicalizePath("../dir2/dir3")';
    $self->{'answer'} = '/dir2/dir3';
  };

  # ====== method: inc ======

  case 'should include on pure stdin input' => sub {
    my $self = shift;
    $self->{'input'} = "!%: inc('dir1/relfile')";
    $self->{'answer'} = 'RELFILE';
  };

  case 'should include given pathname' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, qq(-n dir2/somefile);
    $self->{'input'} = "!%: inc('../dir1/relfile')";
    $self->{'answer'} = 'RELFILE';
  };

  case 'should be able to include more than one layer' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, qq(-n dir2/somefile);
    $self->{'input'} = "!%: inc('../dir1/dir2/inc')";
    $self->{'answer'} = "RELFILE";
  };

  case 'should pass var values into include scope' => sub {
    my $self = shift;
    $self->{'input'} = "!%: assign('var1', 'VAR1')\n!%: inc('dir1/varvalue')";
    $self->{'answer'} = 'VAR1';
  };

  case 'should pass var values out of include scope' => sub {
    my $self = shift;
    $self->{'input'} = "!%: inc('dir1/doassign')\n[% \$var1 %]";
    $self->{'answer'} = 'VAR1-new';
  };

  case 'should write dep field when including' => sub {
    my $self = shift;
    $self->{'input'} = "!%: inc('dir1/nocontent')\n[% \$_deps['/dir1/nocontent'] %]";
    $self->{'answer'} = "$pathTestData/dir1/nocontent";
  };

  case 'should be able to optional inc' => sub {
    my $self = shift;
    $self->{'input'} = "!%: inc('should/not/exist', '')";
    $self->{'answer'} = "";
  };

  case 'should be able to optional inc with default text' => sub {
    my $self = shift;
    $self->{'input'} = "!%: inc('should/not/exist', 'UNKNOWN')";
    $self->{'answer'} = "UNKNOWN";
  };

  case 'should crash if include failure' => sub {
    my $self = shift;
    $self->{'input'} = "!%: inc('should/not/exist')";
    $self->{'exitcode'} = 2;
  };

  # ====== method: incRaw ======

  case 'should raw-include given pathname' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, qq(-n dir2/somefile);
    $self->{'input'} = "!%: incRaw('../dir1/relfile')";
    $self->{'answer'} = "[% 'RELFILE' %]";
  };

  case 'should write dep field when raw-including' => sub {
    my $self = shift;
    $self->{'input'} = "!%: incRaw('dir1/nocontent')\n[% \$_deps['/dir1/nocontent'] %]";
    $self->{'answer'} = "$pathTestData/dir1/nocontent";
  };

  case 'should be able to optional incRaw' => sub {
    my $self = shift;
    $self->{'input'} = "!%: incRaw('should/not/exist', '')";
    $self->{'answer'} = "";
  };

  case 'should be able to optional incRaw with default text' => sub {
    my $self = shift;
    $self->{'input'} = "!%: incRaw('should/not/exist', 'UNKNOWN')";
    $self->{'answer'} = "UNKNOWN";
  };

  case 'should crash if incRaw failure' => sub {
    my $self = shift;
    $self->{'input'} = "!%: incRaw('should/not/exist')";
    $self->{'exitcode'} = 2;
  };

  # ====== method: debug-related ======

  case 'should print only a newline with debug if no debug flag' => sub {
    my $self = shift;
    $self->{'input'} = "!%: assign('var1', '12345')\n!%: debug()";
    $self->{'answer'} = "";
  };

  case 'should print debug if have debug flag' => sub {
    my $self = shift;
    $ENV{'TRIS_BUILD_DEBUG'} = 1;
    $self->{'input'} = "!%: assign('var1', '12345')\n!%: debug()";
    $self->{'like'} = qr|var1 => 12345|;
  };

  case 'should print debug if in forced mode' => sub {
    my $self = shift;
    $self->{'input'} = "!%: assign('var1', '12345')\n!%: debug(1)";
    $self->{'like'} = qr|var1 => 12345|;
  };

  case 'should crash if called error' => sub {
    my $self = shift;
    $self->{'input'} = "!%: error('some_error_message')";
    $self->{'exitcode'} = 2;
    $self->{'likeErr'} = qr|some_error_message|;
  };

  it 'should give correct text output' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand($self->{'cmdline'}, $self->{'input'});
    is($objIPC->{'exit_code'}, $self->{'exitcode'}, $objIPC->{'stderr'});
    compareIsOrLike $self, $output;
  };

};

done_testing;
