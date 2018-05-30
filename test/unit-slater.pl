#!/usr/bin/env perl
# Unit test for slater module
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
use lib "$Bin/../local/lib/perl5";
use lib "$Bin/../lib";
use Test2::V0;
use Test2::Tools::Spec ':ALL';
spec_defaults case => (iso => 1, async => 1);

use UnladenTriskelion::Slater;
sub Slater { UnladenTriskelion::Slater:: }

my $pathTestData = "$Bin/data-unit-slater";

describe 'Slater creation function' => sub {

  it 'should return a simple xslate renderer if passed nothing' => sub {
    my $self = shift;
    my $rslt = Slater->new();
    is(ref $rslt, 'UnladenTriskelion::Slater');
    is($rslt->render('[% 3 %]'), '3');
  };

  it 'should accept option variations' => sub {
    my $self = shift;
    my $rslt = Slater->new({tag_end => ':>'});
    is($rslt->render('[% 3 :>'), '3');
  };

  it 'should properly process path' => sub {
    my $self = shift;
    my $rslt = Slater->new({path => [$pathTestData]});
    is($rslt->render('!%: include "tmpl"'), 'INSIDE');
  };

  it 'should properly process multiple paths' => sub {
    my $self = shift;
    # Latter path have precedence, so should get the "tmpl" file from second path
    my $rslt = Slater->new({path => [$pathTestData, "$pathTestData/data2"]});
    is($rslt->render('!%: include "tmpl"'), 'INSIDE2');
  };

  it 'should die if passed non-module as module' => sub {
    my $self = shift;
    ok(dies { Slater->new({tag_end => ':>'}, ["A STRING"]) });
  };

  package EmptyModule {
    sub new { return bless {}, $_[0] }; 1;
  };

  it 'should be ok if passed an empty module' => sub {
    my $self = shift;
    my $rslt = Slater->new({tag_end => ':>'}, [EmptyModule->new()]);
    is($rslt->render('[% 3 :>'), '3');
  };

  it 'should be same calling render and doTemplate without pre/post' => sub {
    my $self = shift;
    my $rslt = Slater->new();
    my $input = '[% 3 %]';
    is($rslt->render($input), $rslt->doTemplate($input));
  };

  it 'should crash on doTemplate failure' => sub {
    my $self = shift;
    my $rslt = Slater->new();
    my $input = '[% include "should_not_exist" %]';
    ok(dies { $rslt->doTemplate($input); });
  };

  it 'should crash on render failure' => sub {
    my $self = shift;
    my $rslt = Slater->new();
    my $input = '[% include "should_not_exist" %]';
    ok(dies { $rslt->render($input); });
  };

  it 'should add given function' => sub {
    my $self = shift;
    my $rslt = Slater->new({function => {func1 => sub {return 'FUNC1'}}});
    is($rslt->render('!%: func1()'), 'FUNC1');
  };

  it 'should add given method' => sub {
    my $self = shift;
    my $rslt = Slater->new({method => {method1 => sub {return ref $_[0]}}});
    is($rslt->render('!%: method1()'), 'UnladenTriskelion::Slater');
  };

}; # end test fix Slater creation function

