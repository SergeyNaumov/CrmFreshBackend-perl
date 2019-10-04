use utf8;
use strict;
use Digest::SHA qw(sha256_hex);
package CRM::Password;
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

  my $form=$arg{form}=CRM::read_conf(config=>$arg{config},script=>$arg{script},action=>$R->{action},id=>$arg{id});
  my $field=CRM::get_child_field(fields=>$form->{fields},name=>$arg{field_name});
  

  if($R->{action} eq 'change'){ # изменение пароля

    my $rules=[
      {exp=>($form->{read_only} || $field->{read_only}),message=>'Вам запрещено изменять данное поле'},
      {exp=>!$R->{new_password},message=>'Не указан новый пароль'},
      {exp=>
        (
          $field->{min_length} && 
          length($R->{new_password}) < $field->{min_length}
        ),
        message=>"Длина пароля не должна быть менее $field->{min_length} символов"
      },
      {
        exp=>!$field->{encrypt_method},
        'Не указан encrypt_method'
      },
      {
        exp=>($field->{encrypt_method}!~m/^(mysql_encrypt)$/),
        message=>"указан не известный encrypt_method: $field->{encrypt_method}"
      },
      { exp=>
        (
          $R->{method_send} &&
          (
            $R->{method_send}!~m/^\d+$/ 
              ||
            !exists($field->{methods_send}->[$R->{method_send}])
          )

        ),
        message=>'не известный method_send :'.$R->{method_send}
      }
    ];

    foreach my $r (@{$rules}){ # проверка
      if(!CRM::errors($form)){
          push @{$form->{errors}->{$r->{message}}} if($r->{exp});
      }

    }


    if(!CRM::errors($form)){ # Всё хорошо, меняем
      
    }

    if(!CRM::errors($form)){
      my $encrypt_password='';
      if($field->{encrypt_method} eq 'mysql_encrypt'){
        $encrypt_password=$form->{db}->query(query=>'select encrypt(?)',values=>[$R->{new_password}],onevalue=>1);
      }

      $form->{db}->query(
        query=>"UPDATE $form->{work_table} SET $field->{name}=? where id=?",
        errors=>$form->{errors},
        debug=>1,
        values=>[$encrypt_password,$form->{id}]
      );
    }

    if(!CRM::errors($form)){ # отправляем пароль указанным методом
      my $method_send=$field->{methods_send}->[$R->{method_send}];
      if($method_send && exists($method_send->{code}) && ref($method_send->{code}) eq 'CODE'){
        &{$method_send->{code}}($R->{new_password});
      }
    }

    $s->print_json({
      success=>scalar(@{$form->{errors}})?0:1,
      values=>$form->{values},
      errors=>$form->{errors}
    })->end;
  }



}

return 1;