#!/usr/bin/perl
use lib '.';
use lib './lib';
use utf8;
use Engine;
use Controller;
use strict;
package Work;

#my $connects=connects::get();

our $engine; # в этой переменной указатель на сущность фреймворка
our @zombie=(); # будем убивать зомби-процессы

my $app=sub{
  my $env=shift;
  my $s=$engine=Engine->new(env=>$env);
  $s->{to_stream}=
  $s->{vars}->{TEMPLATE_FOLDER}='./views';
  $s->{controller}=Controller->new unless($s->{controller});

  $s->process();
  
  $s->{form}=undef;
  #print Dumper($env);
  if($s->{stream_out}){
    
    return sub{
      my $respond=shift;
      #print Dumper({respond=>$respond,headers=>$s->{APP}->{HEADERS}});
      my $writer = $respond->([200, $s->{APP}->{HEADERS}]);
      if($s->{stream_file}){

        open (my $fh,'<',$s->{stream_file}) or print "work.psgi (stream_file) error read $s->{stream_file}\n$!\n";
        binmode $fh;
        while(my $row = <$fh>){
          $writer->write($row)
          
        }
        $writer->close;
        if($s->{stream_file_need_unlink}){
          unlink($s->{stream_file})
        }
        
        delete($s->{stream_file});
      }
      delete($s->{stream_out});
      
    }

  }
  else{
    return $s->out();
  }


  
};


