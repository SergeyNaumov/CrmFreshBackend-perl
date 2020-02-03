use utf8;
use strict;
sub run_event{
  # Запускает событие
    #my $event=shift; 
    my $s=$Work::engine;
    
    my %arg=@_;
    my $event=$arg{event};
    my $permissions_name=$arg{description}; 
    return unless($event);
    if($arg{description} eq 'events->before_search'){
      #use Data::Dumper;
      #print Dumper({tables=>$arg{tables},where=>$arg{where}});
    }

    if(ref($event) eq 'CODE'){

      my $result;
      if(ref($arg{'arg'}) eq 'ARRAY'){
        eval {$result=&{$event}(@{$arg{'arg'}})};
      }
      else{

        eval {$result=&{$event}($arg{'arg'})};
      }
      
      if($@){
        
        push @{ $arg{form}->{errors} },"Произошли программные ошибки. обратитесь к разработчику ($permissions_name)";
        push @{ $arg{form}->{errors} },"$permissions_name: $@"
      }
      return $result;
      
    }
    elsif(ref($event) eq 'ARRAY'){
      my $i=0;
      foreach my $e (@{$event}){
          run_event(event=>$e,description=>$permissions_name."[".$i."]",form=>$arg{form},arg=>$arg{'arg'});
        
        $i++;
      }
    }

}

sub error_eval{
  my $s=$Work::engine; my $error=shift; my $code=shift;
  my $i=1;
  my $log="ERROR EVAL: $error<br><hr>\n";
  while($code=~m!([^\n]+\n)!gs){
    my $str=$1;
    $str=~s/\s/&nbsp;&nbsp;/g;
    $log.=qq{$i: $str<br>\n};
    $i++;
  };

  $s->print_json(
    {
      success=>0,
      title=>'',
      filters=>[],
      errors=>[$log]
    }
  )->end;
}

sub print_header{
  my $txt=shift;
  my $s=$Work::engine;
  $s->print($txt);
}
sub param{
  my $name=shift; return $Work::engine->param($name);
}

sub get_clean_json{ # создаёт "чистый" json (без кодовых вставок)
  my $data=shift;
  my $s=$Work::engine;
  if(ref($data) eq 'ARRAY'){
      my $i=0;
      foreach my $d (@{$data}){
          $data->[$i]=get_clean_json($data->[$i]);
          $i++;
      }
  }
  elsif(ref($data) eq 'HASH'){
      foreach my $k (keys %{$data}){
        $data->{$k}=get_clean_json($data->{$k});
        delete $data->{$k} if(!defined($data->{$k}));
      }
  }
  elsif(ref($data) eq 'CODE'){
      $data='';
  }
  return $data
}


sub create_fields_hash{
  my $form=shift;
  foreach my $f (@{$form->{fields}}){
    $form->{fields_hash}->{$f->{name}}=$f;
  }
}
sub run_before_code_for_fields{
  my $form=shift;
  foreach my $f (@{$form->{fields}}){
    if(exists $f->{before_code} && ref($f->{before_code} eq 'CODE')){
        &{$f->{before_code}}($f);
    }
  }
}
sub set_default_attributes{
  my $form=shift;
  if(!exists($form->{QUERY_SEARCH_TABLES})){
      $form->{QUERY_SEARCH_TABLES}=[{table=>$form->{work_table},alias=>'wt'}];
  }
  
  $form->{events}={} if(!exists($form->{events}));
  $form->{log}=[] if(!exists($form->{log}));
  $form->{header_field}='header' unless($form->{header_field});
  $form->{sort_field}='sort' unless($form->{sort_field});
  $form->{make_delete}=1 if(!defined($form->{make_delete}));
  $form->{not_create}=0 if( !defined($form->{not_create}) );
  $form->{read_only}=0 if( !defined($form->{read_only}) );
  $form->{on_filters}=[] if(!$form->{on_filters} || ref($form->{on_filters}) ne 'ARRAY' );

  foreach my $e (qw(permissions before_search after_search before_insert after_insert before_update after_update before_save after_save)){
    $form->{events}->{$e}=[] if(!exists($form->{events}->{$e}));
  }

  # преобразование колонок Колонки
  if(ref($form->{cols}) eq 'ARRAY'){
    foreach my $c (@{$form->{cols}}){
        foreach my $block (@{$c}){
            $block->{hide}=0 if(!exists($block->{hide}))
        }
    }
  }
  else{
    $form->{cols}=[];
  }

  # 1. tablename у select_from_table
  my $tbl_name_alias={};
  foreach my $t (@{$form->{QUERY_SEARCH_TABLES}}){
    $tbl_name_alias->{$t->{table}}=$t->{alias};
  }
  my $exists={};
  $form->{errors}=[] if(!$form->{errors} || ref($form->{errors} ne 'ARRAY'));

  foreach my $f (@{$form->{fields}}){
    
    if(!$f->{name}){
      push @{$form->{errors}},qq{Обратитесь к разработчику: для элемента: description: $f->{description}, type: $f->{type} не указано name};
    }

    if($exists->{$f->{name}}){
      push @{$form->{errors}},"Обратитесь к разработчику: поле $f->{name} ($f->{description}) встречается повторно";
      return ;
    }
    $exists->{$f->{name}}=1;
    if($f->{type} eq 'select_from_table'){
      $f->{header_field}='header' unless($f->{header_field});
      $f->{value_field}='id' unless($f->{value_field});
      $f->{tablename}=$tbl_name_alias->{$f->{table}} unless($f->{tablename});
    }
    elsif($f->{type} eq '1_to_m'){
      $f->{make_delete}=1 if(!exists($f->{make_delete}));
    }
    elsif($f->{type} eq 'select_values'){
      foreach my $v (@{$f->{values}}){
        $v->{v}="$v->{v}";
      }
    }


  }
  $exists=undef;
  
}


