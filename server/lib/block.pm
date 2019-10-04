#! /usr/bin/perl
package block;

use strict;
use utf8;
use Digest::SHA qw(sha256_hex);
#use lib '../lib';
#use freshdb;
#use coresubs qw(pre);
use  Try::Tiny;
use JSON qw(from_json to_json);

use Data::Dumper;
$Data::Dumper::Useqq = 1;

{ no warnings 'redefine';
    sub Data::Dumper::qquote {
        my $s = shift;
        return "'$s'";
    }
}

sub new{
  my ($class,%args) = @_;

  my $self=bless {}, $class;
  $self->{SYSTEM_BALANCE}=10500000;
  $self->{db}=$args{db};
  return $self;
}



sub check_chain{
   my $self=shift;
   my %arg=@_;
   $arg{depth}=4 unless($arg{depth}=~m{^\d+$});
   my @list=reverse( @{$self->{db}->query(query=>'select * from transaction order by id desc limit ?',values=>[$arg{depth}])});
   my $prev=shift(@list);
   my $out='';
   foreach my $l (@list){
         
      
         my $hash_prev=$self->get_hash_block($prev);
         #$out.="$l->{hash_prev} hash_prev: $hash_prev<br>\n";
         #print "$l->{hash_prev} hash_prev: $hash_prev\n";
         if($l->{hash_prev} ne $hash_prev){
            return qq{хеш предыдущего блока не прошёл проверку (id: $l->{id}, $l->{hash_prev} != $hash_prev)\n}
         }
         
      #}
      #exit;
      $prev=$l;
   }

   return 1;
   #pre($first);
}
sub go_transact{
   my $self=shift;
   my %arg=@_;
   #print "$arg{bill_from}\n"; exit;
   $self->{db}->{connect}->{AutoCommit}=0;
   my $result={};
   my @err=();
   if(!$self->check_sys_balance()){
      push @err,'Ошибка системы! Баланс системы расходится';
   }
   if(!$self->exists_bill(bill=>"$arg{bill_from}")){
      push @err,'Счёт-источник не существует';
   }
   if(!$self->exists_bill(bill=>"$arg{bill_to}")){
      push @err,'Счёт-приёмник не существует';
   }

   if(!scalar(@err) && ($arg{bill_to} eq $arg{bill_from})){
      push @err,'Счёт-источник и счёт приёмник -- один и тот же счёт';
   }
   if(!$arg{sum}=~m{^\d+(\.\d{1,2})?$}){
      push @err,'Сумма не указана или указана не верно';
   }
   my $err_hash=$self->check_chain(depth=>4);
   if($err_hash ne '1'){
      push @err,$err_hash;
   }

   my $source_balance=$self->bill_balance(bill=>"$arg{bill_from}");
   if($source_balance<$arg{sum}){
      push @err,'На счёте-источнике отсутствует необходимая сумма';
   }

   
   
   if(!scalar(@err)){ # всё ок, выполняем операцию
      my $prev_block=$self->get_prev_block(%arg);
      my $balace_source=$self->{db}->query(query=>'select balance from account where bill_num=?',values=>["$arg{bill_from}"],onevalue=>1);
      #print "s: $balace_source\n"; exit;
      my $balace_recepient=$self->{db}->query(query=>'select balance from account where bill_num=?',values=>["$arg{bill_to}"],onevalue=>1);
      my $data={
         bill_from=>$arg{bill_from},
         bill_to=>$arg{bill_to},
         amount=>$arg{sum},
         balance_sender_before=>$balace_source,
         balance_recipient_before=>$balace_recepient,
         balance_before=>$self->{db}->query(query=>'select sum(balance) from account',onevalue=>1),
         registered=>'func::now()',
      };

      if($prev_block){
         $data->{hash_prev}=$self->get_hash_block($prev_block); 
      }


      $result->{block_id}=$self->{db}->save(
         table=>'transaction',
         data=>$data,
      );
      $result->{balance_source}=($balace_source-$arg{sum});
      $self->{db}->save(
         table=>'account',
         data=>{balance=>($balace_source-$arg{sum})},
         where=>qq{bill_num="$arg{bill_from}"},
         #debug=>1,
         update=>1
      );
      $result->{balance_recipient}=($balace_recepient+$arg{sum});
      $self->{db}->save(
         table=>'account',
         data=>{balance=>$result->{balance_recipient}},
         where=>qq{bill_num="$arg{bill_to}"},
         #debug=>1,
         update=>1
      );
      #exit;
   }
   $self->{db}->{connect}->commit ();
   $self->{db}->{connect}->{AutoCommit}=1;
   $result->{errors}=\@err;
   
   return $result;
}

sub exists_bill{ # проверка наличия счёта
   my $self=shift;
   my %arg=@_;
   return 
      $self->{db}->query(
         query=>'SELECT count(*) from account where bill_num=?',
         values=>[$arg{bill}],
         onevalue=>1,
         #debug=>1
      );
}

sub get_prev_block{
   my $self=shift;
   #my %arg=@_;
   return 
      $self->{db}->query(
         query=>'SELECT * from transaction order by id desc limit 1',
         onerow=>1
      );
}

sub check_sys_balance{
   my $self=shift;
   my %arg=@_;
   my $sum=$self->{db}->query(
      query=>'select sum(balance) from account',onevalue=>1
   )+0;
   return ($sum==$self->{SYSTEM_BALANCE});
}
sub bill_balance{
   my $self=shift;
   my %arg=@_;
   return 
      $self->{db}->query(query=>'SELECT balance from account where bill_num=?',values=>[$arg{bill}],onevalue=>1);
}

sub gen_token{
   my $self=shift;
   my $s=shift;
   my $len=shift;
   my $symbols=shift;
   $len=100 unless($len);
   $symbols='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' unless($symbols);
   my $key='';
   foreach my $k (1..$len){
      $key.=substr($symbols,int(rand(length($symbols))),1)
   }
   return $key
}


sub get_hash_block{
   my $self=shift;
   my $block=shift;
   return
      sha256_hex($block->{id}.'|'.$block->{bill_from}.'|'.$block->{bill_to}.'|'.$block->{sum});
}
return 1;