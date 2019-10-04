#!/usr/bin/perl
use lib './lib';
use utf8;
use Engine;
use Controller;
#use connects;
package Work;

#my $connects=connects::get();

our $engine; # в этой переменной указатель на сущность фреймворка
our @zombie=(); # будем убивать зомби-процессы
my $app=sub{
  my $env=shift;
  my $s=$engine=Engine->new(env=>$env);
  $s->{vars}->{TEMPLATE_FOLDER}='./views';
  $s->{controller}=Controller->new unless($s->{controller});
  $s->process();
  #$s->pre($s->{config})->end;
  return $s->out();
};


