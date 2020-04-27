package OneToM;
#use lib './lib/CRM';
#use Routine;
use utf8;
use strict;
use CRM;


sub one_to_m_init{
  my %arg=@_;
  my $form=$arg{form};
  my $field=undef;
  
  if($arg{field_name}!~m{^[a-zA-Z0-9\_]+$}){
    push @{$form->{errors}}, '1_to_m: field_name не указано или указано неверно. обратитесь к разработчику'
  }
  if(!scalar(@{$form->{errors}})){
    foreach my $f (@{$form->{fields}}){
      if($f->{name} eq $arg{field_name}){
        $field=$f; last;
      }
    }
  }
  push @{$form->{errors}},"поле $arg{field_name} не найдено. обратитесь к разработчику" unless($field);
  return ($field);
}
sub process{
    my %arg=@_;
    my $field=one_to_m_init(%arg);
    my $s=$arg{s};
    
    my $form=$arg{form};
    my $id=undef;
    if(!$arg{action}){
      push @{$form->{errors}},'Обратитесь к разработчику: не указано action';
    }
    if($form->{read_only}){
      push @{$form->{errors}},'Карточка только для чтения'
    }
    if($field->{read_only}){
      push @{$form->{errors}},"Поле $field->{description} только для чнения"
    }


    if($arg{action} eq 'upload_file'){
      #$s->pre($field)->end;
      my $child_field=get_child_field(fields=>$field->{fields},name=>$arg{child_field_name});
      my $file_info;
      my $unlink_info;
      
      use Data::Dumper;
      if($child_field){
        unless(-f "$child_field->{filedir}"){
          mkdir $child_field->{filedir}
        }
        #print Dumper(\%arg);
        if($arg{one_to_m_id}){
              my $oldfile=$form->{db}->query(
                query=>
                qq{
                  SELECT $child_field->{name} from $field->{table}
                    WHERE
                      $field->{foreign_key}=$form->{id} and $field->{table_id}=$arg{one_to_m_id}
                },
                onevalue=>1,errors=>$form->{errors}
              );

              if(!scalar(@{$form->{errors}})){
                  if($oldfile=~m{^(.+);}){
                    $oldfile=$1;
                  }
                  if($oldfile){
                    unlink $child_field->{filedir}.'/'.$oldfile;
                  }

                  $file_info=$s->save_upload(
                    var=>$child_field->{name},
                    to=>$child_field->{filedir},
                    resize=>$child_field->{resize}
                  );
                  
                  # $file_info

                  # foreach my $r (@{$child_field->{resize}}){
                  #     my ($width,$height)=split /x/,$r->{size};
                  #     my $filename=$r->{file};
                  #     $filename=~s/<\%filename_without_ext\%>/$filename_without_ext/g;
                  #     $filename=~s/<\%ext\%>/$ext/g;

                  #     print Dumper({
                  #       resize=>{
                  #         from=>"$child_field->{filedir}/$filename_without_ext\.$ext",
                  #         to=>"$child_field->{filedir}/$filename",
                  #         width=>"$width",
                  #         height=>"$height",
                  #         grayscale=>$r->{grayscale}?$r->{grayscale}:'',
                  #         composite_file=>$r->{composite_file}?$r->{composite_file}:'',
                  #         quality=>$r->{quality}?$r->{quality}:''
                  #       }
                  #     });

                  #     resize(
                  #         from=>"$child_field->{filedir}/$filename_without_ext\.$ext",
                  #         to=>"$child_field->{filedir}/$filename",
                  #         width=>"$width",
                  #         height=>"$height",
                  #         grayscale=>$r->{grayscale}?$r->{grayscale}:'',
                  #         composite_file=>$r->{composite_file}?$r->{composite_file}:'',
                  #         quality=>$r->{quality}?$r->{quality}:''
                  #     );

                  # }

                  if($file_info){
                    my $db_value="";
                    if($child_field->{keep_orig_filename}){
                      $db_value="$file_info->{name};$file_info->{orig_name}"
                    }
                    else{
                      $db_value="$file_info->{name}"
                    }
                    $form->{db}->save(
                      table=>$field->{table},
                      update=>1,
                      where=>qq{$field->{foreign_key}=$form->{id} and $field->{table_id}=$arg{one_to_m_id}},
                      data=>{
                        $child_field->{name}=>$db_value
                      }
                    );          
                  }

              }
              else{
                push @{$form->{errors}}, qq{нет поля $child_field->{name}}
              }
        }
        else{ # Загружаем новый файл и создаём запись (multiload)
              my $values=[];
              my $i=0;
              my $uploads=$s->save_upload(
                  var=>"$child_field->{name}",
                  to=>"$child_field->{filedir}",
                  multi=>"1",
                  resize=>$child_field->{resize}
              );


              foreach my $file_info (@{$uploads}){
                  if($file_info){
                    my $value={}; # вставляемая в таблицу строка
                    
                    my $db_value="";
                    if($child_field->{keep_orig_filename}){
                      $db_value="$file_info->{name};$file_info->{orig_name}"
                    }
                    else{
                      $db_value="$file_info->{name}"
                    }

                    my $id=$form->{db}->save(
                      table=>$field->{table},
                      data=>{
                        $field->{foreign_key}=>$form->{id},
                        $child_field->{name}=>$db_value
                      }
                    );
                    
                    $arg{one_to_m_id}=$id;
                        $value={
                          $field->{foreign_key}=>$form->{id},
                          $field->{table_id}=>$id,
                          $child_field->{name}=>$file_info->{name},
                          $child_field->{name}.'_filename'=>$file_info->{name}
                          #$child_field->{name}.'_filename'=>$file_info->{orig_name}
                        };
                        # foreach my $cf (@{$field->{fields}}){
                        #   $value->{$cf->{name}}=''
                        # }
                        
                        push @{$values},$value;
                        
                        $i++;
                        if($i>30){
                          print "exit!";
                          exit;
                        }
                  }
              }

              $s->print_json({
                success=>( scalar( @{$form->{errors}} ) )?0:1,
                values=>$values,
                errors=>$form->{errors}
              })->end;
              return ;
        }
      }
      else{
        push @{$form->{errors}}, qq{не найдено поле $field->{name}:$child_field->{name} в конфиге $arg{config}}
      }
      
      get_1_to_m_data(form=>$form,'s'=>$s,field=>$field);

      $s->print_json({
        success=>( scalar( @{$form->{errors}} ) )?0:1,
        file_info=>$file_info,
        values=>$field->{values},
        errors=>$form->{errors}
      })->end;
      return ;
      
    }
    elsif($arg{action} eq 'delete_file'){
        my $cf=get_child_field(fields=>$field->{fields},name=>$arg{child_field_name});
        delete_file(
          form=>$form,
          child_field=>$cf,
          field=>$field,
          one_to_m_id=>$arg{one_to_m_id}
        );

        $s->print_json({
          success=>( scalar( @{$form->{errors}} ) )?0:1,
          errors=>$form->{errors}
        })->end;
    }
    elsif($arg{action} eq 'delete'){
      

      if(! scalar( @{$form->{errors}}) ){
        #run_event()
        # если всё ок -- удаляем из базы
        
        CRM::run_event(
          event=>$field->{before_delete_code},
          description=>'before delete code 1_to_m for '.$field->{name},
          form=>$form,
          arg=>$field
        );
        
        unless(scalar( @{$form->{errors}} )){
            foreach my $cf (@{$field->{fields}}){
              
              if($cf->{type} eq 'file'){
                  
                  delete_file(
                    form=>$form,
                    child_field=>$cf,
                    field=>$field,
                    one_to_m_id=>$arg{one_to_m_id}
                  );
                  
              }
              last if(scalar @{$form->{errors}});
            }
            unless (scalar @{$form->{errors}}){
              $form->{db}->query(
                query=>"DELETE FROM $field->{table} WHERE $field->{foreign_key}=? and $field->{table_id}=?",
                values=>[$arg{id},$arg{one_to_m_id}],
              );
            }

            unless (scalar @{$form->{errors}}){
              CRM::run_event(
                event=>$field->{after_delete_code},
                description=>'after  delete code 1_to_m for '.$field->{name},
                form=>$form,
                arg=>$field
              );
            }

        }

        # after_delete

      }

      $s->print_json({
        success=>( scalar( @{$form->{errors}} ) )?0:1,
        errors=>$form->{errors}
      })->end;
      return;
    }
    elsif($arg{action} eq 'sort'){

          my $R=$s->request_content(from_json=>1);
          my $sort_hash={};
          if(!$field->{sort}){
            push @{$form->{errors}},'сортировка запрещена'
          }
          if(!$R){
            push @{$form->{errors}},'не передан JSON'
          }
          else{
            if(!$R->{sort_hash}){
              push @{$form->{errors}},'отсутствует параметр sort_hash'
            }
            else{
              if(ref($R->{sort_hash}) ne 'HASH'){
                push @{$form->{errors}},'sort_hash должен быть хешем'
              }
              $sort_hash=$R->{sort_hash};
            }
          }

          my $query;
          #use Data::Dumper;
          #print Dumper($form->{errors});
          unless ( scalar @{$form->{errors}} ){
             # ошибок нет, сортируем
             my $sort_field=$field->{sort_field}?$field->{sort_field}:'sort';
             my $when_list='';
             foreach my $id ( keys(%{$sort_hash}) ){
              #print "id: $id=>$sort_hash->{$id}\n";
                if($id=~m/^\d+$/ && $sort_hash->{$id}=~m/^\d+$/){
                  $when_list.="WHEN $field->{table_id}=$id THEN '$sort_hash->{$id}'\n"
                }
              
             }
             $query="
                UPDATE $field->{table}
                  SET $sort_field=(
                    CASE 
                      $when_list
                    END
                  )
               WHERE $field->{foreign_key}=$form->{id}";
               $form->{db}->query(
                  query=>$query,
                  errors=>$form->{errors},
               );
          }
          
          $s->print_json({
            success=>scalar(@{$form->{errors}})?0:1,
            sort_hash=>$R->{sort_hash},
            errors=>$form->{errors},
          })->end;
    }
    elsif($arg{action} eq 'update_field'){
          my $R=$s->request_content(from_json=>1);
          #use Data::Dumper;
          my $field=$form->{fields_hash}->{$arg{field_name}};
          my $child_field;
          if($field){
            if($arg{child_field_name}){
              $child_field=get_child_field(fields=>$field->{fields},name=>$arg{child_field_name});
              if(!$child_field){
                push @{$form->{errors}},"Не найден элемент $arg{child_field_name} в элементе $arg{field_name}"
              }
            }
            else{
              push @{$form->{errors}},"не указан параметр child_field_name. обратитесь к разработчику"
            }
          }
          else{
            if(!$arg{field_name}){
              push @{$form->{errors}},"Не указан параметр field_name. обратитесь к разработчику"
            }
            else{
              push @{$form->{errors}},"Элемент с именем $arg{field_name} не найден"
            }
            
          }

          my $value=$R->{value};
          my $id=$R->{cur_id};
          
          if(scalar @{$child_field->{regexp_rules}} ){ # проверка
            my $j=0;
            while($j < scalar @{$child_field->{regexp_rules}}){
              my $regexp=$child_field->{regexp_rules}->[$j];
              if(eval q{ $value!~}.$regexp){
                push @{$form->{errors}},$child_field->{regexp_rules}->[$j+1]
              }
              $j+=2;
            }
          }

          unless(scalar(@{$form->{errors}})){
            $form->{db}->query(
              query=>"UPDATE $field->{table} SET $child_field->{name}=? WHERE $field->{table_id}=?",
              values=>[$value,$id]
            );
          }
          
          get_1_to_m_data(form=>$form,'s'=>$s,field=>$field);
          
          $s->print_json({
            success=>scalar(@{$form->{errors}})?0:1,
            values=>$field->{values},
            errors=>$form->{errors},
          })->end;
    }
    else{ # insert, update
          my $R=$s->request_content(from_json=>1);
          if(!$R || !exists($R->{values}) || !$R->{values} || ref($R->{values}) ne 'HASH' || !scalar( keys %{$R->{values}} ) ){
            push @{$form->{errors}},"обратитесь к разработчику: в запросе отсутствуют значения (values)"
          }
          my $data=get_data($R,$form,$field,$arg{id});
          
          if(  !scalar(@{$form->{errors}})  ){
            
            if($arg{action} eq 'insert'){
              CRM::run_event(
                event=>$field->{before_insert_code},
                description=>'before insert code 1_to_m for '.$field->{name},
                form=>$form,
                arg=>[$field,$data]
              );
              CRM::run_event(
                event=>$field->{before_save_code},
                description=>'before save code 1_to_m for '.$field->{name},
                form=>$form,
                arg=>[$field,$data]
              );
              unless( scalar (@{$form->{errors}}) ){
                  $data->{$field->{table_id}}=$form->{db}->save(
                    table=>$field->{table},
                    data=>$data
                  );
                  CRM::run_event(
                    event=>$field->{after_insert_code},
                    description=>'after insert code 1_to_m for '.$field->{name},
                    form=>$form,
                    arg=>[$field,$data]
                  );
                  CRM::run_event(
                    event=>$field->{after_save_code},
                    description=>'after save code 1_to_m for '.$field->{name},
                    form=>$form,
                    arg=>[$field,$data]
                  );
              }

            }
            elsif($arg{action} eq 'update'){
              #print Dumper({one_to_m_id=>arg{one_to_m_id}});
              $data->{$field->{table_id}}=$arg{one_to_m_id};
              CRM::run_event(
                event=>$field->{before_update_code},
                description=>'before update code 1_to_m for '.$field->{name},
                form=>$form,
                arg=>[$field,$data]
              );
              CRM::run_event(
                event=>$field->{before_save_code},
                description=>'before save code 1_to_m for '.$field->{name},
                form=>$form,
                arg=>[$field,$data]
              );
              unless( scalar (@{$form->{errors}}) ){
                  $form->{db}->save(
                    table=>$field->{table},
                    where=>qq{$field->{foreign_key}=$arg{id} and $field->{table_id}=$arg{one_to_m_id}},
                    update=>1,
                    data=>$data,
                  );
                  $data=$form->{db}->query(
                    query=>qq{select * from $field->{table} where $field->{table_id}=?},
                    values=>[$arg{one_to_m_id}],
                    onerow=>1
                  );
                  if(!$data){
                    push @{$form->{errors}},"данной записи уже не существует, возможно, кто-то удалил её";
                  }
                  
                  normalize_value_row(form=>$form,field=>$field,row=>$data);

                  CRM::run_event(
                    event=>$field->{after_update_code},
                    description=>'after update code 1_to_m for '.$field->{name},
                    form=>$form,
                    arg=>[$field,$data],
                    
                  );
                  CRM::run_event(
                    event=>$field->{after_save_code},
                    description=>'after save code 1_to_m for '.$field->{name},
                    form=>$form,
                    arg=>[$field,$data]
                  );
              }
            }
            else{
              push @{$form->{errors}},qq{обратитесь к разработчику: неизвестный action при вызове 1_to_m}
            }
            
          }
          
          get_1_to_m_data(form=>$form,'s'=>$s,field=>$field);
          $s->print_json({
            success=>( scalar( @{$form->{errors}} ) )?0:1,
            errors=>$form->{errors},
            id=>$data->{$field->{table_id}},
            #values=>$data,
            values=>$field->{values}
          })->end;      
    }

}
sub delete_file{
      my %arg=@_;
      
      my ($form,$field,$child_field)=($arg{form}, $arg{field},$arg{child_field});
      if($child_field){
        unless(-f "$child_field->{filedir}"){
          mkdir $child_field->{filedir}
        }

        my $oldfile=$form->{db}->query(
          query=>
          qq{
            SELECT $child_field->{name} from $field->{table}
              WHERE
                $field->{foreign_key}=$form->{id} and $field->{table_id}=$arg{one_to_m_id}
          },
          onevalue=>1,errors=>$form->{errors}
        );
        if($oldfile=~m{^(.+);}){
          $oldfile=$1;
        }
        my $fullname=$child_field->{filedir}.'/'.$oldfile;
        if($child_field->{resize} && scalar(@{$child_field->{resize}})){
          if($oldfile=~m/^(.+)\.([^\.]+)$/){
            my $filename_without_ext=$1; my $ext=$2;
            foreach my $r (@{$child_field->{resize}}){
              my $file=$r->{file};
              $file=~s/<%filename_without_ext%>/$filename_without_ext/;
              $file=~s/<%ext%>/$ext/;
              unlink "$child_field->{filedir}/$file";
              
            }
          }

        }
        
        
        if($oldfile && -e $fullname){ # сделать проверку, удалился ли
          
          unlink $fullname;
          if(-e $fullname){
            push @{$form->errors},qq{Не удалось удалить файл $fullname. Обратитесь к разработчику}
          }
        }
        
        return if(scalar(@{$form->{errors}}));
        $form->{db}->save(
          table=>$field->{table},
          update=>1,
          where=>qq{$field->{foreign_key}=$form->{id} and $field->{table_id}=$arg{one_to_m_id}},
          data=>{
            $child_field->{name}=>''
          },
          errors=>$form->{errors}
        );
        

        
      }
      else{
        push @{$form->{errors}}, qq{не найдено поле $field->{name}:$child_field->{name} в конфиге $arg{config}}
      }
}
sub check_request{
  my %arg=@_;
}

