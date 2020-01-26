package CRM::ParserExcel;
use utf8;
use strict;
use Data::Dumper;
use Spreadsheet::ParseXLSX;
use MIME::Base64;
use Encode;

# хак для Data::Dumper + utf8
$Data::Dumper::Useqq = 1;
$Data::Dumper::Useperl = 1;
{ no warnings 'redefine';
    sub Data::Dumper::qquote {
        my $s = shift;
        return "'$s'";
    }
}

sub process{
    
    my %arg=@_;
    my $parser=read_conf(%arg);
    my $s=$arg{s};
    my $R=$s->request_content(from_json=>1);
    my $action=$R->{action};
    if($action eq 'init'){
        $s->print(
            $s->to_json({
                success=>scalar(@{$parser->{errors}})?0:1,
                errors=>$parser->{errors},
                parser=>$parser
            })
        )->end;
        
    }
    elsif($action eq 'preload'){
        preload('s'=>$s,parser=>$parser,R=>$R);
        return ;
    }
    elsif($action eq 'load'){
        load('s'=>$s,parser=>$parser,R=>$R)
    }
    elsif($action eq 'remove_tmp_file'){
        remove_tmp_file(s=>$s,R=>$R,parser=>$parser);
    } 

}

sub preload{
    my %arg=@_; my $s=$arg{s}; my $parser=$arg{parser}; my $R=$arg{R};
    my ($name_without_ext,$ext)=('','');
    my $src=$R->{src};
    my @errors=();
    if($R->{orig_name}=~m/^(.+)\.([^\.]+)$/){
        $name_without_ext=$1; $ext=$2;
    }
    if($src=~m/^data:(.+?);base64,(.+)/gs){
        my ($mime,$base64)=($1,$2);
        
        unless(-d $parser->{tmp_dir}){
            mkdir($parser->{tmp_dir}) || die($!);
        }
        
        my $filename=time().'_'.substr(rand(),3,3).'.'.$ext;
        
        my $fullname=$parser->{tmp_dir}.'/'.$filename;
        
        #print "save to: $fullname\n";
        open F, '>'.$fullname;
        binmode F;
        my $bin=decode_base64($base64) || die($!);
        print F $bin;
        close F;
        my $result=go_parse(filename=>$filename,tmp_path=>$parser->{tmp_dir},limit=>30);
        #print Dumper({s=>$s});
        $s->print(
            $s->to_json($result)
        )->end;
        return ;
        # $result
    }
    else{
        #push @errors,
        $s->print(
            $s->to_json({
                errors=>['отсутствует параметр src, либо он не соответствует base64']
            })
        )->end
    }
    
}
sub load{
    my %arg=@_; my $s=$arg{s}; my $parser=$arg{parser}; my $R=$arg{R};
    my @errors=();
    my $fields=$R->{fields};
    my $loaded_filename=$R->{loaded_filename};
    my $data_line_number=$R->{data_line_number};
    if(!$fields || (ref($fields) ne 'ARRAY') || !scalar($fields)){
        push @errors,'fields не указано'
    }
    elsif(!$loaded_filename || $loaded_filename!~m/^[a-zA-Z0-9_\-\.]+$/){
        push @errors,'loaded_filename не указан или указан не верно'
    }
    elsif($data_line_number!~m/^\d+$/){
        push @errors,'data_line_number не указан или указан не верно'
    }
    my $hash_fields={};
    foreach my $f (@{$fields}){
        $hash_fields->{$f->{selected}}=$f->{name}
    }
    unless(scalar(@errors)){
        go_parse(
            filename=>$loaded_filename,
            hash_fields=>$hash_fields,
            tmp_path=>$parser->{tmp_dir},
            data_line_number=>$data_line_number,
            loopback=>sub{
                my $data=shift;
                if(scalar( keys %{$data} )){
                    $s->{db}->save(
                        table=>$parser->{work_table},
                        data=>$data,
                        #debug=>1,
                    );
                }
            }
        );
    }
    # print Dumper({
    #      fields=>$hash_fields,
    #      loaded_filename=>$loaded_filename,
    #      data_line_number=>$data_line_number,
    # });


    $s->print_json({
        success=>scalar(@errors)?0:1,
        errors=>\@errors
    })->end;
}


