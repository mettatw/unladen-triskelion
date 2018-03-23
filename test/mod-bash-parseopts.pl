#!/usr/bin/env perl
# Test for parseopts.sh script
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

  # ====== Basic parsing ======

  case 'should parse --a=b style' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\n$self->{'input'}\necho \$aaa";
    push @{$self->{'cmdline2'}}, '--aaa=newvalue';
    $self->{'answer'} = "newvalue";
  };

  case 'should parse a=b style' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\n$self->{'input'}\necho \$aaa";
    push @{$self->{'cmdline2'}}, 'aaa=newvalue';
    $self->{'answer'} = "newvalue";
  };

  case 'should NOT parse --a b style' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\n$self->{'input'}\necho \$aaa \$@";
    push @{$self->{'cmdline2'}}, '--aaa';
    push @{$self->{'cmdline2'}}, 'newvalue';
    $self->{'answer'} = "true newvalue";
  };

  case 'should parse options with dash' => sub {
    my $self = shift;
    $self->{'input'} = "aaa_bbb=default\n$self->{'input'}\necho \$aaa_bbb";
    push @{$self->{'cmdline2'}}, '--aaa-bbb=newvalue';
    $self->{'answer'} = "newvalue";
  };

  case 'should parse things after positional args' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\n$self->{'input'}\necho \$aaa \$@";
    push @{$self->{'cmdline2'}}, 'something123';
    push @{$self->{'cmdline2'}}, 'aaa=newvalue';
    $self->{'answer'} = "newvalue something123";
  };

  case 'should parse nothing after --' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\n$self->{'input'}\necho \$aaa \$@";
    push @{$self->{'cmdline2'}}, '--';
    push @{$self->{'cmdline2'}}, 'aaa=newvalue';
    $self->{'answer'} = "default aaa=newvalue";
  };

  case 'should error if invalid option' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\n$self->{'input'}";
    push @{$self->{'cmdline2'}}, '--bbb=newvalue';
    $self->{'likeErr'} = qr|invalid option|;
    $self->{'exitcode2'} = 5;
  };

  # ====== Multiple values ======

  case 'should parse multiple times' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\nbbb=default2\n$self->{'input'}\necho \$aaa \$bbb";
    push @{$self->{'cmdline2'}}, '--aaa=newvalue';
    push @{$self->{'cmdline2'}}, '--bbb=newvalue2';
    $self->{'answer'} = "newvalue newvalue2";
  };

  case 'should overwrite previous value' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\n$self->{'input'}\necho \$aaa";
    push @{$self->{'cmdline2'}}, '--aaa=newvalue';
    push @{$self->{'cmdline2'}}, '--aaa=newvalue2';
    $self->{'answer'} = "newvalue2";
  };

  case 'should concat array' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=()\n$self->{'input'}\necho \${aaa[@]}";
    push @{$self->{'cmdline2'}}, '--aaa=newvalue';
    push @{$self->{'cmdline2'}}, '--aaa=newvalue2';
    $self->{'answer'} = "newvalue newvalue2";
  };

  # ====== config file ======

  case 'should parse config file' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\nbbb=default2\n$self->{'input'}\necho \$aaa \$bbb";
    push @{$self->{'cmdline2'}}, '--config=data-mod-bash-parseopts/config2';
    $self->{'answer'} = "configvalue configvalue2";
  };

  case 'should error from bad config entry' => sub {
    my $self = shift;
    $self->{'input'} = "bbb=default\n$self->{'input'}";
    push @{$self->{'cmdline2'}}, '--config=data-mod-bash-parseopts/config2';
    $self->{'likeErr'} = qr|invalid option|;
    $self->{'exitcode2'} = 5;
  };

  case 'should parse config file with space' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\nbbb=default2\n$self->{'input'}\necho \$aaa \$bbb";
    push @{$self->{'cmdline2'}}, '--config=data-mod-bash-parseopts/config2space';
    $self->{'answer'} = "config value config value2";
  };

  case 'should parse config file even if no trailing newline' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\nbbb=default2\n$self->{'input'}\necho \$aaa \$bbb";
    push @{$self->{'cmdline2'}}, '--config=data-mod-bash-parseopts/config2nonl';
    $self->{'answer'} = "configvalue configvalue2";
  };

  case 'should parse config file and be overriden by commandline options after' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\nbbb=default2\n$self->{'input'}\necho \$aaa \$bbb";
    push @{$self->{'cmdline2'}}, '--config=data-mod-bash-parseopts/config2';
    push @{$self->{'cmdline2'}}, '--aaa=newvalue';
    $self->{'answer'} = "newvalue configvalue2";
  };

  case 'should parse config file and not be overriden by commandline options before' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\nbbb=default2\n$self->{'input'}\necho \$aaa \$bbb";
    push @{$self->{'cmdline2'}}, '--aaa=newvalue';
    push @{$self->{'cmdline2'}}, '--config=data-mod-bash-parseopts/config2';
    $self->{'answer'} = "configvalue configvalue2";
  };

  # ====== environment variable ======

  case 'should get config value from environment variable' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\nbbb=default2\n$self->{'input'}\necho \$aaa \$bbb";
    $ENV{'TRIS_DEFAULTARG_bbb'} = "envvalue2";
    $self->{'answer'} = "default envvalue2";
  };

  case 'should get env value with dash inside it' => sub {
    my $self = shift;
    $self->{'input'} = "aaa_bbb=default\n$self->{'input'}\necho \$aaa_bbb";
    $ENV{'TRIS_DEFAULTARG_aaa_bbb'} = "envvalue";
    $self->{'answer'} = "envvalue";
  };

  case 'should get env value overriden by cmdline' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\nbbb=default2\n$self->{'input'}\necho \$aaa \$bbb";
    $ENV{'TRIS_DEFAULTARG_bbb'} = "envvalue2";
    push @{$self->{'cmdline2'}}, '--bbb=newvalue2';
    $self->{'answer'} = "default newvalue2";
  };

  case 'should get env value overriden by config file' => sub {
    my $self = shift;
    $self->{'input'} = "aaa=default\nbbb=default2\n$self->{'input'}\necho \$aaa \$bbb";
    $ENV{'TRIS_DEFAULTARG_bbb'} = "envvalue2";
    push @{$self->{'cmdline2'}}, '--config=data-mod-bash-parseopts/config2';
    $self->{'answer'} = "configvalue configvalue2";
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
