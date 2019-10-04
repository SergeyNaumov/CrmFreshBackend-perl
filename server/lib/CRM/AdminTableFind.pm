use utf8;
use strict;
use POSIX;
sub admin_table_find{ # Поиск результатов
    my $s=$Work::engine; my $R=shift;
    
    #$R={config=>'manager'} unless($R);

    my $form=read_conf(config=>$R->{config},script=>'find_objects');
    
    
    
    #set_default_attributes($form);
    
    
    if($R->{page}=~m{^\d+$} && $R->{page}){
        $form->{page}=$R->{page}
    }
    else{
        $form->{page}=1
    }
    $form->{perpage}=20 unless($form->{perpage});

    
    my $params=$R->{params};
    
    if($R->{params} && exists($R->{params}->{priority_sort}) && (ref($R->{params}->{priority_sort}) eq 'ARRAY') && ( scalar(@{$R->{params}->{priority_sort}})==2) && $R->{params}->{priority_sort}->[1]=~m{^(asc|desc)$}){

        $form->{priority_sort}=$R->{params}->{priority_sort}
    }

    $form->{query_search}={
        on_filters_hash=>{}, # включённые фильтры
        SELECT_FIELDS=>[],
        WHERE=>[],
        ORDER=>[],
        TABLES=>[],
        GROUP=>[],
    };

    if($form->{GROUP_BY}){ # depricated
        push @{$form->{query_search}->{GROUP}},$form->{GROUP_BY};
    }
    $form->{SEARCH_RESULT}={
        log=>$form->{log},
        config=>$form->{config},
        headers=>[], # список заголовков таблицы результатов
        card_format=>$form->{card_format}?$form->{card_format}:'vue'
    };

    foreach my $values (@{$R->{query}}){
        my $name=$values->[0];
        $form->{query_search}->{on_filters_hash}->{$name}=$values->[1];
    }
    get_search_tables($form,$R->{query});
    get_search_where($form,$R->{query});
    #$s->pre([$R,$form->{query_search}]); 
    # Формируем запрос
    run_event($form->{events}->{before_search},'events.before_search');
    my ($query,$query_count)=gen_query_search($form);
    #$s->print($query);
    #print "$query";
    
    my $total_count=$s->{db}->query(query=>qq{select sum(cnt) from ($query_count) x},onevalue=>1,errors=>$form->{errors});
    $form->{SEARCH_RESULT}->{count_total}=$total_count;
    $form->{SEARCH_RESULT}->{count_pages}=($form->{not_perpage})?1:( ceil($total_count/$form->{perpage}) );

    # Если мы запрашиваем страницу, которой нет -- отдаём первую страницу
    if($form->{page} > $form->{SEARCH_RESULT}->{count_pages}){
        $form->{page}=1;
    }
    #print "$query\n";
    my $result_list=$s->{db}->query(query=>$query,errors=>$form->{log},log=>$form->{log},debug=>$form->{explain}?1:0);


    #$s->pre($form->{SEARCH_RESULT});
    #$s->pre($result_list);
    my $output=[];
    my @ids=map {$_->{wt__id} } @{$result_list};
    my $memo_values={};
    # if(scalar(@ids)){
    #     foreach my $f (@{$form->{fields}}){
    #         next if($f->{type} ne 'memo');
    #         $memo_values->{$f->{name}}=get_many_memo(form=>$form,field=>$f,ids=>\@ids);
    #     }
    # }
    $form->{SEARCH_RESULT}->{selects}={};

    foreach my $r (@{$result_list}){
        my $data=[];
        #print Dumper($r);
        foreach my $q (@{$R->{query}}){
            my $name=$q->[0];
            my $field=$form->{fields_hash}->{$name};
            my $type=$field->{type};
            my $tbl=$field->{tablename}?$field->{tablename}:'wt';
            my $db_name=$field->{db_name}?$field->{db_name}:$name;
            my $value;
            
            #if($field->{type}=~m{^(filter_extend_)?(select|select_from_table)$}){

                
            #}
            #else{
            $value=$r->{$tbl.'__'.$db_name};
            #}
            
            if($field->{type_orig} eq 'select_values'){ # преобразуем select_values
                my $values_finded=0;
                foreach my $v (@{$field->{values}}){
                    if($v->{v}==$value || $v->{v} eq $value){
                        $value=$v->{d}; $values_finded=1;# last;
                    }
                }
                unless($values_finded){
                    $value='не выбрано'
                }
            }


            if(!$field->{make_change_in_search} && ref($field->{filter_code}) eq 'CODE'){
                $value=&{$field->{filter_code}}({str=>$r,value=>$value});
            }
            #if($field->{type} eq 'memo'){
                #$value=[grep {$r->{wt__id}==$_->{fk_id}} @{$memo_values->{$name}} ];
                #push @{$data},{name=>$name,type=>'memo',value=>$value}
            #}
            my $type='html';
            if($field->{type} eq 'memo'){
                $type='memo'
            }
            elsif($field->{type}=~m{^font}){
                $type=$field->{type};
            }
            elsif($field->{type} eq 'checkbox'){
                if($field->{make_change_in_search}){
                    $type='checkbox'
                }
                else{
                    $value=$value?'да':'нет'
                }
                
            }
            elsif($field->{type_orig}=~m{^(filter_extend_)?select_from_table}){
                if($field->{make_change_in_search}){
                    $type='select';
                    $value=$r->{$tbl.'__'.$field->{value_field}};
                    if(!$form->{SEARCH_RESULT}->{selects}->{$field->{name}}){
                        $form->{SEARCH_RESULT}->{selects}->{$field->{name}}=$field->{values}
                    }   
                }
                else{
                    if($r->{$tbl.'__'.$field->{header_field}}){
                        $value=$r->{$tbl.'__'.$field->{header_field}}
                    }
                    else{
                        $value='-';
                    }
                }                
            }
            elsif($field->{type_orig}=~m{^(filter_extend_)?select_values$}){
                if($field->{make_change_in_search}){
                    $type='select';
                    $value=$r->{$tbl.'__'.$db_name};
                    if(!$form->{SEARCH_RESULT}->{selects}->{$field->{name}}){
                        $form->{SEARCH_RESULT}->{selects}->{$field->{name}}=$field->{values}
                    }
                }
                
            }
            elsif($field->{type}=~m{^(text|textarea)}){
                if($field->{make_change_in_search}){
                    $type=$field->{type}; $value=$r->{$tbl.'__'.$db_name};
                }
            }
            elsif($field->{type} eq 'password'){
                $value='[пароль нельзя увидеть]'
            }

            
            push @{$data},{name=>$name,type=>$type,value=>$value}
            
            
        }
        push @{$output},{key=>$r->{wt__id},data=>$data};
    }
    $form->{SEARCH_RESULT}->{log}=$form->{log};
    $form->{SEARCH_RESULT}->{output}=$output; 

    $s->print_json({
      success=>errors($form)?0:1,
      results=>$form->{SEARCH_RESULT},
      errors=>$form->{errors}
    })->end;
}

