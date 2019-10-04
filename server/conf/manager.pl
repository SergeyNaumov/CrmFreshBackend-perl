$form={
    engine=>'mysql-strong',
    title=>'Сотрудники',
    card_format=>'vue',
    #read_only=>1,
    default_find_filter=>[
      'login','name'
    ],
    events=>{
      before_delete=>sub{
        #push @{$form->{errors}},'Удалять запрещено!'
      }
    },
    cols=>[
      [ # Колонка1
        {description=>'Общая информация',name=>'main'},
      ],
      [
        {description=>'Права',name=>'permissions'},
      ]
    ],
    fields=>[
      {
          description=>'Логин',
          type=>'text',
          name=>'login',
          filter_on=>1,
          regexp_rules=>[
            q{/^[a-zA-Z0-9]+$/}=>'логин может содержать только латинские буквы и цифры',
            q{/^.{3,8}$/}=>'длина логина должна боть от 3 до 8 символов',
          ],
          ajax_check=>sub{
            
          },
          placeholder=>'это placeholder',
          add_description=>'доп. описание',
          filter_on=>1,
          tab=>'main'
      },
      {
        description=>'Пароль',
        name=>'password',
        type=>'password',
        encrypt_method=>'mysql_encrypt',
        symbols=>'123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-/\?+&#@!~`^$()[]{}.,;:',
        min_length=>8,
        #not_filter=>1,
        permissions=>sub{
          #print "id: $form->{id} form: $form\n";
          if($form->{id}){
            $form->{old_values}=$form->{db}->query(query=>'select * from manager where id=?',values=>[$form->{id}],onerow=>1);
          }
          
          #print Dumper($form->{old_values});
        },
        methods_send=>[
          {
            description=>'сохранить и отправить на email',
            code=>sub{
              my $new_password=shift;
              #print "self: $form->{self}\n";
              if($form->{old_values}->{email}!~m/@/){
                push @{$form->{errors}},'Email для данного сотрудника не указан. Пароль изменён, но не отправлен';
              }
              #use Data::Dumper;
              #print Dumper($form->{old_values});
              my $cfg=$form->{self}->{config};
              # $form->{self}->send_mes(
              #   from=>$cfg->{system_email},
              #   to=>$form->{old_values}->{email},
              #   subject=>"Для Вас сгенерирован новый пароль",
              #   message=>qq{
              #     Ваш новый пароль: $new_password
              #   }
              # );
            }
          },
          {
            description=>'сохранить и отправить по SMS',
            code=>sub{
              my $new_password=shift; 
              if(!$form->{old_values}->{email}){
                push @{$form->{old_values}},'Email не указан!';
              }
              else{
                $form->{db}->query(
                  query=>"UPDATE $form->{work_table} SET password=? where id=?",
                  errors=>$form->{errors},
                  values=>[$new_password,$form->{id}]
                );
              }
              

            }
          },
          {
            description=>'сохранить и не отправлять',
            code=>sub{
              
            }
          },
        ],
        tab=>'main'
      },
      {description=>'Email',type=>"text",name=>"email",tab=>'main'},
      {
        description=>'ФИО сотрудника',
        type=>'text',
        name=>'name',
        filter_on=>1,
        tab=>'main'
      },
      {
        description=>'Фото',
        type=>'file',
        filedir=>'./files/manager',
        name=>'photo',
        tab=>'main'
      },
      # {
      #   description=>'Число и месяц рождения',
      #   tab=>'main',
      #   add_description=>'dd/mm',
      #   type=>'text',
      #   name=>'born'
      # },
      {
        description=>'Телефон',type=>"text",name=>"phone",
        add_description=>'в формате +7XXXXXXXXXX',
        regexp_rules=>[
          q{/^\+?\d{11}$/}=>'в формате +7XXXXXXXXXX'
          #q{/^.{3,8}$/}=>'длина логина должна боть от 3 до 8 символов',
        ],
        replace_rules=>[
          '/^8/'=>'+7',

           '/(^\(|,\s*\()/'=>'+7',

           '/[^\+\s\d,]/'=>'',
           '/(^\s+|[^,\d]\s+$)/'=>'',
           '/(^|,\s*)(9|4)/'=>'$1+7$2',
           '/(^|,\s*)[8]/'=>'+7',
           '/^(\d)/'=>'+$1',
           '/(,\s*)(\d)/'=>', +$2',
           '/(\d)\s(\d)/'=>'$1$2',
           '/(,\s*),/'=>'$1',
           '/(\d)\+7/'=>'$1, +7'
        ],
        tab=>'main'
      },
      {
        description=>'Имеет доступ в CRM',
        type=>'checkbox',
        name=>'enabled'
      },
      {
        description=>'Уволен',
        type=>'checkbox',
        name=>'gone'
      },
      {
        description=>'Дата увольнения',
        type=>'date',
        name=>'gone_date',
        #read_only=>1
      },

      # {
      #   description=>'Группа',
      #   name=>'group_id',
      #   type=>'select_from_table',
      #   table=>'manager_group',
      #   value_field=>'id',
      #   tree_use=>1
      # },
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
        autocomplete=>1,
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
        permissions=>sub{
          my $e=shift;
          # if($form->{script} eq 'multiconnect'){
          #   push @{$form->{errors}},'Вам запрещено просматривать права менеджеров';
          #   push @{$form->{errors}},'Вам запрещено просматривать права менеджеров';
          # }
          
        },
        description=>'Права менеджеров',
        type=>'multiconnect',
        tree_table=>'permissions',
        name=>'permissions',
        relation_table=>'permissions',
        relation_save_table=>'manager_permissions',
        relation_table_header=>'header',
        relation_save_table_header=>'header',
        relation_table_id=>'id',
        relation_save_table_id_worktable=>'manager_id',
        relation_save_table_id_relation=>'permissions_id',
        tree_use=>1,
        #cols=>3,
        before_code=>sub{
        },
        tab=>'permissions'
    },

    # {
    #   description=>'Статус',
    #   name=>'status',
    #   type=>'multiconnect',
    #   relation_table=>'user_kp_status',
    #   relation_table_header=>'header',
    #   relation_table_id=>'id',
    #   relation_save_table=>'user_kp_HAS_user_kp_status',
    #   relation_save_table_id_relation=>'user_kp_status_id',
    #   relation_save_table_id_worktable=>'user_kp_id',
    #   order=>'sort',
    #   code=>sub{
    #     my $e=shift;
    #     if($form->{manager}->{login}=~m/^(admin1|svetlana|annaya)$/){
    #       $e->{field}='<a href="./admin_tree.pl?config=user_kp_status" target="_blank">редактировать значения</a><br><br>'.$e->{field}
    #     }
    #     return q{<p><a href="#" onclick="$('.status_list').toggle(); return false;">показать / скрыть<a></p>}."<div class='status_list' style='display: none;'>$e->{field}</div>";
    #   }
    # },

      
    ]
};
