package CRM::AdminTree;
use utf8;
use strict;
use CRM;
sub init{ # отдаём информацию о дереве
    my %arg=@_;
    my $s=$arg{'s'};

    my $data=$s->request_content(from_json=>1);
    my ($parent_id,$action,$id);
    if($data){
        if($data->{action}){
            $action=$data->{action};
            $parent_id=$data->{parent_id};
            $id=$data->{id};
        }
    }
    my $form=CRM::read_conf(config=>$arg{config},script=>$arg{script},action=>$action,id=>$id);
    CRM::set_default_attributes($form);
    $form->{id}=$id;

    
    

#print "action: $form->{action}\n";
if($form->{action} eq 'add_branch_plain'){
        my $h=$data->{header};
        if(!$parent_id || $parent_id!~m/^\d+$/){
            $parent_id=undef;
        }
        if($h){
                my $cur_path=''; my $cur_sort=0; 

                if($parent_id && $parent_id=~m{^\d+$}){
                    $cur_path=$form->{db}->query(
                        query=>"SELECT path from $form->{work_table} where $form->{work_table_id}=?",
                        values=>[$parent_id],
                        onevalue=>1
                    ).qq{/$parent_id};
                }
                if($form->{sort}){
                    my $qw='';
                    if($form->{tree_use}){
                      $qw="SELECT max($form->{sort_field}) from $form->{work_table}";
                      if($parent_id){
                    $qw.=" WHERE parent_id=$parent_id";
                      }
                      else{
                    $qw.=" WHERE parent_id is NULL";
                      }
                    }
                    else{
                        $qw="SELECT max($form->{sort_field}) from $form->{work_table}";
                    }

                    $cur_sort=$form->{db}->query(query=>$qw,onevalue=>1);

                    $cur_sort++;
                }



                my $sql_query;
                my @values=();
                my @fields=();
                my $data={};
                if($form->{tree_use}){ # Дерево
                    if($parent_id){ # для каскадного удаления нужно, чтобы parent_id на нулевом уровне был  NULL
                        

                        $data={
                            $form->{header_field}=>$h,
                            parent_id=>$parent_id,
                            path=>$cur_path
                        };
                        

                        if($form->{sort}){
                            $data->{$form->{sort_field}}=>$cur_sort
                        }
                    }
                    else{
                        $data={
                            $form->{header_field}=>$h,
                            path=>$cur_path
                        };
                        if($form->{sort}){
                            $data->{$form->{sort_field}}=$cur_sort;
                        }

                    }
                }
                else{
                    #@values=($h);
                    $data={
                            $form->{header_field}=>$h
                    };
                    if($form->{sort}){
                        $data->{$form->{sort_field}}=$cur_sort
                    }


                }

                if($form->{work_table_foreign_key}=~m/^[a-z0-9_\-]+$/ && $form->{work_table_foreign_key_value}=~m/^\d+$/){
                    $data->{$form->{work_table_foreign_key}}=$form->{work_table_foreign_key_value};
                }
                
                #print "!!!!EVENTS!\n";
                # EVENTS!!!!
                $form->{new_values}=$data;
                CRM::run_event(event=>$form->{events}->{before_insert},description=>'events.before_insert',form=>$form);
                CRM::run_event(event=>$form->{events}->{before_save},description=>'events.before_save',form=>$form);
                my $vopr= join ",",(split //,("?"x ($#fields+1)));
                $form->{id}=$form->{db}->save(
                    table=>$form->{work_table},
                    data=>$data
                );

                # EVENTS!!!!
                CRM::run_event(event=>$form->{events}->{after_insert},description=>'events.after_insert',form=>$form);
                CRM::run_event(event=>$form->{events}->{after_save},description=>'events.after_save',form=>$form);
               
                my $obj={
                    id=>$form->{id},
                    sort=>$cur_sort,
                    header=>$h,
                    childs=>[]
                };
                $s->print_json({
                    success=>1,
                    data=>$obj
                })->end; return;
        }
    }
elsif($form->{action} eq 'get_branch' && $parent_id){
    my $branch=get_branch('s'=>$s,form=>$form,parent_id=>$parent_id);
    $s->print_json({
        success=>1,
        data=>$branch
    })->end; return;
}
elsif($form->{action} eq 'delete_branch'){
    if($form->{make_delete}){
            my $id=$form->{id};
            if($id=~m/^\d+$/ && $id>0){
                    # Удаляем элемент
                    my $where=[qq{$form->{work_table_id}=$id}];


                    add_where_foreign_key($form,$where);
                    my $cur_branch=$form->{db}->query(query=>qq{SELECT * from $form->{work_table} where $form->{work_table_id}=$id},onerow=>1);


                    my $query=add_where_to_query("DELETE FROM $form->{work_table}",$where);
                     $form->{db}->query(query=>$query);

                    # # Удаляем все дочерние элементы
                    if($form->{tree_use}){
                         my $where=[qq{path like '%/$id/%' or path like '/%$id'}];
                         add_where_foreign_key($form,$where);
                         my $query=add_where_to_query("DELETE FROM $form->{work_table}",$where);
                         if($query=~m{ where }i){
                            $form->{db}->query(query=>$query);
                        }

                    }
                    # После удаления смотрим, сколько записей осталось в тек. ветке
                    my $cur_count=0;
                    if($form->{tree_use} && $cur_branch->{parent_id}){
                        $cur_count=$form->{db}->query(
                            query=>"SELECT count(*) from $form->{work_table} where parent_id=?",
                            values=>[$cur_branch->{parent_id}],
                            onevalue=>1
                        );

                    }
                    else{
                        $cur_count=$form->{db}->query(
                            query=>"SELECT count(*) from $form->{work_table}",
                            onevalue=>1
                        );
                    }
                    
                    $s->print_json({success=>1,cur_count=>$cur_count,cur_branch=>$cur_branch})->end; return;
            }
            else{
                $s->print_json({success=>0,error=>'Не указан id!'})->end; return;
                
            }
    }
    else{

        $s->print_json({success=>0,error=>'Удаление запрещено!'})->end; return;
    }
    
}
elsif($form->{action} eq 'sort'){
    if($form->{sort}){
        my $where=["$form->{work_table_id}=?"];
        add_where_foreign_key($form,$where);
        push @{$where},"parent_id=$parent_id" if($parent_id);
        my $query=add_where_to_query("UPDATE $form->{work_table} SET sort=?",$where);
        foreach my $id (keys(%{$data->{obj_sort}})){
            $form->{db}->query(query=>$query,values=>[$data->{obj_sort}->{$id},$id]);
        }
        $s->print_json({success=>1,errors=>[]})->end;
    }
    else{
        $s->print_json({success=>0,errors=>['Сортировка запрещена']});
    }
    $s->end; return;
    
}
elsif($form->{action} eq 'update_branch'){
    if(!$form->{read_only}){
        if($form->{id}){
            $form->{db}->query(query=>"UPDATE $form->{work_table} SET $form->{header_field}=? WHERE $form->{work_table_id}=?",values=>[$data->{header},$form->{id}]);
            $s->print_json({success=>1});
        }
        else{
            $s->print_json({success=>0,error=>'Не указан id'});
        }
    }
    else{
        $s->print_json({success=>0,error=>'Редактирование запрещено!'});
    }
    $s->end; return;
}
elsif($form->{action} eq 'move'){ # перенос объекта из ветки в ветку
    my ($to,$id)=($data->{to},$data->{id});
    if($id!~m/^\d+$/){
        push @{$form->{errors}},'Параметр id не указан, обратитесь к разработчику';
    }
    elsif($form->{read_only} || !$form->{tree_use}){
        push @{$form->{errors}},'Запрещено перемещать элементы в дереве! операция не выполнена';
    }
    elsif($to!~m{^\d+$}){
        push @{$form->{errors}},'Параметр to не указан, обратитесь к разработчику';
    }
    elsif($to eq $id){
        push @{$form->{errors}},'Нельзя перенести в себя';
    }
    else{
        # всё хорошо, переносим
        my ($from_path,$to_path)=('','');
        #$form->{db}->query(query=>"s");
        if($to){
            my $to_item=$form->{db}->query(query=>"SELECT * from $form->{work_table} WHERE $form->{work_table_id}=?",values=>[$to],onerow=>1);
            if($to_item){
               $to_path=$to_item->{path} 
            }
            else{
                push @{$form->{errors}},'в базе отсутствует элемент-приёмник. Возможно, состояние базы было изменено'
            }
        }
        
        my $from_item=$form->{db}->query(query=>"SELECT * from $form->{work_table} WHERE $form->{work_table_id}=?",values=>[$id],onerow=>1);
        if($from_item){
            $from_path=$from_item->{path} 
        }
        else{
            push @{$form->{errors}},'в базе отсутствует элемент-источник. Возможно, состояние базы было изменено'
        }
        

        unless(scalar(@{$form->{errors}})){
            # переносим
            #print "to: $to ; to_path: $to_path\n";
            # обновляем перемещаемый элемент
             if($to){$to_path.="/$to"}
                else{$to='null'}

            $form->{db}->query(
                query=>"UPDATE $form->{work_table} SET parent_id=$to, path=? WHERE $form->{work_table_id}=?",
                values=>[$to_path,$id]
            );
            # обновляем дочерние элементы
            my $childs=$form->{db}->query(
                query=>"SELECT $form->{work_table_id} id, path from $form->{work_table} WHERE path=? OR path like ?",
                values=>["$from_path/$id", "$from_path/$id/%"]
            );
            foreach my $c  (@{$childs}){
                my $path=$c->{path};
                $path=~s|^$from_path$|$to_path|;
                $path=~s|^$from_path\/(.+)$|$to_path\/$1|;
                $form->{db}->query(
                    query=>"UPDATE $form->{work_table} SET path=? WHERE $form->{work_table_id}=?",
                    values=>[$path,$c->{id}],
                );
            }

        }
    }


    #print "id: $id; to: $to\n";
    $s->print_json({
        success=>scalar(@{$form->{errors}})?0:1,
        errors=>$form->{errors}
    })->end;
    return ;
}

# По умолчанию
    my $branch=get_branch('s'=>$s,form=>$form,get_childs=>1);
    if(scalar(@{$form->{errors}})){
        $s->print_json({
            success=>0,
            errors=>$form->{errors}
        })->end;
        return;
    }

    $s->print_json({
        success=>1,
        form=>{
            sort=>$form->{sort}?1:0,
            title=>$form->{title},
            header_field=>$form->{header_field},
            sort_field=>$form->{sort_field}?$form->{sort_field}:'sort',
            config=>$form->{config},
            not_create=>($form->{read_only} || $form->{not_create})?1:0,
            tree_use=>$form->{tree_use}?1:0,
            make_delete=>defined($form->{make_delete})?$form->{make_delete}:1,
            read_only=>$form->{read_only}?1:0,
            max_level=>$form->{max_level}?$form->{max_level}:0,
        },
        log=>$form->{log},
        errors=>$form->{errors},
        tree=>$branch
    })->end;
}

sub get_branch{
    my %arg=@_;
    my ($s,$form)=($arg{'s'},$arg{form});
    my $parent_id=$arg{parent_id}?$arg{parent_id}:undef;
    
    my $where=[];
    my $cur_level=0; # Уровень вложенности в дерево
    my $branch={path=>[],list=>[]};

    if($parent_id){ # Если находимся не в корне, то собираем $branch->{path} (путь ветки)
        push @{$where},qq{$form->{work_table_id}=$parent_id};
        add_where_foreign_key($form,$where);

        my $query_path=qq{SELECT path from $form->{work_table}};
        if(scalar(@{$where})){
            $query_path.=qq{ WHERE }.join(' AND ',@{$where})
        }

        my $pathstr=$form->{db}->query(query=>$query_path, onevalue=>1,errors=>$form->{errors})."/$parent_id";
        return if(scalar(@{$form->{errors}}));
            
        
        # определяем уровень вложенности
        while($pathstr=~m/\//g){$cur_level++;}


        while($pathstr=~m|\/(\d+)|g){
            my $id=$1;
            if($id){
                 my $where=["w.$form->{work_table_id}=$id"];
                 add_where_foreign_key($form,$where);

                 my $query;
                 if($form->{tree_select_header_query}){
                     $query=$form->{tree_select_header_query}." AND ( w.$form->{work_table_id}=$id)"
                 }
                 else{
                     $query="SELECT * from $form->{work_table} w";
                     if(scalar(@{$where})){
                        $query.=' WHERE '.join(' AND',@{$where});
                     }
                 }
                 

                my $item=$form->{db}->query(query=>$query,onerow=>1,errors=>$form->{errors});

                 my $header=$form->{default_find_filter};
                 foreach my $k (keys(%{$item})){
                     #print "$k<br>";
                     $header=~s/<\%$k\%>/$item->{$k}/g;
                 }
                 push @{$branch->{path}},
                     {
                        header=>$header,
                        id=>$id
                     };
                 
                 undef($where);
            }
        }
    }

    
    my $sql_query;
    $where=[];
    if($form->{tree_select_header_query}){
        $sql_query=$form->{tree_select_header_query};
        if($form->{tree_use}){
            if($parent_id=~m/^\d+$/ && $parent_id>0){
                $sql_query.=' AND parent_id = '.$parent_id;
            }
            else{
                $sql_query.=' AND parent_id is NULL '
            }
        }
        if($form->{sort}){
            $sql_query.=" ORDER BY w.sort"
        }
        else{
            $sql_query.=" ORDER BY $form->{header_field}"
        }
    }
    else{
        $sql_query="SELECT * FROM $form->{work_table} w";
        if($form->{tree_use}){
            unless($parent_id){ # для верхнего уровня
                push @{$where},qq{(w.parent_id is null or w.parent_id=0)};
            }
            else{ # для последующих уровней
                push @{$where},qq{w.parent_id=$parent_id};
            }
        }

        add_where_foreign_key($form,$where);
        $sql_query=add_where_to_query($sql_query,$where);
        
        if($form->{sort}){
            $sql_query.=qq{ ORDER BY w.$form->{sort_field}} ;
        }
        else{
            $sql_query.=qq{ ORDER BY w.$form->{header_field}} ;
        }
    }

    # my $sth=$dbh->prepare($sql_query);
    # $sth->execute();
    

    foreach my $item ( @{$form->{db}->query(query=>$sql_query)} ){
        my $id=$item->{$form->{work_table_id}};
        #my $cnt=get_count_in_branch($form,$id);
        my $el={
            header=>$item->{$form->{header_field}},
            id=>$id,
        };
        if($arg{get_childs} && $form->{tree_use}){
            $el->{childs}=get_branch('s'=>$s,form=>$form,get_childs=>0,parent_id=>$id);
        }
        
        if($form->{tree_use}){
            $el->{sort}=$item->{sort};
        }
        push @{$branch->{list}},$el;
    }
    return $branch->{list};
}
sub add_where_foreign_key{
    my $form=shift; my $where=shift;
    if($form->{work_table_foreign_key}=~m/^[a-z0-9_\-]+$/ && $form->{work_table_foreign_key_value}=~m/^\d+$/){
            push @{$where},qq{($form->{work_table_foreign_key}=$form->{work_table_foreign_key_value})};

    }
}
sub add_where_to_query{
    my ($query,$where)=@_;
    if(scalar(@{$where})){
        $query.=' WHERE '.join(' AND ',@{$where})
    }
    return $query
}
sub get_count_in_branch{ # кол-во "дочек" в ветке
    my $form=shift; my $id=shift; my $where=[];
    my $count_query="SELECT count(*) from $form->{work_table}";
    if($form->{tree_use}){
            if($id){ # parent_id указан
                push @{$where},"parent_id=$id";
            }
            else{ # parent_id не указан
                return undef;
            }
    }
    add_where_foreign_key($form,$where);
    $count_query=add_where_to_query($count_query,$where);
    my $sth_count=$form->{db}->query(query=>$count_query,onevalue=>1);
}
return 1;