sub gen_query_search{
    # получаем поисковый запрос на основе $form->{query_search}
    my $form=shift;
    my $qs=$form->{query_search};
    my $query="SELECT ".join(',',@{$qs->{SELECT_FIELDS}}).
        " FROM ".
            join("\n",@{$qs->{TABLES}});
    
    if(scalar(@{$qs->{WHERE}})){
        $query.=" WHERE ".join(' AND ',@{$qs->{WHERE}})
    }

    if(scalar(@{$qs->{GROUP}})){
        $query.=" GROUP BY ".join(', ',@{$qs->{GROUP}})
    }
    if(scalar(@{$qs->{ORDER}})){
        $query.=" ORDER BY ".join(', ',@{$qs->{ORDER}})
    }

    if(!$form->{not_perpage}){
        $query.=" LIMIT ".($form->{page}-1)*$form->{perpage}.', '.($form->{perpage})
    }

    my $query_count="SELECT count(*) cnt FROM ".join("\n",@{$qs->{TABLES}}).
        (
            scalar(@{$qs->{WHERE}})?
                (" WHERE ".join(' AND ',@{$qs->{WHERE}})):''
        ).
        (
            scalar(@{$qs->{GROUP}})?
                (" GROUP BY ".join(', ',@{$qs->{GROUP}})):''
        );
    return ($query,$query_count);
    
}
sub get_search_tables{
    my $form=shift; my $query=shift;
    my $TABLES=[];



    #print Dumper({wt=>$form->{work_table}, QUERY_SEARCH_TABLES=>$form->{QUERY_SEARCH_TABLES}});
    my $aliases_on={wt=>1};
    #$form->{self}->pre($form->{query_search}->{on_filters_hash});
    $form->{errors}=[] unless $form->{errors};
    foreach my $t (@{$form->{QUERY_SEARCH_TABLES}}){
        $t->{table}=$t->{t} if(!$t->{table});
        $t->{alias}=$t->{a} if(!$t->{alias});
        $t->{left_join}=$t->{lj} if(!$t->{left_join});
        $t->{link}=$t->{l} if(!$t->{link});
        my $t_str="";
        my $need_add_table=1; # по умолчанию добавляем таблицу в select

        if($t->{link}){
            if($t->{left_join}){
                $t_str.=" LEFT "
            }
            $t_str.="JOIN $t->{table} as $t->{alias} ON ($t->{link})";
            if(exists $t->{for_fields} && ref($t->{for_fields}) eq 'ARRAY' ){ # если есть for_fields -- определяем, нужно ли включать
                $need_add_table=0;
                foreach my $fld_name (@{$t->{for_fields}} ){
                    if(exists($form->{query_search}->{on_filters_hash}->{$fld_name})){
                        $need_add_table=1; last;
                    }
                }
            }
        }
        else{
            $t_str="`$t->{table}`  `$t->{alias}`"
        }


        if($need_add_table){
            push @{$TABLES},$t_str ;
            my $desc=$form->{self}->{db}->query(query=>"desc $t->{table}",errors=>$form->{log});
            #use Data::Dumper;
            #print Dumper($desc);
            if($desc){
                foreach my $db_field (@{$desc}){
                    if(!$t->{select_fields}  || ($t->{select_fields} && ref($t->{select_fields}) eq 'HASH' && $t->{select_fields}->{$db_field->{Field}})){
                        push @{$form->{query_search}->{SELECT_FIELDS}},qq{$t->{alias}.$db_field->{Field} $t->{alias}__$db_field->{Field}};
                    }
                        
                    #}
                    #else{
                    #    print "ignore: $t->{alias}.$db_field->{Field}\n";
                    #}
                    
                }
            }



        }
    }
    # не забываем дёрнуть db_name с func::

    $form->{query_search}->{TABLES}=$TABLES;

}
sub get_search_where{
=cut
    1. собирает заголовки таблицы результатов ($form->{SEARCH_RESULT}->{HEADERS})
    2. собирает входные данные для формирования запроса (select_fields, tables, where, order)
=cut
    my $form=shift; my $query=shift;
    my $alias_from_table; my $table_from_alias;
    my $WHERE=[];
    my $headers=[];
    unless( scalar(@{$query}) ){
        if($form->{default_find_filter}){
            if(ref($form->{default_find_filter}) ne 'ARRAY'){
                $form->{default_find_filter}=[split /,/,$form->{default_find_filter}];
            }
            foreach my $name (@{$form->{default_find_filter}}){
                if(my $f=$form->{fields_hash}->{$name}){

                    #my $header={h=>$f->{description},n=>$name,make_sort=>(!$form->{not_order} && !$f->{not_order})};
                    #if($form->{priority_sort} && $form->{priority_sort}->[0] eq $name){
                    #    $header->{sorted}=$form->{priority_sort}->[1]
                    #}
                    push @{$query},[$name,''];
                }
            }
        }
    }
    foreach my $q (@{$query}){
        my $name=$q->[0]; my $values=$q->[1];
        my $f=$form->{fields_hash}->{$name};
        # собираем сразу заголовки будущей таблицы
        
        my $header={h=>$f->{description},n=>$name,make_sort=>(!$form->{not_order} && !$f->{not_order})};
        if($form->{priority_sort} && $form->{priority_sort}->[0] eq $name){
            $header->{sorted}=$form->{priority_sort}->[1]
        }
        push @{$form->{SEARCH_RESULT}->{headers}},$header;



        my $db_name=$f->{db_name}?$f->{db_name}:$f->{name};
        my $table=($f->{tablename}?$f->{tablename}:'wt');
        
        if($f->{type}!~m(^(1_to_m|multiconnect|memo)$) && !$f->{not_order}){
            #print "type: $f->{type} ($f->{name})\n";
            my $o; my $operable_fld;
            
            if($f->{type}=~m{^(filter_extend_)?(date|ditetime)$}){
                $operable_fld="$table.$db_name";
                $o="$operable_fld desc"
            }
            elsif($f->{type_orig}=~m/^(filter_extend_)?(select_from_table)$/){
                $operable_fld="$table.$f->{header_field}";
                $o="$operable_fld";
                
            }
            else{
                $operable_fld="$table.$db_name";
                $o=$operable_fld;

            }
            #print "o: $o ($f->{type}) ; $operable_fld ; $o\n";

            if($form->{priority_sort}){
                if($form->{priority_sort}->[0] eq $name){
                    push @{$form->{query_search}->{ORDER}},$operable_fld.' '.(($form->{priority_sort}->[1] eq 'desc')?'desc':'');
                }
            }
            else{
                push @{$form->{query_search}->{ORDER}},$o;
            }
            
        }

        

        next if((ref($values) eq 'ARRAY' && !scalar(@{$values})) || !$values);
        if(ref($values) ne 'ARRAY'){
            $values=[$values]
        }

        if($f->{type}=~m/^(filter_extend_)?(text|textarea|email)$/){
            if(my $v=$values->[0]){
                $v=$form->{self}->{db}->{connect}->quote($v);
                $v=~s/^'/%/; $v=~s/'$/%/;
                push @{$WHERE},qq{ ($table.$db_name like "$v") };
            }
            
        }

        elsif(($f->{type}=~m/^(filter_extend_)?(date|datetime)$/ && !$f->{filter_type}) || $f->{filter_type} eq 'range'){
                my $min=$values->[0]; my $max=$values->[1];
                if($min=~m{^\d+-\d+-\d+(\s+\d+:\d+(:\d+)?)?$}){
                    push @{$WHERE}," ($table.$db_name>='$min') ";
                }
                
                if($max=~m{^\d+-\d+-\d+(\s+\d+:\d+(:\d+)?)?$}){
                    push @{$WHERE}," ($table.$db_name<='$max') ";
                }
        }
        elsif($f->{type} eq 'memo'){
            my $v=$values->[0];
            if($v->{registered_low}=~m{^\d+-\d+-\d+(\s+\d{2}:\d{2}:\d{2})?$}){
                push @{$WHERE}, qq{$f->{memo_table_alias}.$f->{memo_table_registered}>='$v->{registered_low}' }
            }
            if($v->{registered_hi}=~m{^\d+-\d+-\d+(\s+\d{2}:\d{2}:\d{2})?$}){
                push @{$WHERE}, qq{$f->{memo_table_alias}.$f->{memo_table_registered}<='$v->{registered_low}' }
            }
            if(my $m=$v->{message}){
                $m=$form->{self}->{db}->{connect}->quote($m);
                $m=~s/^'/%/; $m=~s/'$/%/;
                push @{$WHERE},qq{ ($f->{memo_table_alias}.$f->{memo_table_comment} like "$m") };
            }

            if($v->{user_id} && scalar(@{$v->{user_id}})){
                push @{$WHERE},qq{ ($f->{memo_table_alias}.$f->{memo_table_auth_id} IN (}.join(',',@{$v->{user_id}}).') )';
            }
        }
        elsif($f->{type_orig}=~m{^(filter_extend_)?(select_from_table)$}){
            push @{$WHERE}," ($table.$f->{value_field} IN (".join(',',@{$values}).") )";

        }
        else{ #if($f->{type}=~m/^(filter_extend_)?(select_from_table|select_values)$/){
            push @{$WHERE}," ($table.$db_name IN (".join(',', (
            map {
                if($_=~m{^\d+$}){
                    $_;
                }
                else{
                    "'$_'"
                }
                
            } @{$values}) ).") )";
            #print Dumper($WHERE);
        }

        
    }

    # если не было выбранных фильтров -- выводим заголовки согласно default_find_filter
    unless(scalar(@{$headers})){

    }

    $form->{query_search}->{WHERE}=$WHERE;


}
sub get_while_for_field_query{ # формирования условия поиска для запроса
    my ($form,$field,$values)=@_;
    if($field->{type} eq 'select_from_table'){
        my $tablename=$field->{tablename}?$field->{tablename}:'wt';

    }
}
return 1;