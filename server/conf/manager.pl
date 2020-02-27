#use lib './lib';
#use core_strateg qw(child_groups);
#use send_mes;
$form={
  title => 'Менеджеры',
  work_table => 'manager',
  work_table_id => 'id',
  make_delete => '0',
  not_create=>1,
  read_only=>1,
  not_create=>1,
  make_delete=>0,
  default_find_filter => 'login',
  tree_use => '0',
  javascript=>{
    include=>['./conf/manager.conf/init.js?ns=1']
  },
  unique_keys=>[['login']],
  #explain=>1,
  run=>{

     gen_pas=>sub{
        my $len=shift;
        my $symbols=shift;
        $len=8 unless($len);
        $symbols='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' unless($symbols);
        my $key='';
        foreach my $k (1..$len){
          $key.=substr($symbols,int(rand(length($symbols))),1)
        }
        return $key
     }
  },
  events=>{
    before_delete=>sub{
      #push @{$form->{errors}},'Ahtung!'
    },
    permissions=>[
      sub{
        
        if($form->{id}){
          my $sth=$form->{dbh}->prepare("SELECT * from manager where id=?");
          $sth->execute($form->{id});
          $form->{old_values}=$sth->fetchrow_hashref;
        }
        # !$form->{manager}->{permissions}->{manager_adm}
        if($form->{manager}->{login} ne 'admin'){

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
          $form->{is_admin}=0;
          $form->{read_only}=0;
          $form->{make_delete}=0;
          $form->{not_create}=0;
        }
        
      },


    ],
    before_delete=>sub{
        if($form->{old_values}->{login} eq 'admin'){
          push @{$form->{errors}},'Админа удалять нельзя'
          #print "<p style='text-align: center;'></p>";
          #exit; 
        }
        
        
        
    },
    # before_search=>sub{
    #   if($form->{where_list}=~m{mg.id IN \((.+?)\)}){
    #     my $list=$1;
    #     my @ids=$list=~m{(\d+)}g;
    #     @ids=core_strateg::child_groups(
    #         connect=>$form->{connects}->{strateg_read},
    #         group_id=>\@ids
    #     );
    #     my $ids_str=join(',',@ids);
    #     $form->{where_list}=~s{mg.id IN \((.+?)\)}{mg.id in \($ids_str\)};
    #   }

    # },

  },
  cols=>[ # Модель формы: Колонки / блоки
    [ # Колонка1
      {description=>'Общая информация',name=>'main'},
    ],
    [
      {description=>'Права',name=>'permissions'},
    ]
  ],
  QUERY_SEARCH_TABLES=>
  [
    {table=>'manager',alias=>'wt'},
    {table=>'manager_group',alias=>'mg',link=>'wt.group_id=mg.id',left_join=>1},
  ],
  search_on_load=>1,
  fields =>
  [
    {
      description=>'ID',
      name=>'id',
      type=>'text',
      read_only=>1,
      filter_on=>1

    },
    {
      name => 'name',
      description => 'Имя',
      type => 'text',
      tab=>'main',
      filter_on=>1
    },
    {
      name => 'login',
      description => 'Логин',
      #add_description=>'только символы: a..z,A..Z, 0-9, _, -, @, .',
      type => 'text',
      filter_on=>1,
      #regexp=>'^[a-zA-Z\-_0-9\.\@]+$',
      filter_code=>sub{
        my $e=shift;
        my $login=$e->{str}->{wt__login};
        $login=~s{([^a-zA-Z\-_0-9\.\@]+)}{<span style="color: red;">$1</span>}gs;
        return $login;
      },
      unique=>1,
      regexp_rules=>[
        '/.{5}/','длина логина должна быть не менее 5 символов',
        '/^[a-zA-Z0-9\-_@\/]+$/','только символы: a..z,A..Z, 0-9, _, -, @, .'
      ],
      tab=>'main'
    },
    {
      description=>'Аватар',
      type=>'file',
      name=>'photo',
      filedir=>'./files/manager',
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
      tab=>'main'
    },
    # {
    #   name=>'login_tel',
    #   description=>'Логин для IP-телефонии',
    #   type => 'text',
    #   tab=>'main'
    # },
    {
      description=>'Телефон',
      type=>'text',
      name=>'phone',
      tab=>'main',
      regexp_rules=>[
        q{/^(\+7\d{10})?$/},'Если указывается телефон, он должен быть в формате +7XXXXXXXXXX',
      ],
      replace_rules=>[
        '/^[87]/'=>'+7',
        '/[^\d\+]+/'=>'',
        '/^([^87\+])/'=>'+7$1',
      ],
      #regexp=>'^(\+\d{6}\d*)?$',
      # replace=>[
      #   ['(^\(|,\s*\()','+7'],
      #   ['[^\+\s\d,]',''],
      #   ['(^\s+|[^,\d]\s+$)',''],
      #   ['(^|,\s*)(9|4)','$1+7$2'],
      #   ['(^|,\s*)[8]','+7'],
      #   ['^(\d)',' +$1'],
      #   ['(,\s*)(\d)',', +$2'],
      #   ['(\d)\s(\d)','$1$2'],
      #   ['(,\s*),','$1'],
      #   ['(\d)\+7','$1, +7']
      # ],
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
          method_send=>sub{
            my $new_password=shift;
            $s->send_mes()
          }
        }
      ],
      tab=>'main'
    },
    {
      description=>'Вкл',
      name=>'enabled',
      type=>'checkbox',
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
      description=>'Уволен',
      type=>'checkbox',
      name=>'gone',
      tab=>'permissions'
    },
    {
      description=>'Текущая роль',
      type=>'select_from_table',
      table=>'manager',
      header_field=>'name',
      value_field=>'id',
      not_filter=>'1',
      name=>'current_role',
      before_code=>sub{
        my $e=shift;
        if(!$form->{is_admin}){
          $e->{where}=qq{id in (select role from manager_role where manager_id=$form->{manager}->{id}) }
        }
        else{
          #$e->{autocomplete}=1
        }
      },
      tab=>'permissions',

    },
    {
      description=>'Доступные роли',
      name=>'manager_role',
      type=>'1_to_m',
      table=>'manager_role',
      table_id=>'id',
      foreign_key=>'manager_id',
      fields=>[
        {
          description=>'Роль',
          name=>'role',
          type=>'select_from_table',
          table=>'manager',
          header_field=>'name',
          value_field=>'id'
        }
      ],
      tab=>'permissions'
    },

    {
      name => 'group_id',
      description => 'Группа менеджера',
      type => 'select_from_table',
      table=>'manager_group',
      tree_use=>1,
      tablename=>'mg',
      header_field=>'header',
      value_field=>'id',
      tab=>'permissions',
      filter_code=>sub{
        my $s=$_[0]->{str};
        return qq{<a href="./edit_form.pl?config=manager_group&action=edit&id=$s->{mg__id}" target="_blank">$s->{mg__header}</a>}
      }
    },

    {
      before_code=>sub{
              my $e=shift;                    
              #$e->{read_only}=1 unless($form->{manager}->{permissions}->{make_change_permissions});
      },
      description=>'Права менеджеров',
      type=>'multiconnect',
      tree_use=>1,
      tree_table=>'permissions',
      name=>'permissions',
      relation_table=>'permissions',
      relation_save_table=>'manager_permissions',
      relation_table_header=>'header',
      relation_save_table_header=>'header',
      relation_table_id=>'id',
      relation_save_table_id_worktable=>'manager_id',
      relation_save_table_id_relation=>'permissions_id',
      tab=>'permissions'
    },



  ]
};



