package extend::DADATA;
use strict;
use utf8;
#use HTTP::Request::Common;
#use LWP::UserAgent;
use CRM;
use Data::Dumper;

sub go{
  my $s=shift;
  my $R=$s->request_content(from_json=>1);
  my @errors=(); my $list;

  #print Dumper($R);
  my $config=$R->{config};
  my $name=$R->{name};
  if($R->{action} eq 'onestring' && $R->{query}){
    #Encode::_utf8_on($R->{query});
    my $form=CRM::read_conf(config=>$config,script=>'/extend/DADATA');
    my $field=$form->{fields_hash}->{$name};


    my $response=$s->get_json(
      method=>'POST',
      url=>'https://cleaner.dadata.ru/api/v1/clean/address',
      json=>[$R->{query}],
      headers=>{
        'Content-Type'=>'application/json',
        'Authorization' => "TOKEN $field->{dadata}->{API_KEY}",
        'X-Secret' => $field->{dadata}->{SECRET_KEY}
      }
    );
    if($response->{success}){
      my $res=$s->from_json($response->{res});
      foreach my $r (@{$res}){
        push @{$list},{header=>$r->{result}};
      }
      
    }
    else{
      push @errors,'ошибка выполнения запроса к https://cleaner.dadata.ru/api/v1/clean/address (lib::extend::DADATA)'
    }
    

  }

  $list=[] unless($list);
  
  $s->print_json({
     success=>scalar(@errors)?0:1,
     list=>$list
  })->end;
}

# sub get_json{
#   my $s=shift;
#   my %arg=@_;
#   $arg{method}=uc($arg{method});
#   $arg{method}='GET' unless($arg{method});

#   my $req = HTTP::Request->new($arg{method}, $arg{url});
    
#     #$req->header( 'Api-Key' => $API_KEY);


#     if($arg{json}){
#       if(ref($arg{json})=~m{^(ARRAY|HASH)}){
#         $arg{json}=to_json($arg{json});
#         Encode::_utf8_off($arg{json});

#       }

#       $req->content( $arg{json} );
#     }
#     print Dumper(\%arg);
#     exit;
#     if(1 || $arg{headers}){
#       print Dumper($arg{headers});
#       $req->header( @{$arg{headers}} );
#     }
#     else{
#       $req->header( 'Content-Type' => 'application/json; charset=utf-8' );
#     }
    
#     my $lwp = LWP::UserAgent->new;
#     my $res = $lwp->request( $req );
#     print Dumper({res=>$res});
#     if ($res->is_success) {
#       my $res=$res->content;
#       return {success=>1,res=>$res};
#     }

#     return undef;
# }
return 1;