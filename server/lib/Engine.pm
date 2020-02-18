package Engine;
#use strict;
use Encode;
use utf8;
use freshdb;
use config;
#require './lib/engine_addons/engine_functions.pm';
#exit;
opendir D,'./lib/engine_addons';
while(my $d=readdir D){
  next if($d!~/\.pm$/);
  require './lib/engine_addons/'.$d;
}
#exit;

#exit;
sub new{
  my($class,%args) = @_;
  my $s = $Work::engine;
  unless($s){
    $s=bless {}, $class;
  }

  # очищаем за предыдущий раз:
  $s->{req}=undef;
  $s->{vars}->{env}={};
  $s->{vars}={};
  $s->{APP}={};
  $s->{TMPL_VARS}={};
  $s->{layout}='';

  $s->{vars}->{env}=$args{env};
  $s->{vars}->{env}->{PATH_INFO}=$s->urldecode($s->{vars}->{env}->{PATH_INFO});
  Encode::_utf8_on($s->{vars}->{env}->{PATH_INFO});

  my $sth; my $list;
  unless($s->{config}){
      #$s->{config}=$s->from_json($s->read_file('config.json'));
      $s->{config}=config::get();
      foreach my $name (  keys(%{$s->{config}->{connects}})  ){
        
          my $db=$s->{config}->{connects}->{$name}; $db->{name}=$name;
          #print Dumper({config=>$s->{config}, name=>$name,db=>$db}); next;
          if($db->{connect_ref}){
            $s->{connects}->{$name}=$db->{connect_ref};
          }
          if(!$db->{connect}){
            $db->{connect}=$s->{connects}->{$name}=freshdb->new($db,$s);
          }
          else{
            $s->{connects}->{$name}->repair;
          }
      }
  }
  # константы системы
  get_const($s); 
  return $s;
}
sub get_const{
  my $s=shift;
  my $db=$s->{connects}->{crm_read};
  if(!$s->{const}){
    $s->{const}={__last_update=>0};
  }

  if(time()-$s->{const}->{__last_update}>50){ # константы обновляем раз в 50 секунд
    %{$s->{const}}=
    map {
      $_->{name}=>$_->{value}
    }
    @{
      $db->query(
      query=>q{
        SELECT 
          c.name,cv.value
        FROM
          const c LEFT JOIN const_values cv ON cv.const_id=c.id
      })
    };
    $s->{const}->{__last_update}=time();
  }
}
sub out{
  my $self=shift;
  $self->{APP}->{STATUS}=200 unless $self->{APP}->{STATUS};

  $self->{layout}=$self->{vars}->{TMPL_VARS}->{layout} if($self->{vars}->{TMPL_VARS}->{layout} && !$self->{layout});

  if($self->{page_type} || $self->{layout}){
    my $url=$self->{vars}->{env}->{PATH_INFO};
    $self->print_header({'content-type'=>'text/plain'}) if($url=~m/\.txt$/);
    $self->print_header({'content-type'=>'application/xml'}) if($url=~m/\.xml$/);
    $self->print_header({'content-type'=>'text/xml'}) if($url=~m/\.rss$/);
  }

  if(!$self->{vars}->{end}){
    #print Dumper($self);
    if(!$self->{vars}->{TMPL_VARS}->{page_type} && !$self->{layout}){
      $self->{APP}->{STATUS}=404;
      $self->print_error('page not found');
    }
    elsif($self->{layout}=~m/(.*\/)?([^\/]+)$/){
      $self->print_template({dir=>$1,template=>$2});
    }
    else{
      
      $self->print_template($self->{APP});
    }
  }
  my $opt;
  if(!length($self->{APP}->{DATA})){
    $self->print_header();
    $self->{APP}->{DATA}='';
  }

  # печатаем заголовок перед выводом
  $self->print_header($opt) unless($self->{vars}->{print_header}=1);

  $self->{APP}->{DATA}='' if(!length($self->{APP}->{DATA}));
  

  Encode::_utf8_off($self->{APP}->{DATA});
  foreach my $h (@{$self->{APP}->{HEADERS}}){
      Encode::_utf8_off($h);
  }

  return [
      $self->{APP}->{STATUS},
      $self->{APP}->{HEADERS},
      [$self->{APP}->{DATA}]
  ];
  
}
sub end{
  my $self=shift;
  $self->{vars}->{end}=1;
  return $self;
}



sub print_header{
  my $self=shift;
  my $opt=shift;
  return if($self->{vars}->{print_header});
  $opt->{'content-type'}='text/html' unless($opt->{'content-type'});
  $self->{vars}->{print_header}=1;
  $self->{APP}->{STATUS}=200 unless $self->{APP}->{STATUS};

  push @{$self->{APP}->{HEADERS}},'Content-type';
  my $header=$opt->{'content-type'};
  $header.='; charset=utf-8' if($opt->{'content-type'}=~/(text|xml|html)/);
  push @{$self->{APP}->{HEADERS}}, $header;
  return $self;
}
sub location{
  my $self=shift; my $location=shift;
  $self->{APP}->{STATUS}=301 unless $self->{APP}->{STATUS};
  if($location=~m/^\//){
    $location='//'.$self->{vars}->{env}->{HTTP_HOST}.$location;
  }
  $self->{vars}->{print_header}=1;
  push @{$self->{APP}->{HEADERS}}, ('Location',$location);
  #print Dumper($self->{APP}->{HEADERS});
  return $self;
}

sub urldecode {
    my $self = shift;
    my $s=shift;
    $s =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    $s =~ s/\+/ /g;
    Encode::_utf8_on($s);
    return $s;
}

sub process{ # check and run controllers
  my $self=shift;
  #$self->{vars}->{TMPL_VARS}={};
  return if($self->{vars}->{end});
  my $url = $self->{vars}->{env}->{PATH_INFO};
  my $page=1;


  # perpaging
  if($url=~m!/page=(\d+)$!){
    $page=$1;
    $url=~s!/page=\d+$!!;
    $self->{vars}->{env}->{PATH_INFO}=$url;
  }
  #print Dumper($self->{vars}->{env}->{PATH_INFO});
  
  $self->to_tmpl('page',$page);
  $self->to_tmpl('href',$url);
  foreach my $rule (@{$self->{controller}->{rules}}){
    
    #print "url: '$url'; rule: '$rule->{url}'; end: $self->{vars}->{end}; layout: $self->{layout}\n" if($url eq '/');
    if(
      $url=~m/$rule->{url}/
    ){
      #print "$rule->{url} ok\n";

      &{$rule->{code}}($self) if($rule->{code});
      $self->{vars}->{TMPL_VARS}->{page_type}=$self->{vars}->{page_type}=$rule->{page_type} if($rule->{page_type});
      if($rule->{layout} && !$self->{layout}){
        $self->{layout}=$rule->{layout};
      }

      #print "$url / $rule->{url} / layout: $self->{layout} /page_type: $self->{vars}->{TMPL_VARS}->{page_type}\n";
      if($self->{vars}->{end} || $self->{layout} || $self->{vars}->{TMPL_VARS}->{page_type}){
#        print "\tLAST\n";
        last;
      }
    }

  }
  $self->{layout}=$self->{controller}->{layout} unless($self->{layout});
  return $self;
}
# для stream-а

1;