sub get_values_for_select_from_table{ # получаем список значений для select_from_table
  my $f=shift; my $form=shift; my $s=$Work::engine;

  

  $f->{value_field}='id' unless($f->{value_field});
  $f->{header_field}='header' unless($f->{header_field});
  

  my $select_fields;
  if( $f->{tree_use}){
    $select_fields="$f->{value_field} v, $f->{header_field} d, parent_id";
  }
  else{
    $select_fields=qq{$f->{header_field} d,$f->{value_field} v};
  }

  my $query=qq{select $select_fields from $f->{table} };
  
  # Когда нет необходимости считывать всю таблицу
  if($f->{autocomplete}){ 
    if($f->{value}){
      if($f->{where}){
        $f->{where}.=' AND '
      }
      $f->{where}.=qq{($f->{value_field}=$f->{value})}
    }
    else{
      #print "$f->{read_only}  $form->{read_only} $f->{name} empty\n";
      return []
    }
  }
  
  if($f->{where}){
    if($f->{where}!~m{^\s*where\s}i){
      $query.=" WHERE ";
    }
    $query.=" $f->{where}";
  }
  if($f->{order}){
    if($f->{order}!~m{^\s*order\s+by}i){
      $query.=" ORDER BY ";
    }
    if($f->{tree_use}){
      $query.="parent_id, $f->{order}";
    }
    else{
      $query.=" $f->{order}";
    }
    
  }
  else{
      $query.=' ORDER BY '.($f->{tree_use}?'parent_id':$f->{header_field});
  }
  #print "q: $query\n";
  my $list=$s->{db}->query(query=>$query,errors=>$form->{log});
  if($f->{tree_use}){
    my $tree_list=[];
    my $hash={};
    foreach my $l (@{$list}){
      $hash->{$l->{v}}=$l;
      if(!$l->{parent_id}){
        push @{$tree_list},$l;
      }
      else{
        push @{ $hash->{$l->{parent_id}}->{children} },$l
      }
    }
    $list=[];
    #print Dumper($tree_list);
    tree_to_list($tree_list,$list,0);
    #print Dumper($list);
    #$list=$tree_list;
  }
  else{
    # foreach my $v (@{$list}){
    #   if($v=~m{^\d+$}){$v->{v}=$v->{v}+0;}
    # }
    #use Data::Dumper;print Dumper($list);
  }
  return $list
}
sub tree_to_list{
  my $tree_list=shift; my $list=shift; my $level=shift;
  foreach my $t (@{$tree_list}){
    $t->{d}=('..'x$level).$t->{d};
    push @{$list},{v=>$t->{v},d=>$t->{d}};    
    if($t->{children} && scalar(@{$t->{children}})){
      tree_to_list($t->{children},$list,$level+1);
    }
    
  }
}
sub errors{ # возвращает tru если есть $form->{errors}
    my $form=shift;
    $form->{errors}=[] if(!$form->{errors});
    return scalar(@{$form->{errors}})
}


sub return_link{ # рутина для блока ссылок
  # join '<br>', map { return_link($_) } @links;
  my $e=shift;
  my $style=''; my $onclick=''; my $id='';
  $style="style='color: red;'" if($e->{mark});
  $onclick=qq{onclick='$e->{cl}'} if($e->{cl});
  $id=qq{id='$e->{id}'}if($e->{id});
  return $e->{d} unless($e->{l});
  return qq{<a href="$e->{l}" $style $onclick $id target="_blank">$e->{d}</a>};
}

sub format_sql_query{
  my $query=shift;
  $query=~s/^\s*SELECT/<b>SELECT<\/b>\n/;

  return $query;
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
            $f->{value}=$values->{$name};
            
        }

        if(exists($f->{before_code}) && ref($f->{before_code}) eq 'CODE'){
            #&{$f->{before_code}}($f);
            run_event(event=>$f->{before_code},description=>'before code for '.$name,form=>$form,arg=>$f);
        }

        if($form->{action}!~m{^(insert|update)$} && $f->{type} eq 'select_from_table'){
            $f->{type_orig}=$f->{type}; $f->{type}='select'; 
            $f->{values}=get_values_for_select_from_table($f,$form);

            # foreach my $v (@{ $f->{values} }){
            #     if($v->{v}==$f->{value}){
            #         #$f->{vuetify_value}=$v
            #     }
            # }
        }
        elsif($form->{action}!~m{^(insert|update)$} && $f->{type} eq 'select_values'){
            $f->{type_orig}=$f->{type}; $f->{type}='select';
        }
        elsif($f->{type} eq '1_to_m'){
          OneToM::get_1_to_m_data(form=>$form,'s'=>$s,field=>$f);
        }
        elsif($f->{type} eq 'in_ext_url'){
          get_in_ext_url('s'=>$s,form=>$form,field=>$f);
          $values->{$name}=$f->{value}
        }


        #my $field=($f);
        if($f->{value}=~m/^\d+$/){ # в json-е должны быть только строки
            $f->{value}="$f->{value}"
        }
        push @{$form->{edit_form_fields}},$f;
        $form->{values}->{$f->{name}}=$f->{value};
    }
    $form->{values}=$values;
    foreach my $f (@{$form->{fields}}){
        my $name=$f->{name};


        if(ref($f->{code}) eq 'CODE'){
          #print "code: $name\n";
            $f->{after_html}=run_event(event=>$f->{code},description=>'code for '.$name,form=>$form,arg=>$f);
            #print "$f->{after_html}\n\n";
            #$f->{before_html}=&{$f->{code}}($f);
            #$f->{before_html}=$f->{after_html}='ZZZZ';
        }      
    }
    
}
return 1;