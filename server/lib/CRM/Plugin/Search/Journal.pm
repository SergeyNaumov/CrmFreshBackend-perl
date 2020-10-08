package Plugin::Search::Journal;
use odt_file2;

# Журнал регистрации поверочных работ (водоучёт-сервис)
use strict;
use utf8;
use Data::Dumper;
#use Text::CSV qw( csv );
use Text::CSV::Encoded;
use Encode;
# libtext-csv-perl libtext-csv-encoded-perl

my $config={
    name=>'vod_journal', # имя плагина не должно повторяться, иначе беда!
    icon=>'fa-file-word',
    title=>'Выгрузить в журнал регистрации проверочных работ',
};
sub clean_dir{
    my $dir=shift;
    opendir (my $dh, $dir) || die "Can't opendir $dir: $!"; 
    while(my $f=readdir($dh)){
        next if($f=~m/^\./);
        my $t=time();

        my $mtime=(stat("$dir/$f"))[9];
        my $d=$t-$mtime;
        if($d>600){ # 10 минут и хорош
            unlink("$dir/$f")
        }
        

    }
    closedir $dh;
}

my $after_search=sub{
    my %arg=@_;
    my $s=$arg{s}; my $form=$arg{form};
    my $filepath='files/tmp';
    my $filename=$form->{config}.'_'. $form->{manager}->{login}.'.csv';
    #print Dumper(\%arg);
    unless(-e ){
        mkdir $filepath
    }
    
    
    my $full_path=$filepath.'/'.$filename;
    
    my $const={
      template_path=>'./files/blank_document',
      template=>'journal.odt',
      result_file_name=>'files/tmp/'.$form->{manager}->{login}.'_journal.doc'
    };
    clean_dir('./files/tmp');

    my $data={
        list=>$arg{result}
        # list=>[
        #     {
        #         dat_pov=>'2019-01-01',
        #         type_wather=>'Type counterZZ2',
        #         zav_num=>int(rand()),
        #         type_wather=>'ХВС',
        #         result=>'годен',
        #         owner=>'Иванов Иван Иванович',
        #         number=>'8378728772', # номер свидетельства
        #         master_fio=>'Болотов Владимир Алексеевич',
        #     },

        # ]
    };
    foreach my $l (@{$data->{list}}){
        foreach my $k ( keys %{$l} ){
            Encode::_utf8_off($l->{$k});
        }
        
    }
    odt_file2::odt_process( {
      's'=>$s,
      template            => $const->{template}, # шаблон, можно без пути если указан template_path
      template_path       => $const->{template_path}, # там лежат бланки шаблонов
      tmp_dir             => './files/tmp/'.$form->{manager}->{login},
      result_file_name=>'./'.$const->{result_file_name},
      format              => 'doc',
      vars => 
        {
          data=>$data,
          #img=>$img   
        },
    } );
    $s->print_json({
        success=>1,
        ready=>1,
        format=>'html',
        result=>qq{
            <h2>журнал регистрации проверочных работ готов!</h2>
            <a href="/$const->{result_file_name}">нажмите, чтобы скачать</a>
        }
    })->end;
    #$s->{stream_out}=1;
    #$s->end;
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