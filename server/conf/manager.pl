#use lib './lib';
#use core_strateg qw(child_groups);
$form={
	title => 'Менеджеры',
	work_table => 'manager',
	work_table_id => 'id',
	make_delete => '0',
  not_create=>1,
  read_only=>1,
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
		permissions=>[
      sub{
              if($form->{id}){
                my $sth=$form->{dbh}->prepare("SELECT * from manager where id=?");
                $sth->execute($form->{id});
                $form->{old_values}=$sth->fetchrow_hashref;
              }
      },
      sub{
        


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
          if($form->{id} && $form->{action} eq 'changepas'){
            print_header;
            my $newpassword=param('newpassword');
            if(length($newpassword)){
              my $sth=$form->{dbh}->prepare("UPDATE manager set password=ENCRYPT(?) where id=?");
              $sth->execute($newpassword,$form->{id});
              #pre(param('need_send_pas')); pre($form->{old_values}->{email});
              if(param('need_send_pas') && $form->{old_values}->{email}=~m/@/){
                print "отправлено на $form->{old_values}->{email}<br>";
                $form->{self}->send_mes({
                  from=>'info@crm.strateg.ru',
                  to=>$form->{old_values}->{email},
                  subject=>'изменение пароля',
                  message=>qq{
                    Для доступа в https://crm.strateg.ru/:<br>
                    Логин: $form->{old_values}->{login}<br>
                    Пароль: $newpassword
                  }
                });
              }
              print "Пароль для данного сотрудника был успешно изменён";
            }
            else{
              print "Не удалось изменить пароль"
            }
            exit;
          }
        }

      },


    ],
    before_delete=>sub{
        if($form->{old_values}->{login} eq 'admin'){
          print "<p style='text-align: center;'>Админа удалять нельзя!</p>";
        }
        exit; 
    },
    before_search=>sub{
      if($form->{where_list}=~m{mg.id IN \((.+?)\)}){
        my $list=$1;
        my @ids=$list=~m{(\d+)}g;
        @ids=core_strateg::child_groups(
            connect=>$form->{connects}->{strateg_read},
            group_id=>\@ids
        );
        my $ids_str=join(',',@ids);
        $form->{where_list}=~s{mg.id IN \((.+?)\)}{mg.id in \($ids_str\)};
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
  QUERY_SEARCH_TABLES=>
  [
    {table=>'manager',alias=>'wt'},
    {table=>'manager_group',alias=>'mg',link=>'wt.group_id=mg.id',left_join=>1},
  ],
	fields =>
	[
    {
      description=>'Вкл',
      name=>'enabled',
      type=>'checkbox',
      tab=>'main'
    },
		{
			name => 'login',
			description => 'Логин',
      add_description=>'только символы: a..z,A..Z, 0-9, _, -, @, .',
			type => 'text',
      regexp=>'^[a-zA-Z\-_0-9\.\@]+$',
      filter_code=>sub{
        my $e=shift;
        my $login=$e->{str}->{wt__login};
        $login=~s{([^a-zA-Z\-_0-9\.\@]+)}{<span style="color: red;">$1</span>}gs;
        return $login;
      },
      tab=>'main'
		},
    {
      name=>'login_tel',
      description=>'Логин для IP-телефонии',
      type => 'text',
      tab=>'main'
    },
    {
      description=>'Телефон',
      type=>'text',
      name=>'phone',
      tab=>'main',
      regexp=>'^(\+\d{6}\d*)?$',
      replace=>[
        ['(^\(|,\s*\()','+7'],
        ['[^\+\s\d,]',''],
        ['(^\s+|[^,\d]\s+$)',''],
        ['(^|,\s*)(9|4)','$1+7$2'],
        ['(^|,\s*)[8]','+7'],
        ['^(\d)',' +$1'],
        ['(,\s*)(\d)',', +$2'],
        ['(\d)\s(\d)','$1$2'],
        ['(,\s*),','$1'],
        ['(\d)\+7','$1, +7']
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
      regexp=>'^(\+\d{6}\d*)?$',
      replace=>[
        ['(^\(|,\s*\()','+7'],
        ['[^\+\s\d,]',''],
        ['(^\s+|[^,\d]\s+$)',''],
        ['(^|,\s*)(9|4)','$1+7$2'],
        ['(^|,\s*)[8]','+7'],
        ['^(\d)',' +$1'],
        ['(,\s*)(\d)',', +$2'],
        ['(\d)\s(\d)','$1$2'],
        ['(,\s*),','$1'],
        ['(\d)\+7','$1, +7']
      ],
    },
    {
      description=>'Пароль',
      name=>'password',
      type=>'code',
      before_code=>sub{
        my $e=shift;
        if($form->{action} eq 'new'){
          $e->{value}=&{$form->{run}->{gen_pas}};
        }
        if($form->{action}=~m{^(new|insert)$}){
          $e->{type}='text';
          $e->{code_completed}=1;
        }
        
      },
      code=>sub{
        my $e=shift;
        return '' unless($form->{id});
        unless($form->{is_admin}){
          return 'возможность изменять пароль есть только у сотрудников со специальными правами';
        }

        my $need_send_pas=$form->{old_values}->{email}=~m/@/?
        qq{<input type="checkbox" id="need_send_pas"> отправить сотруднику на почту}:'';

        return qq{
          <div style="padding: 10px 0 10px 0">
            <p>Текущий пароль сотрудника <b>зашифрован</b>.<br>Вы не можете его увидеть, но можете изменить его:</p>
            $need_send_pas
            <input type="text" id="newpassword" placeholder="изменить"> <input type="button" id="changepas" value="изменить">
            <br><a href="#" id="genpas">сгенерировать</a>
          </div>
          <div id="password_process" style="color: red; font-weight: bold;">
          </div>
        }
      },
      tab=>'main'
    },

    {
      name => 'name',
      description => 'Имя',
      type => 'text',
      tab=>'main'
    },
    {
      description=>'Фото',
      type=>'file',
      filedir=>'./files/manager',
      name=>'photo',
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
          
          $form->{self}->send_mes({
            from=>'info@crm.strateg.ru',
            to=>$e->{value},
            subject=>'CRM ООО "Стратег"',
            message=>qq{
              Для Вас создана учётная запись:
              <a href="https://crm.digitalstrateg.ru">https://crm.digitalstrateg.ru</a><br>
              логин: $form->{values}->{login}<br>
              пароль: $form->{values}->{password}
            }
          });
        }
        #pre($e);
      },
      tab=>'main'
    },
    {
      description=>'Число и месяц рождения',
      tab=>'main',
      add_description=>'dd/mm',
      type=>'text',
      name=>'born'
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
      
      #tree_table=>'permissions',
      name=>'permissions',
      relation_table=>'permissions',
      relation_save_table=>'manager_permissions',
      relation_table_header=>'header',
      relation_save_table_header=>'header',
      relation_table_id=>'id',
      relation_save_table_id_worktable=>'manager_id',
      relation_save_table_id_relation=>'permissions_id',
      before_code=>sub{

      },
      tree_use=>1,
      tab=>'permissions'
    },
    # {
    #   description=>'RE-ID',
    #   type=>'text',
    #   name=>'re_id',
    #   make_change_in_search=>1,
    #   tab=>'permissions'
    # },


	]
};



