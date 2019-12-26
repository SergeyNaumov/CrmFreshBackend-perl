    {
      description=>'Контакты',
      type=>'1_to_m',
      name=>'contacts',
      table=>'user_contact',
      table_id=>'id',
      foreign_key=>'user_id',
      full_str=>1,
      view_type=>'list',
      
      fields=>[
        {
          description=>'Логин пользователя',
          name=>'username',
          type=>'text',
          change_in_slide=>1
        },
        {
          description=>'Фамилия',
          name=>'last_name',
          type=>'text',
          change_in_slide=>1
        },
        {
          description=>'Имя',
          name=>'first_name',
          type=>'text'
        },
        {
          description=>'Отчество',
          name=>'middle_name',
          type=>'text'
        },

        {
          description=>'Телефон',
          name=>'phone',
          type=>'text',
          # раньше было несколько телефонов из-за ограничений Агоры сделали возможность только одного (либо пустое поле)
          #regexp=>'^(\+\d{6}\d*)$',
          
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
          change_in_slide=>1,
          # slide_code=>sub{
          #   my $e=shift; return unless $e->{value};
            
          #   my @out=();
            
          #   foreach my $p ((split/,\s*/,$e->{value})){
              
          #     if($p=~m{(^\+\d)(\d{3})(\d{3})(\d+)}){
          #       push @out,qq{$1&nbsp;($2)&nbsp;$3&nbsp;$4};
          #     }
          #   }
          #   unless(scalar(@out)){
          #     return qq{$e->{value} <span style="color: red; font-weight: bold; font-size: 8pt;">Неправильный формат</span>};
          #   }
          #   foreach my $p (@out){
          #     my $phone_for_call=$p; $phone_for_call=~s{^\+7}{8};
          #     $phone_for_call=~s{[^\d]}{}g;
          #     $p=qq{<a href="/tools/call_tel.pl?phone=$phone_for_call" target="forcall">$p</a>}
          #   }
          #   return join(',<br>', @out);
            
          # },
          code=>sub{
            my $e=shift;
            if($form->{script} eq 'load_1_to_m.pl' && $form->{action}=~m{^(add_form|edit)$}){
              $e->{field}.=
              '<br><br>&nbsp;&nbsp;в формате: +[код_страны][код_города][телефон],<br>'
            }

            return $e->{field};
          }
        },
        {
          description=>'Email',
          name=>'email',
          type=>'text'
        },
        {
          description=>'Верифицированный email',
          type=>'checkbox',
          read_only=>1,
          before_code=>sub{
            my $e=shift;
            $e->{read_only}=0 if($form->{manager}->{permissions}->{admin_paids} || ($form->{manager}->{login} eq 'admin'));
          },
          name=>'verify_email'
        },
        {
          description=>'Должность',
          name=>'position',
          type=>'text',
          tab=>'comp'
        },
        {
          description=>'Комментарий',
          name=>'comment',
          type=>'textarea',
        },
      ],
      after_insert_code=>sub{
        my $e=shift;
        my $username=param('username');
        my $add_set='';
        unless($username=~m{\S+}){
          $add_set=q{,username=concat('user_2_',id)};
        }
        #my $sth=$form->{dbh}->prepare("UPDATE user_contact set KEYFLD=concat('user_2_',id),last_update=now()$add_set where id=?");
        #$sth->execute($e->{id});

      },
      after_update_code=>sub{
        my $e=shift;
        #my $sth=$form->{dbh}->prepare("UPDATE user_contact set last_update=now() where id=?");
        #$sth->execute($e->{id});
      },
      code=>sub{
        my $e=shift;
        return '<small>доступно после добавления компании</small>' if($form->{action} eq 'new');
        return 
            qq{<p><a href="./tools/user_contact_history.pl?id=$form->{id}" target="_blank">история изменения контактов</a></p>}.
            '<br>Строка вызова: <iframe name="forcall" style="width: 100%; height: 50px;"></iframe>';
      },
      before_update_code=>sub{
            my $sth=$form->{dbh}->prepare("SELECT * from user_contact where user_id=?");
            $sth->execute($form->{id});
            my $contacts=$sth->fetchall_arrayref({});
            
            
            foreach my $c (@{$contacts}){
              foreach my $k ((keys %{$c})){
                Encode::_utf8_on($c->{$k});
              }
            }
            my $contacts_json=$form->{self}->to_json($contacts);
            $sth=$form->{dbh}->prepare("SELECT (body=?) from user_contact_history where id=? order by moment desc limit 1");
            $sth->execute($contacts_json,$form->{id});
            my $body_exists=$sth->fetchrow();
            unless($body_exists){
              $sth=$form->{dbh}->prepare("INSERT INTO user_contact_history(id,moment,body,manager_id) values(?,now(),?,?)");
              $sth->execute($form->{id},$contacts_json,$form->{manager}->{id});
            }
      },
      before_delete_code=>sub{
            my $sth=$form->{dbh}->prepare("SELECT * from user_contact where user_id=?");
            $sth->execute($form->{id});
            my $contacts=$sth->fetchall_arrayref({});
            
            
            foreach my $c (@{$contacts}){
              foreach my $k ((keys %{$c})){
                Encode::_utf8_on($c->{$k});
              }
            }
            my $contacts_json=$form->{self}->to_json($contacts);
            $sth=$form->{dbh}->prepare("SELECT (body=?) from user_contact_history where id=? order by moment desc limit 1");
            $sth->execute($contacts_json,$form->{id});
            my $body_exists=$sth->fetchrow();
            unless($body_exists){
              $sth=$form->{dbh}->prepare("INSERT INTO user_contact_history(id,moment,body,manager_id) values(?,now(),?,?)");
              $sth->execute($form->{id},$contacts_json,$form->{manager}->{id});
            }
      },
      tab=>'comp'
    }
