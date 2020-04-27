package CRM::Documentation;
use utf8;
use strict;

sub go{
    my $s=shift; my $config=shift;
    if(-f './conf_documentation/'.$config){ # Если существует конфиг -- можно считать правила

    }
    my $errors=[];
    my $list=$s->{db}->get(
        table=>$config,
        order=>'sort',
        where=>'parent_id is null',
        errors=>$errors,
        tree_use=>1
    );
    # правила по умолчанию -- читаем все разделы в виде дерева и отдаём
    $s->print_json(
        {
            errors=>$errors,
            success=>scalar(@{$errors})?0:1,
            list=>$list
        }
    )->end;

}

return 1;