#!/usr/bin/env perl
# Bash script
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

package UnladenTriskelionPlugin::Bash;

use Text::Xslate;

use File::Basename; # for dirname
use Cwd qw( realpath );

# regex pattern to match the shell-invoke command
use constant patternIncShell => qr{
  (?: \s | ^ ) \K         # look-behind non-capture, start without non-space
  ! ([.#]) ([^\s;]+)      # The command we want, .=execute, #=export
}sx;

sub getDeps {
  return ['Builtin'];
}

sub mutateOptions {
  my $self = shift;
  my $args = shift // die;

  # Add root templates for bash scripts
  my $tmpldir = realpath(dirname(__FILE__) . "/../../tmpl");
  push @{$args->{'path'}}, $tmpldir;
}

# Add cascade around
sub preProcessEach {
  my $self = shift;
  my $text = shift // die;

  # Resolve bash shell invoke pattern
  while ($text =~ patternIncShell) {
    my $symbol = $1;
    my $fname = $2;
    my $startBlock = $-[0];
    my $lenBlock = $+[0]-$-[0];

    if ($symbol eq '.') {
      substr($text, $startBlock, $lenBlock, "[% incShell('$fname') %]");
    } elsif ($symbol eq '#') {
      substr($text, $startBlock, $lenBlock, "[% incShell('$fname', 1) %]");
    }
  }

  $text = $self->{'deps'}{'Builtin'}->parseSpecialCommand($text, 'bash', sub {
    my $textIn = shift // die;
    my $posFront = shift // die;
    my $posBack = shift // die;
    my @listParameter = @{shift // []};

    my $template = "/base/tris-bash/main.tx";
    if (scalar @listParameter > 0) {
      $template = $listParameter[0];
    }

    return $self->{'deps'}{'Builtin'}->applyCascadeTemplate($textIn, $posFront, $posBack, $template);
  });

  return $text;
}

sub getMethods {
  return {

    # Declare usable type checks
    enabletype => sub {
      my $self = shift;
      my $name = shift // die;

      my $var = Text::Xslate->current_vars;
      $var->{'_typecheck'} //= {}; # default value
      $var->{'_typecheck'}{$name} = 1;
      return '';
    },

    # Declare shell script options
    arg => sub {
      my $self = shift;
      my $name = shift // die;
      my $value = shift // die;
      my %opts = %{shift // die};
      my $desc = shift // die;

      $opts{'required'} = 1;
      return $self->{'tx'}{'function'}{'opt'}($name, $value, \%opts, $desc);
    },

    opt => sub {
      my $self = shift;
      my $name = shift // die;
      my $value = shift // die;
      my %opts = %{shift // die};
      my $desc = shift // die;

      $opts{'name'} = $name;
      $opts{'varname'} = ($name =~ s/-/_/rg);
      $opts{'isArray'} = ($value eq '()') ? 1 : 0;
      $opts{'value'} = $opts{'isArray'} ? '()' : "\"$value\"";

      # Text-process descriptions
      $desc =~ s/^[\n\r]+//;
      $desc =~ s/[\n\r]+$//;
      if ($desc =~ /^(\s+)/) {
        my $levelIndent = length($1);
        $desc =~ s/^\s{$levelIndent}//mg;
      }
      $opts{'desc'} = (($desc =~ s/^/# /mrg) =~ s/\n/\n    /gr);

      my $var = Text::Xslate->current_vars;
      $var->{'_args'} //= {}; # default value
      $var->{'_args'}{$name} = \%opts;

      return "$opts{'varname'}=$opts{'value'} " . $opts{'desc'} . "\n";
    },

    # Call a file in bash's process substitution, or export as bash function
    incShell => sub {
      my $self = shift;
      my $target = shift // die;
      my $toExport = shift // 0;
      $target = $self->{'tx'}{'function'}{'addDependency'}($target);

      # Add to shell include list
      my $var = Text::Xslate->current_vars;
      $var->{'_shelldeps'} //= {}; # default value
      $var->{'_shelldeps'}{$target} = 1;

      if ($toExport == 0) {
        return "<(_GET\%$target)";
      } else {
        return "declare -f \"_GET\%$target\"";
      }
    },

    dumpAllIncludedShellFiles => sub {
      my $self = shift;
      my $var = Text::Xslate->current_vars;
      my %target = shift // %{$var->{'_shelldeps'} // {}};
      my $rslt = '';

      foreach my $fname (keys %target) {
        $rslt .= "_GET\%$fname() { # {{{" . "\n"
        . "  cat <<\"EOF__::$fname\"" . "\n"
        . $self->{'tx'}{'function'}{'incRaw'}($fname) . "\n"
        . "EOF__::$fname" . "\n"
        . "} # }}}" . "\n";
      }
      return $rslt;
    }

  };
}

sub new { return bless {}, $_[0] };
1;
