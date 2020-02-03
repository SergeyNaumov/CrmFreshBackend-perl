$form={
    title => 'Клиенты',
    work_table => 'user',
    work_table_id => 'id',
    default_find_filter => 'firm,next_contact',
    read_only => 0,
    make_delete=>0,
    tree_use => '0',
    GROUP_BY=>'wt.id',
    filters_groups=>[
      {
        description=>'Данные о компании',show=>1,filter_list=>
        [
          'login','firm','otr_id','region_id','web', 'company_type', 'company_role'
        ]
      },
    {
      description=>'Данные о продажах',show=>1,filter_list=>
      [
        'memo','is_consult','not_export','status','vajn','state','manager_id'
      ]
    },
  ],
  before_filters_html=>q{
    
  },
  javascript=>{
    admin_table=>q{
      function click_link(link){
        console.log('Вы нажали ссылку: ');
        console.log(link)
      }
    },
    find_results=>q{

    },
    edit_form=>q{

    },
  },
  search_links=>[
    {link=>'./admin_table.pl?config=user',target=>'_blank',description=>'Пользователи (старый)'}
  ],


  QUERY_SEARCH_TABLES=>
    [
      {table=>'user',alias=>'wt',},
      {table=>'user_contact',alias=>'c',link=>'wt.id = c.user_id', for_fields=>['f_email','f_phone','f_first_name','f_middle_name','f_last_name','f_login'],left_join=>1},
      {table=>'manager',alias=>'m',link=>'wt.manager_id = m.id',left_join=>1},
      {table=>'status',alias=>'s',link=>'wt.status = s.id',left_join=>1,for_fields=>['status']},
      
      # комментарий ОП
      {table=>'user_memo',alias=>'memo',link=>'memo.user_id = wt.id and  memo.type=1',left_join=>1,for_fields=>['memo'],
        select_fields=>{}
      },
      {table=>'manager',alias=>'m_memo',link=>'m_memo.id=memo.manager_id',left_join=>1,for_fields=>['memo'],
        select_fields=>{}
      },
      
      # комментарий СОПР
      {table=>'user_memo',alias=>'memo_sopr',link=>'memo_sopr.user_id = wt.id and memo_sopr.type=2',left_join=>0,for_fields=>['memo_sopr']},
      {table=>'manager',alias=>'m_memo_sopr',link=>'m_memo_sopr.id=memo_sopr.manager_id',left_join=>1,for_fields=>['memo_sopr']},

      # менеджер сопр
      {table=>'manager',alias=>'man_sopr',link=>'wt.manager_sopr = man_sopr.id',left_join=>1,for_fields=>['manager_sopr']},

      # отрасль
      {table=>'otr',alias=>'otr',link=>'wt.otr_id=otr.id',for_fields=>'otr_id',left_join=>1},
      {table=>'region',alias=>'region',link=>'wt.region_id=region.id',for_fields=>'region_id',left_join=>1},
      # комментарий руководителя
      {table=>'user_memo_owner',alias=>'memo_own',link=>'memo_own.user_id = wt.id',left_join=>1,for_fields=>['memo_owner']},
      {table=>'manager',alias=>'m_memo_own',link=>'m_memo_own.id=memo_own.manager_id',left_join=>1,for_fields=>['memo_owner']},
      
      {table=>'docpack',alias=>'dp',link=>'dp.user_id = wt.id',left_join=>1,for_fields=>['bill_paid_to','act_registered']},
      {table=>'user_nuz',alias=>'user_nuz',link=>'user_nuz.user_id=wt.id',left_join=>0,for_fields=>['f_nuz']},
      {table=>'nuz',alias=>'nuz',link=>'nuz.id=user_nuz.nuz_id',,left_join=>0,for_fields=>['f_nuz']},
      # акты, делал для Светы
      {table=>'bill',alias=>'b',link=>'b.docpack_id=dp.id',left_join=>0,for_fields=>['act_registered','bill_paid_to']},
      {table=>'act',alias=>'act',link=>'act.bill_id=b.id',left_join=>0,for_fields=>['act_registered']},
    ],
  run=>{[%INCLUDE './conf/user.conf/run.pl'%]},
  cols=>[ # Модель формы: Колонки / блоки
    [ # Колонка1
      {description=>'Ссылки',name=>'links',hide=>1},
      {description=>'Компания',name=>'comp',make_save=>1},
      {description=>'Реквизиты',name=>'rekvizits',hide=>1},
      {description=>'Сертификаты',name=>'tab_cert',hide=>1},
    ],
    [
      {description=>'Работа',name=>'work',hide=>0},
      {description=>'Сопровождение',name=>'sopr',hide=>1},
      {description=>'Пакеты документов',name=>'docpack',hide=>1},
      {description=>'Коммерческие предложения',name=>'kp',hide=>1},
    ]
  ],
  events=>{
        before_save=>sub{
          my $next_contact=&{$form->{run}->{date_to_int}}(param('next_contact'));
          my $cur_date=&{$form->{run}->{date_to_int}}(&{$form->{run}->{cur_date}}());
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
            #my $sth=$form->{dbh}->prepare("UPDATE $form->{work_table} set registered = now(), KEYFLD=?, last_update=now() where id = ?");
            #$sth->execute($form->{old_values}->{KEYFLD},$form->{id});
            
          }
          else{
            #$form->{dbh}->do("UPDATE user set last_update=now() where id=$form->{id}")
          }
        },
        before_update=>sub{
            my $sth=$form->{dbh}->prepare("SELECT * from user where id=?");
            $sth->execute($form->{id});
            my $values=$sth->fetchall_arrayref({});
            
          
            my $values_json=$form->{self}->to_json($values);
            $sth=$form->{dbh}->prepare("SELECT body from user_history where id=? order by moment desc limit 1");
            $sth->execute($form->{id});
            my $body=$sth->fetchrow();
            if($body ne $values_json){
              
              $sth=$form->{dbh}->prepare("INSERT INTO user_history(id,moment,body,manager_id) values(?,now(),?,?)");
              $sth->execute($form->{id},$values_json,$form->{manager}->{id});
            }
        },
        before_search=>sub{
          if(param('to_doc') eq 'yes'){
            $form->{perpage}=1000;
          }
        },
        after_search=>sub{
          if(param('to_doc') eq 'yes'){
              my $result_list=shift;
              pre($result_list);
              exit;
          }

        }
  },
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
    [%INCLUDE './conf/user.conf/tab_comp.pl'%],
    [%INCLUDE './conf/user.conf/tab_rekvizits.pl'%],
    [%INCLUDE './conf/user.conf/user_getting_cert.pl'%],
    [%INCLUDE './conf/user.conf/tab_work.pl'%],
    [%INCLUDE './conf/user.conf/docpack.pl'%],
  ]
};
