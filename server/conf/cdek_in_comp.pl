$form={
    title=>'Компании для проверки',
    header_field=>'header',
    work_table=>'cdek_in_comp',
    tree_use=>1,
    sort=>1,
    max_level=>2,
    read_only=>1,
    explain=>1,
    events=>{
      permissions=>sub{
        my $v=$form->{values};
        # if($form->{manager}->{login} ne 'admin'){
        #   push @{$form->{errors}},'Доступ запрещён!'
        # }
        if($form->{manager}->{login} eq 'admin' || $v->{manager_id}==$form->{manager}->{id}){
          $form->{read_only}=0;
        }
        if($form->{id}){
          $form->{title}='Редактирование компании'
        }
      }
    },
    QUERY_SEARCH_TABLES=>[
      {t=>'cdek_in_comp',a=>'wt'},
      {t=>'manager',a=>'m',l=>'wt.manager_id=m.id',lj=>1}
    ],
    cols=>[
      [{name=>'info',description=>'общая информация'}],
      [{name=>'work',description=>'работа с компанией'}],
    ],
    fields=>[
      {
          description=>'Наименование',
          type=>'text',
          name=>'header',
          tab=>'info',
          filter_on=>1
      },
      {
          description=>'ИНН',
          type=>'text',
          name=>'inn',
          tab=>'info',
          filter_on=>1
      },
      {
          description=>'Email',
          type=>'text',
          name=>'email',
          tab=>'info',
          filter_on=>1
      },
      {
          description=>'Сайт',
          type=>'text',
          name=>'site',
          tab=>'info',
          filter_on=>1
      },
      {
          description=>'Телефон',
          type=>'text',
          name=>'phone',
          tab=>'info',
          filter_on=>1
      },
      {
        description=>'Результат проверки',
        type=>'select_values',
        tab=>'work',
        name=>'checked',
        values=>[
          {v=>'0',d=>'не проверялась'},
          {v=>'1',d=>'дубль (ИНН)'},
          {v=>'2',d=>'дубль (email)'},
          {v=>'3',d=>'дубль (телефон)'},
          {v=>'4',d=>'дубль (сайт)'},
          {v=>'100',d=>'дублей не найдено'},
          {v=>'101',d=>'поставлен на паузу (ошибка проверки)'},
        ],
        filter_on=>1,

      },
      {
        description=>'Менеджер',
        name=>'manager_id',
        type=>'select_from_table',
        table=>'manager',
        header_field=>'name',
        value_field=>'id',
        tablename=>'m',
        read_only=>1,
        before_code=>sub{
          my $e=shift;
          if($form->{manager}->{login} eq 'admin'){
            $e->{read_only}=0;
            $e->{make_change_in_search}=1
          }
        },
        tab=>'work'
      },
      {
        description=>'Следующий контакт',
        type=>'date',
        name=>'next_contact',
        tab=>'work'
      },
      {
        description=>'Статус процесса',
        name=>'status',
        type=>'select_values',
        tab=>'work',
        before_code=>sub{
          my $e=shift;
          if($form->{manager}->{login} eq 'admin'){
            $e->{make_change_in_search}=1
          }
        },
        values=>[
          {v=>'0',d=>'не выбрано'},
          {v=>'2',d=>'некачественный контакт'},
          {v=>'1',d=>'жду реквизиты'},
          {v=>'3',d=>'жду сканы'},
          {v=>'4',d=>'жду оригинал'},
        ]
      },
      {
        description=>'Статус результата',
        name=>'status_result',
        type=>'select_values',
        tab=>'work',
        read_only=>1,
        make_change_in_search=>1,
        before_code=>sub{
          # здесь руководителю разрешаем редактировать
          my $e=shift;
          if($form->{manager}->{login} eq 'admin'){
            $e->{read_only}=1
          }
        },
        values=>[
          {v=>'0',d=>"нет результата"},
          {v=>'2',d=>"получены реквизиты"},
          {v=>'1',d=>"получен скан"},
          {v=>'3',d=>"получен оригинал"},
          
        ]

      },
      { # Memo
          # Комментарий 
          description=>'Комментарий',
          name=>'memo',
          type=>'memo',
          memo_table=>'cdek_in_comp_memo',
          memo_table_id=>'id',
          memo_table_comment=>'body',
          memo_table_auth_id=>'manager_id',
          memo_table_registered=>'registered',
          memo_table_foreign_key=>'cdek_in_comp_id',
          auth_table=>'manager',
          auth_login_field=>'login',
          auth_id_field=>'id',
          auth_name_field=>'name',
          reverse=>1,
          memo_table_alias=>'memo',
          auth_table_alias=>'m_memo',
          make_delete=>1,
          make_edit=>1,
          tab=>'memo',
          tab=>'work'
      },


    ]
};
