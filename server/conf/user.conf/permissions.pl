 [
#       sub{

#         #pre($form->{manager}->{login});
#         if($form->{manager}->{login}=~m{^(KSemenov|skrash|admin|svcomplex)$}i){
#           #$form->{plugins} = ['find::to_xls'];
#         }
#       },
#       sub{
#         if($form->{action}=~m{^(new|insert)}){
#           #$form->{operations}->{remove_field}('certs');
#         }
#         #pre($form->{config});
#         if(!$form->{manager}->{permissions}->{view_all_users}){
#            if(exists($form->{manager}->{owner_groups}) && scalar(@{$form->{manager}->{owner_groups}}) 
#              ){
#                if($form->{manager}->{full_group_path}=~m{^\/14(\/|$)}){ # департамент рекламы-- разрешаем искать по свободной базе
#                  $form->{add_where}='(m.group_id IN ('.join(',',@{$form->{manager}->{owner_groups}}).') OR wt.manager_id=61)';
#                }
#                else{
#                  $form->{add_where}='m.group_id IN ('.join(',',@{$form->{manager}->{owner_groups}}).')';
#                }
#            }
#            else{
#              if($form->{manager}->{full_group_path}=~m{^\/14(\/|$)}){ # департамент рекламы -- разрешаем искать по свободной базе
#                $form->{add_where}=qq{ wt.manager_id IN ($form->{manager}->{id},61)};
#              }
#              else{
#                $form->{add_where}=qq{wt.manager_id=$form->{manager}->{id}};
#              }
#            }
#         }
#       },
#       sub{
#         if($form->{action} eq 'find_doubles'){
#           &{$form->{run}->{find_doubles}}();
#           exit;
#         }
        
#         if($form->{manager}->{login}=~m{^(skrash|admin)$}){
#           $form->{is_admin}=1
#         }
        
#       },
      sub{ # old_values

        use Plugin::Search::XLS;
        use Plugin::Search::CSV;
        #print Dumper({1=>$form->{QUERY_SEARCH_TABLES}});
        Plugin::Search::XLS::go($form);
        Plugin::Search::CSV::go($form);

        my $R=$form->{R};



        if($form->{id}){
          my $cur_begin_mon=&{$form->{run}->{cur_date}};
          $cur_begin_mon=~s{\d+$}{01 00:00:00};
          #pre($cur_begin_mon); exit;

          $form->{http_link}=qq{https://crm.strateg.ru/edit_form.pl?config=user&action=edit&id=$form->{id}};

          my $sth=$form->{dbh}->prepare(qq{
            SELECT
              wt.*,m.group_id,m.email m__email, m.name m__name,m.phone m__phone, m.mobile_phone m__mobile_phone,
              m.phone_dob m__phone_dob,
              mg.header mg__header,
              own.name own__name,own.email own__email, own.id own__id,
              if(im.id is null,0,1) im_exists,
              if(uo.id is null,0,1) user_optimization_exists,
              if(ao.id is null,0,1) anketa_optim_exists,
              if(ip.id is null,0,1) internet_project_exsists,
              if(smm.id is null,0,1) smm_exists,
              r.header region_header, r.timeshift region_timeshift,
              ms.id ms__id, ms.email ms__email
            FROM 
              user wt
              LEFT JOIN manager m ON m.id=wt.manager_id
              LEFT JOIN manager ms ON (wt.manager_sopr = ms.id)
              LEFT JOIN manager_group mg ON m.group_id=mg.id
              LEFT JOIN manager own ON (own.id=mg.owner_id)
              LEFT JOIN internet_market im ON (im.id=wt.id)
              LEFT JOIN user_optimization uo ON (uo.id=wt.id)
              LEFT JOIN anketa_optim ao ON (ao.id=wt.id)
              LEFT JOIN internet_project ip ON (wt.id=ip.id)
              LEFT JOIN smm ON (wt.id=smm.id)
              LEFT JOIN region r ON (wt.region_id=r.id)
            WHERE wt.id = ?
          });
          
          $sth->execute($form->{id});

          if($form->{old_values}=$sth->fetchrow_hashref()){
            #pre($form->{old_values});
            $form->{title}=$form->{old_values}->{firm};
            # # Не считаем сумму баллов, не используется
            # $sth=$form->{dbh}->prepare("SELECT sum(ball) from user_ball where user_id=? and registered>=? and manager_id=?");
            # $sth->execute($form->{id},$cur_begin_mon,$form->{old_values}->{manager_id});
            # $form->{old_values}->{BALL}=$sth->fetchrow();
            # $form->{old_values}->{BALL}=0 unless($form->{old_values}->{BALL});
            
            ##################### Блок не нужен
            # Операции с баллами
            # if($R->{cgi_params}->{action} eq 'ball_operation'){
            #   pre($R->{cgi_params});
            #   $s->print_header();
            #   my $value=$R->{cgi_params}->{value};
            #   if($value==1 || $value==-1){
            #     my $anti_value=$value*-1;
            #     # чтобы не накапливался мусор -- удаляем 
            #     #my $sth=$form->{dbh}->do("DELETE FROM user_ball WHERE user_id=? and registered>=? and manager_id=?")
            #     #$sth->execute($form->{id},$cur_begin_mon,$form->{old_values}->{manager_id});
                
            #     $sth=$form->{dbh}->prepare("INSERT INTO user_ball(user_id,registered,manager_id,manager_id_set,ball) values(?,now(),?,?,?)");
            #     $sth->execute($form->{id},$form->{old_values}->{manager_id},$form->{manager}->{id},$value);
                
            #     print $form->{old_values}->{BALL}+$value;
            #   }
            #   exit;
            # }
            
            $form->{is_owner_group}=($form->{old_values}->{group_id}~~$form->{manager}->{owner_groups});
            $form->{is_manager}=($form->{old_values}->{manager_id}==$form->{manager}->{id});
          }
          if($form->{old_values}->{manager_id}==61){ # если на менеджере "свободная база" -- разрешаем переводить на кого угодно
            $form->{read_only}=0;
          }          
          elsif(
            $form->{id} && !$form->{manager}->{permissions}->{view_all_users} && !$form->{is_admin} && !$form->{is_owner_group}
            && !($form->{old_values}->{manager_id} == $form->{manager}->{id})
          ){

            push @{$form->{errors}},"Доступ запрещён!";
            
          }
          

        }
      },
      # sub{
        
      #   if($form->{action} eq 'view_history' && $form->{id}){
      #     #use field_operations;
      #     $s->print_header();
         
      #     my $moment_list;
          
          
      #     my $sth=$form->{dbh}->prepare("SELECT MOMENT FROM user_history WHERE id=$form->{id} order by MOMENT desc");
      #     $sth->execute();
      #     $moment_list=[map {$_->{MOMENT}} @{$sth->fetchall_arrayref({})}];
          
      #     my $MOMENT=$form->{self}->param('MOMENT');
      #     $MOMENT=$moment_list->[0] unless($MOMENT);
          
      #     $sth=$form->{dbh}->prepare(q{
      #       SELECT h.body,m.name manager FROM 
      #         user_history h
      #         left join manager m ON m.id=h.manager_id
      #       WHERE h.id=? and h.MOMENT=?
      #     });
      #     $sth->execute($form->{id},$MOMENT);
      #     my $current=$sth->fetchrow_hashref;
          
      #     $sth=$form->{dbh}->prepare(q{
      #       SELECT h.body,m.name manager FROM 
      #         user_history h
      #         left join manager m ON m.id=h.manager_id
      #       WHERE h.id=? and h.MOMENT>? order by h.MOMENT limit 1
      #     });
      #     $sth->execute($form->{id},$MOMENT);
      #     my $next=$sth->fetchrow_hashref;
          
      #     if($next->{body}){
      #       $next->{body}=from_json($next->{body});
      #       $next->{body}=$next->{body}->[0];
      #     }
      #     else{
      #       $next={body=>$form->{old_values}};
      #     }
      #     #pre($next);

      #     if($current->{body}){
      #       $current->{body}=from_json($current->{body});
      #       $current->{body}=$current->{body}->[0];

            
            
      #       foreach my $n (qw(company_role status vajn)){
      #         #$current->{body}->{$n.'__v'}=field_operations::get_label_from_select_values(form=>$form,name=>$n,value=>$current->{body}->{$n});
      #       }
            
            
      #     }
          
      #     my $changed={};
          
      #     foreach my $k (keys(%{$current->{body}})){
      #       if($next->{body}->{$k} && ($current->{body}->{$k} ne $next->{body}->{$k})){
              
      #         $changed->{$k}=1;
      #       }
      #     }
      #     #pre($current->{'next_contact'} ne $next->{next_contact});
      #     #pre($changed);
      #     if(exists($current->{body}->{manager_id}) && $current->{body}->{manager_id}){
      #       my $sth=$form->{connects}->{strateg_read}->prepare("SELECT name FROM manager where id=?");
      #       $sth->execute($current->{body}->{manager_id});
      #       $current->{body}->{manager_name}=$sth->fetchrow;
      #     }
      #     template({
      #       template=>'./conf/user.conf/view_history.tmpl',
      #       vars=>{
      #         form=>$form,
      #         moment_list=>$moment_list,
      #         MOMENT=>$MOMENT,
      #         current=>$current,
      #         changed=>$changed
      #       },
      #       utf8=>1,
      #       print=>1
      #     });
      #     exit;
      #   }
        
      # },
      # sub{ # доступ в карту
        
      #   #$form->{make_delete} = 1 if($form->{manager}->{permissions}->{user_delete});
      #   if($form->{is_admin} || $form->{manager}->{permissions}->{make_delete}){
      #     $form->{make_delete}=1
      #   }
      #   if($form->{is_admin} || $form->{manager}->{permissions}->{edit_all_users}){
        
      #     $form->{read_only} = 0;
          
      #   }
      #   else{ # для смертным разрешаем видеть только их клиентов
          
      #     #$form->{add_where}=qq{ ( (wt.manager_id = $form->{manager}->{id}) OR ((wt.manager_id=0 OR wt.manager_id) IS NULL AND (status=0 OR status=1)) ) };
      #   }
      #   if(
      #       $form->{read_only} && 
      #       (
      #       ($form->{script} eq 'edit_form' && $form->{action}=~m/^(insert|new)$/)
      #       ||
      #       (
      #         ($form->{old_values}->{manager_id} == $form->{manager}->{id})
      #           ||
      #         $form->{is_owner_group}
      #           ||
      #         ($form->{manager}->{permissions}->{edit_all_users})
                
      #          # статус: не указан или "в базе"
      #       )
      #       )
      #   ){
      #       # Если чел работает со своим клиентом -- разрешаем редактировать
      #       $form->{read_only} = 0;
      #     }
      # },

      # sub{
      #     if($form->{self}->param('debug')){
      #       $form->{self}->pre($form->{manager}->{permissions}->{manager_sopr});
      #     }
      #     if($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{manager_sopr}){
      #       # если для менеджера сопр. форма закрыта -- разрешаем редактировать 2 поля: "состояние ОСО" и "Контакты"
      #       if($form->{read_only}){
      #         foreach my $f (@{$form->{fields}}){
      #           if($f->{name}=~m{^(contacts|memo_sopr|nuz|docpack)$}){
      #             $f->{read_only}=0;  
      #           }
      #           else{
      #             $f->{read_only}=1;
      #           }
      #         }
      #         $form->{read_only}=0;
      #       }
      #       #$e->{read_only}=0;
      #      }
          
      # },
      # sub {
      #   # меняем поля местами поля для комментарие в инструменте "пользователи сопр"
      #   return unless($form->{config} eq 'user_sopr');
      #   #use field_operations;
      #   foreach my $c (@{$form->{cols}}){
      #     foreach my $c2 (@{$c}){
      #       if($c2->{name} eq 'sopr'){
      #         $c2->{description}='Отдел продаж'
      #       }
      #     }
      #   }
      #   foreach my $f (@{$form->{fields}}){
      #       if($f->{name} eq 'memo'){
      #         $f->{description}='Комментарий Сопр';
      #         $f->{tab}='sopr'; $f->{description}='Комментарий ОП'
      #       }
      #       elsif($f->{name} eq 'memo_sopr'){
      #         $f->{tab}='work';
      #       }
      #       else{ next };
      #   }
      #   if($form->{id} && $form->{old_values}->{KEYFLD}=~m{^supplier_1_}){
      #               my $sth=$form->{dbh}->prepare(q{
      #                   SELECT
      #                    count(*) 
      #                   FROM
      #                      docpack d join bill b ON d.id=b.docpack_id where d.user_id=? and b.paid_to>=curdate()
      #                 });
      #               $sth->execute($form->{id});
      #               my $is_paid=
      #               $form->{is_paid}=$sth->fetchrow;
      #               my $read_only=1;

      #               if($form->{manager}->{login}=~m{^(admin|skrash|KSemenov|svcomplex)$}){
      #                 $read_only=0;
      #               }
      #               if($form->{manager}->{permissions}->{manager_sopr} && !$is_paid && !$form->{old_values}->{is_consult}){
      #                 $read_only=0;
      #               }
      #   }

      # }

 ]
