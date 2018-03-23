#!/usr/bin/env perl
# Integration tests for build command line tool
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

package CommonTest;
use base 'Exporter';

# Insert sub-module use here
our @EXPORT = qw( runTestCommand runTestPerlCommand createTempDir compareIsOrLike );
our @EXPORT_OK = qw();

use IPC::Cmd qw( run_forked );
use File::Temp;
use Test2::V0;

use Module::Loaded; # for detecting coverage mode

sub runTestCommand {
  my @cmdline = @{shift // die};
  my $input = shift // undef;
  my $objIPC;
  if (defined $input) {
    $objIPC = run_forked(\@cmdline, {child_stdin => $input});
  } else {
    $objIPC = run_forked(\@cmdline);
  }
  my $output = $objIPC->{'stdout'};
  $output =~ s@[\n\r]+\z@@; # equivalent to multiple chomp with $/=\n
  return ($objIPC, $output);
}

sub runTestPerlCommand {
  my @cmdline = @{shift // die};
  my $input = shift // undef;
  if (is_loaded('Devel::Cover')) {
    unshift @cmdline, ($^X, '-MDevel::Cover=-db,cover_db,-ignore,.*local/.*,-select,.*UnladenTriskelionPlugin/.*\.pm,-silent,1')
  }
  return runTestCommand(\@cmdline, $input);
}

sub compareIsOrLike {
  my $self = shift // die;
  my $value = shift // undef;
  my $postfix = shift // '';

  my $answerIs = $self->{'answer' . $postfix};
  my $answerLike = $self->{'like' . $postfix};

  if (defined $answerIs) {
    is($value, $answerIs);
  } elsif (defined $answerLike) {
    like($value, $answerLike);
  }
}

sub createTempDir {
  # newdir() interface should automatically cleanup the directory on end
  my $dir = File::Temp->newdir("/tmp/TRISTEST-XXXXXXXXXX");
  return $dir;
}

1;
