package CRM::Schedule;
use CRM;
use ReadConf;
use utf8;
use strict;
use Data::Dumper;

sub process{
    my %arg=@_;
    my $action=$arg{action};
    my $config=$arg{congfig};
    my $s=$arg{'s'};
    my $R=$s->request_content(from_json=>1);
    my $form=CRM::read_conf(config=>$arg{config},script=>$arg{script},id=>$arg{id});
    unless($form){
        $form->{errors}=['Проблема при инициализации формы']
    }
    my $errors=$form->{errors};

    

    my $response=undef;
    unless(scalar(@{$errors})){
            if($action eq 'init'){
                my $select_list;
                if($form->{select_list_query}){
                    $select_list=$s->{db}->query(
                        query=>$form->{select_list_query},
                        errors=>$errors
                    )
                }
                else{
                    $select_list=$s->{db}->query(
                        query=>qq{
                            SELECT 
                                wt.$form->{work_table_id} as `value`,  wt.$form->{header_field} as `text`
                            FROM
                                $form->{work_table} wt
                            ORDER BY $form->{header_field}
                        },
                        errors=>$errors
                    )
                }
                unless(scalar(@{$errors})){
                    $response={success=>1,errors=>$errors,
                        form=>{
                            title=>$form->{title},
                            interval_minutes=>$form->{interval_minutes},
                            interval_count=>$form->{interval_count},
                            first_interval=>$form->{first_interval},
                            value=>( $form->{start_date}?$form->{start_date}:CRM::cur_date() ),
                            select_label=>($form->{select_label}?$form->{select_label}:'Выберите значение'),
                            log=>$form->{log},
                            fields=>$form->{fields},
                            select_list=>$select_list,
                            multi=>$form->{multi}?1:0
                        }
                    }
                }

            }
            else{
                
                #$s->pre($action);
                if($action eq 'addEvent'){
                    
                    my $times=$R->{times};
                    # Проверка временного интервала
                    unless($times && ref($times) eq 'ARRAY' &&scalar(@{$times}==2) && !time_error($times->[0]) && !time_error($times->[1])){
                        push @{$errors},'ошибка во временном интервале'
                    }
                    unless($R->{id}=~m/^\d+$/){
                        push @{$errors},'не передан id'
                    }

                    if(time_busy('s'=>$s,times=>$times,form=>$form,R=>$R)){
                        push @{$errors},'указанное Вами время занято'
                    }
                    my $data={
                                interval_begin=>$times->[0],
                                interval_end=>$times->[1],
                                $form->{foreign_key}=>$R->{id}
                            };
                    if($R->{fields_values} && ref($R->{fields_values}) eq 'HASH'){
                        my $fv=$R->{fields_values};
                        foreach my $f (@{$form->{fields}}){
                            if($f->{type} eq 'checkbox'){
                                if($fv->{$f->{name}} && $fv->{$f->{name}} ne '0'){
                                    $data->{$f->{name}}=1
                                }
                                else{
                                    $data->{$f->{name}}=0
                                }
                            }
                        }
                    }
                    
                    unless(scalar(@{$errors})){ # проверка пройдена, записываем
                        $s->{db}->save(
                            table=>$form->{table},
                            data=>$data,
                            
                        )
                    }
                }
                elsif($action eq 'deleteEvent' && $R->{id}=~m/^\d+$/){
                    if($form->{read_only} || !$form->{make_delete}){
                        push @{$errors}, 'Вам запрещено удалять записи из расписания'
                    }
                    else{
                        $s->{db}->query(
                            query=>"DELETE FROM $form->{table} WHERE id=?",
                            delete=>1,
                            values=>[$R->{id}]
                        )
                    }
                }
                elsif($action eq 'getList' && $R->{date}=~m/^\d{4}-\d{2}-\d{2}$/){
                    my $events;
                    if($form->{get_list_query}){
                        $events=$s->{db}->query(
                            query=>$form->{get_list_query},
                            values=>[$R->{date},$R->{date}]
                        )
                    }
                    else{
                        $events=$s->{db}->query(
                            query=>qq{
                                SELECT
                                    tt.id id,tt.id as '_id',
                                    tt.$form->{foreign_key} fk,
                                    concat(wt.$form->{header_field},'-',tt.id) as `name`,
                                    tt.interval_begin as `start`,
                                    tt.interval_end as `end`
                                FROM
                                    $form->{table} tt
                                    JOIN $form->{work_table} wt ON wt.$form->{work_table_id} = tt.$form->{foreign_key}
                                WHERE 
                                    (tt.interval_begin - interval 30 day) <= ? and 
                                    (tt.interval_begin + interval 30 day) >= ?
                            },
                            values=>[$R->{date},$R->{date}]
                        );
                    }
                    $response={
                        success=>1,
                        errors=>$errors,
                        events=>$events
                    };
                    # Заполняем цветом на основе fk (id-шник записи)

                    if($form->{colors_fill}){
                        &{$form->{colors_fill}}($events);
                    }
                    else{
                        my $len=scalar(@{$form->{colors}});
                        foreach my $e (@{$events}){
                            unless($e->{color}){
                                $e->{color}=$form->{colors}->[$e->{fk} % $len];
                            }
                            
                        }
                    }

                }
                else{
                    push @{$errors},'неизвестный метод'
                }
            }
    }

    unless($response){
        $response={
            success=>scalar(@{$errors})?0:1,
            errors=>$errors
        }
    }
    $s->print_json($response)->end

}
# проверяет, занято ли время
sub time_busy{ #
    my %arg=@_;

    my $s=$arg{'s'}; my $times=$arg{times}; my $form=$arg{form};
    
    if($form->{time_busy}){
        return &{$form->{time_busy}}(%arg);
    }
    else{
        return $s->{db}->query(
            query=>qq{SELECT count(*) from $form->{table} WHERE interval_begin>=? and interval_end<=?},
            values=>[$times->[0],$times->[1]],
            onevalue=>1,
            
        )
    }



}
# проверяет формат даты и времени
sub time_error{ 
    my $t=shift;
    unless($t=~m/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/){
        return 1
    }
    return 0
}
return 1;