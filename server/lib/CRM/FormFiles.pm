use utf8;
use strict;
use MIME::Base64;
use Image::Magick; 
use File::Path qw(make_path);
=cut
Работа с файлами: сохранение из base64, ресайз
=cut
sub DeleteFile{
    my %arg=@_;
    my $s=$arg{'s'}; my $form=$arg{form}; my $R=$s->request_content(from_json=>1);
    my @errors=();
    my $name=$R->{name};
    push @errors, 'не указано name'  unless($name);
    my $field=$form->{fields_hash}->{$name};
    my $value=$form->{values}->{$name};
    if($field && $value){
        my ($filename_without_ext,$ext)=get_name_and_ext($value);
        delete_file( # удаляет файл со всеми миниатюрами
            field=>$field,
            filename_without_ext=>$filename_without_ext,
            ext=>$ext,
            value=>$value
        );
    }
    else{
        push @errors, "поле $name не найдено"  unless($name);
    }
    unless(@errors){ # удаляем информацию о фото в базе
        my $keep_str='';
        if($field->{keep_orig_filename_in_field}){
            $keep_str=", $field->{keep_orig_filename_in_field}=''"
        }
        $s->{db}->query(
            query=>"UPDATE $form->{work_table} SET $name='' $keep_str WHERE $form->{work_table_id}=?",
            values=>[$form->{id}]
        )
    }
    $s->print_json({
        success=>scalar(@errors)?0:1,
        errors=>\@errors,
        
    });
}
sub UploadFile{
    my %arg=@_;
    my $s=$arg{'s'}; my $form=$arg{form}; my $R=$s->request_content(from_json=>1);
    my $name=$R->{name}; my $value=$R->{value};

    my @errors=();
    push @errors, 'не указано name'  unless($name);
    push @errors, 'не указано value' unless($value);
    my $field=$form->{fields_hash}->{$name};
    push @errors, "не найдено поле $name" unless($field);
    my $ext='';
    if(!errors($form)){
        if(!$value->{src}){
            push @errors,"нет value.src"
        }

        if(!$value->{orig_name}){
            push @errors,"нет orig_name"
        }
        elsif($value->{orig_name}=~m/\.([^\.]+)$/){
            $ext=$1;
        }
        else{
            push @errors,"не удалось определить расщирение. orig_name: $value->{orig_name}"
        }
    }
    
    my $filename_for_out='';
    if(!scalar(@errors)){
        my $filename_without_ext=filename();
        
        my $crops=$value->{crops};  
        # 1. Сохраняем оригинал изображения
        my @errors=();
        #print "src: $value->{src}\n";
        if($value->{src}=~m/^\/[a-z0-9_A-Z\/]+\/([^\/]+)\.([^\.]+)$/){
            $filename_without_ext=$1; $ext=$2;
            #$value->{src}=~s/^\///;
            
            #print "src2: $value->{src} ($filename_without_ext ; $ext)\n";
        }
        else{
            #print "base64\n";
            $filename_for_out=$filename_without_ext.'.'.$ext;
            @errors=save_base64(
                's'=>$s,
                src=>$value->{src},
                field=>$field,
                table=>$form->{work_table},
                id=>$form->{id},
                orig_name=>$value->{orig_name},
                filename=>$filename_without_ext.'.'.$ext,
                ext=>$ext,
                #filename_without_ext=>$filename_without_ext
            );
        }


        #print Dumper({errors=>\@errors});
        if(!scalar(@errors)){
            if($field->{crops} && $crops){
                foreach my $r (@{$field->{resize}}){
                    my ($width,$height)=split /x/,$r->{size};
                    foreach my $c (@{$crops}){
                        next unless($c->{width} eq $width && $c->{height} eq $height);
                        my $filename=$r->{file};
                        $filename=~s/<\%filename_without_ext\%>/$filename_without_ext/g;
                        $filename=~s/<\%ext\%>/$ext/g;
                        save_base64(
                            's'=>$s,
                            src=>$c->{data},
                            field=>$field,
                            filename=>$filename
                        );
                        # ресайзим изображение
                        resize(
                            from=>"$field->{filedir}/$filename",
                            to=>"$field->{filedir}/$filename",
                            width=>$width,
                            height=>$height,
                            grayscale=>$r->{grayscale}?$r->{grayscale}:'',
                            composite_file=>$r->{composite_file}?$r->{composite_file}:'',
                            quality=>$r->{quality}?$r->{quality}:''
                        )
                    }
                }

                
            }
            else{ # ресайзим оригинальную фото
                foreach my $r (@{$field->{resize}}){
                    my ($width,$height)=split /x/,$r->{size};
                    my $filename=$r->{file};
                    $filename=~s/<\%filename_without_ext\%>/$filename_without_ext/g;
                    $filename=~s/<\%ext\%>/$ext/g;

                    resize(
                        from=>"$field->{filedir}/$filename_without_ext\.$ext",
                        to=>"$field->{filedir}/$filename",
                        width=>"$width",
                        height=>"$height",
                        grayscale=>$r->{grayscale}?$r->{grayscale}:'',
                        composite_file=>$r->{composite_file}?$r->{composite_file}:'',
                        composite_gravity=>$r->{composite_gravity}?$r->{composite_gravity}:'',
                        composite_resize=>$r->{composite_resize}?$r->{composite_resize}:'',
                        quality=>$r->{quality}?$r->{quality}:''
                    );
                }
            }
        }
    }
    $s->print_json({
        success=>scalar(@errors)?0:1,
        errors=>\@errors,
        value=>$filename_for_out
    });
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
        $arg{composite_gravity}='center' unless($arg{composite_gravity});
        $image->Composite(image=>$layer,gravity=>$arg{composite_gravity}); # ,x=>10,y=>10 compose=>'Atop',x=>10, y=>20

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

sub save_base64{
    my %arg=@_; my $field=$arg{field};
    my @errors=();
    my $ext=$arg{ext}; 

    my $to_save_field='';
    # имя файла, под которым мы сохраняем в базе
    my $filename=$arg{filename};
    my $fullname=$field->{filedir}.'/'.$filename;

    if($arg{src}=~m{^data:(.+?);base64,(.+)}gs){
        
        # Создание каталога для файла (если его нет)
        unless(-d $field->{filedir}){
            print "mkdir: $field->{filedir}\n";
            make_path($field->{filedir}) || die($!);
        }

        my ($mime,$base64)=($1,$2);
        #Encode::_utf8_on($base64);
        #print "C: $base64\n" unless($arg{table});
        #print "save_to: $fullname\n";

        open F, '>'.$fullname;
        binmode F;
        my $bin=decode_base64($base64) || die($!);
        print F $bin;
        close F;
    }

    # если не указана таблица -- сохраняем на диск и  выходим
    if(!$arg{table} || scalar(@errors)){
        return @errors;
    }

    my $old_photo=$arg{'s'}->{db}->query(query=>"SELECT $field->{name} from $arg{table} where id=?",values=>[$arg{id}],onevalue=>1);
    $old_photo=~s/;+$//; # если keep_orig_filename

    #print "old_photo: $old_photo\n";
    if($old_photo){
        if($old_photo=~m/^(.+)\.([^\.]+)$/){
            my $f_without_ext=$1; my $ext=$2;
            foreach my $r (@{$field->{resize}}){
                my $f=$r->{file};
                $f=~s/<\%filename_without_ext\%>/$f_without_ext/g;
                $f=~s/<\%ext\%>/$ext/g;
                unlink("$field->{filedir}/$f");
            }

        }
        #print "unlink: $field->{filedir}/$old_photo\n";
        unlink($field->{filedir}.'/'.$old_photo);
    }

    # Сохраняем полное имя в базе или нет?
    if($field->{keep_orig_filename}){
        $filename.=';'.$arg{orig_name}
    }
    elsif($field->{keep_orig_filename_in_field}){
        $arg{'s'}->{db}->query(
            query=>"UPDATE $arg{table} SET $field->{name}=?,$field->{keep_orig_filename_in_field}=? where id=?",
            values=>[$filename,$arg{orig_name},$arg{id}]
        );
    }

    $arg{'s'}->{db}->query(
        query=>"UPDATE $arg{table} SET $field->{name}=? where id=?",
        values=>[$filename,$arg{id}]
    );
    

    return @errors;
}
sub filename{
    return (time().'_'.int(rand()*100000));
}
sub get_name_and_ext{
    my $v=shift;
    if($v=~m/([^\/]+)\.([^\.]+)$/){
        return ($1,$2)
    }
}

sub delete_file{
    my %arg=@_;
    my $field=$arg{field};
    foreach my $r (@{$field->{resize}}){
        my $f=$r->{file};
        $f=~s/<\%filename_without_ext\%>/$arg{filename_without_ext}/g;
        $f=~s/<\%ext\%>/$arg{ext}/g;
        if(-f "$field->{filedir}/$f"){
            unlink("$field->{filedir}/$f");
        }
        
    }
    if(-f $field->{filedir}.'/'.$arg{value}){
        unlink($field->{filedir}.'/'.$arg{value});
    }
}
return 1;