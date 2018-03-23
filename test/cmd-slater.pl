#!/usr/bin/env perl
# Test for slater command
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

my $pathTestData = "$Bin/data-cmd-slater";
$ENV{'PERL5LIB'} = "$pathTestData/lib:$ENV{'PERL5LIB'}";
$ENV{'PATH'} = "$Bin/../bin:$ENV{'PATH'}";

use lib "$Bin"; # for CommonTest
use CommonTest;
use File::Slurp; # for reading output file

describe 'Run the tool' => sub {

  before_case 'Fallback Input' => sub {
    my $self = shift;
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion )];
    $self->{'exitcode'} = 0;
  };

  case 'should passthru dumb input' => sub {
    my $self = shift;
    $self->{'input'} = 'ABC';
    $self->{'answer'} = 'ABC';
  };

  case 'should passthru normal template' => sub {
    my $self = shift;
    $self->{'input'} = '[% 3 %]';
    $self->{'answer'} = '3';
  };

  case 'should read things under path' => sub {
    my $self = shift;
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion -r data-cmd-slater )];
    $self->{'input'} = "!%: include 'tmpl1'\n!%: include 'dir1/tmpl2'";
    $self->{'answer'} = "TMPL1\nTMPL2";
  };

  case 'should read things under multiple path' => sub {
    my $self = shift;
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion -r data-cmd-slater -r data-cmd-slater/dir1 )];
    $self->{'input'} = "!%: include 'tmpl1'\n!%: include 'tmpl2'";
    $self->{'answer'} = "TMPL1\nTMPL2";
  };

  case 'should get plugin' => sub {
    my $self = shift;
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion -p Simple1 )];
    $self->{'input'} = "[% 1+5 %]";
    $self->{'answer'} = "6+Simple1";
  };

  case 'should get plugin that have dependencies' => sub {
    my $self = shift;
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion -p Dep1 )];
    $self->{'input'} = "[% 1+5 %]";
    $self->{'answer'} = "6+Simple1+Dep1";
  };

  case 'should do template if given file on command line' => sub {
    my $self = shift;
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion -r data-cmd-slater $pathTestData/dir1/tmpl2 )];
    $self->{'answer'} = "TMPL2";
  };

  case 'should have pathname variable if given' => sub {
    my $self = shift;
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion -n /dir5/showpath.txt )];
    $self->{'input'} = '[% $_pathname %]';
    $self->{'answer'} = "/dir5/showpath.txt";
  };

  case 'should get --vars parameter' => sub {
    my $self = shift;
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion --vars '{"abc": "def"}' )];
    $self->{'input'} = '[% $abc %]';
    $self->{'answer'} = "def";
  };

  case 'should get --vars parameter: more than one level' => sub {
    my $self = shift;
    $self->{'cmdline'} = [qq( $Bin/../bin/triskelion --vars '{"abc": {"def": "ghi"}}' )];
    $self->{'input'} = '[% $abc.def %]';
    $self->{'answer'} = "ghi";
  };

  it 'should give correct text output' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand($self->{'cmdline'}, $self->{'input'});
    is($objIPC->{'exit_code'}, $self->{'exitcode'}, $objIPC->{'stderr'});
    compareIsOrLike $self, $output;
  };

};

describe 'Tool error' => sub {

  it 'should report error if cannot open output file' => sub {
    my $self = shift;
    my $fname = "/----NONEXIST/outputfile";
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/triskelion -o $fname )], '[% "OUT" %]');
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/Can't open output file/);
  };

  it 'should report error if template failure' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/triskelion )], '[% include "should_not_exist" %]');
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/LoadError/);
  };

  it 'should print help message on stderr' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/triskelion --help )]);
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/SYNOPSIS/);
  };

  it 'should die if given too many filenames' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/triskelion file1 file2 )], '[% "OUT" %]');
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/more than one filenames/);
  };

  it 'should die if given unparseable vars option' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/triskelion --vars '{{' )], '[% "OUT" %]');
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/Malformed JSON/);
  };

  it 'should die if write-dependency but no output file' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/triskelion -d 123 )], '[% "OUT" %]');
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/Cannot write dependency without plain/);
  };

  it 'should die if write-dependency but non-plain output file ' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/triskelion -d 123 -o /dev/stderr )], '[% "OUT" %]');
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/Cannot write dependency without plain/);
  };

};

describe 'Tool output' => sub {

  before_each 'Setup temporary output directory' => sub {
    my $self = shift;
    $self->{'dir'} = createTempDir();
  };

  it 'should write output file' => sub {
    my $self = shift;
    my $fname = $self->{'dir'} . "/outputfile";
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/triskelion -o $fname )], '[% "OUT" %]');
    is($objIPC->{'exit_code'}, 0, $objIPC->{'stderr'});
    is(read_file($fname), 'OUT');
  };

  it 'should write dependency file alongside output file' => sub {
    my $self = shift;
    my $fname = $self->{'dir'} . "/outputfile";
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/triskelion --vars '{"_deps": {"qq": "/a/b"}}' -r data-cmd-slater -o $fname -d $fname.d )], 'OUT');
    is($objIPC->{'exit_code'}, 0, $objIPC->{'stderr'});
    like(read_file("$fname.d"), qr{outputfile: /a/b});
  };

  it 'should write dependency file excluding skipped dependencies' => sub {
    my $self = shift;
    my $fname = $self->{'dir'} . "/outputfile";
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/triskelion --vars '{"_deps": {"/qq": "/a/b"}}' -r data-cmd-slater -o $fname -d $fname.d -S '/q.*' )], 'OUT');
    is($objIPC->{'exit_code'}, 0, $objIPC->{'stderr'});
    like(read_file("$fname.d"), qr{outputfile: $});
  };

};

done_testing;
