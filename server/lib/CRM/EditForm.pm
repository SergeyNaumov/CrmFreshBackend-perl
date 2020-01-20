use utf8;
use strict;
use CRM::FormFiles;
sub processEditForm{
    my %arg=@_;
    my $s=$Work::engine;
    my $config=$arg{config}; my $id=$arg{id};
    #$CRM::s=$s;
    
    my $form=CRM::read_conf(%arg);

    return unless($form);

    if($form->{action}=~m{^(insert|update)$}){
        if(defined $form->{make_create} && !$form->{make_create}){
            push @{$form->{errors}},"Вам запрещено создавать новые записи";
            $form->{read_only}=1;
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
        
        $s->print_json({
            success=>errors($form)?0:1,
            errors=>$form->{errors},
            log=>$form->{log},
            id=>"$form->{id}"
        });
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
    #print Dumper($save_hash);
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
    }



}
sub is_wt_field{
    my $f=shift;
    return ($f->{type}=~m/^(text|textarea|wysiwyg|select_from_table|select_values|date|time|datetime|yearmon|daymon|hidden|checkbox|switch|font-awesome|file)$/);
}




return 1;