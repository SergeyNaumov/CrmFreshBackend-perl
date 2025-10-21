use Plack::Request;
use strict;
use Image::Magick; 
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
  #print "upload_filename ; p: $p\n";
  if($multi){
    my $list=[];
    foreach my $u ($s->{req}->upload($p)) {
      #print('u: ',$u);
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
    #print "var: $args{var}\n";
    $list=$s->upload_filename('attach',1); # $args{var}
  }
  else{
    
    $list=[$s->upload_filename($args{var})]
  }
  my $result=[]; 
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

          my ($width,$height)=split /x/,$r->{size};
          my $filename=$r->{file};
          $filename=~s/<\%filename_without_ext\%>/$orig_name_without_ext/g;
          $filename=~s/<\%ext\%>/$ext/g;
          my $to_path=qq{$args{to}/$filename};
          push @{$return_resize_info},{fullname=>$to_path, name=>$args{filename}};

          resize(
              from=>"$full_path",
              to=>$to_path,
              width=>"$width",
              height=>"$height",
              grayscale=>$r->{grayscale}?$r->{grayscale}:'',
              composite_file=>$r->{composite_file}?$r->{composite_file}:'',
              quality=>$r->{quality}?$r->{quality}:''
          );
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

sub resize{
    my %arg=@_;
    my $image = Image::Magick->new();
    $image->Read($arg{from});
    my ($ox,$oy)=$image->Get('base-columns','base-rows');
    my ($k,$nx,$ny);
    if($arg{quality}=~m{^\d+$}){
        $image->Set( quality => $arg{quality} );
    }

    if(!$arg{height}){
        if($arg{width}>$ox){
          # Тимоненкова попросила сделать так, что если у нас ресайз вида 800x0, А мы загружаем картинку меньшую, чем
          # 800 по ширине -- чтобы она оставалась без изменений, кладём на пропорции
          $image->Write($arg{to});
          return;
          
        }
        $k=$oy/$ox;$arg{height}=int($arg{width}*$k);
    }
    elsif(!$arg{width}){
        $k=$ox/$oy;$arg{width}=int($arg{height}*$k);
    }
    else{
        $ny=int(($oy/$ox)*$arg{width});
        $nx=int(($ox/$oy)*$arg{height});
    }

    if($arg{width} eq $arg{height}){
        if($ox ne $oy){
            my $min=minarg($ox,$oy);
            $image->Crop(geometry=>$min.'x'.$min, gravity=>'center');
        }
        $image->Resize(geometry=>'geometry', width=>$arg{width}, height=>$arg{height});
    }
    if($nx>=$arg{width}){ # горизонтально ориентированная
        $nx=$arg{width} if($nx<$arg{width});
        $image->Resize(geometry=>'geometry', width=>$nx, height=>$arg{height});
        if($nx>$arg{width}) { #Если ширина получилась больше 200
            my $nnx=int(($nx-$arg{width})/2); #Вычисляем откуда нам резать
            $image->Crop(geometry=>$arg{width}.'x'.$arg{height}, gravity=>'center');
        }
    }
    else{ # вертикально ориентированная
        $ny=$arg{height} if($ny < $arg{height});
        $image->Resize(geometry=>'geometry', width=>$arg{width}, height=>$ny);
    
        if($ny>$arg{height}) {
            my $nny=int(($ny-$arg{height})/2); #Вычисляем откуда нам резать
            $image->Crop(geometry=>$arg{width}.'x'.$arg{height}, gravity=>'center');
        }
    }

    if($arg{composite_file}){
        my $layer = new Image::Magick;
        $layer->Read($arg{composite_file});
        if($arg{composite_resize}){
            $layer->Resize(geometry=>$arg{composite_resize});
        }
        $image->Composite(image=>$layer,gravity=>'SouthEast',x=>10,y=>10); # compose=>'Atop',x=>10, y=>20

        $layer=undef;
    }
    $image->Quantize(colorspace=>'gray') if($arg{grayscale});

    #  $img->Strip;
    $image->Write($arg{to});
    chmod 0664, $arg{to};
    $image=undef;
}

sub minarg{
  my $min=100000000;
  foreach my $m (@_){
    $min=$m if($m<$min);
  }
  return $min
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
