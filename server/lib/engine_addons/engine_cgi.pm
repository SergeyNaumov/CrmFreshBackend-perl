use Plack::Request;
use strict;
sub set_status{$_[0]->{APP}->{STATUS}=$_[1]; return $_[0]}

# методы plack

sub param{
  my $s=shift;
  if(!exists($s->{req}) || !$s->{req}){
    $s->{req}=Plack::Request->new($s->{vars}->{env});
  }
  my $p=shift;
  my $v=$s->{req}->param($p);
  Encode::_utf8_on($v);
  return $v;
}


sub param_mas{
  my $s=shift;
  if(!exists($s->{req}) || !$s->{req}){
    $s->{req}=Plack::Request->new($s->{vars}->{env});
  }
  my $p=shift;
  my @v=$s->{req}->param($p);
  my $i=0;
  foreach my $v (@v){
    Encode::_utf8_on($v);
    $p->[$i]=$v;
    $i++;
  }
  return @v;
}
sub upload_filename{
  my $s=shift;
  unless($s->{req}){
    $s->{req}=Plack::Request->new($s->{vars}->{env});
  }
  my $p=shift; my $multi=shift;
  if($multi){
    my $list=[];
    foreach my $u ($s->{req}->upload($p)) {
      
      my $filename=$u->{filename};
      my $tempname=$u->{tempname};
      Encode::_utf8_on($filename);
      Encode::_utf8_on($tempname);
      push @{$list},{filename=>$filename,tempname=>$tempname};;
    }
    return $list
  }

  my $u=$s->{req}->upload($p);
  my $filename=$u->{filename};
  my $tempname=$u->{tempname};
  Encode::_utf8_on($filename);
  Encode::_utf8_on($tempname);
  return {filename=>$filename,tempname=>$tempname};
}
# сохранение файла
sub save_upload{
  my ($s,%args)=@_;
  unless($s->{req}){
    $s->{req}=Plack::Request->new($s->{vars}->{env});
  }
  #my $u=$s->{req}->upload($args{var});
  $s->print_error("argument var not found!") unless($args{var});
  $s->print_error("argument to not found!") unless($args{to});
  my $list=[];
  if($args{multi}){
    $list=$s->upload_filename($args{var},1);
  }
  else{
    
    $list=[$s->upload_filename($args{var})]
  }
  my $result=[]; 
  #print Dumper({list=>$list});
  foreach my $f (@{$list}){
      my $newname=$args{newname};
      next if(!$f->{filename} || !$f->{tempname});
      my $ext;
      #print Dumper({f=>$f});
      if($f->{filename}=~m/([^\.]+)$/){
        $ext=$1;
      }

      if($newname){
        #$args{newname}.='.'.$ext;
      }
      else{
        if($args{original}){
          $newname =  $f->{filename};

        }
        else{
          $newname=time().'_'.substr(rand(),3,4).'.'.$ext;
          
           
        }
      }

      my $orig_name_without_ext;
      if($newname=~m/^([^\.]+)\./){
        $orig_name_without_ext=$1;
      }
      my $full_path="$args{to}/$newname";
      if($newname){
        
        move ($f->{tempname},$full_path)  || die("move $f->{tempname} to $full_path: $!");
        chmod 0644, $full_path;
      }

      my $return_resize_info=[];
      if(exists($args{resize})){
        foreach my $r (@{$args{resize}}){

          my $to_path; my $resize_name;
          #print Dumper($r);
          if($r->{file}){
            $resize_name=$r->{file};
            #$to_path=qq{$args{to}/$r->{file}};
            $resize_name=~s/\[\%ext\%\]/$ext/;
            $resize_name=~s/\[\%filename_without_ext\%\]/$orig_name_without_ext/;
            $to_path=qq{$args{to}/$resize_name};
          }
          else{ # если сохраняем в оригинальный файл
            $to_path=$full_path; $resize_name=$args{newname};
          }
          push @{$return_resize_info},{fullname=>$to_path, name=>$resize_name};
          #print "./app/resize.pl $full_path  --output_file=$to_path --size='$r->{size}'\n";
          #print
          `./app/resize.pl $full_path  --output_file=$to_path --size='$r->{size}'`

        }

      }
      push @{$result},
      {
          name=>$newname,
          orig_name=>$f->{filename},
          fullname=>qq{$args{to}/$newname},
          resize=>$return_resize_info
      }
  }
  
  return $args{multi}?$result:$result->[0];

}

sub get_cookie{
  my $self=shift; my $get_name=shift;
  foreach my $para ((split /;/,$self->{vars}->{env}->{HTTP_COOKIE})){
    $para=~s/^\s+//;
    my ($name,$value)=split /=/,$para;
    return $value if($name eq $get_name);
  }
  return undef;
}

sub set_cookie{ #   Set-Cookie: NAME=VALUE; expires=DATE; path=PATH; domain=DOMAIN_NAME; secure
  my $self=shift;
  my %opt=@_;
  die 'not set cookie name: '.$opt{name} unless($opt{name});# die 'not set cookie value' unless($opt->{value});
  my $domain=$opt{domain}?$opt{domain}:$self->{vars}->{env}->{HTTP_HOST};
  $domain=~s/:\d+$//;
  push @{$self->{APP}->{HEADERS}},'Set-Cookie';
  push @{$self->{APP}->{HEADERS}}, qq{$opt{name}=$opt{value}; domain=.$domain; path=/};
  return $self;
}

sub request_content{
  my $s=shift; my %arg=@_;
  unless($s->{req}){
    $s->{req}=Plack::Request->new($s->{vars}->{env});
  }
  my $R=$s->{req}->content;
  if(!$R  ) {
    $R={}
  }
  else{
    Encode::_utf8_on($R);
    if($arg{from_json}){
      if($R){
        $R=$s->from_json($R);
      }
    }
  }
  return $R;
}


return 1;
