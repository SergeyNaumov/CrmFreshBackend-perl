#$ENV{REMOTE_USER}='managerop2';
use send_mes;
# Детализация бюджетов. Расход. Индексы. Карточка интернет маркетинга. Карточка оптимизации. Карточка интернет проектов.
$form={
	title => 'Карточка бухгалтера',
	work_table => 'user',
	work_table_id => 'id',
	default_find_filter => 'firm,next_contact',
	read_only => '1',
	make_delete=>0,
	tree_use => '0',
  GROUP_BY=>'wt.id',
  javascript=>{
    include=>[
      './conf/user.conf/doubles.js', # проверка на дубли
      './conf/user.conf/lib.js?nc=1'
    ] 
    
  },
  #explain=>1,
  #unique_keys=>[['username']],
  QUERY_SEARCH_TABLES=>
    [
      {table=>'user',alias=>'wt',},
      {table=>'user_contact',alias=>'c',link=>'wt.id = c.user_id', for_fields=>['f_email','f_phone','f_first_name','f_middle_name','f_last_name','f_login'],left_join=>1},
      {table=>'manager',alias=>'m',link=>'wt.manager_id = m.id',left_join=>1},
      {table=>'status',alias=>'s',link=>'wt.status = s.id',left_join=>1,for_fields=>['status']},
      
      # комментарий
      {table=>'user_memo',alias=>'memo',link=>'memo.user_id = wt.id',left_join=>1,for_fields=>['memo']},
      {table=>'manager',alias=>'m_memo',link=>'m_memo.id=memo.manager_id',left_join=>1,for_fields=>['memo']},
      
      # отрасль
      {table=>'otr',alias=>'otr',link=>'wt.otr_id=otr.id',for_fields=>'otr_id',left_join=>1},
      {table=>'region',alias=>'region',link=>'wt.region_id=region.id',for_fields=>'region_id',left_join=>1},
      # комментарий руководителя
      {table=>'user_memo_owner',alias=>'memo_own',link=>'memo_own.user_id = wt.id',left_join=>1,for_fields=>['memo_owner']},
      {table=>'manager',alias=>'m_memo_own',link=>'m_memo_own.id=memo_own.manager_id',left_join=>1,for_fields=>['memo_owner']},
      
      {table=>'docpack',alias=>'dp',link=>'dp.user_id = wt.id',left_join=>1,for_fields=>['paid_to']},
      {table=>'user_nuz',alias=>'user_nuz',link=>'user_nuz.user_id=wt.id',left_join=>0,for_fields=>['f_nuz']},
      {table=>'nuz',alias=>'nuz',link=>'nuz.id=user_nuz.nuz_id',,left_join=>0,for_fields=>['f_nuz']}
    ],
  run=>{[%INCLUDE './conf/user.conf/run.pl'%]},
  cols=>[ # Модель формы: Колонки / блоки
    [ # Колонка1
      
      {description=>'Компания',name=>'comp'},
      
    ],
    [
      {description=>'Пакеты документов',name=>'docpack'},
    ]
  ],
	events=>{
		permissions=>[%INCLUDE './conf/user.conf/permissions.pl'%],
    before_save=>sub{
      #pre();
      my $next_contact=&{$form->{run}->{date_to_int}}(param('next_contact'));
      my $cur_date=&{$form->{run}->{date_to_int}}(&{$form->{run}->{cur_date}}());

      #if($cur_date>$next_contact){
      #  push @{$form->{errors}},q{Дата след. контакта не может быть в прошлом};
      #}

    },
    before_insert=>sub{
      $form->{old_values}->{company_role}=$form->{new_values}->{company_role};
      if($form->{new_values}->{company_role}==1){
        $form->{KEYFLD}='supplier_2_'
      }
      elsif($form->{new_values}->{company_role}==2){
        $form->{KEYFLD}='contractor_2_'
      }
      else{
        push @{$form->{errors}},q{Не выбран тип клиента!}
      }
    },
    after_save=>sub{
      if($form->{action} eq 'insert'){
        #$form->{old_values}->{company_role}=$form->{new_values}->{company_role}; 
        $form->{old_values}->{KEYFLD}=$form->{KEYFLD}.$form->{id};
        my $sth=$form->{dbh}->prepare("UPDATE $form->{work_table} set registered = now(), KEYFLD=?, last_update=now() where id = ?");
        $sth->execute($form->{old_values}->{KEYFLD},$form->{id});
        
      }
      else{
        $form->{dbh}->do("UPDATE user set last_update=now() where id=$form->{id}")
      }
    },
    before_update=>sub{
        my $sth=$form->{dbh}->prepare("SELECT * from user where id=?");
        $sth->execute($form->{id});
        my $values=$sth->fetchall_arrayref({});
        
        
        foreach my $c (@{$values}){
          foreach my $k ((keys %{$c})){
            Encode::_utf8_on($c->{$k});
          }
        }
        my $values_json=to_json($values);
        $sth=$form->{dbh}->prepare("SELECT body from user_history where id=? order by moment desc limit 1");
        $sth->execute($form->{id});
        my $body=$sth->fetchrow();
        if($body ne $values_json){
          
          $sth=$form->{dbh}->prepare("INSERT INTO user_history(id,moment,body,manager_id) values(?,now(),?,?)");
          $sth->execute($form->{id},$values_json,$form->{manager}->{id});
        }
    }
	},
  #get_const=>['make_comment_owner'],
	fields=>[
    [%INCLUDE './conf/user.conf/tab_links.pl'%],
    {
      name=>'KEYFLD',
      type=>'hidden',
      before_insert=>sub{
        my $e=shift;
        unless($e->{value}){
          $e->{value}='tmp_'.gen_pas();
        }
      }
    },
    [%INCLUDE './conf/user.conf/filters.pl'%],

    # {
    #   description=>'Логин пользователя',
    #   name=>'username',
    #   type=>'text',
    #   tab=>'comp'
    # },

    
    [%INCLUDE './conf/user.conf/tab_comp.pl'%],
    [%INCLUDE './conf/user.conf/tab_rekvizits.pl'%],
    
    
    
    [%INCLUDE './conf/user.conf/docpack.pl'%],
    
	]
};
