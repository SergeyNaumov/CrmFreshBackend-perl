use utf8;
use strict;
use POSIX;

sub admin_table_find{ # Поиск результатов
    my $s=$Work::engine; my $R=shift;
    
    #$R={config=>'manager'} unless($R);

    my $form=read_conf(config=>$R->{config},script=>'find_objects');
    
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

    get_search_tables($s,$form,$R->{query});
    get_search_where($s,$form,$R->{query});

    run_event(
        event=>$form->{events}->{before_search},
        description=>'events->before_search',
        form=>$form,
        arg=>[
            tables=>join(" ",@{$form->{query_search}->{TABLES}}),
            where=>join(" AND ",@{$form->{query_search}->{WHERE}})
        ]
    );
    
    my ($query,$query_count)=gen_query_search($s,$form);

    my $total_count=$s->{db}->query(query=>qq{select sum(cnt) from ($query_count) x},onevalue=>1,errors=>$form->{errors});
    $form->{SEARCH_RESULT}->{count_total}=$total_count;
    $form->{SEARCH_RESULT}->{count_pages}=($form->{not_perpage})?1:( ceil($total_count/$form->{perpage}) );

    # Если мы запрашиваем страницу, которой нет -- отдаём первую страницу
    if($form->{page} > $form->{SEARCH_RESULT}->{count_pages}){
        $form->{page}=1;
    }

    my $debug_explain;
    my $log=[];
    my $result_list=$s->{db}->query(
        query=>$query,
        errors=>$form->{errors},
        #log=>$log,
        #debug=>$form->{explain}
    );
    if($form->{explain}){
        $form->{explain_query}=$query;#$debug_explain->{query}
    }


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
    my @id_list=();
    foreach my $r (@{$result_list}){
        push @id_list,$r->{wt__id};
        #print "r: $r->{wt__id}\n";

    }
    
    my $multiconnect_values;
    if(scalar (@id_list) ){
        foreach my $q (@{$R->{query}}){
            my $name=$q->[0];
            my $values=$q->[1]; 
            my $field=$form->{fields_hash}->{$name};
            if($field->{type} eq 'multiconnect' && scalar( @id_list ) ){
                # multiconnect, получаем список тэгов
                $multiconnect_values=
                {
                    map { $_->{id}=>$_->{header} }
                    @{$s->{db}->query(
                        query=>qq{
                            SELECT
                                rst.$field->{relation_save_table_id_worktable} id,
                                group_concat(rt.$field->{relation_table_header} SEPARATOR ',') header
                            FROM
                                $field->{relation_save_table} rst
                                join $field->{relation_table} rt ON (rt.$field->{relation_table_id} =rst.$field->{relation_save_table_id_relation})
                            WHERE
                                rst.$field->{relation_save_table_id_worktable} IN (}.join(',',@id_list).qq{)
                            GROUP BY rst.$field->{relation_save_table_id_worktable}
                            },
                        
                    )}
                };

            }
        }
    }

    
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
            $field->{type_orig}=$field->{type} unless($field->{type_orig});
            #print "$field->{name} $field->{type_orig}=> $field->{type}\n";
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

            my $type='html';

            if(!$field->{make_change_in_search} && ref($field->{filter_code}) eq 'CODE'){
                $value=&{$field->{filter_code}}({str=>$r,value=>$value});
            }
            else{
                    #print "ZZZ ($field->{type_orig})\n";
                    if($field->{type} eq 'memo'){
                        $type='memo'
                    }
                    elsif($field->{type} eq 'multiconnect'){
                        $type='multiconnect';
                        $value=$multiconnect_values->{$r->{wt__id}};
                        $value='' unless($value);
                    }
                    elsif($field->{type}=~m{^font}){
                        $type=$field->{type};
                    }
                    elsif($field->{type_orig}=~m/^(checkbox|switch)$/){
                        if($field->{make_change_in_search}){
                            $type=$field->{type}
                        }
                        else{
                            $value=$value?'да':'нет'
                        }
                        
                    }
                    elsif($field->{type_orig}=~m/^filter_extend_(checkbox|switch)$/){
                        $value=$value?'да':'нет'
                    }
                    elsif($field->{type_orig}=~m{^(filter_extend_)?select_from_table}){
                        #print "This!\n";
                        if($field->{make_change_in_search}){
                            $type='select';
                            $value=$r->{$tbl.'__'.$field->{value_field}};
                            if(!$form->{SEARCH_RESULT}->{selects}->{$field->{name}}){
                                $form->{SEARCH_RESULT}->{selects}->{$field->{name}}=$field->{values}
                            }   
                        }
                        else{

                            if($r->{$tbl.'__'.$field->{header_field}}){
                                #print "tbl: $field->{tablename}\n";
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
                    elsif($field->{type_orig}=~m{^(filter_extend_)?(text|textarea)}){
                        my $t=$2;
                        if($field->{make_change_in_search}){
                            $type=$t; 
                        }
                        $value=$r->{$tbl.'__'.$db_name};
                    }
                    elsif($field->{type_orig} eq 'password'){
                        $value='[пароль нельзя увидеть]'
                    }
                    elsif($field->{type_orig} eq 'in_ext_url'){
                        $value=$r->{in_ext_url__ext_url}
                    }
            }
            
            push @{$data},{name=>$name,type=>$type,value=>$value};
            
            #print "v: $value\n";
        }
        push @{$output},{key=>$r->{wt__id},data=>$data};
    }
    
    $form->{SEARCH_RESULT}->{log}=$form->{log};
    $form->{SEARCH_RESULT}->{output}=$output; 
    $form->{explain_query}='' unless($form->{explain_query});
    $form->{out_before_search}=[] unless($form->{out_before_search});
    $s->print_json(
        $s->clean_json({
            success=>errors($form)?0:1,
            results=>$form->{SEARCH_RESULT},
            errors=>$form->{errors},
            out_before_search=>$form->{out_before_search},
            explain_query=>$form->{explain_query}
        })
    )->end;
    
}

sub gen_query_search{
    # получаем поисковый запрос на основе $form->{query_search}
    my $s=shift; my $form=shift;
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
    if($qs->{HAVING} && scalar(@{$qs->{HAVING}})){
        $query.=" HAVING ".join(' AND ',@{$qs->{HAVING}})
    }

    if($qs->{ORDER}){
        if(ref($qs->{ORDER}) ne 'ARRAY'){
            $qs->{ORDER}=[$qs->{ORDER}]
        }
        if( scalar(@{$qs->{ORDER}}) ){
            $query.=" ORDER BY ".join(', ',@{$qs->{ORDER}})
        }
    }



    if(!$form->{not_perpage}){
        $query.=" LIMIT ".($form->{page}-1)*$form->{perpage}.', '.($form->{perpage})
    }
    my $query_count;

    if( scalar @{$qs->{GROUP}} ){
        #pre(1);
        $query_count=q{
        SELECT count(*) cnt FROM (
            select }.join(',',@{$qs->{SELECT_FIELDS}}).' FROM '.join("\n",@{$qs->{TABLES}}).
            (
                scalar(@{$qs->{WHERE}})?(" WHERE ".join(' AND ',@{$qs->{WHERE}})):''
            ).
            (
                scalar(@{$qs->{GROUP}})?(" GROUP BY ".join(', ',@{$qs->{GROUP}})):''
            ).
            (
               $qs->{HAVING} && scalar(@{$qs->{HAVING}})?(" HAVING ".join(', ',@{$qs->{HAVING}})):''
            ).
        ') x';
        #pre($query_count);
    }
    else{
       # pre(2);
        $query_count="SELECT count(*) cnt FROM ".join("\n",@{$qs->{TABLES}}).
        (
            scalar(@{$qs->{WHERE}})?(" WHERE ".join(' AND ',@{$qs->{WHERE}})):''
        ).
        (
            scalar(@{$qs->{GROUP}})?(" GROUP BY ".join(', ',@{$qs->{GROUP}})):''
        ).
        (
           $qs->{HAVING} && scalar(@{$qs->{HAVING}})?(" HAVING ".join(', ',@{$qs->{HAVING}})):''
        )
        ;
    }
    

    return ($query,$query_count);
    
}
sub get_search_tables{
    my $s=shift; my $form=shift; my $query=shift;
    my $TABLES=[];

    # in_ext_url -- добавление таблицы
    if( scalar(@{$form->{QUERY_SEARCH_TABLES}}) ){
        foreach my $f (@{$form->{fields}}){
            if($f->{type} eq 'in_ext_url'){
                my $in_ext_url=$f->{in_url};
                if($in_ext_url=~m/^(.*)<%id%>(.*)$/){
                    my ($x1,$x2)=($1,$2);
                    my @for_concat_val=();
                    if($x1){
                        push @for_concat_val,qq{'$x1'}
                    }
                    push @for_concat_val,'wt.id';
                    if($x2){
                        push @for_concat_val,qq{'$x2'}
                    }
                    my $concat='concat('.join(', ',@for_concat_val).')';
                    #print Dumper(\@for_concat_val);
                    #print Dumper();
                    if($f->{foreign_key} && $f->{foreign_key_value}=~m/^\d+$/){
                        push @{$form->{QUERY_SEARCH_TABLES}},{t=>'in_ext_url',a=>'in_ext_url',l=>"in_ext_url.in_url=$concat and in_ext_url.$f->{foreign_key}=$f->{foreign_key_value}",lj=>1,for_fields=>[$f->{name}]}
                    }
                    else{
                        push @{$form->{QUERY_SEARCH_TABLES}},{t=>'in_ext_url',a=>'in_ext_url',l=>"in_ext_url.in_url=$concat",lj=>1,for_fields=>[$f->{name}]}
                    }
                }
                else{
                    push @{$form->{errors}},"в элементе $f->{name} ($f->{description} не корректное значение in_url";
                }

                
            }
        }
    }

    #print Dumper($form->{QUERY_SEARCH_TABLES});
    my $aliases_on={wt=>1};

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
            if(!$t->{not_add_in_select_fields}){
                
                my $desc=$s->{db}->query(query=>"desc $t->{table}",errors=>$form->{log});
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
            
            
            #print Dumper($desc);




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
    my $s=shift; my $form=shift; my $query=shift;
    my $alias_from_table; my $table_from_alias;
    my $WHERE=[];
    my $headers=[];
    $form->{SEARCH_RESULT}->{query_fields}=[];
    unless( scalar(@{$query}) ){
        if($form->{default_find_filter}){
            if(ref($form->{default_find_filter}) ne 'ARRAY'){
                $form->{default_find_filter}=[split /,/,$form->{default_find_filter}];
            }
            foreach my $name (@{$form->{default_find_filter}}){
                if(my $f=$form->{fields_hash}->{$name}){
                    push @{$form->{SEARCH_RESULT}->{query_fields}},$f;
                    #my $header={h=>$f->{description},n=>$name,make_sort=>(!$form->{not_order} && !$f->{not_order})};
                    #if($form->{priority_sort} && $form->{priority_sort}->[0] eq $name){
                    #    $header->{sorted}=$form->{priority_sort}->[1]
                    #}
                    push @{$query},[$name,''];
                }
            }
        }
    }
    $form->{query_hash}={};
    foreach my $q (@{$query}){
        my $name=$q->[0]; my $values=$q->[1];
        my $f=$form->{fields_hash}->{$name};
        $form->{query_hash}->{$name}=$values;
        # собираем сразу заголовки будущей таблицы
        push @{$form->{SEARCH_RESULT}->{query_fields}},$f;
        my $header={h=>$f->{description},n=>$name,make_sort=>(!$form->{not_order} && !$f->{not_order})};
        if($form->{priority_sort} && $form->{priority_sort}->[0] eq $name){
            $header->{sorted}=$form->{priority_sort}->[1]
        }
        push @{$form->{SEARCH_RESULT}->{headers}},$header;


        next if($f->{not_process});
        my $db_name=$f->{db_name}?$f->{db_name}:$f->{name};
        my $table=($f->{tablename}?$f->{tablename}:'wt');
        if($f->{type} eq 'multiconnect'){
                
                #push @{$form->{query_search}->{SELECT_FIELDS}},"group_concat($f->{tablename}.$f->{relation_table_header} SEPARATOR ', ') $f->{tablename}__$f->{name}" ;
                
                #print Dumper($form->{query_search}->{SELECT_FIELDS});
        }
        elsif($f->{type}!~m(^(1_to_m|memo)$) && !$f->{not_order}){
            #print "type: $f->{type} ($f->{name})\n";
            my $o; my $operable_fld;
           # if($f->{type} eq 'multiconnect'){
                #$o="$f->{tablename}.$f->{relation_table_header}";
            #}
            if($f->{type}=~m{^(filter_extend_)?(date|ditetime)$}){
                $operable_fld="$table.$db_name";
                $o="$operable_fld desc"
            }
            elsif($f->{type_orig}=~m/^(filter_extend_)?(select_from_table)$/){
                $operable_fld="$table.$f->{header_field}";
                $o="$operable_fld";
                
            }
            elsif($f->{type} eq 'in_ext_url'){
                $operable_fld="in_ext_url.ext_url";
                $o=$operable_fld;
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
                $v=$s->{db}->{connect}->quote($v);
                $v=~s/^'/%/; $v=~s/'$/%/;
                push @{$WHERE},qq{ ($table.$db_name like "$v") };
            }
            
        }

        elsif(($f->{type}=~m/^(filter_extend_)?(date|datetime)$/ && !$f->{filter_type}) || $f->{filter_type} eq 'range'){
                my $min=$values->[0]; my $max=$values->[1];
                if($min=~m{^\d+-\d+-\d+(\s+\d+:\d+(:\d+)?)?$}){
                    if($min=~m/^\d+-\d+-\d+$/){
                        $min.=' 00:00:00';
                    }
                    push @{$WHERE}," ($table.$db_name>='$min') ";
                }
                
                if($max=~m{^\d+-\d+-\d+(\s+\d+:\d+(:\d+)?)?$}){
                    if($max=~m/^\d+-\d+-\d+$/){
                        $max.=' 23:59:59';
                    }
                    push @{$WHERE}," ($table.$db_name<='$max') ";
                }
        }
        elsif($f->{type} eq 'memo'){
            my $v=$values->[0];
            if($v->{registered_low}=~m{^\d+-\d+-\d+(\s+\d{2}:\d{2}:\d{2})?$}){
                
                if($v->{registered_low}=~m/^\d+-\d+-\d+$/){
                    $v->{registered_low}.=' 00:00:00'
                }
                push @{$WHERE}, qq{$f->{memo_table_alias}.$f->{memo_table_registered}>='$v->{registered_low}' }
            }
            if($v->{registered_hi}=~m{^\d+-\d+-\d+(\s+\d{2}:\d{2}:\d{2})?$}){
                
                if($v->{registered_hi}=~m/^\d+-\d+-\d+$/){
                    $v->{registered_hi}.=' 23:59:59'
                }
                push @{$WHERE}, qq{$f->{memo_table_alias}.$f->{memo_table_registered}<='$v->{registered_hi}' }
            }
            if(my $m=$v->{message}){
                $m=$form->{db}->{connect}->quote($m);
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
        elsif($f->{type} eq 'multiconnect'){
            #print Dumper({multiconnect=>$values,f=>$f});
            if(!$f->{tablename}){
                push @{$form->{errors}},"не указано tablename для $f->{name}";
            }
            else{
                my @values = grep /^\d+$/, @{$values};
                if( scalar @values ){
                    push @{$WHERE},"$f->{tablename}.$f->{relation_table_id} in (".join(',',@values).')'
                }
            }
            
        }
        elsif($f->{type} eq 'in_ext_url'){
           # print Dumper({name=>$f->{name},values=>$values});
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
    #print Dumper($form->{query_hash});
    # если не было выбранных фильтров -- выводим заголовки согласно default_find_filter
    unless(scalar(@{$headers})){

    }

    $form->{query_search}->{WHERE}=$WHERE;


}
sub get_result{
    my $s=$Work::engine;
    $s->print_header({'content-type'=>'text/html'});
    my $R=$s->request_content();
    if($R){
        $R=$s->from_json($R);
    }

    admin_table_find($R);
}
sub get_while_for_field_query{ # формирования условия поиска для запроса
    my ($form,$field,$values)=@_;
    if($field->{type} eq 'select_from_table'){
        my $tablename=$field->{tablename}?$field->{tablename}:'wt';

    }
}
return 1;