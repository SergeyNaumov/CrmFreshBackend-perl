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
        debug=>1,
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
  my $request={success=>0};
  if($field->{make_delete}){
    $form->{db}->query(
      query=>"DELETE FROM $field->{memo_table} WHERE $field->{memo_table_id}=? and $field->{memo_table_foreign_key}=?",
      values=>[$arg{memo_id},$form->{id}],
    );
    $request->{success}=1;
  }
  $s->print_json($request)->end;
}
sub update_memo{
  my %arg=@_;
  my $s=$arg{'s'};
  my ($form,$field)=memo_init(%arg);
  my $request={success=>0,user_id=>$form->{manager}->{id},user_name=>$form->{manager}->{name},now=>datetime()};
  my $R=$s->request_content(from_json=>1);
  if(!$form->{read_only} && $field->{make_edit} && $R && (ref($R) eq 'HASH') && $R->{message}=~m/\S+/){
    
    $request->{success}=1;
    $form->{db}->query(
      query=>"
        UPDATE
          $field->{memo_table}
        SET
          $field->{memo_table_comment}=?,
          $field->{memo_table_registered}=?,
          $field->{memo_table_auth_id}=?

        WHERE $field->{memo_table_id}=? and $field->{memo_table_foreign_key}=?",
      values=>[$R->{message},$request->{now},$form->{manager}->{id},$arg{memo_id},$form->{id}],
      debug=>1
    );
  }
  
  $s->print_json($request)->end;
  
}
sub add_to_memo{
  my %arg=@_;
  my $s=$arg{'s'};
  my ($form,$field)=memo_init(%arg);
  
  my $R=$s->request_content(from_json=>1);
  #$s->pre({R=>$R});

  my $request={user_id=>$form->{manager}->{id},user_name=>$form->{manager}->{name},now=>datetime()};
  if($R && (ref($R) eq 'HASH') && $R->{message}=~m/\S+/){

    $request->{memo_id}=$form->{db}->save(
      table=>$field->{memo_table},
      data=>{
        $field->{memo_table_foreign_key}=>$form->{id},
        $field->{memo_table_registered}=>$request->{now},
        $field->{memo_table_auth_id}=>$form->{manager}->{id},
        $field->{memo_table_comment}=>$R->{message}
      },
      #debug=>1
    );

    $request->{success}=1;
  }
  else{
    $request={
      success=>0
    }
  }
  $s->print_json($request)->end;

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