package Plugin::Search::XLS;
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
    
    my $f=$wb->add_format( bottom=>1, border_color=>8);

  #print Dumper({output=>$arg{output}});
    foreach my $tr (@{$arg{output}}){
      my $id=$tr->{key};
      my $i=0;
      map 
        {
            my $data=$_->{value};
            {
                $data =~ s!</?.*?>!!g;
                if($data=~m{^\d+((\.|,)\d+)?$}){
                    $data=~s{^(\d+),(\d+)$}{$1\.$2};
                    $ws->write_number($col, $i, $data, $f);
                }
                else{
                    $ws->write($col, $i, $data, $f);
                }
            }
            $i++;
        }
        @{ $tr->{data} };
        $col++;
    }

    
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