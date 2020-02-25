package Plugin::Search::CSV;
use strict;
use utf8;
use Data::Dumper;
use Class::CSV;
use Encode;
# libclass-csv-perl

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
    
    my $csv = Class::CSV->new(
        
        line_separator => "\r\n",
        fields   => [map { $_->{n} } @{ $arg{headers} }]
    );
    my $line_header={map { $_->{n}=>$_->{h} } @{ $arg{headers} }};
    my @fields=();
    $csv->add_line($line_header);
    #print Dumper({headers=>$line_header});
    #print Dumper({output=>$arg{output}});
    
    foreach my $tr (@{$arg{output}}){
           my $id=$tr->{key};
           
           my $line={};
           foreach my $d ( @{ $tr->{data} } ){
             my $data=$d->{value};
             $data =~ s!</?.*?>!!g;
             if($data=~m{^\d+((\.|,)\d+)?$}){
                 $data=~s{^(\d+),(\d+)$}{$1\.$2};
             }
             $line->{$d->{name}}=$data
           }          
           $csv->add_line($line);
    }
    my $file=$csv->string();
    Encode::_utf8_off($file);
    Encode::from_to($file, 'utf8','cp1251');
    #Encode::_utf8_on($file);
    $s->save_file(
        "./$full_path",
        $file
    );
    
    
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