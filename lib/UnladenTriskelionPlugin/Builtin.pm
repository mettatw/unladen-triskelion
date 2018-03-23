#!/usr/bin/env perl
# Builtin things
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

package UnladenTriskelionPlugin::Builtin;

use Text::Xslate;
use List::Util qw(first);

use File::Basename; # for dirname
use File::Slurp; # for reading raw file

use Try::Tiny;

# Manipulate $target for relative paths
sub eliminateDoubleDot {
  my $path = shift // die;
  require File::Spec;
  $path = File::Spec->canonpath($path);
  # https://stackoverflow.com/a/45635706
  # from the answer composed by Denilson Sá Maia
  # license: cc by-sa 3.0
  while ($path =~ s{
      (^|/)              # Either the beginning of the string, or a slash, save as $1
      (                  # Followed by one of these:
      [^/]|          #  * Any one character (except slash, obviously)
      [^./][^/]|     #  * Two characters where
      [^/][^./]|     #    they are not ".."
      [^/][^/][^/]+  #  * Three or more characters
      )                  # Followed by:
      /\.\./             # "/", followed by "../"
    }{$1}x
  ) {}

  return $path;
}

sub getMethods {
  return {

    # Assign value to a variable
    assign => sub {
      my $self = shift;
      my $name = shift // die;
      my $value = shift // die;
      my $var = Text::Xslate->current_vars;
      $var->{$name} = $value;
      return '';
    },

    # get relative path of top-layer file
    getPathTop => sub {
      my $self = shift;
      my $var = Text::Xslate->current_vars;
      if (exists $var->{'_pathname'}) { # user have specified filename
        if (substr($var->{'_pathname'},0,1) eq '/') {
          return $var->{'_pathname'};
        } else {
          return '/' . $var->{'_pathname'};
        }
      } else {
        return '/<string>';
      }
    },

    # get relative path of current file (where this statement lives)
    getPath => sub {
      my $self = shift;
      my $pathFile = Text::Xslate->current_file;
      if ($pathFile eq '<string>') { # Case 1: top-level file
        return $self->{'tx'}{'function'}{'getPathTop'}->()
      } else { # Case 2: non-top-level file (included file etc.)
        my %hTmpl = %{$self->{'tx'}{'template'}};
        my $match = first {defined $hTmpl{$_}[2] && $hTmpl{$_}[2] eq $pathFile} keys %hTmpl;
        $match //= '/<string>'; # if not defined

        if (substr($match,0,1) ne '/') { # make sure it starts with a slash
          $match = '/' . $match;
        }
        return $match;
      }
    },

    # get relative dir of top-layer file
    getDirTop => sub {
      my $self = shift;
      return dirname($self->{'tx'}{'function'}{'getPathTop'}->());
    },

    # get relative dir of current file
    getDir => sub {
      my $self = shift;
      return dirname($self->{'tx'}{'function'}{'getPath'}->());
    },

    canonicalizePath => sub {
      my $self = shift;
      my $target = shift // die;
      if (!($target =~ qr{^/})) {
        $target = eliminateDoubleDot($self->{'tx'}{'function'}{'getDir'}() . '/' . $target);
      }
      return $target;
    },

    # Get canonical name of a target path, and add to dependency
    addDependency => sub {
      my $self = shift;
      my $target = shift // die;
      $target = $self->{'tx'}{'function'}{'canonicalizePath'}($target);

      my $var = Text::Xslate->current_vars;
      $var->{'_deps'} //= {}; # default value
      my $fullpath = File::Spec->canonpath($self->{'tx'}->find_file($target)->{'fullpath'});
      $var->{'_deps'}{$target} = $fullpath;

      return $target; # also return canonicalized path
    },

    # Include other template
    inc => sub {
      my $self = shift;
      my $target = shift // die;
      my $isOptional = shift // 0;
      my $doSkip = 0;
      try {
        $target = $self->{'tx'}{'function'}{'addDependency'}($target);
      } catch {
        die "$_" if (!$isOptional);
        $doSkip = 1;
      };
      return '' if ($doSkip == 1);

      # Do the render work
      my $var = Text::Xslate->current_vars;
      my $rslt = $self->{'tx'}->render($target, $var);
      return $rslt;
    },

    # Include other raw file
    incRaw => sub {
      my $self = shift;
      my $target = shift // die;
      my $isOptional = shift // 0;
      my $doSkip = 0;
      try {
        $target = $self->{'tx'}{'function'}{'addDependency'}($target);
      } catch {
        die "$_" if (!$isOptional);
        $doSkip = 1;
      };
      return '' if ($doSkip == 1);

      # Do the file work
      my $var = Text::Xslate->current_vars;
      my $rslt = read_file($var->{'_deps'}{$target});
      return $rslt;
    },

    # print contents of variables
    debug => sub {
      my $self = shift;
      my $forced = shift // 0;
      my $var = Text::Xslate->current_vars;
      use Data::Dumper; # this is actually compile-time
      if ($forced == 1 || (exists $ENV{'TRIS_BUILD_DEBUG'} && $ENV{'TRIS_BUILD_DEBUG'} == 1)) {
        $Data::Dumper::Terse = 1;
        $Data::Dumper::Indent = 1;
        $Data::Dumper::Quotekeys = 0;
        return "\n# (DEBUG) VARAIBLES: "
        . (Dumper($var) =~ s/[\n\r]+/$&# /gr) . "\n";
      } else {
        return "\n";
      }
    }

  };
}

sub new { return bless {}, $_[0] };

1;