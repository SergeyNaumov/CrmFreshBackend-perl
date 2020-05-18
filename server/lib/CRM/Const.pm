package CRM::Const;
use CRM;
use strict;
use utf8;
use Data::Dumper;
sub get{
    my %arg=@_;
    my $s=$arg{s}; 
    my $errors=[];
    
    my $R=$s->request_content(from_json=>1);
    my $list=[];
    if($R->{config}){
        # 1. читаем конфиг
        #print "config: $R->{config}\n";
        my $form=CRM::read_conf(
            's'=>$s,
            script=>'const',
            config=>$R->{config}
        );
        $errors=$form->{errors};

        unless(scalar(@{$errors})){
            push @{$form->{errors}},"в конфиге $R->{config} не указано work_table" if($form->{work_table}!~m/^[a-zA-Z_0-9\_]+$/)
        }

        unless(scalar(@{$errors})){
            
            my $data=$s->{db}->query(
                query=>"SELECT $form->{name_field} name, $form->{value_field} value from $form->{work_table}",
                errors=>$errors
            );

            unless(scalar(@{$errors})){
                form_defaults($form);
                foreach my $f (@{$form->{fields}}){
                    push @{$list},{header=>$f->{description}, name=>$f->{name},type=>$f->{type}}
                }
                my $values={
                    map {
                        $_->{name}=>$_->{value}
                    } @{$data}
                };

                foreach my $l (@{$list}){
                    if($values->{$l->{name}}){
                        $l->{value}=$values->{$l->{name}}
                    }
                }
            }
        }


    }
    else{
        $list=$s->{db}->query(
            query=>q{
                SELECT
                    c.*, cv.value
                from
                    const c
                    LEFT JOIN const_values cv ON cv.const_id=c.id
                order by c.sort
            }
        );
    }

    $s->print(
        $s->to_json({
            success=>scalar(@{$errors})?0:1,
            errors=>$errors,
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
        
        if($R->{config}){
            my $form=CRM::read_conf(
                's'=>$s,
                script=>'const',
                config=>$R->{config}
            );
            my $const=undef;
            foreach my $f (@{$form->{fields}}){
                if($f->{name} eq $R->{name}){
                    $const=$f;
                }

            }
            unless($const){
                push @{$errors},"не найдено поле с именем $R->{name}"
            }
            $errors=$form->{errors};
            unless(scalar(@{$errors})){
                push @{$errors},"в конфиге $R->{config} не указано work_table" if($form->{work_table}!~m/^[a-zA-Z_0-9\_]+$/)
            }
            unless(scalar(@{$errors})){
                if($const->{type} eq 'file'){

                }
                elsif($const->{type}=~m/^(text|textarea|wysiwyg|checkbox|switch)$/){
                    $s->{db}->save(
                        table=>$form->{work_table},
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
        }
        else{
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


    }
    $s->print(
        $s->to_json({
            success=>scalar(@{$errors})?0:1,
            errors=>$errors,
        })
    )->end;
}
sub form_defaults{
    my $form=shift;
    $form->{name_field}='name' unless($form->{name_field});
    $form->{value_field}='value' unless($form->{value_field});
}
return 1;