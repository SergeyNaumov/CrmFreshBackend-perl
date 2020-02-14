package extend::KLADR;
use strict;
use utf8;
use HTTP::Request::Common;
use LWP::UserAgent;
use URI::Escape;
use LWP::UserAgent;
use HTTP::Request;
use Encode;
use Data::Dumper;
use CRM;

sub go{
  my $s=shift;
  my $R=$s->request_content(from_json=>1);
  my @errors=(); my $list;

  #print Dumper($R);
  my $config=$R->{config};
  my $name=$R->{name};
  if($R->{action} eq 'onestring' && $R->{query}){
    Encode::_utf8_off($R->{query});
    my $request_str=get_request_str({
      query=>uri_escape($R->{query}),
      oneString=>1,
      #regionId=>'[,4000000000000]', # москва
      #regionId=>'', # калужская область
      #regionId=>qq{7700000000000,4000000000000},
      withParent=>'false',
      limit=>10
    });
    #$request_str.="&regionId=7700000000000&regionId=4000000000000";
    #$request_str.=qq{&regionId=["7700000000000","4000000000000"]};
    my $ua = LWP::UserAgent->new;
    my $url='https://kladr-api.ru/api.php?'.$request_str;
    my $req = HTTP::Request->new(GET=>$url);
    $req->content_type('application/javascript; charset=utf-8');
    $req->content($request_str);
    my $res = $ua->request($req);
    if(my $content=$res->content){
        #print Dumper($content);
        if(my $data=$s->from_json($content)){
          my $function_process=0;
          if($config && $name){
            my $form=CRM::read_conf(config=>$config,script=>'/extend/KLADR');
            my $field=$form->{fields_hash}->{$name};
            if(exists $field->{kladr}->{after_search}){
              $function_process=1;
              $list=&{$field->{kladr}->{after_search}}($data->{result});
            }
          }

=cut
{
  'id' => '77000005000006000',
  'ifnsfl' => 7751,
  'contentType' => 'street',
  'cadnum' => '',
  'oktmo' => 45931000,
  'zip' => undef,
  'typeShort' => 'мкр',
  'parentGuid' => '7dde11f6-f6ab-4a05-8052-78e0cab8fc59',
  'fullName' => 'Москва Город, Город Троицк, Микрорайон В',
  'type' => 'Микрорайон',
  'parents' => [
                 {
                   'cadnum' => '',
                   'oktmo' => 45000000,
                   'zip' => 123182,
                   'typeShort' => 'г',
                   'ifnsfl' => 7700,
                   'id' => '7700000000000',
                   'contentType' => 'region',
                   'type' => 'Город',
                   'name' => 'Москва',
                   'okato' => '45000000000',
                   'ifnsul' => 7700,
                   'guid' => '0c5b2444-70a0-4932-980c-b4dc0d3f02b5',
                   'parentGuid' => ''
                 },
                 {
                   'guid' => '7dde11f6-f6ab-4a05-8052-78e0cab8fc59',
                   'ifnsul' => 7751,
                   'okato' => '45298578000',
                   'name' => 'Троицк',
                   'type' => 'Город',
                   'parentGuid' => '0c5b2444-70a0-4932-980c-b4dc0d3f02b5',
                   'typeShort' => 'г',
                   'zip' => 108841,
                   'cadnum' => '',
                   'oktmo' => 45931000,
                   'contentType' => 'city',
                   'id' => '7700000500000',
                   'ifnsfl' => 7751
                 }
               ],
  'name' => 'В',
  'okato' => undef,
  'ifnsul' => 7751,
  'guid' => 'cb0d107a-57c7-49d3-9127-753618279d0c'
}

=cut
          unless($function_process){
            foreach my $d (@{$data->{result}}){
              #print Dumper($d);
              push @{$list},{header=>$d->{fullName}};
            }
          }

        }
    }

  }

  $list=[] unless($list);
  
  $s->print_json({
    success=>scalar(@errors)?0:1,
    list=>$list
  })->end;
}

sub get_request_str{
    my $hash=shift;
    my @str=();
    foreach my $k ((keys %{$hash})){

        push @str,"$k=".$hash->{$k};
    }
    return join("&",@str);
}
return 1;