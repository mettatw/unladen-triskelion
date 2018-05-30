#!/usr/bin/env perl
# Main Xslate wrapper module
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

package UnladenTriskelion::Slater;

use Scalar::Util qw(blessed); # in order to do object check

use Text::Xslate;
use Hash::Merge::Simple qw(merge);
use List::MoreUtils qw(any);

sub new {
  my $class = shift;
  my %confGiven = %{shift // {}};

  my $self = {};
  bless $self, $class;

  # Default config and modules
  my %mapMethods = ();
  my %conf = (
    path => [],
    verbose => 2,
    type => 'text',
    tag_start => '[%',
    tag_end => '%]',
    line_start => '!%:',
    cache => 0,
    function => {},
    warn_handler => sub { die join("\n", @_); }
  );

  my @listModules = @{shift // []};
  my %mapModules = map {ref($_) =~ s/^UnladenTriskelionPlugin:://r => $_} @listModules;
  $self->{'listModules'} = \@listModules;
  $self->{'mapModules'} = \%mapModules;

  # Start unwrapping what modules have to given
  foreach my $module (@listModules) {
    die unless (blessed $module);
    if ($module->can('getDeps')) { # insert dependencies into the module
      $module->{'deps'} //= {};
      for my $nameDep (@{$module->getDeps()}) {
        $module->{'deps'}{$nameDep} = $mapModules{$nameDep};
      }
    }
    if ($module->can('mutateOptions')) {
      $module->mutateOptions(\%conf);
    }
    if ($module->can('getFunctions')) {
      $conf{'function'} = merge($conf{'function'}, $module->getFunctions());
    }
    if ($module->can('getMethods')) {
      %mapMethods = %{merge(\%mapMethods, $module->getMethods())};
    }
  }

  # Special merge treatment to paths, since it cannot be merged automatically
  if (defined $confGiven{'path'}) {
    push @{$conf{'path'}}, @{$confGiven{'path'}};
    delete $confGiven{'path'}; # so that it will not overwrite conf.path later
  }
  # In Xslate, former paths take precendence, so we want to reverse the whole
  # path array, since we push new paths to the end...
  $conf{'path'} = [ reverse(@{$conf{'path'}}) ];

  # Special treatment to methods, since Xslate itself cannot handle this
  if (defined $confGiven{'method'}) {
    %mapMethods = %{merge(\%mapMethods, $confGiven{'method'})};
    delete $confGiven{'method'}; # so that is does not cause Xslate warnings
  }
  # Add method-like functions
  $self->{'mapMethods'} = \%mapMethods;
  foreach my $nameMethod (keys %mapMethods) {
    my $thisMethod = $mapMethods{$nameMethod};
    $conf{'function'}{$nameMethod} = sub {
      return $thisMethod->($self, @_);
    }
  }

  # After modules, override config with given options
  %conf = %{merge(\%conf, \%confGiven)};

  # Add pre-process handler if needed
  if (any {$_->can('preProcessEach')}, @listModules) {
    $conf{'pre_process_handler'} = sub {
      my $text = shift // die;
      foreach my $module (@listModules) {
        if ($module->can('preProcessEach')) {
          $text = $module->preProcessEach($text);
        }
      } # end for each module
      return $text;
    } # end preprocess handler function
  } # end if need preprocess handler

  my $tx = Text::Xslate->new(\%conf);
  $self->{'tx'} = $tx;

  return $self;
}

# do the template part only
sub doTemplate {
  my $self = shift;
  my $tmpl = shift // die;
  my $pVars = shift // {};
  return $self->{'tx'}->render_string($tmpl, $pVars);
}

sub preProcess {
  my $self = shift;
  my $tmpl = shift // die;
  my $pVars = shift // {};
  foreach my $module (@{$self->{'listModules'}}) {
    die unless (blessed $module);
    if ($module->can('preProcess')) {
      $tmpl = $module->preProcess($tmpl, $pVars);
    }
  }
  return $tmpl;
}

sub postProcess {
  my $self = shift;
  my $tmpl = shift // die;
  my $pVars = shift // {};
  foreach my $module (@{$self->{'listModules'}}) {
    die unless (blessed $module);
    if ($module->can('postProcess')) {
      $tmpl = $module->postProcess($tmpl, $pVars);
    }
  }
  return $tmpl;
}

# The main render function
sub render {
  my $self = shift;
  my $tmpl = shift // die;
  my $pVars = shift // {};

  my $rslt = $self->preProcess($tmpl, $pVars);
  if (defined $self->{'tx'}{'pre_process_handler'}) {
    $rslt = $self->{'tx'}{'pre_process_handler'}($rslt)
  }
  $rslt = $self->doTemplate($rslt, $pVars);
  $rslt = $self->postProcess($rslt, $pVars);
  return $rslt;
}

1;
