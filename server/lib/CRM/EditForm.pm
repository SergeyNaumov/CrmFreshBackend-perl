use utf8;
use strict;
use CRM::FormFiles;
use CRM::in_ext_url;
sub processEditForm{
    my %arg=@_;
    my $s=$Work::engine;
    my $config=$arg{config}; my $id=$arg{id};
    #$CRM::s=$s;
    
    my $form=CRM::read_conf(%arg);
    

    return unless($form);

    if($form->{action}=~m/^(insert|new)$/ && $form->{not_create}){
        $form->{read_only}=1
    }
    if($form->{action}=~m{^(insert)$}){
        if($form->{not_create}){
            push @{$form->{errors}},"Вам запрещено создавать новые записи $form->{make_create}";
        }
    }

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
        my $response={
            success=>errors($form)?0:1,
            errors=>$form->{errors},
            log=>$form->{log},
            id=>"$form->{id}"
        };
        #if(!errors($form)){
        #    $form=CRM::read_conf(%arg);
        #    process_edit_form_fields($form);
        #    $response->{fields}=$s->clean_json($form->{edit_form_fields});
        #}

        $s->print_json($response);
    }
    elsif($form->{action} eq 'delete_file'){
        DeleteFile(form=>$form,'s'=>$s);
    }
    elsif($form->{action} eq 'upload_file'){
        #LoadBase64(form=>$form,'s'=>$s);
        UploadFile(form=>$form,'s'=>$s);
    }
    else{
        if($form->{action}=~m{^(new|edit)$}){
            if(scalar( @{$form->{errors}} ) ){
                $form->{read_only}=1;
            }
        }
        process_edit_form_fields($form);


        $s->print_json({
                    title=>$form->{title},
                    success=>scalar(@{$form->{errors}})?0:1,
                    errors=>$form->{errors},
                    fields=>$s->clean_json($form->{edit_form_fields}),
                    id=>$form->{id},
                    log=>$form->{log},
                    read_only=>$form->{read_only},
                    width=>$form->{width}?$form->{width}:'',
                    cols=>$form->{cols}?$form->{cols}:[],
                    config=>$form->{config}
        });
       # print "after_prin"
    }
    $s->end;
  

}

sub process_edit_form_fields{
    my $form=shift;
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
        elsif($f->{type} eq 'file' && $f->{value}){
            my $v=$f->{value};
            my ($filename_without_ext,$ext);
            if($v=~m/^(.+)\.([^\.]+)$/){
                ($filename_without_ext,$ext)=($1,$2);
            }
            if($f->{resize}){
                foreach my $r (@{$f->{resize}}){
                    my $file=$r->{file};
                    $file=~s/<%filename_without_ext%>/$filename_without_ext/g;
                    $file=~s/<%ext%>/$ext/g;
                    $r->{loaded}=$f->{filedir}.'/'.$file;
                    $r->{loaded}=~s/^\.\//\//;
                }
            }
        }
        #elsif($f->{type} eq 'select_from_table'){
        #    $f->{values}=get_values_for_select_from_table($f,$form,$s);
        #}
    }
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
        next if(!exists( $form->{new_values}->{$name}) );
        
        my $v=$form->{new_values}->{$name};

        if(is_wt_field($f)   ){ # значения для work_table
            # проверки, преобразования перед сохранением
            
            if($f->{type}=~m/^(select_values|select_from_table)$/ && !$v && $v ne '0'){
                next;
            }
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
                #print "$f->{name}: $v\n";
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
            if( ($f->{type} eq 'select_from_table' || $f->{type} eq 'select_values') && !defined($v)){
                
                next
            }

            $save_hash->{$name}=$v
        }

    }
    

    if(scalar keys(%{$save_hash}) ){
        if($form->{id}){
            my $where="$form->{work_table_id} = $form->{id}";
            if($form->{work_table_foreign_key} && $form->{work_table_foreign_key_value}){
                $where.=" AND $form->{work_table_foreign_key}=$form->{work_table_foreign_key_value}"
            }

            $form->{db}->save(
                table=>$form->{work_table},
                where=>$where,
                update=>1,
                data=>$save_hash,
                errors=>$form->{errors},
                debug=>$form->{explain}?1:0,
                log=>$form->{log}
            );
        }
        else{
            if($form->{work_table_foreign_key} && $form->{work_table_foreign_key_value}){
                $save_hash->{$form->{work_table_foreign_key}}=$form->{work_table_foreign_key_value};
            }
            my $id=$form->{db}->save(
                table=>$form->{work_table},
                data=>$save_hash,
                errors=>$form->{errors},
                debug=>$form->{explain}?1:0,
                log=>$form->{log}
            );
            $form->{id}=$id unless(errors($form));
        }
    }
    # Сохранили основную форму, получили ID, теперь сохраняем остальное:
    foreach my $f (@{$form->{fields}}){
        
        last if(errors($form));
        
        next if($f->{read_only} || !exists($form->{new_values}->{$f->{name}}) );
        my $value=$form->{new_values}->{$f->{name}};
        # Сохраняем Multiconnect
        if($f->{type} eq 'multiconnect'){ 
            
            if(defined($value) && ref($value) eq 'ARRAY'){
                CRM::Multiconnect::save(
                    form=>$form,
                    field=>$f,
                    's'=>$s,
                    new_values=>$form->{new_values}->{$f->{name}}
                );
            }
        }
        elsif($f->{type} eq 'in_ext_url'){
            save_in_ext_url( # in_ext_url.pm
                's'=>$s,
                form=>$form,
                value=>$value,
                field=>$f
            );
            
        }
    }



}





return 1;