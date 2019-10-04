#$ENV{REMOTE_USER}='admin' if($ENV{REMOTE_USER} eq 'admin');
use lib './lib';
use coresubs;
use send_mes;
use tinymce_load_base64;
use field_operations;
use core_strateg;
use lib './conf/task.conf';
use permissions;

$form={
	title => 'Задачи',
	work_table => 'task',
	work_table_id => 'id',
	make_delete => '1',
	
	#read_only => '1',
	make_delete=>0,
	not_create=>1,
	tree_use => '0',
  GROUP_BY=>'wt.id',
  #explain=>1,
  javascript=>{
    include=>['./conf/task.conf/init.js'] # проверка на дубли
  },
  search_links=>[
    {link=>'./admin_table.pl?config=task_project',description=>'Проекты для задач',target=>'_blank'},
  ],
  QUERY_SEARCH_TABLES=>
    [
      {table=>'task',alias=>'wt'},
      {table=>'task_project',alias=>'tp',left_join=>1,link=>'wt.project_id=tp.id',for_fields=>['project_id']},
      {table=>'manager',alias=>'fm',link=>'wt.from_task=fm.id',for_fields=>['from_task']},
      {table=>'manager',alias=>'tm',link=>'wt.to_task=tm.id',for_fields=>['to_task']},
      {table=>'task_observe',alias=>'obs',link=>'wt.id=obs.task_id',left_join=>1}
    ],
    # 
    #   Ставить задачи (make_add_task)     
    #   Изменять исполнителя (task_change_isp)    
    #   Удалять задачи (make_del_task)     
    #   Редактирование проектов (adm_task_projects)    
    #  Р едактировать описание всех задач task_change_all_body change_all_task
  run=>{
      get_link=>sub{
        my $id=shift;
        if($id!~m{^\d+$}){
          $id=$form->{id}
        }
        return "https://crm.strateg.ru/edit_form.pl?config=task&action=edit&id=$id"
      },
      send_create_message=>sub{
        my %arg=@_;
        my %to=('sv@digitalstrateg.ru'=>1);

        
        # Добавляем в получаетели исполнителя
        my $to_task=param('to_task');
        if($to_task=~m{^(\d+)$}){
            my $sth=$form->{dbh}->prepare("SELECT email from manager where id=?");
            $sth->execute($to_task);
            my $email=$sth->fetchrow;
            if($email=~m/@/){
                $to{$email}=1;
            }
        }
        else{
            my $sth=$form->{dbh}->prepare(q{
              SELECT
                p.header,m.email,p.owner
              FROM
                task_project p join manager m ON (m.id=p.owner)
              where p.id=?
            });
            $sth->execute($arg{project_id});
            my $project=$sth->fetchrow_hashref;
            
            if($project->{email}){
              $to{$project->{email}}=1;
            }
            if($project->{owner}=~m{^\d+$}){
              $form->{dbh}->do("UPDATE task set to_task=$project->{owner} where id=$form->{id}");
            }
        }
        # собираем наблюдателей
        my $sth=$form->{dbh}->prepare("SELECT m.email from task_observe o join manager m ON m.id=o.manager_id where o.task_id=?");
        $sth->execute($form->{id});
        while(my $item=$sth->fetchrow_hashref){
          $to{$item->{email}}=1
        }
        

        if(scalar(keys %to)){
            my $link=&{$form->{run}->{get_link}};

            send_mes({
              from=>'no-reply@crm.strateg.ru',
              to=>join(',',keys(%to)),
              subject=>'Новая задача: '.$form->{new_values}->{header}.' | '.$project->{header},
              message=>qq{
                <p>Новая задача: <a href="$link">$form->{new_values}->{header}</a><br>
                <p>
                  <b>Проект:</b> $project->{header}<br>
                  <b>Постановщик:</b> $form->{manager}->{name}
                </p>
                <hr>
                
              }
            });
        }
      },
      get_to_addr=>sub{
          my %to=('sv@digitalstrateg.ru'=>1);
          return '' unless($form->{id});
          foreach my $e (($form->{old_values}->{fm__email}, $form->{old_values}->{tm__email})){
            if($e=~m{@} && $e ne $form->{manager}->{email}){
              $to{$e}=1
            }
          }

          my $sth=$form->{dbh}->prepare("SELECT email from manager m join task_observe o ON (m.id=o.manager_id) where o.task_id=?");
          $sth->execute($form->{id});
          while(my $item=$sth->fetchrow_hashref){
            if($item->{email}=~m{@}){
              $to{$item->{email}}=1;
            }
          }

          return join(',',(keys %to));
      },
      html_links=>sub{
        my $v=shift;
        $v=~s{([^"'>])(https?://[a-zA-Z0-9\._\/\?=&%-;]+)}{$1<a href="$2" target="_blank">$2</a>}gis;
        return $v
      }
  },
	events=>{
		permissions=>[
      sub{
          if($form->{action} eq 'notifications'){
              my $sth=$form->{dbh}->prepare(q{
                SELECT
                  wt.*,
                  fm.id fm__id, fm.name fm__name, fm.email fm__email, 
                  tm.id tm__id, tm.name tm__name, tm.email tm__email,
                  complete_date2 end_time
                FROM
                  task wt
                  LEFT JOIN manager fm ON (fm.id=wt.from_task)
                  LEFT JOIN manager tm ON (tm.id=wt.to_task)
                WHERE wt.status in (5,2)
              });
              $sth->execute();

              while(my $t=$sth->fetchrow_hashref){
                  my $link=&{$form->{run}->{get_link}}($t->{id});
                  my $message;
                  if($t->{status}=5){ # задача выполнена исполнителем
                    $message=qq{
                      $t->{tm__name} указал в задаче №$t->{id} <a href="$link">$t->{header}</a>, что завершил её ($t->{end_time}).<br>
                      Если Вы не согласны с тем, что задача завершена переведите её в состояние "на стороне исполнителя".<br>
                      Если задача действительно завершена и Вы согласны с этим -- переведите её в статус "Проверено, претензий нет"
                    };
                  }elsif($t->{status}==2){ # на согласовании у постановщика
                    $message=qq{
                      задаче №$t->{id} <a href="$link">$t->{header}</a> уже более суток находится в статусе "на согласовании у постановщика.<br>
                      сокрее всего исполнитель задачи запросил дополнительные сведения или задал вопрос.<br>
                      пожалуйста отреагируйте
                    };
                  }
                  else{
                    next;
                  }
                  
                  send_mes({
                    from=>'no-reply@crm.strateg.ru',
                    to=>$t->{fm__email},
                    subject=>"Задача №$t->{id} $t->{header}, отреагируйте",
                    message=>$message
                  });
              }

          }
      },
      sub{ # доступ в карту


        tinymce_load_base64::init($form,'./files/task');
        if($form->{id}){
          my $sth=$form->{dbh}->prepare(q{
            SELECT
              wt.*,
              fm.id fm__id, fm.name fm__name, fm.email fm__email, 
              tm.id tm__id, tm.name tm__name, tm.email tm__email
            FROM
              task wt
              LEFT JOIN manager fm ON (fm.id=wt.from_task)
              LEFT JOIN manager tm ON (tm.id=wt.to_task)
            WHERE wt.id=?
          });
          $sth->execute($form->{id});
          $form->{old_values}=$sth->fetchrow_hashref;
          $form->{title}=$form->{old_values}->{header};
        }

        if($form->{manager}->{permissions}->{make_add_task}){
            $form->{not_create}=0;
        }
        #pre($form->{manager});
        $form->{is_owner}=( # Права постановщика задачи
          $form->{manager}->{login}=~m{^(admin|svcomplex)$} || 
          ($form->{old_values}->{fm__id} eq $form->{manager}->{id})
        ) ;

        $form->{is_isp}=( # Права постановщика задачи
          $form->{manager}->{login}=~m{^(admin|svcomplex)$} || 
          ($form->{old_values}->{tm__id} eq $form->{manager}->{id})
        ) ;

        $form->{is_admin}=(
          $form->{manager}->{login}=~m{^(admin|svcomplex)$}
        );
        
        $form->{make_delete}=1 if($form->{is_admin} || $form->{manager}->{permissions}->{make_del_task});
        
        if(!$form->{is_admin} && !$form->{manager}->{permissions}->{view_all_task}){ # показываем только свои задачи
          $form->{add_where}="( wt.from_task=$form->{manager}->{id} OR wt.to_task=$form->{manager}->{id} OR obs.manager_id=$form->{manager}->{id} )";
        }

        #if(param('debug')){
        #  pre(&{$form->{run}->{get_to_addr}});
        #  exit;
        #}

      }
      
    ],
    before_update=>sub{

      #if($form->{new_values}->{registered} ne $form->{old_values}->{registered}){
      #  &{$form->{run}->{refresh_act_number}}($form->{id},$form->{new_values}->{registered});
      #}
    },
    after_save=>sub{

    },
    after_insert=>sub{
      #if(!$form->{new_values}->{to_task} && $form->{new_values}->{project_id}=~m{^\d+$}){
      &{$form->{run}->{send_create_message}}(
        project_id=>$form->{new_values}->{project_id}
      );
      #}
      my $set="registered = now()";
      my $sth=$form->{dbh}->prepare("UPDATE $form->{work_table} set $set where id = ?");
      $sth->execute($form->{id});
      
    },
    after_update=>sub{
      
      if($form->{new_values}->{status} && $form->{old_values}->{status} ne $form->{new_values}->{status}){
          my $status_hash=field_operations::select_values_hash(name=>'status',form=>$form);
          my $ns=$status_hash->{$form->{new_values}->{status}};
          my $os=$status_hash->{$form->{old_values}->{status}};

          
          my $link=&{$form->{run}->{get_link}};
          
          my $to_str=&{$form->{run}->{get_to_addr}};
          if($to_str=~m{@}){
              send_mes({
                from=>'no-reply@crm.strateg.ru',
                to=>$to_str,
                subject=>qq{Задача №$form->{id} $form->{old_values}->{header} Статус: $ns},
                message=>qq{
                  Только что $form->{manager}->{name}<br>
                  изменил статус задачи №$form->{id} <a href="$link">$form->{old_values}->{header}</a>:<br>
                  $os => $ns
                }
              });
          }
          
          if($form->{new_values}->{status}=~m{^(1|7)$}){
            # если задача была выполнена исполнителем, но её переводят обратно в работу -- сбрасываем дату
            $form->{dbh}->do("UPDATE task set complete_date2='0000-00-00 00:00:00' where id=$form->{id}");
          }
          if($form->{new_values}->{status}==5){
            # если задача закрывается исполнителем -- проставляем дату закрытия
            $form->{dbh}->do("UPDATE task set complete_date2=now() where id=$form->{id}");
          }

      }

      my $to_task=$form->{new_values}->{to_task};
      
      if($to_task=~m{^\d+$} && $to_task ne $form->{old_values}->{to_task}){
        my $to_addr=&{$form->{run}->{get_to_addr}};
        my $link=&{$form->{run}->{get_link}};
        
        my $sth=$form->{dbh}->prepare("SELECT name from manager where id=?");
        $sth->execute($to_task);
        my $to_name=$sth->fetchrow;

        my $from_name;
        my $sth=$form->{dbh}->prepare("SELECT name from manager where id=?");
        $sth->execute($form->{old_values}->{to_task});
        my $from_name=$sth->fetchrow;

        send_mes({
          from=>'no-reply@crm.strateg.ru',
          to=>$to_addr,
          subject=>qq{Задача №$form->{id} $form->{old_values}->{header} Новый исполнитель: $ns},
          message=>qq{
            Только что $form->{manager}->{name}<br>
            изменил исполнителя задачи №$form->{id} <a href="$link">$form->{old_values}->{header}</a>:<br>
            $from_name => $to_name
          }
        });
        
      }


    },
    before_search=>sub{
        my %arg=@_;
        $form->{select_fields}.=q{, 
          if(wt.complete_date1>'0000-00-00 00:00:00' and wt.complete_date1<now(),1,0) expired
        };
        if(param('order_price')){
          my $where=($arg{where}?" where $arg{where}":'');
          my $query="SELECT sum(price) from $arg{tables} $where";
          my $sth=$form->{dbh}->prepare($query);
          $sth->execute();
          my $total=$sth->fetchrow;
          print "$total";
        }
        
    },


	},
  # cols=>[ # Модель формы: Колонки / блоки
  #   [ # Колонка1
  #     #{description=>'Ссылки',name=>'links'},
  #     {description=>'Файлы',name=>'attaches'},
  #     {description=>'Сведения о задаче',name=>'main'},

  #   ],
  #   [
  #     {description=>'Сроки',name=>'dates'},
  #     {description=>'Работа',name=>'work'},
      
  #   ]
  # ],
	fields=>[
      {
        description=>'№',
        type=>'filter_extend_text',
        name=>'id',
        filter_type=>'range',
        filter_on=>1
      },
      { # Проект
        description=>'Проект',
        type=>'select_from_table',
        table=>'task_project',
        header_field=>'header',
        value_field=>'id',
        tablename=>'tp',
        name=>'project_id',
        regexp=>'^\d+$',
        tab=>'main'
      },
      {
        description=>'Наименование задачи',
        type=>'text',
        name=>'header',
        filter_on=>1,
        tab=>'main',
        filter_code=>sub{
          my $s=$_[0]->{str};
          my $out=$s->{wt__header};
          if($s->{wt__status}==5){ # выполнена исполнителем
            $out=qq{<span style="color: #469d00">$out<br><small>выполнена исполнителем</small></span>}
          }
          elsif($s->{wt__status}==6){ # проверено, претензий нет
            $out=qq{<span style="color: #037e22"><b>$out</b><br><small>проверена</small></span><b}
          }
          elsif($s->{expired}){
            $out.=qq{<br><div style="color: red;"><b>просрочена</b></div>}
          }
          return $out;
        }
      },
      {
        description=>'Постановщик задачи',
        type=>'select_from_table',
        name=>'from_task',
        table=>'manager',
        tablename=>'fm',
        before_code=>sub{
          my $e=shift;
          $e->{filter_value}=$form->{manager}->{id} if($form->{manager}->{permissions}->{task_customer} && !$form->{manager}->{permissions}->{task_performer});
          $e->{read_only}=1 if($form->{action} ne 'insert');
          if($form->{action}=~m{^(new|insert)$}){
            $e->{value}=$form->{manager}->{id};
          }
          my $list=core_strateg::select_managers_ids_from_perm($form,'task_customer');
          push @{$list},$e->{value} if($e->{value});
          $e->{where}='id IN ('.join(',',@{$list}).')';

          $e->{read_only}=0 if($form->{manager}->{permissions}->{task_change_customer} || $form->{is_admin});
        },
        header_field=>'name',
        value_field=>'id',
        tab=>'main',
        filter_on=>1
      },
      {
        description=>'Исполнитель задачи',
        type=>'select_from_table',
        name=>'to_task',
        table=>'manager',
        tablename=>'tm',
        header_field=>'name',
        value_field=>'id',
        not_view_on_create=>1,

        before_code=>sub{
          my $e=shift;
          $e->{filter_value}=$form->{manager}->{id} if($form->{manager}->{permissions}->{task_performer});
          if($form->{is_admin} || $form->{manager}->{permissions}->{task_change_isp}){
            $e->{read_only}=0; $e->{regexp}='^\d+$';
          }
          
          # выводим только исполнителей
          my $list=core_strateg::select_managers_ids_from_perm($form,'task_performer');
          push @{$list},$e->{value} if($e->{value});
          $e->{where}='id IN ('.join(',',@{$list}).')';
          
          
        },
        read_only=>1,
        filter_on=>1,
        tab=>'main',

      },

      {
        description=>'Описание',
        type=>'wysiwyg',
        name=>'body',
        tab=>'main',
        read_only=>1,
        before_code=>sub{
          my $e=shift;
          if($form->{action}=~m{^(insert|new)$}){
            $e->{read_only}=0;
          }

          if(($form->{is_owner} || $form->{manager}->{permissions}->{change_all_task}) && param('need_change_body')){
              $e->{read_only}=0;
          }

          if($e->{read_only}){
            $e->{value}=&{$form->{run}->{html_links}}($e->{value});
            $e->{value}=~s/<\/form>//gis;
            $e->{value}=~s/<form[^>]*>//gis;
          }

        },
        
        style=>'height: 800px;',
        full_str=>1,
        code=>sub{
          my $e=shift;
          if($e->{read_only}){
            #return $e->{value};
            $e->{field}=$e->{value}
          }
          if(form->{is_owner} || $form->{manager}->{permissions}->{change_all_task}){
            $e->{field}.=qq{<p><a href="?config=$form->{config}&action=edit&id=$form->{id}&need_change_body=1">РЕДАКТИРОВАТЬ</a></p>}
          }

          if(param('need_change_body')){
            $e->{field}.=qq{<input type="hidden" name="need_change_body" value="1">}
          }
          return $e->{field};
        }
      },

      {
        description=>'Комментарий по стоимости',
        name=>'price_comment',
        type=>'textarea',
        tab=>'main',
        read_only=>1,
        before_code=>sub{
          my $e=shift;
          $e->{read_only}=0 if($form->{is_admin})
        },
        filter_code=>sub{
          my $e=shift;
          my $s=$e->{str};
          if($form->{is_admin} || ($s->{wt__to_task}==$form->{manager}->{id})){
            $s->{wt__price_comment}=~s{\n}{<br>};
            return $s->{wt__price_comment};
          }
        },
        code=>sub{
          my $e=shift;
          if($form->{is_isp} || $form->{is_admin}){
            return $e->{field}
          }
          else{
            return '-'
          }
        }
      },
      {
        description=>'Стоимость работы',
        name=>'price',
        type=>'text',
        tab=>'main',
        regexp=>'^\d*$',
        read_only=>1,
        before_code=>sub{
          my $e=shift;
          $e->{read_only}=0 if($form->{is_admin})
        },
        filter_code=>sub{
          my $e=shift;
          my $s=$e->{str};
          if($form->{is_admin} || ($s->{wt__to_task}==$form->{manager}->{id})){
            return $s->{wt__price};
          }
        },
        code=>sub{
          my $e=shift;
          if($form->{is_isp} || $form->{is_admin}){
            return $e->{field}
          }
          else{
            return '-'
          }
        }
      },
      {
        description=>'Наблюдатели',
        name=>'observe',
        type=>'1_to_m',
        table=>'task_observe',
        table_id=>'id',
        foreign_key=>'task_id',
        fields=>[
          {description=>'Сотрудник',name=>'manager_id',type=>'select_from_table',table=>'manager',header_field=>'name',value_field=>'id'}
        ],
        after_save_code=>sub{
          my $e=shift;
          my $manager_id=$e->{fields}->[0]->{value};
          my $sth=$form->{dbh}->prepare("SELECT email,name from manager where id=?");
          $sth->execute($manager_id);
          my $m=$sth->fetchrow_hashref;
          my $to_addr=&{$form->{run}->{get_to_addr}};
          $link=&{$form->{run}->{get_link}};
          unless($form->{old_values}->{header}){
            $form->{old_values}->{header}=$form->{new_values}->{header}
          }

          
          send_mes({
            to=>$to_addr,
            subject=>qq{Задача №$form->{id} $form->{old_values}->{header}, Добавлен наблюдатель},
            message=>qq{
              <b>$form->{manager}->{name}</b> добавил(а) в задачу <a href="$link">№$form->{id} $form->{old_values}->{header}</a><br>
              <a href="$link">$link</a> нового наблюдателя: <b></b><br>
              
            }
          });
          if(exists($m->{email}) && $m->{email}){
            send_mes({
              to=>$m->{email},
              subject=>qq{Задача №$form->{id} $form->{old_values}->{header}, Добавлен наблюдатель},
              message=>qq{
                <b>$form->{manager}->{name}</b> добавил(а) в задачу <a href="$link">№$form->{id} $form->{old_values}->{header}</a><br>
                <a href="$link">$link</a> Вас в качестве наблюдателя
                
              }
            });
          }


          
        },
        
        tab=>'main'
      },
      {
        description=>'Приоритет',
        type=>'select_values',
        name=>'priority',
        read_only=>1,
        before_code=>sub{
          my $e=shift;
          $e->{read_only}=0 if($form->{manager}->{login}=~m{^(svcomplex|admin|skrash|Stas)$});
        },
        values=>[
          {v=>1,d=>'не срочно',c=>'green'},
          {v=>2,d=>'важно',c=>'yellow'},
          {v=>3,d=>'очень важно',c=>'orange'},
          {v=>4,d=>'критично',c=>'red'},
        ]
      },
      {
        description=>'Статус',
        name=>'status',
        type=>'select_values',
        values=>[
          {v=>1,d=>'На стороне Исполнителя'},
          {v=>2,d=>'На согласовании у Постановщика'},
          {v=>7,d=>'В работе'},
          {v=>3,d=>'Отложена'},
          {v=>4,d=>'Отклонена'},
          {v=>5,d=>'Выполнена исполнителем'},
          {v=>6,d=>'Проверено, претензий нет'},
        ],
        
        filter_on=>1,
        tab=>'work',
        before_code=>sub{
          my $e=shift;
          if($form->{script} eq 'admin_table.pl'){
            $e->{multiple_filter_size}=scalar(@{$e->{values}});
          }
          if($form->{action}=~m{^(new|insert)$}){
            $e->{value}=1;
          }
          if($form->{action}=~m{^new$}){
            $e->{read_only}=>1
          }
          if($form->{manager}->{permissions}->{task_performer}){
            $e->{filter_value}=[1,2,7] ;
          }
          elsif($form->{manager}->{permissions}->{task_customer}){
            $e->{filter_value}=[1,2,7,3,5];
          }
          
        },
        code=>sub{
          my $e=shift;
          if(!$form->{read_only} && $form->{script} eq 'edit_form.pl'){
            $e->{field}.='<p style="margin-top:20px"><input type="submit" value="сохранить"></p>'
          }
          return $e->{field}
          
        },
        filter_code=>sub{
          my $e=shift; my $s=$e->{str};
          #pre($e);
          my $status=$s->{wt__status};
          my $out=$e->{value};
          my $color='black';
          if( 
              ($status==1 && $s->{wt__to_task} == $form->{manager}->{id}) # ты исполнитель и "на стороне исполнителя"
                ||
              ($status=~m{^(2|5)$} && $s->{wt__from_task} == $form->{manager}->{id}) # ты постановщик и "на стороне постановщика" или "Выполнена исполнителем"
            ){ 
              $color='red'
          }
          elsif($status==7){
            $color='green'
          }
          return $out=qq{<span style="font-weight: bold; color: $color;">$out</span>};

        }
      },
      { # Комментарии
          description=>'Комментарии',
          full_str=>1,
          name=>'comments',
          type=>'memo',
          method=>'multitable',
          memo_table=>'task_comment',
          memo_table_id=>'id',
          memo_table_comment=>'body',
          memo_table_auth_id=>'manager_id',
          memo_table_registered=>'registered',
          memo_table_foreign_key=>'task_id',
          auth_table=>'manager',
          auth_login_field=>'login',
          auth_id_field=>'id',
          auth_name_field=>'name',
          reverse=>0,
          format=>q{<div id="[comment_id]" [style]> <b>[date]</b>  [edit_button] [delete_button] <span class="datetime">[hour]:[min]:[sec]  </span> [remote_name]<br><span class="message">[message]</span></div><hr>},
          memo_table_alias=>'c',
          auth_table_alias=>'cm',
          not_html=>1,
          before_code=>sub{

            
            #$e->{make_edit}=1 if($form->{manager}->{login} eq 'admin')
          },
          after_add=>sub{
              my $e=shift;
              my $message=$e->{message};
              my $link=&{$form->{run}->{get_link}};
              #my %to=();
              #$to{$form->{old_values}->{fm__email}}=1 if($form->{old_values}->{fm__email});
              #$to{$form->{old_values}->{tm__email}}=1 if($form->{old_values}->{tm__email}); 
              #$to{'sv@digitalstrateg.ru'}=1;
              my $to=&{$form->{run}->{get_to_addr}};
              send_mes({
                to=>$to,
                subject=>qq{Задача №$form->{id} $form->{old_values}->{header}, Новый комментарий},
                message=>qq{
                  <b>$form->{manager}->{name}</b> добавил(а) комментарий в задачу №$form->{id} <a href="$link">$form->{old_values}->{header}</a><br>
                  <a href="$form->{http_link}">$form->{http_link}</a><br>
                  $form->{manager}->{name}: $message
                }
              })
          },
          code=>sub{
            my $e=shift;
            $e->{field}=~s{width: auto; max-height: \d+px; overflow-y: scroll;}{width: auto; max-height: 800px; overflow-y: scroll;}gs;
            $e->{field}
          },
          #filter_on=>1,
          tab=>'work'
      },
      { # вложения
        name=>'attaches',
        type=>'1_to_m',
        table=>'task_attach',
        table_id=>'id',
        foreign_key=>'task_id',
        fields=>[
          {description=>'Комментарий',name=>'header',type=>'text'},
          {description=>'Файл',
            type=>'file',filedir=>'./files/task_attach',
            name=>'attach'
          }
        ],

        tab=>'attaches'
      },
      {
        description=>'Дата создания',
        name=>'registered',
        tablename=>'wt',
        type=>'datetime',
        read_only=>1,
        tab=>'dates',
        filter_on=>1,
        default_off=>1
      },
      {
        description=>'Выполнить до',
        name=>'complete_date1',
        type=>'datetime',
        before_code=>sub{
          my $e=shift;
          if($form->{action}=~m{^(new|insert)$} || $form->{old_values}->{fm__id}==$form->{manager}->{id}){
            $e->{read_only}=0
          }
        },
        read_only=>1,
        tab=>'dates',
        filter_on=>1,
        default_off=>1
      },
      {
        description=>'Закрыта исполнителем',
        name=>'complete_date2',
        read_only=>1,
        type=>'datetime',
        tab=>'dates'
      },
	],

};


