use utf8;
use strict;
package CRM::Multiconnect;
# sub one_to_m_init{
#   my %arg=@_;
#   my $form=$arg{form};
#   my $field=undef;
  
#   if($arg{field_name}!~m{^[a-zA-Z0-9\_]+$}){
#     push @{$form->{errors}}, '1_to_m: field_name не указано или указано неверно. обратитесь к разработчику'
#   }
#   if(!scalar(@{$form->{errors}})){
#     foreach my $f (@{$form->{fields}}){
#       if($f->{name} eq $arg{field_name}){
#         $field=$f; last;
#       }
#     }
#   }
#   push @{$form->{errors}},"поле $arg{field_name} не найдено. обратитесь к разработчику" unless($field);
#   return ($field);
# }
sub process{
  my %arg=@_;
  my $s=$arg{s};
  my $R=$s->request_content(from_json=>1);
  $R={} if(!$R);
  my $form=$arg{form}=CRM::read_conf(
    config=>$arg{config},
    script=>$arg{script},
    action=>$R->{action},
    id=>"$R->{id}"
  );
  

  my $field=CRM::get_child_field(fields=>$form->{fields},name=>$arg{field_name});

  check_defaults(form=>$form,field=>$field);
    #use Data::Dumper;
  if($R->{action} eq 'add_tag' && $R->{header}){
    # добавление нового тэга
    unless($R->{header}){
      push @{$form->{errors}},'Новый тэг не указан';
    }
    my $tag_id;
    unless(scalar(@{$form->{errors}})){
      $tag_id=$form->{db}->get(
        select_fields=>qq{$field->{relation_table_id}},
        table=>$field->{relation_table},
        where=>qq{$field->{relation_table_header}=?},
        values=>[$R->{header}],
        onevalue=>1,
        errors=>$form->{errors},
      );
    }
    #print "1 tag_id: $tag_id $field->{relation_table}.$field->{relation_table_header}=>$R->{header}\n";

    if(!$tag_id && !scalar(@{$form->{errors}})){
      $tag_id=$form->{db}->save(
        table=>$field->{relation_table},
        data=>{
          $field->{relation_table_header}=>$R->{header}
        },
        debug=>1,
        #log=>$form->{log},
        #errors=>$form->{errors}
      );
    }
    # my $list=[]; my $value=[];
    # if(!scalar(@{$form->{errors}})){
    #   get(field=>$field,form=>$form,list=>$list,value=>$value);
    # }
    

    #print "2 tag_id: $tag_id\n";
    $s->print_json({
      success=>scalar(@{$form->{errors}})?0:1,
      tag_id=>$tag_id,
      #list=>$list,
      #value=>$value,
      errors=>$form->{errors},
      log=>$form->{log}
    })->end;


  }
  elsif($R->{action} eq 'autocomplete'){
    my $list;

    $list=$form->{db}->get(
      select_fields=>qq{$field->{relation_table_id} v, $field->{relation_table_header} d},
      table=>$field->{relation_table},
      where=>qq{$field->{relation_table_header} like ?},
      values=>['%'.$R->{header}.'%'],
      errors=>$form->{errors}
    );
    my $exists_tag=$form->{db}->get(
      select_fields=>qq{count(*) cnt},
      table=>$field->{relation_table},
      where=>qq{$field->{relation_table_header}=?},
      values=>[$R->{header}],
      onevalue=>1,
      errors=>$form->{errors},
    );

    $s->print_json({
      success=>scalar(@{$form->{errors}})?0:1,
      list=>$list,
      exists_tag=>$exists_tag,
      errors=>$form->{errors}
    })->end;

  }
  elsif($R->{action} eq 'get'){
    my $list=[]; my $value=[];
    ($list,$value)=get(field=>$field,form=>$form,list=>$list,value=>$value);
    
    $s->print_json({
      success=>scalar(@{$form->{errors}})?0:1,
      list=>$list,
      value=>$value,
      errors=>$form->{errors}
    })->end;
  }



}

sub get{
    my %arg=@_;
    my $form=$arg{form}; my $field=$arg{field};;
    
    my $where=$field->{relation_table_where};
    if($field->{tree_use}){
        $where.=' AND ' if($where);
        $where.=' parent_id is null'
    }

    my $list=$form->{db}->get(
      select_fields=>"$field->{relation_table_id} id, $field->{relation_save_table_header} header",
      table=>$field->{relation_table},
      where=>$where,
      order=>$field->{relation_tree_order},
      tree_use=>$field->{tree_use},
      errors=>$form->{errors}
    );



    
    my $value=get_values(form=>$form,field=>$field);
    if(scalar(@{$form->{errors}})){
      $list=[]; $value=[];
    }
    return $list,$value;
}
sub save{ # вызывается из EditForm
    my %arg=@_; my $form=$arg{form}; my $field=$arg{field};
    my $old_values=get_values(form=>$form,field=>$field);
  
    my $old_values_hash={
      map {$_=>1}
      @{$old_values}
    };
  
    my $values_joined=join(',',@{$arg{new_values}});
  
    # удаляем лишнее
    $form->{db}->query(
      query=>"DELETE FROM $field->{relation_save_table} WHERE $field->{relation_save_table_id_worktable}=? ".
      (
         $values_joined?" AND $field->{relation_save_table_id_relation} not in ($values_joined)":
         ''
      ),
      #debug=>1,
      values=>[$form->{id}]
    );

    # сохраняем то, чего ещё нет
    foreach my $v (@{$arg{new_values}}){
      if(!$old_values_hash->{$v}){
        $form->{db}->save(
          table=>$field->{relation_save_table},
          ignore=>1,
          data=>{
            $field->{relation_save_table_id_worktable}=>$form->{id},
            $field->{relation_save_table_id_relation}=>$v
          },
          #debug=>1
        )
      }
    }


}
sub check_defaults{
  my %arg=@_;
  my $form=$arg{form}; my $field=$arg{field};
  
  my $defaults={
    relation_table_id=>'id',
    relation_save_table_header=>'header',
    relation_tree_order=>'header',
    relation_save_table_header=>'header',
    relation_save_table_id_worktable=>$form->{work_table}.'_id',
    relation_save_table_id_relation=>$form->{relation_table}.'_id',
    tree_use=>0
  };
  foreach my $k (keys %{$defaults}){
    $field->{$k}=$defaults->{$k} unless($field->{$k});
  }
  return $field
}
sub get_values{
  my %arg=@_;
  my $form=$arg{form}; my $field=$arg{field};
  if($form->{id}){
      check_defaults(form=>$form,field=>$field);
      return $form->{db}->query(
          query=>qq{
            SELECT
              $field->{relation_save_table_id_relation}
            FROM
                $field->{relation_save_table}
            WHERE
              $field->{relation_save_table_id_worktable}=?

          },
          massive=>1,
          values=>[$form->{id}],
          errors=>$form->{errors}
      );
  }
  else{
    return []
  }
  
}
return 1;