$form={
  title => 'Сотрудники',
  work_table => 'project_manager',
  work_table_id => 'id',
  make_delete => '0',
  not_create=>1,
  read_only=>1,
  default_find_filter => 'login',
  tree_use => '0',
  javascript=>{
    include=>['./conf/manager.conf/init.js?ns=1']
  },
  run=>{
  },
  events=>{
    permissions=>[
      sub{
        if($form->{id}){
          $form->{old_values}=$form->{db}->query(
            query=>'SELECT * from project_manager where id=?',
            values=>[$form->{id}],
            onerow=>1,
          );

        }
        #print Dumper({ov=>$form->{old_values}});
        if(!$form->{manager}->{permissions}->{manager_adm} && ($form->{manager}->{login} ne 'admin')){

          foreach my $f (@{$form->{fields}}){
            # для тех, кому не дано право администрировать сотрудников -- разрешаем только выбирать роль
            if(($f->{name} eq 'current_role') && ($form->{old_values}->{id}==$form->{manager}->{id}) ){
              $f->{read_only}=0;
            }
            else{
             $f->{read_only}=1; 
            }
          }
        }
        else{
          $form->{is_admin}=1;
          $form->{read_only}=0;
          $form->{make_delete}=1;
          $form->{not_create}=0;
        }

      },
    ],
    before_delete=>sub{
      if($form->{old_values}->{login} eq 'admin'){
        push @{$form->{errors}},"Пользователя с логином admin удалять нельзя";
      }
    },
  },
  cols=>[ # Модель формы: Колонки / блоки
    [ # Колонка1
      {description=>'Общая информация',name=>'main'},
    ],
    [
      {description=>'Права',name=>'permissions'},
    ]
  ],
  explain=>1,
  QUERY_SEARCH_TABLES=>
  [
    {table=>'project_manager',alias=>'wt'},
    {table=>'project',alias=>'p',left_join=>1,link=>'wt.project_id=p.id'},
    {table=>'project_manager_group',alias=>'mg',link=>'wt.group_id=mg.id',left_join=>1},
  ],
  fields =>
  [
    {
      description=>'Проект',
      type=>'select_from_table',
      tablename=>'p',
      table=>'project',
      name=>'project_id',
      header_field=>'header',
      value_field=>'id',
      value=>'1',
      filter_on=>1,
      filter_code=>sub{
        my $str=$_[0]->{str};
        return qq{$str->{p__header} ($str->{p__domain})}
      }
    },
    {
      name => 'name',
      description => 'Имя',
      type => 'text',
      tab=>'main',
      filter_on=>1
    },
    {
      description=>'Аватар',
      type=>'file',
      name=>'photo',
      before_code=>sub{
        my $e=shift;
        $e->{filedir}='./files/project_'.$form->{project}->{id}.'/manager'
      },
      # .accept=>'doc,.docx,.xml,application/msword,application/vnd.openxm
      #accept=>'image/png, image/jpeg',
      accept=>'image/*',
      crops=>1,
      resize=>[
        {
          description=>'Горизонтальное фото',
          file=>'<%filename_without_ext%>_mini1.<%ext%>',
          size=>'256x256',
          quality=>'100'
        },
      ],
      filter_code=>sub{
        my $e=shift;
        my $str=$e->{str};
        if($str->{wt__photo}){
          if($str->{wt__photo}=~m/^(.+)\.([^.]+)$/){
            my ($name,$ext)=($1,$2);
            return qq{<img src="/files/project_1/manager/$name\_mini1.$ext">}
          }
          return '';
          
        }
        else{
          return 'нет фото'
        }
        
      },
      tab=>'main'
    },
    {
      name => 'login',
      description => 'Логин',
      #add_description=>'только символы: a..z,A..Z, 0-9, _, -, @, .',
      type => 'text',
      filter_on=>1,
      before_code=>sub{
        my $e=shift;
        if($form->{old_values} && $form->{old_values}->{login} eq 'admin'){
          $e->{read_only}=1;
          $e->{add_description}='Внимание! у администратора запрещено менять логин'
        }
      },
      filter_code=>sub{
        my $e=shift;
        my $login=$e->{str}->{wt__login};
        $login=~s{([^a-zA-Z\-_0-9\.\@]+)}{<span style="color: red;">$1</span>}gs;
        return $login;
      },
      unique=>1,
      tab=>'main'
    },
    {
      description=>'Телефон',
      type=>'text',
      name=>'phone',
      tab=>'main',
      regexp_rules=>[
        q{/^(\+\d+)?$/},
        #q{/^(\+7\d{10})?$/},'Если указывается телефон, он должен быть в формате +7XXXXXXXXXX',
      ],
      replace_rules=>[
        '/^[87]/'=>'+7',
        '/[^\d\+]+/'=>'',
        '/^([^87\+])/'=>'+7$1',
      ],
    },
    {
      description=>'Добавочный',
      type=>'text',
      name=>'phone_dob',
      tab=>'main',
      regexp=>'^\d*$'
    },
    {
      description=>'Мобильный телефон',
      type=>'text',
      name=>'mobile_phone',
      tab=>'main',
      regexp_rules=>[
        q{/^(\+7\d{10})?$/},'Если указывается телефон, он должен быть в формате +7XXXXXXXXXX',
      ],
      replace_rules=>[
        '/^[87]/'=>'+7',
        '/[^\d\+]+/'=>'',
        '/^([^87\+])/'=>'+7$1',
      ],
    },
    {
      description=>'Пароль',
      name=>'password',
      type=>'password',
      encrypt_method=>'mysql_encrypt',
      methods_send=>[
        {
          description=>'сохранить',
        },
        {
          description=>'сохранить и отправить на email',
          code=>sub{
            my $new_password=shift;
            # v=spf1 ip4:37.143.9.146 ip4:178.57.220.204 include:_spf.yandex.net ~all
            
            my $email=$form->{old_values}->{email};
            #print "email: $email\n";
            
            $form->{project}->{email_for_notifications}='info@freshcrm.ru' 
              unless($form->{project}->{email_for_notifications});

            if($email=~m/@/){
                $s->send_mes(
                  from=>$form->{project}->{email_for_notifications},
                  to=>$email,
                  subject=>qq{CRM "$form->{project}->{header}"},
                  message=>qq{
                    Для Вас создана учётная запись:
                    <a href="https://$form->{host}">https://$form->{host}</a><br>
                    логин: $form->{values}->{login}<br>
                    пароль: $new_password
                  }
                );
            }

          }
        }
      ],
      tab=>'main'
    },

    {
      name => 'email',
      description => 'Email',
      type => 'text',
      replace=>[
        ['\s+','']
      ],
      regexp=>'^([a-zA-Z0-9_\-\.]+@[a-zA-Z0-9_\-\.]+\.[a-zA-Z0-9_\-]+)?$',
      after_insert=>sub{
        my $e=shift;
        #pre($form->{values});
        if($e->{value}=~m{@}){
          my $sth=$form->{dbh}->prepare("UPDATE manager set password=ENCRYPT(?) where id=?");
          $sth->execute($form->{values}->{password},$form->{id});
          
          $form->{self}->send_mes(
            from=>'info@crm.strateg.ru',
            to=>$e->{value},
            subject=>'CRM ООО "Стратег"',
            message=>qq{
              Для Вас создана учётная запись:
              <a href="https://crm.strateg.ru">https://crm.strateg.ru</a><br>
              логин: $form->{values}->{login}<br>
              пароль: $form->{values}->{password}
            }
          );
        }
        #pre($e);
      },
      tab=>'main'
    },
    {
      description=>'Вкл',
      name=>'enabled',
      type=>'checkbox',
      tab=>'permissions',
      before_code=>sub{
        my $e=shift;
        if($form->{action} eq 'new'){
          $e->{value}=1
        }
      }
    },
    {
      description=>'Уволен',
      type=>'checkbox',
      name=>'gone',
      tab=>'permissions'
    },
    {
      description=>'Текущая роль',
      type=>'select_from_table',
      table=>'project_manager',
      header_field=>'name',
      value_field=>'id',
      not_filter=>'1',
      name=>'current_role',
      before_code=>sub{
        my $e=shift;
        {
          $e->{where}.=qq{ id in
            (
              select
                mr.role
              from
                project_manager_role mr 
              where
                mr.manager_id=$form->{manager}->{id}
            ) 
          }
        }
      },
      tab=>'permissions',

    },
    {
      name => 'group_id',
      description => 'Группа менеджера',
      type => 'select_from_table',
      table=>'project_manager_group',
      tree_use=>1,
      tablename=>'mg',
      header_field=>'header',
      value_field=>'id',
      tab=>'permissions',
      read_only=>1,
      before_code=>sub{
        my $e=shift;
      },
      filter_code=>sub{
        my $s=$_[0]->{str};
        return qq{<a href="/edit_form/project_manager_group/$s->{mg__id}" target="_blank">$s->{mg__header}</a>}
      }
    },
    {
      before_code=>sub{
        my $e=shift;
      },
      description=>'Права менеджеров',
      type=>'multiconnect',
      tree_use=>1,
      #tree_table=>'permissions',
      name=>'permissions',
      relation_table=>'permissions_for_project',
      relation_save_table=>'project_manager_permissions',
      relation_table_header=>'header',
      relation_save_table_header=>'header',
      relation_table_id=>'id',
      relation_save_table_id_worktable=>'manager_id',
      relation_save_table_id_relation=>'permissions_id',
      before_code=>sub{

      },
      tab=>'permissions'
    },
  ]
};
