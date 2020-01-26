package CRM::Const;
use strict;
use utf8;
sub get{
    my %arg=@_;
    my $s=$arg{s}; 
    my @errors=();
    my $list=$s->{db}->query(
        query=>q{
            SELECT
                c.*, cv.value
            from
                const c
                LEFT JOIN const_values cv ON cv.const_id=c.id
            order by c.sort
        }
    );
    $s->print(
        $s->to_json({
            success=>scalar(@errors)?0:1,
            errors=>\@errors,
            list=>$list
        })
    )->end;
}
sub save_value{
    my %arg=@_;
    my $s=$arg{s}; 
    my $R=$s->request_content(from_json=>1);
    my $errors=[];
    if(!$R || !exists($R->{name}) ) {
        push @{$errors},'параметры name и value обязательны, обратитесь к разработчику'
    }
    else{
        #print "name: $R->{name} value: $R->{value}\n"
        my $const=$s->{db}->query(
            query=>'SELECT * from const where name=?',
            values=>[$R->{name}],
            onerow=>1
        );

        if($const){
            if($const->{type} eq 'file'){

            }
            elsif($const->{type}=~m/^(text|textarea|wysiwyg|checkbox|switch)$/){
                $s->{db}->save(
                    table=>'const_values',
                    data=>{
                        const_id=>$const->{id},
                        name=>$R->{name},
                        value=>$R->{value}
                    },
                    replace=>1,

                )
            }
            else{
                if(!$const->{type}){
                    push @{$errors},"тип константы для $R->{name} не указан"
                }
                else{
                    push @{$errors},"Не известный тип константы: '$const->{type}'"
                }
            }
        }
        else{
            push @{$errors},"Не найдена константа с именем: $R->{name}"
        }
    }
    $s->print(
        $s->to_json({
            success=>scalar(@{$errors})?0:1,
            errors=>$errors,
        })
    )->end;
}
return 1;