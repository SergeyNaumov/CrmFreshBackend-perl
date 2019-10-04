package CRM::Download;
use utf8;
use Image::Magick;
use strict;
sub is_view_in_browser {
  my $fill_path=shift;
  return ($fill_path=~m/\.(pdf|png|jpg|gif|jpeg)/i);
}
sub download_init{
  my %arg=@_;
  my $form=$arg{form};
  my $field=undef;
  
  if($arg{field_name}!~m{^[a-zA-Z0-9\_]+$}){
    push @{$form->{errors}}, 'Download: field_name не указано или указано неверно. обратитесь к разработчику'
  }
  if(!scalar(@{$form->{errors}})){
    foreach my $f (@{$form->{fields}}){
      if($f->{name} eq $arg{field_name}){
        $field=$f; last;
      }
    }
  }
  push @{$form->{errors}},"поле $arg{field_name} не найдено. обратитесь к разработчику" unless($field);
  return ($field);
}
sub process{
    my %arg=@_;
    
    my $form=$arg{form}=CRM::read_conf(config=>$arg{config},script=>$arg{script},id=>$arg{id});
    my $field=download_init(%arg);
    my $s=$arg{s}; my $form=$arg{form};
    my $id=undef;

    if(!$arg{id}){
      push @{$form->{errors}},'Обратитесь к разработчику: не указано id';
    }

    
    if($arg{child_field_name}){
      
      my $child_field;
      foreach my $f (@{$field->{fields}}){
        if($f->{name} eq $arg{child_field_name}){
          $child_field=$f
        }
      }

      if($child_field){
          my $file=$form->{db}->query(
              query=>qq{SELECT $arg{child_field_name} from $field->{table} where $field->{foreign_key}=? and $field->{table_id}=?},
              values=>[$arg{id},$arg{one_to_m_id}],
              onevalue=>1
          );
          my $full_path=$child_field->{filedir};
          my $orig_name;
          if($file=~m{^(.+?);(.+)$}){
              $full_path.='/'.$1;
              $orig_name=$2;
          }
          else{
              $full_path.='/'.$file;
              $orig_name=$file;
          }
          #$s->print(qq{$full_path ; Content-Disposition:attachment; filename=\"$orig_name\"})->end;# return;
          if(-f $full_path){
            my $view=$s->param('view');
            if($view){ #is_view_in_browser($fill_path)
              push @{$s->{APP}->{HEADERS}},q{Content-Disposition: inline; filename="filename.pdf"};
            }
            else{
              push @{$s->{APP}->{HEADERS}},q{Content-Type: application/x-force-download};
              push @{$s->{APP}->{HEADERS}},qq{Content-Disposition:attachment; filename=\"$orig_name\"};
            }
            
            $s->{vars}->{print_header}=1;
            if($view=~m{^(\d+)x(\d+)$}){
              my ($w,$h)=($1,$2);
              
              if($full_path=~m{\.(gif|jpg|png|jpeg|bmp)$}){
                    my $output_file='./tmp/'.rand().'.png';
                    $s->print(
                      resize({
                        input_file=>$full_path,
                        width=>$w,
                        height=>$h,
                        output_file=>$output_file
                      })
                    );
                    $s->print_file($output_file)->end;
                    unlink($output_file);
              }
            }
            else{
              $s->print_file($full_path)->end;
            }
            $s->end;
          }
          else{
              push @{$form->{errors}}, qq{ файл "$full_path" отсутствует на диске }
          }

          #$s->end;
          #$s->pre([$full_path,$orig_name])->end;
          return;
          
      }
      else{
          push @{$form->{errors}}, qq{не найдено поле $field->{name}:$child_field->{name} в конфиге $arg{config}}
      }
      $s->print_json({
        success=>( scalar( @{$form->{errors}} ) )?0:1,
        child_field=>$child_field,
        field=>$field,
        errors=>$form->{errors}
      })->end;

      return ;
    }
    else{


      $s->print_json({
        success=>( scalar( @{$form->{errors}} ) )?0:1,
        errors=>$form->{errors},
        download_main_form=>1,
      })->end;
      
    }


}
sub resize{ # процедура ресайзинга
=cut
	input_file
	output_file
	width
	height
=cut
 my $opt=shift;
	#my ($input_file, $output_file, $width, $height)=@_;
	my $image;
	$image = Image::Magick->new; #новый проект
	my $x = $image->Read($opt->{input_file}); #открываем файл
	#$img->Set(quality=>90);
	#$image->set_quality(90);

#	$image->Contrast(); #Контрастность
#	$image->Normalize(); #Нормализуем
	my ($ox,$oy)=$image->Get('base-columns','base-rows');
	my $k;
	#$image->Set(quality => 90);
	# для ресайза по одной стороне
	if($opt->{height} eq '0'){
		$k=$oy/$ox;$opt->{height}=int($opt->{width}*$k);		
	}
	elsif($opt->{width} eq '0'){
		$k=$ox/$oy;$opt->{width}=int($opt->{height}*$k);		
	}
	my $ny=int(($oy/$ox)*$opt->{width});
	my $nx=int(($ox/$oy)*$opt->{height});
	
	if($nx>=$opt->{width}){ # горизонтально ориентированная
	
		$nx=$opt->{width} if($nx<$opt->{width});
		#print "resize: $nx x $opt->{height}<br>";
		$image->Resize(geometry=>'geometry', width=>$nx, height=>$opt->{height});
		if($nx>$opt->{width}) { #Если ширина получилась больше 200
			my $nnx=int(($nx-$opt->{width})/2); #Вычисляем откуда нам резать
			#print "<br>nnx: $nnx<br>\n";			
			#print "1crop: $opt->{width}x$opt->{height}<br>";
			#$image->Crop(x=>0, y=>0); #Задаем откуда будем резать (x=>$nnx, y=>0)
			$image->Crop(geometry=>$opt->{width}.'x'.$opt->{height}, gravity=>'center'); 
		}
	}
	else{ # вертикально ориентированная
		
		#print "ny: $ny<br>vert: size: $opt->{width}x$ny<br>\n";
		$ny=$opt->{height} if($ny<$opt->{height});
		$image->Resize(geometry=>'geometry', width=>$opt->{width}, height=>$ny);
		#print "resize: $opt->{width}x$ny<br>";
		if($ny>$opt->{height}) { 
			my $nny=int(($ny-$opt->{height})/2); #Вычисляем откуда нам резать
			#print "ny: $ny ; nny: $nny<br>";
			#$image->Crop(x=>0,y=>0); #Задаем откуда будем резать (x=>0,y=>$nny)
			#print "2crop: $opt->{width}x$opt->{height}<br>";
			$image->Crop(geometry=>$opt->{width}.'x'.$opt->{height}, gravity=>'center'); 
		}		
	}
	if($opt->{composite_file}){
		#print "$opt->{composite_file}\n";
		my $layer = new Image::Magick;
		$layer->Read($opt->{composite_file});
		$image->Composite(image=>$layer,); # compose=>'Atop',x=>10, y=>20
		
	}
	$image->Quantize(colorspace=>'gray') if($opt->{grayscale});
	#return $image->Write('.png:-');
  if($opt->{output_file}){
    $x = $image->Write($opt->{output_file});
  }
	
}
return 1;