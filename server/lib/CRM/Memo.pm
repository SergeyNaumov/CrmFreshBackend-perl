use utf8;
use strict;

sub memo_init{
  my %arg=@_;
  my $form=read_conf(config=>$arg{config},script=>$arg{script},id=>$arg{id});
  my $field=undef;
  
  if($arg{field_name}!~m{^[a-zA-Z0-9\_]+$}){
    push @{$form->{errors}}, 'MEMO: field_name не указано или указано неверно. обратитесь к разработчику'
  }
  if(!scalar(@{$form->{errors}})){
    foreach my $f (@{$form->{fields}}){
      if($f->{name} eq $arg{field_name}){
        $field=$f; last;
      }
    }
  }
  push @{$form->{errors}},"поле $arg{field_name} не найдено. обратитесь к разработчику" unless($field);
  return ($form,$field);
}

sub get_memo{
  my %arg=@_;
  my $s=$arg{'s'};
  
  
  my $data=[];

  my ($form,$field)=memo_init(%arg);

  if(!scalar(@{$form->{errors}})){

    my $response={};
    
    if($field){
      $data=$form->{db}->query(
        query=>qq{
            SELECT
              memo.$field->{memo_table_id} id, user.$field->{auth_id_field} user_id,
              user.$field->{auth_name_field} user_name, memo.body message, memo.$field->{memo_table_registered} date
            FROM
              $field->{memo_table} memo
              LEFT JOIN $field->{auth_table} user ON (memo.$field->{memo_table_auth_id} = user.$field->{auth_id_field} )
            WHERE
              memo.$field->{memo_table_foreign_key}=? ORDER BY memo.$field->{memo_table_registered} desc},
        
        log=>$form->{log},
        values=>[$form->{id}],
        errors=>$form->{errors}
      );

      foreach my $d (@{$data}){
        $d->{registered}=~s/(\d{4})-(\d{2})-(\d{2})/$3\/$2\/$1/;
        if($d->{registered}=~m/\s+(\d{2}:\d{2}:\d{2})/){
          $d->{time}=$1; $d->{registered}=~s/\s+(\d{2}:\d{2}:\d{2})//;
        }
        
      }
    }

  }


  $s->print_json({
    field=>$s->clean_json($field),
    data=>$data,
    errors=>$form->{errors}
  })->end;
}
sub delete_from_memo{
  my %arg=@_;
  my $s=$arg{'s'};
  my ($form,$field)=memo_init(%arg);
  
  if(!$field->{make_delete} || !$form->{make_delete}){
    push @{$form->{errors}},'запрещено удалять комментарии'
  }
  

  if(!scalar(@{$form->{errors}})){
    $form->{db}->query(
      query=>"DELETE FROM $field->{memo_table} WHERE $field->{memo_table_id}=? and $field->{memo_table_foreign_key}=?",
      values=>[$arg{memo_id},$form->{id}],
    );
  }
  $s->print_json(
    success=>scalar(@{$form->{errors}})?0:1,
    errors=>$form->{errors}
  )->end;
}
sub update_memo{
  my %arg=@_;
  my $s=$arg{'s'};
  my ($form,$field)=memo_init(%arg);
  
  my $R=$s->request_content(from_json=>1);
  if(!$form->{read_only} && $field->{make_edit} && $R && (ref($R) eq 'HASH') && $R->{message}=~m/\S+/){
    
    $form->{db}->query(
      query=>"
        UPDATE
          $field->{memo_table}
        SET
          $field->{memo_table_comment}=?,
          $field->{memo_table_registered}=?,
          $field->{memo_table_auth_id}=?

        WHERE $field->{memo_table_id}=? and $field->{memo_table_foreign_key}=?",
      values=>[$R->{message},datetime(),$form->{manager}->{id},$arg{memo_id},$form->{id}],
      errors=>$form->{errors}
    );
  }
  
  $s->print_json(
    user_id=>$form->{manager}->{id},
    user_name=>$form->{manager}->{name},
    now=>datetime(),
    success=>scalar(@{$form->{errors}})?0:1,
    errors=>$form->{errors}
  )->end;
  
}
sub add_to_memo{
  my %arg=@_;
  my $s=$arg{'s'};
  my ($form,$field)=memo_init(%arg);
  
  my $R=$s->request_content(from_json=>1);
  

  if($form->{read_only} || $field->{read_only}){
    push @{$form->{errors}},'вы не можете добавлять записи в это поле'
  }
  my $memo_id=undef;
  if(!scalar(@{$form->{errors}}) && $R && (ref($R) eq 'HASH') && $R->{message}=~m/\S+/){

    $memo_id=$form->{db}->save(
      table=>$field->{memo_table},
      data=>{
        $field->{memo_table_foreign_key}=>$form->{id},
        $field->{memo_table_registered}=>datetime(),
        $field->{memo_table_auth_id}=>$form->{manager}->{id},
        $field->{memo_table_comment}=>$R->{message}
      },

    );

    
  }
  
  
  $s->print_json({
      user_id=>$form->{manager}->{id},
      user_name=>$form->{manager}->{name},
      now=>datetime(),
      errors=>$form->{errors},
      success=>scalar(@{$form->{errors}})?0:1,
      memo_id=>$memo_id
  })->end;

}
sub get_many_memo{ # в данный момент не нужно
  my %arg=@_; my $form=$arg{'form'}; my $field=$arg{'field'};
  # 1. Собираем хэш всех memo-полей
  return $form->{db}->query(query=>qq{
          SELECT
              memo.$field->{memo_table_id} id, user.$field->{auth_id_field} user_id,
              user.$field->{auth_name_field} user_name, memo.body message, memo.$field->{memo_table_registered} date,
              memo.$field->{memo_table_foreign_key} fk_id
            FROM
              $field->{memo_table} memo
              LEFT JOIN $field->{auth_table} user ON (memo.$field->{memo_table_auth_id} = user.$field->{auth_id_field} )
            WHERE
              memo.$field->{memo_table_foreign_key} IN (}.join(',',@{$arg{ids}}).qq{) ORDER BY memo.$field->{memo_table_registered} desc
  });
}
return 1;