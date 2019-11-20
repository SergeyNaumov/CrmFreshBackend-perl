use utf8;
use strict;
sub processEditForm{
    my %arg=@_;
    my $s=$Work::engine;
    my $config=$arg{config}; my $id=$arg{id};
    #$CRM::s=$s;
    
    my $form=CRM::read_conf(%arg);
    return unless($form);
    
    #print "zz! $form->{action}\n";
    if($form->{action}=~m/^(update|insert)$/){
        run_event(
            event=>$form->{events}->{permissions},
            description=>'events->permissions',
            form=>$form
        );
        push @{$form->{errors}},'Вам запрещено сохранять изменения в форму' if($form->{read_only});
        
        if(!errors($form)){
            run_event(event=>$form->{events}->{before_update},description=>'events.before_update',form=>$form) if($form->{action} eq 'update');
            run_event(event=>$form->{events}->{before_insert},description=>'events.before_insert',form=>$form) if($form->{action} eq 'insert');
            run_event(event=>$form->{events}->{before_save},description=>'events.before_save',form=>$form) if(!errors($form));
        }
        
        save_form(form=>$form,'s'=>$s);
        
        if(!errors($form)){

            run_event(event=>$form->{events}->{after_update},description=>'events.after_update',form=>$form) if($form->{action} eq 'update');
            run_event(event=>$form->{events}->{after_insert},description=>'events.after_insert',form=>$form) if($form->{action} eq 'insert');
            run_event(event=>$form->{events}->{after_save},description=>'events.after_save',form=>$form) if(!errors($form));
            
        }
        
        $s->print_json({
            success=>errors($form)?0:1,
            errors=>$form->{errors},
            log=>$form->{log},
            id=>"$form->{id}"
        });
    }
    else{
        if($form->{action}=~m{^(new|edit)$} && scalar( @{$form->{errors}} )) {
            $form->{read_only}=1;
            #$form->{edit_form_fields}=[]
        }


        foreach my $f (@{$form->{edit_form_fields}}){
            # убираем то, что пользователю видеть ни к чему
            if($f->{type} eq 'password'){
                delete($f->{encrypt_method}) if(exists $f->{encrypt_method});
                if($f->{methods_send} && ref($f->{methods_send}) eq 'ARRAY'){
                    foreach my $m (@{$f->{methods_send}}){
                        delete $m->{code}
                    }
                }

            }
            #elsif($f->{type} eq 'select_from_table'){
            #    $f->{values}=get_values_for_select_from_table($f,$form,$s);
            #}
        }
        $s->print_json({
                    title=>$form->{title},
                    success=>scalar(@{$form->{errors}})?0:1,
                    errors=>$form->{errors},
                    fields=>CRM::get_clean_json($form->{edit_form_fields}),
                    id=>$form->{id},
                    log=>$form->{log},
                    read_only=>$form->{read_only},
                    cols=>$form->{cols}?$form->{cols}:[],
                    config=>$form->{config}
        });
       # print "after_prin"
    }
    $s->end;
  

}


