$form={
    title=>'Компании для проверки',
    header_field=>'header',
    work_table=>'cdek_in_comp',
    tree_use=>1,
    sort=>1,
    max_level=>2,
    engine=>'mysql-strong',
    events=>{
      before_save=>sub{
        if(
            $form->{new_values}->{status} && $form->{values}->{status} && 
            ($form->{new_values}->{status} ne $form->{values}->{status}) 
        ){
          #pre($form->{new_values}->{status});
          if($form->{new_values}->{status}==2 || $form->{values}->{status}==2){ # некачественный контакт

          }
          elsif($form->{new_values}->{status} < $form->{values}->{status}){
            push @{$form->{errors}},'статус не может меняться в обратном направлении'
          }
          elsif($form->{new_values}->{status}=~m/^[34]$/){ # жду сканы , жду оригинал
            if(
                ($form->{manager}->{login} ne 'admin') &&  !$form->{manager}->{is_owner}
            ){
              push @{$form->{errors}},'статус "жду сканы" или "жду оригинал" может ставить только руководитель'
            }
          }
        }
        
      },
      after_save=>sub{
        my @set=();
        if($form->{new_values}->{status} ne $form->{values}->{status}){
          push @set,'dt_status=now()'
        }
        if($form->{new_values}->{status_result} ne $form->{values}->{status_result}){
          push @set,'dt_status_result=now()'
        }
        if(scalar(@set)){
          $form->{db}->query(query=>'UPDATE cdek_in_comp SET '.join(', ',@set).' where id=?',values=>[$form->{id}],debug=>1)
        }
        
      },
      permissions=>sub{
        #pre($form->{manager});

        my $v=$form->{values};
        # if($form->{manager}->{login} ne 'admin'){
        #   push @{$form->{errors}},'Доступ запрещён!'
        # }
        if($form->{manager}->{login} eq 'admin' || $v->{manager_id}==$form->{manager}->{id}){
          #$form->{read_only}=0;
        }
        if($form->{id}){
          $form->{title}='Редактирование компании'
        }
        #$form->{db}->query(query=>'select * from cdek_in_comp');
        if($form->{id}){
          $form->{ov}=$form->{db}->query(
            query=>q{
              SELECT
                wt.*,
                mg.header group_name, mg.id group_id
              from
                cdek_in_comp wt
                left join manager m ON m.id=wt.manager_id
                left join manager_group mg on m.group_id=mg.id
              WHERE wt.id=?
            },
            onerow=>1,
            values=>[$form->{id}]
          );
          if(
              $form->{manager}->{is_owner} &&
              $form->{manager}->{CHILD_GROUPS_HASH}->{
                $form->{ov}->{group_id}
              }
          ){
            $form->{is_owner}=1;
            $form->{read_only}=0;
          }
        }
        #pre($form->{ov});
      }
    },
    QUERY_SEARCH_TABLES=>[
      {t=>'cdek_in_comp',a=>'wt'},
      {t=>'manager',a=>'m',l=>'wt.manager_id=m.id',lj=>1},
      {t=>'cdek_in_comp_memo',a=>'memo',l=>'memo.cdek_in_comp_id=wt.id',lj=>1}
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
      { # результат проверки
        description=>'Результат проверки',
        type=>'select_values',
        tab=>'work',
        name=>'checked',
        read_only=>1,
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
      { # менеджер
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
          if($form->{ov}->{group_name}){
            $e->{after_html}=qq{Группа: $form->{ov}->{group_name}};
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
        description=>'Статус',
        name=>'status',
        type=>'select_values',
        tab=>'work',
        before_code=>sub{
          my $e=shift;
          if($form->{manager}->{login} eq 'admin' || $form->{manager}->{is_owner}){
            $e->{make_change_in_search}=1
          }
        },
        values=>[
          {v=>'0',d=>'не выбрано'},
          {v=>'2',d=>'некачественный контакт'},
          {v=>'1',d=>'жду реквизиты'},
          {v=>'3',d=>'жду сканы'},
          {v=>'4',d=>'жду оригинал'},
          {v=>'5',d=>'оригинал получен'},
        ]
      },
      {
        description=>'Последнее изменение статуса',
        type=>'datetime',
        name=>'dt_status',
        read_only=>1,
        tab=>'work'
      },
      {
        description=>'Статус результата',
        name=>'status_result',
        type=>'select_values',
        tab=>'work',
        read_only=>1,
        before_code=>sub{
          my $e=shift;
          if($form->{manager}->{login} eq 'admin' || $form->{id_owner}){
            $e->{read_only}=0;
            $e->{make_change_in_search}=1; 
          }
          if($form->{ov} && $form->{ov}->{status_result_dt}){
            $e->{after_html}=qq{последнее изменение: $form->{ov}->{status_result_dt}}
          }
        },
        values=>[
          {v=>'0',d=>'нет результата'},
          {v=>'1',d=>'получены реквизиты'},
          {v=>'2',d=>'получен скан'},
        ]
      },
      {
        description=>'Последнее изменение статуса результата',
        type=>'datetime',
        name=>'dt_status_result',
        read_only=>1,
        tab=>'work'
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
