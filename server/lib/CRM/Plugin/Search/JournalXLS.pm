package Plugin::Search::JournalXLS;
use strict;
use utf8;
use Data::Dumper;
use Spreadsheet::WriteExcel;

my $config={
    name=>'search_xls', # имя плагина не должно повторяться, иначе беда!
    icon=>'fa-file-excel',
    title=>'сохранить в xls',
};


my $after_search=sub{
    my %arg=@_;
    my $s=$arg{s}; my $form=$arg{form};
    my $filepath='files/tmp';
    my $filename=$form->{config}.'_'. $form->{manager}->{login}.'.xls';

    unless(-e ){
        mkdir $filepath
    }

    
    my $full_path=$filepath.'/'.$filename;
    my $wb=Spreadsheet::WriteExcel->new("./$full_path");
    my $ws=$wb->add_worksheet('лист1');
    my $col=1;
    
    my $header = $wb->add_format();
    $header->set_bold();
    $header->set_font('Times New Roman');

    my $f=$wb->add_format( bottom=>1, border_color=>8);
    $f->set_font('Times New Roman');

    $ws->set_column('B:B', 12);
    $ws->set_column('C:C', 25);
    $ws->set_column('D:D', 25);
    $ws->set_column('E:E', 25);
    $ws->set_column('F:F', 30);
    $ws->set_column('G:G', 30);
    # 1 строка
    $ws->write(0,0, '№ п/п', $header);
    $ws->write(0,1, 'Дата поверки', $header);
    $ws->write(0,2, 'Наименование, тип средства измерений, заводской №', $header);
    $ws->write(0,3, '№ выписанного документа, (свидетельства о поверке / извещения о непригодности и протокола поверки)', $header);
    $ws->write(0,4, 'Результат поверки', $header);
    $ws->write(0,5, 'Наименование заказчика', $header);
    $ws->write(0,6, 'Ф.И.О. поверителя', $header);

    # 2 строка
    $ws->write(1, 0, '1', $f);
    $ws->write(1, 1, '2', $f);
    $ws->write(1, 2, '3', $f);
    $ws->write(1, 3, '4', $f);
    $ws->write(1, 4, '5', $f);
    $ws->write(1, 5, '6', $f);
    $ws->write(1, 6, '7', $f);


    #print Dumper({result=>$arg{result}});
    my $i=2; my $j=1;
    foreach my $r (@{$arg{result}}){
        # № п/п
        $ws->write($i, 0, $j, $f);
        $ws->write($i, 1, $r->{wt__dat_pov}, $f);
        $ws->write($i, 2, qq{$r->{rs__header2}, $r->{rs__type}, $r->{wt__zav_num}}, $f);
        $ws->write($i, 3, $r->{num_label}, $f);
        $ws->write($i, 4, $r->{wt__is_ok}?'годен':'не годен', $f);
        $ws->write($i, 5, $r->{wt__owner}, $f);
        $ws->write($i, 6, $r->{mm__header}, $f);
        $i++; $j++;
    }
    # foreach my $tr (@{$arg{output}}){
    #   my $id=$tr->{key};
    #   my $i=0;
    #   map 
    #     {
    #         my $data=$_->{value};
    #         {
    #             $data =~ s!</?.*?>!!g;
    #             if($data=~m{^\d+((\.|,)\d+)?$}){
    #                 $data=~s{^(\d+),(\d+)$}{$1\.$2};
    #                 $ws->write_number($col, $i, $data, $f);
    #             }
    #             else{
    #                 $ws->write($col, $i, $data, $f);
    #             }
    #         }
    #         $i++;
    #     }
    #     @{ $tr->{data} };
    #     $col++;
    # }

    
    $s->print_json({
        success=>1,
        ready=>1,
        format=>'html',
        result=>qq{
            <h2>XLS-файл готов!</h2>
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