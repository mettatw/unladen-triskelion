#!/usr/bin/env perl
# Test for hooks in bash plugin
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

  # ====== Logging ======

  case 'should be able to write log file' => sub {
    my $self = shift;
    $ENV{'TRIS_LOGFILE'} = "$self->{'dir'}/log";
    $self->{'input'} .= "cat '$self->{'dir'}/log'";
    $self->{'like'} = qr|Start of main script|;
  };

  case 'should be able to do log rotation' => sub {
    my $self = shift;
    use File::Slurp; # actually compile-time construct
    write_file "$self->{'dir'}/log", "OLDLOGCONTENT";
    $ENV{'TRIS_LOGFILE'} = "$self->{'dir'}/log";
    $ENV{'TRIS_LOGROTATE'} = "3";
    $self->{'input'} .= "gunzip -c '$self->{'dir'}/log.1\.gz';";
    $self->{'answer'} = "OLDLOGCONTENT";
  };

  case 'should spit out error if logfile is a directory' => sub {
    my $self = shift;
    $ENV{'TRIS_LOGFILE'} = "$self->{'dir'}";
    $self->{'exitcode2'} = 1;
    $self->{'likeErr'} = qr|Cannot log to.*it is a directory|;
  };

  # ====== pre-parse hook ======

  case 'should have pre-parse hook' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::pre_parse::a1() { echo PREPARSE1; }" . $self->{'input'};
    $self->{'answer'} = "PREPARSE1";
  };

  case 'should have pre-parse hook in alphabetical order' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::pre_parse::a2() { echo PREPARSE2; }\n__TRIS::HOOK::pre_parse::a1() { echo PREPARSE1; }" . $self->{'input'};
    $self->{'answer'} = "PREPARSE1\nPREPARSE2";
  };

  case 'should have no fd5~7 yet for pre-parse hook' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::pre_parse::a1() { if { true>&6; } && { true>&5; }; then echo BAD; else echo GOOD; fi; }" . $self->{'input'};
    $self->{'answer'} = "GOOD";
  };

  # ====== post-parse hook ======

  case 'should have post-parse hook' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::post_parse::a1() { echo POSTPARSE1; }" . $self->{'input'};
    $self->{'answer'} = "POSTPARSE1";
  };

  case 'should have post-parse hook in alphabetical order' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::post_parse::a2() { echo POSTPARSE2; }\n__TRIS::HOOK::post_parse::a1() { echo POSTPARSE1; }" . $self->{'input'};
    $self->{'answer'} = "POSTPARSE1\nPOSTPARSE2";
  };

  case 'should have fd5~7 for post-parse hook' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::post_parse::a1() { if { true>&6; } && { true>&5; }; then echo GOOD; fi; }" . $self->{'input'};
    $self->{'answer'} = "GOOD";
  };

  case 'should not have printed title yet at post-parse' => sub {
    my $self = shift;
    $ENV{'TRIS_PRINTTITLE'} = 1;
    $self->{'input'} = "__TRIS::HOOK::post_parse::a1() { echo CUTOUT >&2; exit 0; }" . $self->{'input'};
    $self->{'answerErr'} = "CUTOUT\n";
  };

  case 'should not have opened log file at post-parse' => sub {
    my $self = shift;
    $ENV{'TRIS_LOGFILE'} = "$self->{'dir'}/log";
    $self->{'input'} = "__TRIS::HOOK::post_parse::a1() { if [[ -f $self->{'dir'}/log ]]; then echo BAD >&2; else echo GOOD >&2; fi; exit 0; }" . $self->{'input'};
    $self->{'answerErr'} = "GOOD\n";
  };

  # ====== Pre-script hook ======

  case 'should have pre-script hook' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::pre_script::a1() { echo PRELOG1; }" . $self->{'input'};
    $self->{'answer'} = 'PRELOG1';
  };

  case 'should have pre-script hook in alphabetical order' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::pre_script::a2() { echo PRELOG2; }; __TRIS::HOOK::pre_script::a1() { echo PRELOG1; }" . $self->{'input'};
    $self->{'answer'} = "PRELOG1\nPRELOG2";
  };

  case 'should have printed title at pre-script' => sub {
    my $self = shift;
    $ENV{'TRIS_PRINTTITLE'} = 1;
    $self->{'input'} = "__TRIS::HOOK::pre_script::a1() { echo CUTOUT >&2; exit 0; }" . $self->{'input'};
    $self->{'likeErr'} = qr|\[\d{6}\.\d{6}\].*CUTOUT\n|s;
  };

  case 'should have opened log file at pre-script' => sub {
    my $self = shift;
    $ENV{'TRIS_LOGFILE'} = "$self->{'dir'}/log";
    # Use fd5 here since 2 will have buffering issue if we have log file
    $self->{'input'} = "__TRIS::HOOK::pre_script::a1() { if [[ -f $self->{'dir'}/log ]]; then echo GOOD >&5; else echo BAD >&5; fi; exit 0; }" . $self->{'input'};
    $self->{'likeErr'} = qr|GOOD|;
  };

  case 'should write stdout into log file' => sub {
    my $self = shift;
    $ENV{'TRIS_LOGFILE'} = "$self->{'dir'}/log";
    $self->{'input'} = "__TRIS::HOOK::pre_script::a1() { echo PRELOGGING; }" . $self->{'input'} . "cat $self->{'dir'}/log";
    $self->{'like'} = qr|PRELOGGING.*Start of main script|s;
  };

  # ====== Post-script hook ======

  case 'should have post-script hook' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::post_script::a1() { echo POSTLOG1; }" . $self->{'input'} . "echo IN-SCRIPT";
    $self->{'answer'} = "IN-SCRIPT\nPOSTLOG1";
  };

  case 'should have post-script hook in alphabetical order' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::post_script::a2() { echo POSTLOG2; }; __TRIS::HOOK::post_script::a1() { echo POSTLOG1; }" . $self->{'input'} . "echo IN-SCRIPT";
    $self->{'answer'} = "IN-SCRIPT\nPOSTLOG1\nPOSTLOG2";
  };

  # ====== exit hook ======

  case 'should have exit hook' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::exit::a1() { echo EXIT; }" . $self->{'input'} . "echo I1";
    $self->{'answer'} = "I1\nEXIT";
  };

  case 'should have exit hook in alphabetical order' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::exit::a2() { echo EXIT2; }; __TRIS::HOOK::exit::a1() { echo EXIT1; }" . $self->{'input'} . "echo I1";
    $self->{'answer'} = "I1\nEXIT1\nEXIT2";
  };

  case 'should have exit hook that is able to reflect return value' => sub {
    my $self = shift;
    $self->{'input'} = "__TRIS::HOOK::exit::a1() { echo EXIT\$1; }" . $self->{'input'} . "echo I1;exit 3";
    $self->{'answer'} = "I1\nEXIT3";
    $self->{'exitcode2'} = 3;
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
