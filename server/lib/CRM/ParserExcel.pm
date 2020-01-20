package CRM::ParserExcel;
use utf8;
use strict;
use Data::Dumper;

sub process{
    
    my %arg=@_;
    my $form=read_conf(%arg);
    my $s=$arg{'s'};

    
    my $R=$s->request_content(from_json=>1);
    my $action=$R->{action};
    if($action eq 'init'){
        $s->print(
            $s->to_json({
                success=>scalar(@{$form->{errors}})?0:1,
                errors=>$form->{errors},
                form=>$form
            })
        )->end;
        
    }   
    elsif($action eq 'preload'){
        my $data=preload('s'=>$s,form=>$form,R=>$R);
        $s->print(
            $s->to_json({
                success=>scalar(@{$form->{errors}})?0:1,
                errors=>$form->{errors},
                data=>$data
            })
        )->end;
    } 

}
sub preload{
    my $s=$arg{s}; my $form=$arg{form}; my $R=$arg{R};
    my ($name_without_ext,$ext)=('','');

    if($R->{orig_name}=~m/^(.+)\.([^\.]+)$/){
        $name_without_ext=$1; $ext=$2;
    }
    if($arg{src}=~m{^data:(.+?);base64,(.+)}gs){
        my ($mime,$base64)=($1,$2);
        unless(-d $form->{tmpdir}){
            mkdir($form->{tmpdir}) || die($!);
        }

        my $fullname=$form->{tmpdir}.'/'.$filename;
        open F, '>'.$fullname;
        binmode F;
        my $bin=decode_base64($base64) || die($!);
        print F $bin;
        close F;
        

    }
sub read_conf{
    my $config=$arg{config}; my $s=$arg{s};
    my $form;
    my $dir='./conf/conf-parser';
    if(-f $dir.'/'.$config.'.pl'){
        my $data=$s->template({dir=>$dir,template=>$dir.'/'.$config.'.pl'});
        if($@){
          #$s->print($@.'<hr>');
          $form={errors=>[$@.' in '.$config]};

          
        }
        else{

        }
    }
    return $form;
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
return 1;