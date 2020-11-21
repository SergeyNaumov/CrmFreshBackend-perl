package Plugin::Search::works_csv;
use strict;
use utf8;
use Data::Dumper;
#use Text::CSV qw( csv );
use Text::CSV::Encoded;
use Encode;
# libtext-csv-perl libtext-csv-encoded-perl

my $config={
    name=>'search_csv', # имя плагина не должно повторяться, иначе беда!
    icon=>'fa-file-excel',
    title=>'сохранить в csv',
};


my $after_search=sub{
    my %arg=@_;
    my $s=$arg{s}; my $form=$arg{form};
    my $filepath='files/tmp';
    my $filename=$form->{config}.'_'. $form->{manager}->{login}.'.csv';

    unless(-e ){
        mkdir $filepath
    }

    
    my $full_path=$filepath.'/'.$filename;
    
    my $csv = Text::CSV::Encoded->new ({
        encoding_in  => "utf8", # the encoding comes into   Perl
        encoding_out => "cp1251",     # the encoding comes out of Perl
        sep_char=>';',
        quote_char => '"',
        eol=>"\n"
        #escape_char => "\\"
    });
        

    my $line_header=[
        'TypePOV', # 0
        'GosNumberPOV', # 1
        'NamePOV',
        'DesignationSiPOV', 
        'DeviceMarkPOV',
        'DeviceCountPOV', 
        'SerialNumPOV',
        'SerialNumEndPOV',
        'CalibrationDatePOV',
        'NextcheckDatePOV',
        'MarkCipherPOV',

        'DocPOV',
        'DeprcatedPOV',
        'NumCertfPOV',
        'NumSvidPOV',
        'PrimPOV',
        'ScopePOV',
        'StandartPOV',
        'GpsPOV',
        'SiPOV',
        'SoPOV'
    ];
    #print Dumper($line_header);
    open (my $fh,'>',"./$full_path") or print "error write $filename\n$!\n";
        $csv->print ($fh,$line_header);
    print Dumper($arg{result});
    foreach my $str (@{$arg{result}}){
           #my $id=$tr->{key};
           
           # my $line=[];
           # foreach my $d ( @{ $tr->{data} } ){
           #   my $data=$d->{value};
           #   $data =~ s!</?.*?>!!g;
           #   if($data=~m{^\d+((\.|,)\d+)?$}){
           #       $data=~s{^(\d+),(\d+)$}{$1\.$2};
           #   }
           #   push @{$line}, $data
           # }
           $csv->print ($fh,[
                '1', # TypePOV всегда 1
                $str->{rs__num_gos}, # 'номер ГРСИ'
                '', # NamePOV всегда пусто
                '', # DesignationSiPOV всегда пусто
                '', # DeviceMarkPOV - всегда пусто
                '1', # DeviceCountPOV - всегда 1
                $str->{wt__zav_num}, # SerialNumPOV Зав № счетчика
                '', # SerialNumEndPOV - всегда пусто
                $str->{wt__dat_pov}, # CalibrationDatePOV дата поверки ГГГГ-ММ-ДД
                $str->{dat_pov_next}, # NextcheckDatePOV -- дата след. поверки
                'нет данных',# MarkCipherPOV  Всегда "Нет данных"
                $str->{rs__method}, # DocPOV Методика поверки из "реестра СИ"
                ($str->{wt__is_ok}?'Пригодно':'Непригодно'), # DeprcatedPOV "Пригодно/Непригодно" в зависимости  от годен/не годен
                ($str->{wt__is_ok}?"$str->{num_sv1}/$str->{num_sv2}/$str->{num_sv3}":''), # NumCertfPOV Номер свидетельства о поверке (в случае когда годен, когда не годен - пусто)
                # !!!!!!
                ($str->{wt__is_ok}?'':"$str->{num_sv1}/$str->{num_sv2}/$str->{num_sv3}"),# NumSvidPOV Номер извещения о непригодности (в случае, когда не годен, когда годен - пусто)
                '', # PrimPOV Всегда пусто
                '', # ScopePOV Всегда пусто
                # !!!!
                $str->{mm__etalon_reg_num}, # StandartPOV Регистрационный номер эталона
                '', # GpsPOV всегда пусто
                '', # SiPOV всегда пусто
                ''  # SoPOV всегда пусто


            ]);
    }
    close($fh);
    
    $s->print_json({
        success=>1,
        ready=>1,
        format=>'html',
        result=>qq{
            <h2>CSV-файл готов!</h2>
            <a href="/$full_path">нажмите, чтобы скачать</a>
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


return 1;