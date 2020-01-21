use utf8;
use strict;
sub save_in_ext_url{
    my %arg=@_;
    my $form=$arg{form};
    my $s=$arg{'s'};
    my $f=$arg{field};
    my $value=$arg{value};
    my $in_url=get_in_url($f,$form->{id});
    return unless($in_url);
    my @where=('in_url=?'); my @values=($in_url);
            
    my $data={
        in_url=>$in_url,
        ext_url=>$value
    };

    if($f->{foreign_key} && $f->{foreign_key_value}){
        push @where,"$f->{foreign_key}=?";
        push @values,$f->{foreign_key_value};
        $data->{$f->{foreign_key}}=$f->{foreign_key_value}
    }

    my $where_str=join(' AND ',@where);
    my $exists=$s->{db}->get(
        table=>'in_ext_url',
        where=>$where_str,
        values=>\@values,
        onerow=>1
    );

    if($exists && $exists->{ext_url} ne $value){ # уже существует, обновляем
        $s->{db}->save(
            table=>'in_ext_url',
            update=>1,
            where=>$where_str,
            values=>\@values,
            data=>$data,
            
        );
    }
    elsif(!$exists){
        $s->{db}->save(
            table=>'in_ext_url',
            data=>$data,
            
        );
    }
}

sub get_in_ext_url{
    my %arg=@_;
    my $s=$arg{'s'}; my $form=$arg{form}; my $f=$arg{field};
    return '' unless($form->{id});
    my $in_url=get_in_url($f,$form->{id});
    return '' unless($in_url);
    my @where=('in_url=?'); my @values=($in_url);

    if($f->{foreign_key} && $f->{foreign_key_value}){
        push @where,"$f->{foreign_key}=?";
        push @values,$f->{foreign_key_value};
    }

    my $where_str=join(' AND ',@where);
    my $exists=$s->{db}->get(
        table=>'in_ext_url',
        where=>$where_str,
        values=>\@values,
        onerow=>1
    );
    if($exists){
        $f->{value}=$exists->{ext_url};
    }
    #print Dumper($f);
}

sub get_in_url{
    my $f=shift; my $id=shift;
    my $in_url=$f->{in_url}; $in_url=~s/<%id%>/$id/g;
    return $in_url;
}

return 1;