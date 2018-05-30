#!/usr/bin/env perl
# Test for argument functions in bash plugin
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

my $pathTestData = "$Bin/data-mod-bash-args";
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
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion -n dir1/scriptargs.sh -p Bash -r $pathTestData -o $self->{'output'} )];
    $self->{'cmdline2'} = [qq( bash $self->{'output'} )];
    $self->{'exitcode'} = 0;
    $self->{'exitcode2'} = 0;
  };

  # ====== Base args/opts function ======

  case 'should add options' => sub {
    my $self = shift;
    $self->{'input'} = '!%: opt("a", "b", {}, "DESC");' . $self->{'input'} . 'echo [% $_args.a.name %] [% $_args.a.value %] "[% $_args.a.desc %]"';
    $self->{'answer'} = 'a b # DESC';
  };

  case 'should add options with additional data' => sub {
    my $self = shift;
    $self->{'input'} = '!%: opt("a", "b", {c=>15}, "DESC");' . $self->{'input'} . 'echo "[% $_args.a.c %]"';
    $self->{'answer'} = '15';
  };

  case 'should auto-infer proper variable name' => sub {
    my $self = shift;
    $self->{'input'} = '!%: opt("a-b", "", {}, "");' . $self->{'input'} . 'echo "[% $_args["a-b"].varname %]"';
    $self->{'answer'} = 'a_b';
  };

  case 'should detect array' => sub {
    my $self = shift;
    $self->{'input'} = '!%: opt("a", "()", {}, "");' . $self->{'input'} . 'echo "[% $_args.a.isArray %]"';
    $self->{'answer'} = '1';
  };

  case 'should add required property if using arg' => sub {
    my $self = shift;
    $self->{'input'} = '!%: arg("a", "b", {}, "DESC");' . $self->{'input'} . 'echo [% $_args.a.required %]';
    $self->{'answer'} = '1';
  };

  case 'should un-indent multiline description' => sub {
    my $self = shift;
    $self->{'input'} = '!%: arg("a", "b", {}, "\n  DESC\n  DESC\n  DESC\n");' . $self->{'input'} . 'echo "[% $_args.a.desc %]"';
    $self->{'answer'} = "# DESC\n    # DESC\n    # DESC";
  };

  # ====== Check argument ======

  case 'should error if required arg not given' => sub {
    my $self = shift;
    $self->{'input'} = '!%: arg("a", "", {}, "");' . $self->{'input'};
    $self->{'likeErr'} = qr|Required argument a is not given|;
    $self->{'exitcode2'} = 1;
  };

  case 'should be ok if required arg is given' => sub {
    my $self = shift;
    $self->{'input'} = '!%: arg("a", "", {}, "");' . $self->{'input'} . 'echo $a';
    push @{$self->{'cmdline2'}}, 'a=15';
    $self->{'answer'} = '15';
  };

  case 'should add type check availability' => sub {
    my $self = shift;
    $self->{'input'} = '!%: enabletype("type3")' . $self->{'input'} . 'echo [% $_typecheck.type3 %]';
    $self->{'answer'} = '1';
  };

  case 'should compile error if type does not exist' => sub {
    my $self = shift;
    $self->{'input'} = '!%: arg("a", "", {typecheck=>"wrong-type"}, "");' . $self->{'input'};
    $self->{'exitcode'} = 25;
    $self->{'exitcode2'} = 127;
  };

  case 'should be ok if type correct' => sub {
    my $self = shift;
    $self->{'input'} = '!%: arg("a", "", {typecheck=>"int"}, "");' . $self->{'input'} . 'echo $a';
    push @{$self->{'cmdline2'}}, 'a=15';
    $self->{'answer'} = '15';
  };

  case 'should error if type incorrect' => sub {
    my $self = shift;
    $self->{'input'} = '!%: arg("a", "", {typecheck=>"int"}, "");' . $self->{'input'} . 'echo $a';
    push @{$self->{'cmdline2'}}, 'a=ABCD';
    $self->{'exitcode2'} = 1;
    $self->{'likeErr'} = qr|Type error.*is not of type int|;
  };

  case 'should be ok if array type correct' => sub {
    my $self = shift;
    $self->{'input'} = '!%: arg("a", "()", {typecheck=>"int"}, "");' . $self->{'input'} . 'echo ${a[@]}';
    push @{$self->{'cmdline2'}}, 'a=15';
    push @{$self->{'cmdline2'}}, 'a=16';
    $self->{'answer'} = '15 16';
  };

  case 'should error if array type incorrect' => sub {
    my $self = shift;
    $self->{'input'} = '!%: arg("a", "()", {typecheck=>"int"}, "");' . $self->{'input'} . 'echo ${a[@]}';
    push @{$self->{'cmdline2'}}, 'a=ABCD';
    push @{$self->{'cmdline2'}}, 'a=16';
    $self->{'exitcode2'} = 1;
    $self->{'likeErr'} = qr|Type error.*is not of type int|;
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
