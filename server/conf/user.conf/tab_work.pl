 # правая часть
{
  description=>'Проконсультирован',
  tab=>'work',
  name=>'is_consult',
  type=>'switch',
  make_change_in_search=>1,
  # before_code=>sub{
  #   my $e=shift;
  #   #if($e->{value}){
  #   #  $e->{color}='red';
  #   #  $e->{read_only}=1;
  #   #}
  #   if($e->{value} && $form->{id} && $form->{old_values}->{KEYFLD}=~m{^supplier_1_}){
  #                   my $color='green';
  #                   if(!$form->{is_paid} && $form->{old_values}->{is_consult}){
  #                     $e->{color}='red';
  #                   }
  #                   else{
  #                     $e->{color}='green';
  #                   }
  #   }
  # },
  # code=>sub{
  #   my $e=shift;
  #   return 'after777';
  #   #return $e->{field}.'<script>$(document).ready(function(){$("h1").css("color","'.$e->{color}.'");})</script>'
  # }
},
{
  description=>'Не экспортировать',
  name=>'not_export',
  type=>'checkbox',
  tab=>'work',
  before_code=>sub{
    my $e=shift;
    $e->{value}=1 if($form->{action} eq 'new');
    if($form->{manager}->{permissions}->{op_not_export} || $form->{manager}->{login} eq 'admin'){
      $e->{read_only}=0
    }
  },
  read_only=>1
},
{
  description=>'Статус',
  name=>'status',
  regexp=>'^\d+$',
  #type=>'select_values',
  type=>'select_from_table',
  table=>'status',
  tablename=>'s',
  header_field=>'header',
  value_field=>'id',
  tab=>'work'
},
{
  description=>'Важность',
  name=>'vajn',
  type=>'select_values',
  regexp=>'^\d+$',

  values=>[
    {v=>'1',d=>'Минимальная',c=>'green'},
    {v=>'2',d=>'Средняя',c=>'yellow'},
    {v=>'3',d=>'Высокая',c=>'red'},
  ],
  tab=>'work'
},
{
  name=>'state',
  description=>'Состояние',
  type=>'select_values',
  onchange=>'set_color_for_state_pr()',
  style=>'width: 50%',
  values=>[
    {v=>'0',d=>'Другое',c=>'#FFFFFF'},
    {v=>'1',d=>'Ждем материалы от клиента',c=>'#CC99FF'},
    {v=>'2',d=>'Сделать медиаплан',c=>'#FFFF00'},
    {v=>'3',d=>'Сделать креатив',c=>'#FF0000'},
    {v=>'4',d=>'Работа с сайтом',c=>'#99CCFF'},
    {v=>'5',d=>'Мониторить рекламу',c=>'#CCFFCC'},
    {v=>'6',d=>'Сделать отчет',c=>'#FF6600'},
    {v=>'7',d=>'Работа закончена',c=>'#DDDDDD'},
    {v=>'8',d=>'Отправлять напоминание',c=>'#24FF00'},
    {v=>'9',d=>'Выставлен счёт',c=>'#99CCFF'},
    {v=>'10',d=>'Переговоры по продлению',c=>'#800080'},
    {v=>'11',d=>'Сделать конкурентный анализ',c=>'#84193C'},
    {v=>'12',d=>'Согласование УТП',c=>'#164775'},
    {v=>'13',d=>'Совместная работа',c=>'#c1f498'},
  ],
  tab=>'work',
  before_update=>sub{
    my $new_value=$form->{new_values}->{state_pr};
    if($new_value ne $form->{values}->{state_pr} && $new_value eq '7'){ # Если состояние меняем на "Работа закончена"

    }
    
  },
},
{
  description=>'Менеджер',
  type=>'select_from_table',
  name=>'manager_id',
  name=>'manager_id',
  table=>'manager',
  tablename=>'m',
  header_field=>'name',
  value_field=>'id',
  #read_only=>1,
  make_change_in_search=>1,
  order=>'gone, name',
  before_code=>sub{
    my $e=shift;
    #pre($form->{manager}->{permissions});
    if($form->{manager}->{permissions}->{edit_all_users} || $form->{manager}->{login} eq 'admin'){
      $e->{read_only}=0;
    }
    if($form->{action} eq 'insert' && $e->{read_only}){
      $e->{value}=$form->{manager}->{id};
      $e->{read_only}=0;
    }
    elsif($form->{action} eq 'new' && $e->{read_only}){
      $e->{value}=$form->{manager}->{id};
    }
    if($e->{read_only} && $e->{value}==61){
      $e->{where}=qq{id IN ($form->{manager}->{id},61)};
      $e->{read_only}=0
    }
    
    if($e->{read_only} && ($form->{is_owner_group} || $form->{is_manager})){
      $e->{where}=qq{id IN ($form->{manager}->{id},61)};
      $e->{read_only}=0;
    }
    #if($e->{value}==61 && ($form->{is_owner_group} || $form->{is_manager}) ){
        
        
    #}
    #pre($e);
  },
  code=>sub{
    my $e=shift;
    my $ov=$form->{old_values};
    my @addons=();
    my $field='';

    push @addons, qq{ телефон: <a href="tel:$ov->{m__phone}">$ov->{m__phone}</a>} if($ov->{m__phone});
    push @addons, qq{, доб. $ov->{m__phone_dob}} if($ov->{m__phone_dob});
    push @addons, '<br>' if(scalar(@addons));
    push @addons, qq{мобильный: <a href="tel:$ov->{m__mobile_phone}">$ov->{m__mobile_phone}</a> ; } if($ov->{m__mobile_phone});
    push @addons, qq{ <a href="mailto:$ov->{m__email}">$ov->{m__email}</a>} if($ov->{m__email});
    push @addons, qq{<br>группа: $ov->{mg__header} ; } if($ov->{mg__header});
    push @addons, qq{руководитель: $ov->{own__name}} if($ov->{own__name});
    
    if(scalar(@addons)){
      $field.='<br><small>'.join('',@addons).q{</small>};
    }
    
    return $field
  },
  tab=>'work'
},

