$form={
  title => 'Пакет документов',
  work_table => 'docpack',
  work_table_id => 'id',
  make_delete => '1',
  explain=>1,
  events=>{
    permissions=>sub{
      if($form->{manager}->{login} ne 'admin'){
        push @{$form->{errors}},'Доступ запрещён'
      }
      else{
        

      }
    }
  },
  #explain=>1,
  fields =>
  [
    {
      description=>'Организация',
      type=>'select_from_table',
      table=>'user',
      header_field=>'firm',
      value_field=>'id',
      read_only=>1,
      name=>'user_id',
      autocomplete=>1,
      before_code=>sub{
        my $e=shift;
        if($form->{action} eq 'new'){
          my $R=$s->request_content(from_json=>1);
          if($R->{cgi_params}){
            $e->{value}=$R->{cgi_params}->{user_id};
          }
        }
        elsif($form->{action} eq 'insert'){
          $e->{read_only}=0;
          #print "user_id: $e->{value}\n";
        }
      },
      before_insert=>sub{
        my $e=shift;
        push @{$form->{fields}},{name=>'user_id',type=>'hidden',value=>$e->{value}}
      }
    },
    {
      name => 'tarif_id',
      description => 'Тариф',
      type => 'select_from_table',
      table=>'tarif',
      header_field=>'header',
      value_field=>'id',
      regexp_rules=>[
        '/^\d+$/','Выберите тариф'
      ]
    },
    {
      description=>'Юр. лицо',
      name=>'ur_lico_id',
      type=>'select_from_table',
      table=>'ur_lico',
      header_field=>'header',
      value_field=>'id',
      regexp_rules=>[
        '/^\d+$/','Выберите юридическое лицо'
      ]
    },
    {
      description=>'Создано',
      type=>'datetime',
      name=>'registered',
      read_only=>1,
    },
    {
      description=>'Менеджер',
      type=>'select_from_table',
      table=>'manager',
      name=>'manager_id',
      header_field=>'name',
      before_code=>sub{
        my $e=shift;
        if($form->{action} eq 'new'){
          $e->{value}=$form->{manager}->{id}
        }
      },
      value_field=>'id'
    },
  ]
};
