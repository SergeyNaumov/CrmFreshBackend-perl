{
    name=>'links',
    tab=>'links',
    type=>'code',
    code=>sub{
        sub return_link{ # рутина для блока ссылок
          # join '<br>', map { return_link($_) } @links;
          my $e=shift;
          my $style=''; my $onclick=''; my $id='';
          $style="style='color: red;'" if($e->{mark});
          $onclick=qq{onclick='$e->{cl}'} if($e->{cl});
          $id=qq{id='$e->{id}'}if($e->{id});
          return $e->{d} unless($e->{l});
          return qq{<a href="$e->{l}" $style $onclick $id target="_blank">$e->{d}</a>};
        }
      #pre($form->{ol});
      #pre(7777);
      my @links=(
        {
                d=>qq{Карточка бухгалтера},
                l=>qq{/edit_form/buhgalter_card/$form->{id}}
        }
      );
        #pre($form->{manager});
        #pre($form);
        
        if($form->{id}){
            # my $sth=$form->{dbh}->prepare("SELECT * FROM anketa_promotion where display=1");
            # $sth->execute();
            # while(my $anketa=$sth->fetchrow_hashref){
            #   push @links, {
            #     d=>qq{Анкета - $anketa->{header}},
            #     l=>qq{/users/anketa_promotion_form.pl?anketa_id=$anketa->{id}&user_id=$form->{id}&use_saved_params=1}
            #   }
            # }

            if($form->{id} && ($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{edit_all_users})){
              push @links, {
                  d=>'<span style="color: red; font-weight: bold;">Удалить карту</span>',l=>qq{./delete_element.pl?config=user&id=$form->{id}},
                  cl=>q{return confirm("При удалении карт клиентов удаляться все их дочерние карты и комментарии.\n\nВосстановить будет сложно :)\nВы уверены?")}
              }
            }
            
            # КАРТОЧКА ИНТЕРНЕТ-МАРКЕТИНГА
            if($form->{old_values}->{im_exists}){
              push @links, {d=>'Карточка интернет-маркетинга',l=>qq{./edit_form/internet_market/$form->{id}}}
            }
            else{
              push @links, {
                  d=>'Создать карточку интернет-маркетинга',l=>qq{./edit_form.pl?config=internet_market&action=create_card&id=$form->{id}},
                  cl=>q{return confirm("Вы уверены?")}
              }
            }
            #pre($form->{old_values});
            #push @links, {d=>'Создать карту интернет-проектов',l=>qq{./edit_form.pl?config=internet_project&action=new&user_id=$form->{id}}};
            # КАРТОЧКА ОПТИМИЗАТОРА
            if($form->{old_values}->{user_optimization_exists}){
              push @links, {d=>'Карточка оптимизации',l=>qq{./edit_form/user_optimization/$form->{id}}}
            }
            elsif($form->{manager}->{optimize_permissions}->{superuser} || $form->{manager}->{optimize_permissions}->{ag_closers}){
              push @links, {
                  d=>'Создать карточку оптимизации',l=>qq{./edit_form.pl?config=user_optimization&action=create_card&id=$form->{id}},
                  cl=>q{return confirm("Вы уверены?")}
              }
            }

            # карточка согл. оптимизации
            if($form->{old_values}->{anketa_optim_exists}){
              push @links, {d=>'Карточка согласования оптимизации',l=>qq{./edit_form/anketa_optim/$form->{id}}}
            }
            else{
              push @links, {
                d=>'Создать карточку согласования оптимизации',
                l=>"./edit_form.pl?config=anketa_optim&action=create_card&id=$form->{id}",
                cl=>q{return confirm("Вы уверены?")}
              }
            };


            # SMM https://naumov.ia-trade.su/moderator/crm_fresh/edit_form.pl?config=smm&action=create_card&id=124
            if($form->{old_values}->{smm_exists}){
              push @links, {d=>'SMM',l=>qq{./edit_form/smm/$form->{id}}}
            }
            else{
              push @links, {
                  d=>'Создать карточку SMM',l=>qq{./edit_form.pl?config=smm&action=create_card&id=$form->{id}},
                  cl=>q{return confirm("Вы уверены?")}
              }
            }
            #https://naumov.ia-trade.su/moderator/crm_fresh/edit_form.pl?config=smm&action=create_card&id=124
            #pre($form->{old_values});
            # Карточка интернет-проектов
            if($form->{old_values}->{internet_project_exsists}){
              push @links, {d=>'Карточка интернет-проектов',l=>qq{./edit_form/internet_project/$form->{id}}}
            }
            elsif($form->{manager}->{permissions}->{internet_projects} || $form->{is_admin}){
              push @links, {
                  d=>'Создать карточку интернет-проектов',l=>qq{./edit_form.pl?config=internet_project&action=create_card&id=$form->{id}},
                  cl=>q{return confirm("Вы уверены?")}
              }
            }
            push @links,{d=>'История исправлений',l=>qq{?config=$form->{config}&id=$form->{id}&action=view_history}};

            push @links,{d=>'Калькулятор',l=>qq{/tools/calculate.pl?user_id=$form->{id}}};
        }

        return
          join '<br>', map { return_link($_) } @links;
    }
},
