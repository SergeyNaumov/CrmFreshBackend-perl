package extend::KLADR;
use strict;
use utf8;
use HTTP::Request::Common;
use LWP::UserAgent;
use URI::Escape;
use LWP::UserAgent;
use HTTP::Request;
use Encode;



sub go{
  my $s=shift;
  my $R=$s->request_content(from_json=>1);
  my @errors=(); my $list=[];


  if($R->{action} eq 'onestring' && $R->{query}){
    Encode::_utf8_off($R->{query});
    my $request_str=get_request_str({
      query=>uri_escape($R->{query}),
      oneString=>1,
      limit=>10
    });
    my $ua = LWP::UserAgent->new;
    my $url='https://kladr-api.ru/api.php?'.$request_str;
    my $req = HTTP::Request->new(GET=>$url);
    $req->content_type('application/javascript; charset=utf-8');
    $req->content($request_str);
    my $res = $ua->request($req);
    if(my $content=$res->content){
        if(my $data=$s->from_json($content)){
          foreach my $d (@{$data->{result}}){
            push @{$list},{header=>$d->{fullName}};
          }
        }
    }

  }
  
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