describe 'Slater modules' => sub {

  package ModuleOption1 {
    # mutateOptions should be given 1 parameter: the config hash for the Xslate object
    sub mutateOptions {
      my $self = shift;
      my $args = shift // die;
      $args->{'tag_start'} = '{?';
      $args->{'tag_end'} = '?}';
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  package ModuleOption2 {
    sub mutateOptions {
      my $self = shift;
      my $args = shift // die;
      $args->{'tag_start'} = '<?';
      $args->{'tag_end'} = '?>';
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  it 'should read option in plugin' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModuleOption1->new()]);
    is($rslt->render('{? 3 ?}'), '3');
  };

  it 'should have given options override plugin option' => sub {
    my $self = shift;
    my $rslt = Slater->new({tag_end => ':>'}, [ModuleOption1->new()]);
    is($rslt->render('{? 3 :>'), '3');
  };

  it 'should read option in plugins in order' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModuleOption1->new(), ModuleOption2->new()]);
    is($rslt->render('<? 3 ?>'), '3');
  };

  it 'should read option in plugins in order 2' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModuleOption2->new(), ModuleOption1->new()]);
    is($rslt->render('{? 3 ?}'), '3');
  };

  package ModulePath {
    sub mutateOptions {
      my $self = shift;
      my $args = shift // die;
      push @{$args->{'path'}}, '/PATH1';
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  it 'should get path from module' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModulePath->new()]);
    is($rslt->{'tx'}{'path'}, array { item '/PATH1'; end(); });
  };

  it 'should get path from module, but overriden by given options' => sub {
    my $self = shift;
    my $rslt = Slater->new({path => ['/PATH2']}, [ModulePath->new()]);
    is($rslt->{'tx'}{'path'}, array { item '/PATH2'; item '/PATH1'; end(); });
  };

  package ModuleFunc1 {
    # getFunctions should give a (ref of) hash of functions to be used in templates
    sub getFunctions {
      my $self = shift;
      return {
        func1 => sub { return 'FUNC1-1'; },
        func2 => sub { return 'FUNC1-2'; }
      };
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  package ModuleFunc2 {
    sub getFunctions {
      my $self = shift;
      return {
        func1 => sub { return 'FUNC2-1'; },
        func2 => sub { return 'FUNC2-2'; }
      };
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  it 'should read function in plugin' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModuleFunc1->new()]);
    is($rslt->render('[% func1() %][% func2() %]'), 'FUNC1-1FUNC1-2');
  };

  it 'should have given functions override plugin functions' => sub {
    my $self = shift;
    my $rslt = Slater->new({function => {func1 => sub {return 'OVER';}}}, [ModuleFunc1->new()]);
    is($rslt->render('[% func1() %][% func2() %]'), 'OVERFUNC1-2');
  };

  it 'should read functions in plugins in order' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModuleFunc1->new(), ModuleFunc2->new()]);
    is($rslt->render('[% func1() %][% func2() %]'), 'FUNC2-1FUNC2-2');
  };

  it 'should read functions in plugins in order 2' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModuleFunc2->new(), ModuleFunc1->new()]);
    is($rslt->render('[% func1() %][% func2() %]'), 'FUNC1-1FUNC1-2');
  };

  package ModuleMethod1 {
    sub getMethods {
      my $self = shift;
      return {
        method1 => sub { return "11" . ref $_[0]; },
        method2 => sub { return "12" . ref $_[0]; },
      };
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  package ModuleMethod2 {
    sub getMethods {
      my $self = shift;
      return {
        method1 => sub { return "21" . ref $_[0]; },
        method2 => sub { return "22" . ref $_[0]; },
      };
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  it 'should read method in plugin' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModuleMethod1->new()]);
    is($rslt->render('[% method1() %][% method2() %]'), '11UnladenTriskelion::Slater12UnladenTriskelion::Slater');
  };

  it 'should have given methods override plugin methods' => sub {
    my $self = shift;
    my $rslt = Slater->new({method => {method1 => sub {return 'OVER';}}}, [ModuleMethod1->new()]);
    is($rslt->render('[% method1() %][% method2() %]'), 'OVER12UnladenTriskelion::Slater');
  };

  it 'should read methods in plugins in order' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModuleMethod1->new(), ModuleMethod2->new()]);
    is($rslt->render('[% method1() %][% method2() %]'), '21UnladenTriskelion::Slater22UnladenTriskelion::Slater');
  };

  it 'should read methods in plugins in order 2' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModuleMethod2->new(), ModuleMethod1->new()]);
    is($rslt->render('[% method1() %][% method2() %]'), '11UnladenTriskelion::Slater12UnladenTriskelion::Slater');
  };

  package ModulePre1 {
    # preProcess will, well, preprocess the template text before rendering
    sub preProcess {
      my $self = shift;
      my $text = shift // die;
      return $text . "+[% 1 %]";
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  package ModulePre2 {
    sub preProcess {
      my $self = shift;
      my $text = shift // die;
      return $text . "+[% 2 %]";
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  it 'should read pre in plugin' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModulePre1->new()]);
    is($rslt->preProcess('ABC'), 'ABC+[% 1 %]');
    is($rslt->render('ABC'), 'ABC+1');
  };

  it 'should read pre in plugins in order' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModulePre1->new(), ModulePre2->new()]);
    is($rslt->preProcess('ABC'), 'ABC+[% 1 %]+[% 2 %]');
    is($rslt->render('ABC'), 'ABC+1+2');
  };

  it 'should read pre in plugins in order 2' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModulePre2->new(), ModulePre1->new()]);
    is($rslt->preProcess('ABC'), 'ABC+[% 2 %]+[% 1 %]');
    is($rslt->render('ABC'), 'ABC+2+1');
  };

  package ModulePreEach1 {
    # preProcess will, well, preprocess the template text before rendering
    sub preProcessEach {
      my $self = shift;
      my $text = shift // die;
      return "+[% 1 %]\n" . $text;
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  package ModulePreEach2 {
    sub preProcessEach {
      my $self = shift;
      my $text = shift // die;
      return "+[% 2 %]\n" . $text;
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  it 'should read pre-each in plugin' => sub {
    my $self = shift;
    my $rslt = Slater->new({path => [$pathTestData]}, [ModulePreEach1->new()]);
    is($rslt->render('!%: include "tmpl"'), "+1\n+1\nINSIDE");
  };

  it 'should read pre-each in plugins in order' => sub {
    my $self = shift;
    my $rslt = Slater->new({path => [$pathTestData]}, [ModulePreEach1->new(), ModulePreEach2->new()]);
    is($rslt->render('!%: include "tmpl"'), "+2\n+1\n+2\n+1\nINSIDE");
  };

  it 'should read pre-each in plugins in order 2' => sub {
    my $self = shift;
    my $rslt = Slater->new({path => [$pathTestData]}, [ModulePreEach2->new(), ModulePreEach1->new()]);
    is($rslt->render('!%: include "tmpl"'), "+1\n+2\n+1\n+2\nINSIDE");
  };

  package ModulePost1 {
    # postProcess will, well, postprocess the template text before rendering
    sub postProcess {
      my $self = shift;
      my $text = shift // die;
      return $text . "+[% 1 %]";
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  package ModulePost2 {
    sub postProcess {
      my $self = shift;
      my $text = shift // die;
      return $text . "+[% 2 %]";
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  it 'should read post in plugin' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModulePost1->new()]);
    is($rslt->postProcess('ABC'), 'ABC+[% 1 %]');
    is($rslt->render('ABC'), 'ABC+[% 1 %]');
  };

  it 'should read post in plugins in order' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModulePost1->new(), ModulePost2->new()]);
    is($rslt->postProcess('ABC'), 'ABC+[% 1 %]+[% 2 %]');
    is($rslt->render('ABC'), 'ABC+[% 1 %]+[% 2 %]');
  };

  it 'should read post in plugins in order 2' => sub {
    my $self = shift;
    my $rslt = Slater->new({}, [ModulePost2->new(), ModulePost1->new()]);
    is($rslt->postProcess('ABC'), 'ABC+[% 2 %]+[% 1 %]');
    is($rslt->render('ABC'), 'ABC+[% 2 %]+[% 1 %]');
  };

  package ModuleDependency {
    sub new { return bless {}, $_[0] }; 1;
  };

  package ModuleDependent {
    sub getDeps {
      return ['ModuleDependency'];
    }
    sub new { return bless {}, $_[0] }; 1;
  };

  it 'have dependency written to the dependent module' => sub {
    my $self = shift;
    my $moduleDependency = ModuleDependency->new();
    my $moduleDependent = ModuleDependent->new();
    my $rslt = Slater->new({}, [$moduleDependency, $moduleDependent]);
    is($rslt->{'mapModules'}{'ModuleDependent'}, $moduleDependent);
    is($rslt->{'mapModules'}{'ModuleDependent'}{'deps'}{'ModuleDependency'}, $moduleDependency);
  };


}; # end test fix Slater modules

done_testing;