{
  description=>'Дата последнего визита',
  name=>'last_login',
  type=>'date',
  read_only=>1,
  tab=>'work',
},
{
  description=>'Дата и время создания',
  name=>'registered',
  type=>'datetime',
  read_only=>0,
  tab=>'work',
},
{
  [%INCLUDE './conf/user.conf/field_memo.pl'%]
  tab=>'work'
},
{
  description=>'Следующий контакт',
  type=>'datetime',
  name=>'next_contact',
  tab=>'work'
},
{ # Комментарий руководителя
    description=>'Комментарий руководителя',
    name=>'memo_owner',
    type=>'memo',
    method=>'multitable',
    memo_table=>'user_memo_owner',
    memo_table_id=>'id',
    memo_table_comment=>'body',
    memo_table_auth_id=>'manager_id',
    memo_table_registered=>'registered',
    memo_table_foreign_key=>'user_id',
    auth_table=>'manager',
    auth_login_field=>'login',
    auth_id_field=>'id',
    auth_name_field=>'name',
    reverse=>1,
    #format=>'<span style="color: blue;">[mday]/[mon]/[year] [hour]:[min]:[sec] [remote_name]</span> [message]<br>',
    format=>q{<div id="[comment_id]"> <b>[date]</b>  [edit_button] [delete_button] <span class="datetime">[hour]:[min]:[sec]  </span> [remote_name] <span class="message">[message]</span></div>},
    memo_table_alias=>'memo_own',
    auth_table_alias=>'m_memo_own',
    read_only=>1,
    before_code=>sub{
      my $e=shift;
      if(
        $form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{user_add_memo_owner} ||
        $form->{is_owner_group}
      ){
        $e->{read_only}=0;

      }
      #$e->{make_edit}=1 if($form->{manager}->{login} eq 'admin')
    },
    after_add=>sub{
        my $e=shift;
        
        my $message=param('message');
        my $to;
        if($form->{manager}->{login}=~m{^(KSemenov|Stas)$}){
          $to=$form->{old_values}->{ms__email};
        }
        else{
          $to=$form->{old_values}->{m__email};
        }

        send_mes({
          to=>$to,
          subject=>qq{Руководитель добавил комментарий в $form->{old_values}->{firm}},
          message=>qq{
            $form->{manager}->{name}  добавил комментарий в $form->{old_values}->{firm}<br>
            <a href="$form->{http_link}">$form->{http_link}</a><br>
            $form->{manager}->{name}: $message
          }

        }) if($to)
    },
    code=>sub{
      my $e=shift;
      my $field='';
      if($form->{id}){
        my $sth=$form->{dbh}->prepare("SELECT registered,body from user_memo_owner where user_id=$form->{id} and manager_id=46 order by registered desc limit 1");
        $sth->execute();
        if(my $item=$sth->fetchrow_hashref){
          $e->{before_html}=qq{
            <div style="border: 1px solid black; padding: 10px; color: red">
              $item->{body}
            </div>
          }
        }
      }
      return '';
    },
    tab=>'work'
},

