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

my $pathTestData = "$Bin/data-genbuild";
$ENV{'PERL5LIB'} = "$pathTestData/lib:$ENV{'PERL5LIB'}";
$ENV{'PATH'} = "$Bin/../bin:$ENV{'PATH'}";

use lib "$Bin"; # for CommonTest
use CommonTest;
use File::Slurp; # for reading output file and write test file
use File::Path qw(make_path);

describe 'Basic genbuild' => sub {
  before_case 'Fallback Input' => sub {
    my $self = shift;
    $self->{'dir'} = createTempDir();
    $self->{'cmdline'} = [qq( $Bin/../bin/gen-triskelion $self->{'dir'} )];
    $self->{'exitcode'} = 0;
  };

  case 'should generate standard Makefile' => sub {
    my $self = shift;
    $self->{'likeMake'} = qr|\$\(NINJA\) -t clean|;
  };

  case 'should generate standard ninja.build with regen rules' => sub {
    my $self = shift;
    $self->{'like'} = qr|^rule regen.*\$TRISGENBUILD.*build build.ninja: regen|ms;
  };

  case 'should generate standard ninja.build with prebuild commands' => sub {
    my $self = shift;
    $self->{'like'} = qr|^rule prebuild-command.*command = \$prebuildcmd.*build _prebuildall: phony|ms;
  };

  case 'should generate standard ninja.build with build commands' => sub {
    my $self = shift;
    $self->{'like'} = qr|^build \$TRISBIN: phony|ms;
  };

  case 'should accept root parameter' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, ('-r', "$pathTestData/root1");
    $self->{'like'} = qr|'-r' '$pathTestData/root1'|s;
  };

  case 'should accept multiple root parameters' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, ('-r', "$pathTestData/root1", '-r', "$pathTestData/root2");
    $self->{'like'} = qr|'-r' '$pathTestData/root1' '-r' '$pathTestData/root2'|s;
  };

  case 'should accept lib parameter' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, ('-l', "$pathTestData/lib1");
    $self->{'like'} = qr|PERL5LIB =.*$pathTestData/lib1|; # no s modifier: they must be on same line
  };

  case 'should accept multiple lib parameters' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, ('-l', "$pathTestData/lib1", '-l', "$pathTestData/lib2");
    $self->{'like'} = qr|PERL5LIB =.*$pathTestData/lib1:$pathTestData/lib2|; # no s modifier: they must be on same line
  };

  case 'should accept build instruction' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, ('-r', "$pathTestData/root2", '-b', "test,src,,,");
    $self->{'like'} = qr|build template2: build-__|; # no s modifier: they must be on same line
  };

  case 'should accept chmod instruction' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, ('-r', "$pathTestData/root2", '-b', "test,src,,", '--chmod', 'test,a+x');
    $self->{'like'} = qr|build template2: build-__.*chmod|s;
  };

  case 'should pass no-builtin to triskelion' => sub {
    my $self = shift;
    push @{$self->{'cmdline'}}, ('-r', "$pathTestData/root2", '-b', "test,src,,,", '--no-builtin');
    $self->{'like'} = qr|command =.*\$TRISBIN.*--no-builtin|;
  };

  it 'should generate correct build file' => sub {
    my $self = shift;
    my ($objIPC, $dumb) = runTestPerlCommand($self->{'cmdline'});
    is($objIPC->{'exit_code'}, $self->{'exitcode'}, $objIPC->{'stderr'});
    # Need the scalar modifier to make read_file return a single text variable
    compareIsOrLike $self, scalar read_file("$self->{'dir'}/build.ninja");
    compareIsOrLike $self, scalar read_file("$self->{'dir'}/Makefile"), 'Make';
  };
};

describe 'command line things' => sub {

  before_each 'Create tmpdir' => sub {
    my $self = shift;
    $self->{'dir'} = createTempDir();
  };

  it 'should error if not given any parameter' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/gen-triskelion )]);
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/SYNOPSIS/);
  };

  it 'should error if cannot create output dir' => sub {
    my $self = shift;
    my $fname = "$self->{'dir'}/1234";
    write_file($fname, "123"); # occupy the directory name as file
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/gen-triskelion $fname )]);
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/File exists at/);
  };

  it 'should error if cannot create output Makefile' => sub {
    my $self = shift;
    my $fname = "$self->{'dir'}/Makefile";
    make_path $fname;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/gen-triskelion $self->{'dir'} )]);
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/Is a directory at/);
  };

  it 'should error if cannot create output build.ninja' => sub {
    my $self = shift;
    my $fname = "$self->{'dir'}/build.ninja";
    make_path $fname;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/gen-triskelion $self->{'dir'} )]);
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/Is a directory/);
  };

  it 'should print help message on stderr' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/gen-triskelion --help )]);
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/SYNOPSIS/);
  };

  it 'should error if given non-existent root' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/gen-triskelion $self->{'dir'} -r /-----NON_EXISTENCE )]);
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/Specified directory.*does not exist/);
  };

  it 'should error if build parameter have no comma at all' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/gen-triskelion $self->{'dir'} -b abcd )]);
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/Build specs should have commas/);
  };

  it 'should error if external command have "fail" return value' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/gen-triskelion $self->{'dir'} --external-prebuild false )]);
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/Error when running external-prebuild/);
  };

  it 'should error if chmod a non-existent build identifier' => sub {
    my $self = shift;
    my ($objIPC, $output) = runTestPerlCommand([qq( $Bin/../bin/gen-triskelion $self->{'dir'} --chmod abc )]);
    isnt($objIPC->{'exit_code'}, 0);
    like($objIPC->{'stderr'}, qr/Cannot specify mode for build rule.*does not exist/);
  };

}; # end test fix command line things

done_testing;