sub get_1_to_m_data{
  my %arg=@_;
  my ($form,$s,$f)=($arg{form},$arg{'s'},$arg{field});
  #$form->{db}->query(query=>$query)  
  foreach my $cf (@{$f->{fields}}){
    if($cf->{type} eq 'select_from_table'){
      $cf->{values}=CRM::get_values_for_select_from_table($cf,$form,$s);
    }
    if($cf->{type}=~m{(select_values|select_from_table)}){ # преобразуем в строки, чтобы не было проблем с json-ом
      foreach my $v (@{$cf->{values}}){
        $v->{v}="$v->{v}"
      }
    }
  }

  my $headers=[];
  foreach my $c (@{$f->{fields}}){
      
      next if($c->{not_out_in_slide});
      push @{$headers},{name=>$c->{name},description=>$c->{description},type=>$c->{type},change_in_slide=>$c->{change_in_slide}};
  }
  $f->{headers}=$headers;
  
  if($form->{id}){
      my $where=$f->{where};
      $where.=' AND ' if($where);
      $where.="$f->{foreign_key}=$form->{id}";

      if($where!~m{\s*where\s+}i){
        $where="WHERE $where"
      }

      my $order=$f->{order};
      if($f->{sort}){
        $order=$f->{sort_field}?$f->{sort_field}:'sort'
      }

      $order="ORDER BY $order" if($order && $order!~m{\s*order\s+by\s+});

      my $query="select * from $f->{table} $where $order";
      my $data=$form->{db}->query(query=>$query,errors=>$form->{log});
      $f->{values}=[];
      my $element_fields={};
      foreach my $cf (@{$f->{fields}}){
          #$element->{fields}
      }
      my $values;
      foreach my $d (@{$data}){
          
          normalize_value_row(form=>$form,field=>$f,row=>$d);
          push @{$values},$d;
      }
      $f->{values}=$values;
      #$f->{data}=[];
      


  }
  else{
    $f->{value}=[]
  }

}
sub normalize_value_row{
  my %arg=@_; my $d=$arg{row}; 
  foreach my $cf (@{$arg{field}->{fields}}){
      my $c_name=$cf->{name};
      my $fdir=$cf->{filedir}; $fdir=~s/^.\//\//;
      if($cf->{type} eq 'file' && $d->{$cf->{name}}){
          if($d->{$c_name}=~m{^(.+);(.+)}){
            $d->{$c_name.'_filename'}=$2;
          }
          else{
            $d->{$c_name.'_filename'}=$d->{$c_name};
          }
      }
  
      if($cf->{slide_code} && ref($cf->{slide_code}) eq 'CODE'){
          $d->{$c_name}=CRM::run_event(
            event=>$cf->{slide_code},
            description=>"slide code for $arg{field}->{name}:$cf->{name}",
            form=>$arg{form},
            arg=>[$arg{field},$d]
          );
      }
      
  }
}
sub get_data{
    my $R=shift;
    my $form=shift;
    my $field=shift;
    my $id=shift;
    my $data={$field->{foreign_key}=>$id};
    #use Data::Dumper;
    #print Dumper($R); exit;
    foreach my $f (@{$field->{fields}}){
      next if($f->{type}=~m{^(code|file|picture)$});
      next if($f->{read_only});
      
      my $v=$R->{values}->{$f->{name}};
      
      if(defined $v){
          # проверка регулярок
          if($f->{regexp_rules} && ref($f->{regexp_rules}) eq 'ARRAY'){
            my $i=0; my $len=scalar(@{$f->{regexp_rules}});

            while($i<$len){
                my $reg=$f->{regexp_rules}->[$i];
                my $err=$f->{regexp_rules}->[$i+1];
                
                $err=qq{поле $f->{description} не заполнено или заполнено неверно} unless($err);
                $reg=~s/^\///;  my $pattern=''; 
                my $regexp_keys='';
                if($reg=~m/\/([a-zA-Z]+)?$/){
                  $reg=~s/\/([a-zA-Z]+)?$//;
                }
                
                if($reg){
                    # print q{EVAL: 
                    #     if($v!~/}.$reg.q{/}.$regexp_keys.q{){
                    #       push @{$form->{errors}},
                    #     }
                    
                    # };
                     eval q{
                       if($v!~/}.$reg.q{/}.$regexp_keys.q{){
                         push @{$form->{errors}},$err;
                       }
                     }
                  
                }



                $i=$i+2;
            }

          }
          $data->{$f->{name}}=$v;
          
          #print Dumper($data)
      }

      #keys %{$R->{values}}
    }
    return $data;
}

sub get_child_field{
  my %arg=@_;
  foreach my $f (@{$arg{fields}}){
    if($f->{name} eq $arg{name}){
        return $f;
    }
  }
}
return 1;