{
    description=>'Напоминания о контакте',
    name=>'notification',
    type=>'1_to_m',
    table=>'user_notification',
    table_id=>'id',
    foreign_key=>'user_id',
    fields=>[
        {description=>'Оповестить в',type=>'datetime',name=>'moment'},
        {description=>'Тема',type=>'text',name=>'subject'},
        {description=>'Текст',type=>'textarea',name=>'message'},
        {description=>'Отправлено',type=>'checkbox',name=>'sent',read_only=>1},
    ],
    tab=>'work'
},
{
  description=>'Баллы (руководитель)',
  type=>'code',
  name=>'ball',
  code=>sub{
    my $e=shift;
    return qq{<a href="" class="ball_dec">-</a> <span id="ball">$form->{old_values}->{BALL}</span> <a href="" class="ball_inc">+</a>}
  },
  tab=>'work'
},
# {
#   description=>'Следующий контакт (руководитель)',
#   type=>'datetime',
#   name=>'next_contact_owner',
#   tab=>'work'
# },
{
  description=>'Звонки',
  type=>'1_to_m',
  name=>'calls',
  table=>'call_history',
  table_id=>'uid',
  foreign_key=>'user_id',
  full_str=>1,
  fields=>[
      {
        description=>'Тип звонка',
        name=>'type',
        type=>'select_values',
        values=>[
          {v=>1,d=>'входящий'},
          {v=>2,d=>'исходящий'},
          {v=>3,d=>'пропущенный'},
        ],
      },
      {
        description=>'Сотрудник',
        type=>'select_from_table',
        table=>'manager',
        name=>'manager_id',
        header_field=>'name',
        value_field=>'id',
      },
      {
        description=>'Время начала звонка',
        type=>'datetime',
        name=>'start',
        
      },
      {
        description=>'Продолжительность звонка, сек',
        type=>'text',
        filter_type=>'range',
        name=>'duration',
        
      },
      {
        description=>'Ссылка на запись',
        type=>'text',
        name=>'record',
        
        filter_code=>sub{
          my $e=shift;
          if($e->{str}->{wt__record}){
            return qq{<a href="$e->{str}->{wt__record}" target="_blank">слушать</a>}
          }
          return '';
        },
        slide_code=>sub{
          my $e=shift; my $v=shift;
          #use Data::Dumper; print Dumper({v=>$v});
          return '' unless($v->{record});
          return qq{<a href="$v->{record}" target="_blank">слушать</a>}
        }
      }
  ],
  code=>sub{
    my $e=shift;
    qq{<a href="./find_objects.pl?config=call_history&__page=0&f_firm=$form->{id}&order_f_firm=1&type=&order_type=2&manager_id=&order_manager_id=3&order_start=4&order_duration=5&record=&order_record=6" target="_blank">посмотреть все звонки $form->{old_values}->{firm}</a>};
  },
  perpage=>5,
  read_only=>1,
  not_edit=>1,
  order=>'start desc',
  tab=>'work'
},
# { 
#   name=>'btn',
#   tab=>'work',
#   type=>'code',
#   full_str=>1,
#   code=>sub{
#     return qq{
#       <div style="text-align: center; margin-top: 20px; margin-bottom: 20px;">
#         <input type="submit" value="сохранить данные" class="submit_button">
#       </div>
#     }
#   }
# },
{
  name=>'nuz',
  description=>'НУЗы',
  type=>'1_to_m',
  table=>'user_nuz',
  table_id=>'id',
  foreign_key=>'user_id',
  tab=>'work',
  before_code=>sub{
    my $e=shift;
    if($form->{action} eq 'add_form'){
      $e->{fields}->[0]->{tree_use}=0
    }
  },

  fields=>[
    {
      description=>'Дирекция здравоохранения',
      name=>'nuz_id',
      type=>'select_from_table',
      table=>'nuz',
      header_field=>'header',
      value_field=>'id',
      autocomplete=>1,
      order=>'sort',
      tree_use=>1,

    }
  ]
},
{ # фильтр по НУЗам
  description=>'НУЗ',
  name=>'f_nuz',
  tablename=>'nuz',
  type=>'filter_extend_select_from_table',
  db_name=>'header',
  table=>'nuz',
  header_field=>'header',
  value_field=>'id',
  db_name=>'id',
  order=>'sort',
  tree_use=>1
},
# {
#     description=>'Данные клиентских сайтов',
#     type=>'code',
#     name=>'hosting',
#     full_str=>1,
#     code=>sub{

#         my $sth=$form->{dbh}->prepare(q{
#             SELECT
#                 ph.header, d.domain, ph.testdomain, ph.born_date, ph.hosting_paid_to, (ph.size_project + ph.size_template) total_size,
#                 ph.paid_on_year,ph.id
#             FROM
#                 project_hosting ph
#                 LEFT join domain d ON (d.domain_id = ph.domain_id)
#                 join project p ON (p.project_id=d.project_id)
#             WHERE crm_id=?
#         });
#          $sth->execute($form->{id});
#          my $hosting_list=$sth->fetchall_arrayref({});
#          return 
#              template({
#                  template=>'./conf/internet_project.conf/hosting.tmpl',
#                  vars=>{hosting_list=>$hosting_list},
#              });
        
#     },
#     tab=>'work'
# },