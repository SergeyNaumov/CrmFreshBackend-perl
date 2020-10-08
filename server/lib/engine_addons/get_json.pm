use strict;
use utf8;
use HTTP::Request::Common;
use LWP::UserAgent;
sub get_json{
  my $s=shift;
  my %arg=@_;
  $arg{method}=uc($arg{method});
  $arg{method}='GET' unless($arg{method});

  my $req = HTTP::Request->new($arg{method}, $arg{url});


    if($arg{json}){
      if(ref($arg{json})=~m{^(ARRAY|HASH)}){

        $arg{json}=$s->to_json($arg{json});

        Encode::_utf8_off($arg{json});

      }

      $req->content( $arg{json} );
    }
    
    
    if(exists($arg{headers})){
      
      $req->header( %{$arg{headers}} );
    }
    else{
      $req->header( 'Content-Type' => 'application/json; charset=utf-8' );
    }
    
    my $lwp = LWP::UserAgent->new;
    my $res = $lwp->request( $req );
    
    if ($res->is_success) {
      my $res=$res->content;

      Encode::_utf8_on($res);
      return {success=>1,res=>$res};
    }

    return undef;
}
return 1;