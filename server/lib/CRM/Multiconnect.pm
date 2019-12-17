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

  my $form=$arg{form}=CRM::read_conf(
    config=>$arg{config},
    script=>$arg{script},
    action=>$R->{action},
    id=>$R->{id}
  );
  

  my $field=CRM::get_child_field(fields=>$form->{fields},name=>$arg{field_name});

  check_defaults(form=>$form,field=>$field);

  if($R->{action} eq 'get'){

    my $list=[]; my $value=[];
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
    use Data::Dumper;
    print Dumper({list=>$list});

    
    my $value=get_values(form=>$form,field=>$field);
    if(scalar(@{$form->{errors}})){
      $list=[]; $value=[];
    }
    $s->print_json({
      success=>scalar(@{$form->{errors}})?0:1,
      list=>$list,
      value=>$value,
      errors=>$form->{errors}
    })->end;
  }



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