sub save_form{
    my %arg=@_;
    my $form=$arg{form}; my $s=$arg{'s'};
    return if(errors($form));
    my $save_hash={};
    
    
    foreach my $f (@{$form->{fields}}){
        if($f->{read_only} || $f->{not_process}){
            next
        }
        my $name=$f->{name};
        
        
        if(is_wt_field($f) && exists( $form->{new_values}->{$name} ) ){ # значения для work_table
            # проверки, преобразования перед сохранением
            my $v=$form->{new_values}->{$name};

            if($f->{type} eq 'date'){
                unless($v=~m/^\d{4}-\d{2}-\d{2}/){
                    if($form->{engine} eq 'mysql-strong' || $f->{empty_value} eq 'null'){
                        $v='func::NULL'
                    }
                    else{
                        $v='0000-00-00'
                    }
                }

                
            }
            elsif($f->{type} eq 'time'){
                unless($v){
                    $v='00:00:00'
                }
                print "$f->{name}: $v\n";
            }
            elsif($f->{type} eq 'datetime'){
                if(!$v || $v=~/^\s*$/){
                    if($form->{engine} eq 'mysql-strong' || $f->{empty_value} eq 'null'){
                        $v='func::NULL';
                    }
                    else{
                        $v='0000-00-00 00:00:00'
                    }
                }
            }

            $save_hash->{$name}=$v
        }
    }

    if(scalar keys(%{$save_hash}) ){
        if($form->{id}){
            $s->{db}->save(
                table=>$form->{work_table},
                where=>"$form->{work_table_id} = $form->{id}",
                update=>1,
                data=>$save_hash,
                errors=>$form->{errors},
                debug=>$form->{explain}?1:0
            );
        }
        else{
            my $id=$s->{db}->save(
                table=>$form->{work_table},
                data=>$save_hash,
                errors=>$form->{errors},
                debug=>$form->{explain}?1:0
            );
            $form->{id}=$id unless(errors($form));
        }
    }
    # Сохранили основную форму, получили ID, теперь сохраняем остальное:
    foreach my $f (@{$form->{fields}}){
        next if($f->{read_only});
        last if(errors($form));
        # Сохраняем Multiconnect
        if($f->{type} eq 'multiconnect'){ 
            my $value=$form->{new_values}->{$f->{name}};
            if(defined($value) && ref($value) eq 'ARRAY'){
                CRM::Multiconnect::save(
                    form=>$form,
                    field=>$f,
                    's'=>$s,
                    new_values=>$form->{new_values}->{$f->{name}}
                );
            }
            
        }
        elsif($f->{type} eq 'file'){ # Сохраняем файл

        }
        


    }



}
sub is_wt_field{
    my $f=shift;
    return ($f->{type}=~m/^(text|textarea|wysiwyg|select_from_table|select_values|date|time|datetime|yearmon|daymon|hidden|checkbox|switch|font-awesome)$/);
}
sub get_values_form{ # получаем старые значения для формы (до редактирования, )
    my %arg=@_;
    my $form=$arg{form}; my $s=$arg{'s'};
    my $values={};
    if($form->{id}){
        $values=$s->{db}->query(
            query=>qq{SELECT * from $form->{work_table} where $form->{work_table_id}=?},
            values=>[$form->{id}],
            onerow=>1,
        );

        if(!$values){
            push @{$form->{errors}},qq{В инструменте $form->{title} запись с id: $form->{id} не найдена. Редактирование невозможно};
            return ;
        }
        # удаляем из хеша значения полей типа password
        foreach my $f (@{$form->{fields}}){
            if($f->{type} eq 'password'){
                delete $values->{$f->{name}};
            }

        }
        
    }
    foreach my $f (@{$form->{fields}}){
        next if($f->{type}=~m{^(filter_)});
        my $name=$f->{name};

        if(defined($values->{$name}) && is_wt_field($f) ){ # $f->{type}=~m{^(date|datetime|select_from_table|hidden|select_from_table|select_values|text|checkbox|switch|textarea)$}
            $f->{value}=$values->{$name}
        }
        
        if($form->{action}!~m{^(insert|update)$} && $f->{type} eq 'select_from_table'){
            $f->{type_orig}=$f->{type}; $f->{type}='select'; 
            $f->{values}=get_values_for_select_from_table($f,$form);
            foreach my $v (@{ $f->{values} }){
                if($v->{v}==$f->{value}){
                    #$f->{vuetify_value}=$v
                }
            }
        }
        elsif($form->{action}!~m{^(insert|update)$} && $f->{type} eq 'select_values'){
            $f->{type_orig}=$f->{type}; $f->{type}='select';
        }
        elsif($f->{type} eq '1_to_m'){
          OneToM::get_1_to_m_data(form=>$form,'s'=>$s,field=>$f);

          
        }
        if(exists($f->{before_code}) && ref($f->{before_code}) eq 'CODE'){
            #&{$f->{before_code}}($f);
            run_event(event=>$f->{before_code},description=>'before code for '.$name,form=>$form,arg=>$f);
        }
        if(ref($f->{code}) eq 'CODE'){
          #print "code: $name\n";
            $f->{after_html}=run_event(event=>$f->{code},description=>'code for '.$name,form=>$form,arg=>$f);
            #print "$f->{after_html}\n\n";
            #$f->{before_html}=&{$f->{code}}($f);
            #$f->{before_html}=$f->{after_html}='ZZZZ';
        }

        #my $field=($f);
        if($f->{value}=~m/^\d+$/){ # в json-е должны быть только строки
            $f->{value}="$f->{value}"
        }
        push @{$form->{edit_form_fields}},$f;
    }
    return $values;
}

return 1;