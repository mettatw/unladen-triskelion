#!/usr/bin/env perl
# Test for bash plugin
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

my $pathTestData = "$Bin/data-mod-bash";
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
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion -n dir1/script1.sh -p Bash -r $pathTestData -o $self->{'output'} )];
    $self->{'cmdline2'} = [qq( bash $self->{'output'} )];
    $self->{'exitcode'} = 0;
    $self->{'exitcode2'} = 0;
  };

  case 'should have basic working script' => sub {
    my $self = shift;
    $self->{'input'} .= "echo 1357";
    $self->{'answer'} = "1357";
  };

  case 'should be able to use another main template file' => sub {
    my $self = shift;
    $self->{'input'} = "\n!\@bash:/folder/new.tx\n";
    $self->{'answer'} = "NEW TEMPLATE FILE";
  };

  # ====== Unusable env detections ======

  case 'should not work when invoked with other sh' => sub {
    my $self = shift;
    $self->{'input'} .= "echo 1357";
    $self->{'cmdline2'} = [qq( zsh $self->{'output'} )];
    $self->{'exitcode2'} = 32;
  };

  # ====== Screen messages ======

  case 'should not print titles when simply executed' => sub {
    my $self = shift;
    $self->{'input'} .= '#';
    $self->{'answerErr'} = '';
  };

  case 'should print titles when asked' => sub {
    my $self = shift;
    $ENV{'TRIS_PRINTTITLE'} = 1;
    $self->{'input'} .= '#';
    $self->{'likeErr'} = qr|\(done in|;
  };

  case 'should not print anything with TRIS_NOTITLE' => sub {
    my $self = shift;
    $ENV{'TRIS_PRINTTITLE'} = 1;
    $ENV{'TRIS_NOTITLE'} = 1;
    $self->{'input'} .= '#';
    $self->{'answerErr'} = '';
  };

  # ====== Important global variables ======

  case 'should have TRIS_SCRIPTNAME' => sub {
    my $self = shift;
    $self->{'input'} .= 'echo $TRIS_SCRIPTNAME';
    $self->{'answer'} = "script1.sh";
  };

  case 'should have open fd 5, 6, 7' => sub {
    my $self = shift;
    $self->{'input'} .= 'echo >&5; echo >&6; echo >&7';
  };

  case 'should have TRIS_LEVEL' => sub {
    my $self = shift;
    $self->{'input'} .= 'echo $TRIS_LEVEL';
    $self->{'answer'} = "1";
  };

  case 'should have TRIS_LEVEL on nested invocation' => sub {
    my $self = shift;
    $self->{'input'} .= 'if [[ "$TRIS_LEVEL" == 1 ]]; then bash $0; else echo $TRIS_LEVEL; fi';
    $self->{'answer'} = "2";
  };

  # ====== Shell import ======

  case 'should be able to shell import' => sub {
    my $self = shift;
    $self->{'input'} .= 'cat !./folder/shellinclude';
    $self->{'answer'} = "CONTENT";
  };

  case 'should be able to shell import and terminating with semicolon' => sub {
    my $self = shift;
    $self->{'input'} .= 'cat !./folder/shellinclude;';
    $self->{'answer'} = "CONTENT";
  };

  case 'should be able to shell export' => sub {
    my $self = shift;
    $self->{'input'} .= '!#/folder/shellinclude;';
    $self->{'answerLike'} = qr{_GET%.*CONTENT};
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
