#!/usr/bin/env perl
# Test for misc.sh in bash plugin
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

my $pathTestData = "$Bin/data-mod-bash-misc";
$ENV{'PERL5LIB'} = "$pathTestData/lib:$ENV{'PERL5LIB'}";
$ENV{'PATH'} = "$Bin/../bin:$ENV{'PATH'}";

use lib "$Bin"; # for CommonTest
use CommonTest;

describe 'The bash module' => sub {

  before_case 'Fallback Input' => sub {
    my $self = shift;
    $self->{'dir'} = createTempDir();
    $self->{'input'} = "\n!\@bash\n";
    $self->{'output'} = $self->{'dir'} . "/output";
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion -n dir1/scriptmisc.sh -p Bash -r $pathTestData -o $self->{'output'} )];
    $self->{'cmdline2'} = [qq( bash $self->{'output'} )];
    $self->{'exitcode'} = 0;
    $self->{'exitcode2'} = 0;
  };

  # ====== Screen messages ======

  case 'should be able to print Info' => sub {
    my $self = shift;
    $self->{'input'} .= 'printInfo "INFOSTR"';
    $self->{'likeErr'} = qr|\[\d{6}\.\d{6}\] INFOSTR|;
  };

  case 'should be able to print Warnings' => sub {
    my $self = shift;
    $self->{'input'} .= 'printWarning "WARNSTR"';
    $self->{'likeErr'} = qr|\[\d{6}\.\d{6}\] Warning: WARNSTR|;
  };

  case 'should be able to print Error and end program' => sub {
    my $self = shift;
    $self->{'input'} .= 'printError "ERRSTR"; echo SHOULD_NOT_PRINT';
    $self->{'likeErr'} = qr|\[\d{6}\.\d{6}\] Error: ERRSTR|;
    $self->{'exitcode2'} = 1;
    $self->{'answer'} = '';
  };

  # ====== User interactions ======
  # NOTE: unable to test this for now, due to some weird IPC::Cmd problems...

  # ====== Really misc functions ======

  case 'should be ok to isArray' => sub {
    my $self = shift;
    $self->{'input'} .= 'a=(); if isArray a; then echo ISARRAY; else echo NOTARRAY; fi';
    $self->{'answer'} = 'ISARRAY';
  };

  case 'should be ok to un-isArray' => sub {
    my $self = shift;
    $self->{'input'} .= 'a=15; if isArray a; then echo ISARRAY; else echo NOTARRAY; fi';
    $self->{'answer'} = 'NOTARRAY';
  };

  case 'should be able to getProperDuration in only seconds' => sub {
    my $self = shift;
    $self->{'input'} .= 'getProperDuration 15';
    $self->{'answer'} = '15s';
  };

  case 'should be able to getProperDuration in m/s' => sub {
    my $self = shift;
    $self->{'input'} .= 'getProperDuration 450';
    $self->{'answer'} = '7m30s';
  };

  case 'should be able to getProperDuration in h/m/s' => sub {
    my $self = shift;
    $self->{'input'} .= 'getProperDuration 4050';
    $self->{'answer'} = '1h7m30s';
  };

  it 'should give correct text output' => sub {
    my $self = shift;
    my ($objIPC, $dumb) = runTestPerlCommand($self->{'cmdline'}, $self->{'input'});
    is($objIPC->{'exit_code'}, $self->{'exitcode'}, $objIPC->{'stderr'});
    my ($objIPC2, $output) = runTestCommand($self->{'cmdline2'}, $self->{'input2'});
    is($objIPC2->{'exit_code'}, $self->{'exitcode2'}, $objIPC2->{'stderr'});
    compareIsOrLike $self, $output;
    compareIsOrLike $self, $objIPC2->{'stderr'}, 'Err';
  };

};

done_testing;
