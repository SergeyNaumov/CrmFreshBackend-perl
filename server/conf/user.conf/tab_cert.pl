{
  full_str=>1,
  description=>'Сертификат',
  tab=>'cert',
  name=>'certs',
  type=>'1_to_m',
  table=>'user_cert',
  table_id=>'id',
  foreign_key=>'user_id',
  read_only=>1,
  tab=>'tab_cert',
  view_type=>'list',
  before_code=>sub{
    my $e=shift;
    if($form->{is_admin}){
      $e->{read_only}=0;
      #pre($form->{action});
    }
    if($form->{action}!~m{^(edit|add_form|add)$}){
      $e->{read_only}=1;
    
    }
    #pre($form->{action});
    #pre([$form->{old_values}->{firm},$form->{old_values}->{inn}]);
  },
  fields=>[
    {
      description=>'Номер',
      type=>'text',
      name=>'number',
      read_only=>1,
      slide_code=>sub{
        my $e=shift;
        my $v=shift;
        #pre($v);
        return qq{
          $v->{number}<br>
          pdf: <a href="./tools/load_cert.pl?id=$v->{id}">без печати</a> | <a href="./tools/load_cert.pl?id=$v->{id}&with=1">с печатью</a>}
      }
    },
    {
      description=>'ИНН',
      name=>'inn',
      type=>'text',
      regexp=>'^(\d{10}|\d{12})$',
      before_code=>sub{
        my $e=shift;
        if($form->{action} eq 'add_form'){
          $e->{value}=$form->{old_values}->{inn}
        }
      }
    },
    {
      description=>'Наименование компании или ФИО',
      name=>'firm',
      type=>'text',
      before_code=>sub{
        my $e=shift;
        if($form->{action} eq 'add_form'){
          $e->{value}=$form->{old_values}->{firm}
        }
      }
    },
    {
      description=>'Тип компании',name=>'firmtype',
      type=>'select_values',
      values=>[
        {v=>1,d=>'юридическое лицо'},
        {v=>2,d=>'физическое лицо'},
      ],
      regexp=>'^[12]$'
    },
    {
      description=>'Стандарт организации',
      type=>'select_values',
      name=>'standart',
      values=>[
        {v=>1,d=>'Ком. закупки'},
        #{v=>2,d=>'Ком. закупки + 223'},
        #{v=>3,d=>'Ком. закупки + 223 + 44'},
      ],
      regexp=>'^[1-3]$'
    },
    {description=>'Дата создания',type=>'date',name=>'date_from',regexp=>'^20\d{2}-\d{2}-\d{2}$'},
    {
      description=>'Дата окончания',type=>'date',read_only=>1,name=>'date_to',
      before_code=>sub{
        my $e=shift;
        if($form->{action} eq 'add_form'){
          $e->{value}='-';$e->{type}='text';
        }
      }
    }
  ],
  after_insert_code=>sub{
    my $e=shift;
    my $number=sprintf("РПНПГКО RU.ДС.%05d",$e->{id});
    my $sth=$form->{dbh}->prepare("UPDATE user_cert set date_to=(date_from + interval 1 YEAR - interval 1 day),number=? where id=?");
    $sth->execute($number,$e->{id});
  }
}