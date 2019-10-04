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

return 1;
