package Plugin::Search::works_xml;
use strict;
use utf8;
use Data::Dumper;
#use Text::CSV qw( csv );
use Text::CSV::Encoded;
use Encode;
# libtext-csv-perl libtext-csv-encoded-perl

my $config={
    name=>'work_search_xml', # имя плагина не должно повторяться, иначе беда!
    icon=>'fa-file-code',
    title=>'сохранить в xml',
};


my $after_search=sub{
    my %arg=@_;
    my $s=$arg{s}; my $form=$arg{form};
    my $filepath='files/tmp';
    my $filename=$form->{config}.'_'. $form->{manager}->{login}.'.xml';

    unless(-e ){
        mkdir $filepath
    }

    
    my $full_path=$filepath.'/'.$filename;
    


    foreach my $v (@{$arg{result}}){
        $v->{wt__num_label}="$v->{wt__dat_pov}/$v->{wt__num_sv2}/$v->{wt__num_sv1}";
        #$v->{ranges}=range(from=>,)
        my $qmax=$v->{wt__ranges};
        if($v->{wt__dn}==15){

            $v->{ranges}="0.03-$qmax м3/ч";
        }
        else{
            #$v->{ranges}=range(from=>0.5,to=>$v->{qmax},order=>1); 
            $v->{ranges}="0.05-$qmax м3/ч";
        }   
    }

    my $out_xml=$s->template({
        template=>'./conf/work.conf/works_xml_template.xml',
        vars=>{
          LIST=>$arg{result},
          
        }
    });
    # записываем XML
    $s->save_file($full_path,$out_xml);
    

    # foreach my $str (@{$arg{result}}){
    #        #my $id=$tr->{key};
           
    #        # my $line=[];
    #        # foreach my $d ( @{ $tr->{data} } ){
    #        #   my $data=$d->{value};
    #        #   $data =~ s!</?.*?>!!g;
    #        #   if($data=~m{^\d+((\.|,)\d+)?$}){
    #        #       $data=~s{^(\d+),(\d+)$}{$1\.$2};
    #        #   }
    #        #   push @{$line}, $data
    #        # }
    #        $csv->print ($fh,[
    #             '1', # TypePOV всегда 1
    #             $str->{rs__num_gos}, # 'номер ГРСИ'
    #             '', # NamePOV всегда пусто
    #             '', # DesignationSiPOV всегда пусто
    #             '', # DeviceMarkPOV - всегда пусто
    #             '1', # DeviceCountPOV - всегда 1
    #             $str->{wt__zav_num}, # SerialNumPOV Зав № счетчика
    #             '', # SerialNumEndPOV - всегда пусто
    #             $str->{wt__dat_pov}, # CalibrationDatePOV дата поверки ГГГГ-ММ-ДД
    #             $str->{dat_pov_next}, # NextcheckDatePOV -- дата след. поверки
    #             'нет данных',# MarkCipherPOV  Всегда "Нет данных"
    #             $str->{rs__method}, # DocPOV Методика поверки из "реестра СИ"
    #             ($str->{wt__is_ok}?'Пригодно':'Непригодно'), # DeprcatedPOV "Пригодно/Непригодно" в зависимости  от годен/не годен
    #             ($str->{wt__is_ok}?"$str->{num_sv1}/$str->{num_sv2}/$str->{num_sv3}":''), # NumCertfPOV Номер свидетельства о поверке (в случае когда годен, когда не годен - пусто)
    #             # !!!!!!
    #             ($str->{wt__is_ok}?'':"$str->{num_sv1}/$str->{num_sv2}/$str->{num_sv3}"),# NumSvidPOV Номер извещения о непригодности (в случае, когда не годен, когда годен - пусто)
    #             '', # PrimPOV Всегда пусто
    #             '', # ScopePOV Всегда пусто
    #             # !!!!
    #             $str->{mm__etalon_reg_num}, # StandartPOV Регистрационный номер эталона
    #             '', # GpsPOV всегда пусто
    #             '', # SiPOV всегда пусто
    #             ''  # SoPOV всегда пусто


    #         ]);
    # }
    # close($fh);
    
    $s->print_json({
        success=>1,
        ready=>1,
        format=>'html',
        result=>qq{
            <h2>XML-файл готов!</h2>
            <a href="/$full_path" target="_blank">нажмите, чтобы скачать</a>
        }
    })->end;
};

my $before_search=sub{

};
sub go{
    my $form=shift;
    
    if($form->{script} eq 'admin_table'){
        $form->{search_plugin}=[] unless($form->{search_plugin});
        push @{$form->{search_plugin}},$config;
    }
    elsif($form->{script} eq 'find_objects' && ($config->{name} && $form->{R}->{plugin} eq $config->{name}) ){
        $form->{perpage}=10000;
        #$form->{events}->{search}=$search;
        #$form->{events}->{before_search}=$before_search;
        $form->{events}->{after_search}=$after_search;

    }
}
sub range{
    my %arg=@_;
    my $min=$arg{from};
    my $max=$arg{to};
    my $order=$arg{order};
    $order=0 unless($order);
    my $result=$min+rand($max-$min);

    my $delta=(1 / (10**$order));
    if($order){
        $result=~s/^(-?\d+\.\d{$order})\d*/$1/;
    }
    else{
        $result=~s/\.\d+//;
    }

    if(rand()>0.5){
        $result+=$delta;
    }
    else{
        $result-=$delta;
    }
    return $result
}

return 1;