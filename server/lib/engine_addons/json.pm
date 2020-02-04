use JSON qw();
use utf8;
use strict;
use Data::Dumper;
sub to_json{
  my $s=shift;
  my $data=shift;
  return undef unless($data);
  
  my $json_text = JSON->new->encode($data);
  return $json_text;
}

sub from_json{
  my $s=shift;
  my $data=shift;
  return  JSON->new->decode($data);
}

sub print_json{
    my $s=shift; my $data=shift;
    $s->print($s->to_json($data));
    return $s;
}



sub clean_json{ # создаёт "чистый" json (без кодовых вставок)
  my $s=shift; 
  my $data=shift;
  if(ref($data) eq 'ARRAY'){
      my $i=0;
      foreach my $d (@{$data}){
          $data->[$i]=$s->clean_json($data->[$i]);
          $i++;
      }
  }
  elsif(ref($data) eq 'HASH'){
      foreach my $k (keys %{$data}){
        $data->{$k}=$s->clean_json($data->{$k});
        delete $data->{$k} if(!defined($data->{$k}));
      }
  }
  elsif(ref($data) eq 'CODE'){
      $data='';
  }
  return $data
}

return 1;