sub remove_tmp_file{
    my %arg=@_; my $s=$arg{s}; my $parser=$arg{parser}; my $R=$arg{R};
    my @errors=();
    if($R->{tmp_file}){
        unlink $parser->{tmp_dir}.'/'.$R->{tmp_file}
    }
    else{
        push @errors,'tmp_file не указан' 
    }
    $s->print(
        $s->to_json({
            success=>scalar(@errors)?0:1,errors=>\@errors
        })
    );

}
sub read_conf{
    my %arg=@_;
    my $config=$arg{config}; my $s=$arg{s};
    my $parser;
    my $dir='./conf_parser';
    #print $dir.'/'.$config.'.pl'."\n";
    if(-f $dir.'/'.$config.'.pl'){
        my $data=$s->template({dir=>$dir,template=>$dir.'/'.$config.'.pl'});
        
        eval ($data);
        if($@){
          #$s->print($@.'<hr>');
          $parser={errors=>[$@.' in '.$config]};
        }
        else{
            $parser->{errors}=[] unless($parser->{errors});
        }
    }
    else{
        return {header=>'',errors=>[qq{$dir/$config\.pl не найден}]}
    }
    return $parser;
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
            mkdir($field->{filedir}) || die($!);
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

sub go_parse{
  my %arg=@_;
  my $filename=$arg{filename}; my $tmp_path=$arg{tmp_path};
  my $full_path=$tmp_path.'/'.$filename;
  my @errors;
  my $parser;
  my $hash_fields=$arg{hash_fields};
  #print "full_path: $full_path\n";
  if($filename=~m/\.xlsx$/){
    $parser = Spreadsheet::ParseXLSX->new;
  }
  else{
    $parser = Spreadsheet::ParseExcel->new;
  }


  #print "v: ".$Spreadsheet::ParseXLSX::VERSION."\n";
  
  #print Dumper($parser);
  my $workbook;
  eval {
    $workbook = $parser->parse($full_path);
  };

  if($@){
    push @errors,$@;
  }
  elsif ( !defined $workbook ) {
      push @errors,$parser->error()
  }
  my $Cells = $workbook->{Worksheet}[0]->{Cells};
  my $row=0;
  
  my $data=[];
  foreach my $c (@{$Cells}){
    my $str=[]; my $hash_str={};
    my $col=0;
    my $is_empty_cnt=0;
    if($arg{data_line_number}=m/^\d+$/ && $row<$arg{data_line_number}){
        $row++; next
    }
    while(1){
        last if($col>100);
        my $value=$c->[$col]->{_Value};
        Encode::_utf8_on($filename);
        $value='' unless($value);

        if(!$value || $value=~m/^\s+$/){
          $is_empty_cnt++;
          if($is_empty_cnt>30){
            last
          }
        }
        else{
          $is_empty_cnt++;
        }

        
        if(ref($hash_fields) eq 'HASH'){
            if(my $name=$hash_fields->{$col}){
                $hash_str->{$name}=$value
            }

        }
        else{
            push @{$str},$value;
        }
        $col++;
    }
    if($arg{loopback}){
            #print Dumper({hash_str=>$hash_str});
            &{$arg{loopback}}($hash_str);
    }
    else{
        $str=clear_empty_str($str);
        $data->[$row]=$str;
    }
    

    
    $row++;
    if($arg{limit} && $row>=$arg{limit}){
      last
    }
  }

  return {
    success=>scalar(@errors)?0:1,
    errors=>\@errors,
    loaded_filename=>$filename,
    data=>$data
  }
}

sub clear_empty_str{ # вычищаем пустые значения в конце строки
  my $str=shift;
  my @new_str=();
  my $need_clean=1;
  foreach my $v ( reverse(@{$str}) ){
    if(!$v || $v=~m/^\s+$/){ # значение пустое
      unless($need_clean){
         push @new_str,$v;
      }

    }
    else{ # значение не пустое
      push @new_str,$v;
      $need_clean=0;
    }
  }
  @new_str=reverse(@new_str);
  return \@new_str;
}
return 1;