$form={
    title => 'Отправка писем',
    work_table => 'user_mail',
    work_table_id => 'id',
    default_find_filter => 'status user_id dogovor act schet_facture other_doc tracking',
    read_only => '1',
    make_delete=>'1',
    tree_use => '0',
    search_on_load=>'1',
    QUERY_SEARCH_TABLES=>
    [
      {table=>'user_mail',alias=>'wt',},
      {table=>'user',alias=>'u',link=>'wt.user_id = u.id',left_join=>1},
    ],
    plugins => [
      'find::address_list'
    ],
    events=>{
        permissions=>[
            sub{
                if(($form->{manager}->{login} eq 'admin')){
                    $form->{is_admin}=1
                }
            },
            sub{
                if($form->{is_admin} || $form->{manager}->{permissions}->{make_delete}){
                    $form->{make_delete}=1
                }
                if($form->{is_admin} || $form->{manager}->{permissions}->{manager_mail}){
                    $form->{read_only} = 0;
                }
            },
        ],
        before_search=>sub{


        },
        after_search=>sub{
            #pre(55);
        },
        # before_save=>sub{
            # if ($form->{new_values})
        # }
        after_save=>sub{
            # Если ставится статус 5, то автоматом отправляется в комментарий руководителя сообщение об этом и уведомление на почту менеджеру
            if($form->{values}{status}!='5' && $form->{new_values}{status}=='5') {
                my $message="Возврат $form->{new_values}{tracking} $form->{old_values}{status}";
                my $to;
                if($form->{manager}->{login}=~m{^(KSemenov|Stas)$}){
                    $to=$form->{dbh}->prepare("SELECT m.email from user u left join manager m on u.manager_sopr=m.id where u.id=?");
                    $to->execute($form->{new_values}{user_id});
                    $to=$to->fetchrow();
                }
                else{
                    $to=$form->{dbh}->prepare("SELECT m.email from user u left join manager m on u.manager_id=m.id where u.id=?");
                    $to->execute($form->{new_values}{user_id});
                    $to=$to->fetchrow;
                }
                my $sth=$form->{dbh}->prepare("INSERT INTO user_memo_owner(user_id,manager_id,registered,body) values('$form->{new_values}{user_id}','$form->{manager}->{id}',CURRENT_TIMESTAMP(),'$message')");
                $sth->execute();
                my $firm=$form->{dbh}->prepare("SELECT firm from user where id='$form->{new_values}{user_id}'");
                $firm->execute();
                $firm=$firm->fetchrow();
                my $s=&{$form->{self}};$s->send_mes({
                    to=>$to,
                    subject=>qq{Руководитель добавил комментарий в $firm},
                    message=>qq{
                        $form->{manager}->{name}  добавил комментарий в $firm<br>
                        <a href="https://crm.strateg.ru/edit_form.pl?config=user&action=edit&id=$form->{values}{user_id}">https://crm.strateg.ru/edit_form.pl?config=user&action=edit&id=$form->{values}{user_id}</a><br>
                        $form->{manager}->{name}: $message
                    }
                }) if($to)
            }
            
            
            #Если вводится номер отслеживания, то соответствующая запись идёт в комментарий руководителя и уведомление на почту менеджеру клиента+обновляется дата отправки
            if($form->{values}{tracking} ne $form->{new_values}{tracking}&& $form->{new_values}{tracking}=~m/^\d{14}$/){ 
                my $message="Номер отслеживания $form->{new_values}{tracking}";
                my $to;
                if($form->{manager}->{login}=~m{^(KSemenov|Stas)$}){
                    $to=$form->{dbh}->prepare("SELECT m.email from user u left join manager m on u.manager_sopr=m.id where u.id=?");
                    $to->execute($form->{new_values}{user_id});
                    $to=$to->fetchrow();
                }
                else{
                    $to=$form->{dbh}->prepare("SELECT m.email from user u left join manager m on u.manager_id=m.id where u.id=?");
                    $to->execute($form->{new_values}{user_id});
                    $to=$to->fetchrow;
                }
                my $sth=$form->{dbh}->prepare("INSERT INTO user_memo_owner(user_id,manager_id,registered,body) values('$form->{new_values}{user_id}','$form->{manager}->{id}',CURRENT_TIMESTAMP(),'$message')");
                $sth->execute();
                my $firm=$form->{dbh}->prepare("SELECT firm from user where id='$form->{new_values}{user_id}'");
                $firm->execute();
                $firm=$firm->fetchrow();
                my $s=&{$form->{self}};$s->send_mes({
                    to=>$to,
                    subject=>qq{Руководитель добавил комментарий в $firm},
                    message=>qq{
                        $form->{manager}->{name}  добавил комментарий в $firm<br>
                        <a href="https://crm.strateg.ru/edit_form.pl?config=user&action=edit&id=$form->{values}{user_id}">https://crm.strateg.ru/edit_form.pl?config=user&action=edit&id=$form->{values}{user_id}</a><br>
                        $form->{manager}->{name}: $message
                    }
                }) if($to);
                my $sth=$form->{dbh}->prepare("UPDATE user_mail set status=4 where id=$form->{id}");
                $sth->execute();
                my $sth=$form->{dbh}->prepare("UPDATE user_mail set date_send=CURRENT_TIMESTAMP() where id=$form->{id}");
                $sth->execute();
            }
         
        },
    },
    fields=>[
        # {
            # name=>'pre',
            # type=>'code',
            # code=>sub{
                # pre($form);
            # },
        # },
        {
            name=>'link',
            type=>'code',
            code=>sub{
                # my @links=(
                # {
                #     d=>qq{Карточка Компании},
                #     l=>qq{/edit_form.pl?config=user&action=edit&id=$form->{values}->{user_id}}
                # });
                # return join '<br>', map { return_link($_) } @links;     
                return qq{<a href="/edit_form.pl?config=user&action=edit&id=$form->{values}->{user_id}">Карточка Компании</a><br>}            
            }
        },
        {
            description=>'Статус',
            name=>'status',
            type=>'select_values',
            regexp=>'^\d+$',
            values=>[
                {v=>1,d=>'Заявка сформирована'},
                {v=>2,d=>'Есть вопросы'},
                {v=>3,d=>'Готов к отправке'},
                {v=>4,d=>'Отправлен'},
                {v=>5,d=>'Возврат'}
            ],
            filter_on=>1,
            value=>['1'],
            make_change_in_search=>'1',
        },
        {
            description=>'Комментарий',
            name=>'comment',
            type=>'textarea',
            make_change_in_search=>'1',
        },
        {
            description=>'Название компании',
            type=>'select_from_table',
            table=>'user',
            header_field=>'firm',
            value_field=>'id',
            name=>'user_id',
            autocomplete=>1,
            before_code=>sub{
                my $e=shift;
                if($form->{action} eq 'new'){
                    $e->{value}=param('user_id');
                }
                $e->{read_only}=1 if($form->{action}=~m{^(edit|update)$});
            },
            not_filter=>1,
            #filter_on=>'1',
        },
        {
            description=>'Название компании',
            type=>'filter_extend_text',
            name=>'firm_filter',
            tablename=>'u',
            db_name=>'firm',
            filter_on=>'1',
        },
        {
            description=>'Адрес',
            name=>'address',
            type=>'text'
        },
        {
            description=>'Договоры',
            name=>'dogovor',
            type=>'text',
            make_change_in_search=>'1',
            filter_on=>'1',
        },
        {
            description=>'Счёт-фактуры',
            name=>'schet_facture',
            type=>'text',
            make_change_in_search=>'1',
            filter_on=>'1',
        },
        {
            description=>'Акты',
            name=>'act',
            type=>'text',
            make_change_in_search=>'1',
            filter_on=>'1',
        },
        {
            description=>'Другие документы',
            name=>'other_doc',
            type=>'text',
            make_change_in_search=>'1',
            filter_on=>'1',
        },
        {
            description=>'Дата создания заявки',
            name=>'date_form',
            type=>'date',
            read_only=>'1',
            before_code=>sub{
                my $e=shift;
                if($form->{action} eq 'add_form'|| $form->{action} eq 'new'){
                    my ($d,$m,$y)=(localtime(time))[3,4,5];
                    $e->{value}=sprintf("%04d-%02d-%02d",$y+1900,$m+1,$d);
                }
            },
            after_insert=>sub{
                my $sth=$form->{dbh}->do("UPDATE user_mail set date_form=CURRENT_TIMESTAMP() where id=$form->{id}");
            }
        },
        {
            description=>'Дата отправки',
            name=>'date_send',
            type=>'date',
            before_code=>sub{
                my $e=shift;
                if($form->{action} eq 'add_form'){
                    my ($d,$m,$y)=(localtime(time))[3,4,5];
                    $e->{value}=sprintf("%04d-%02d-%02d",$y+1900,$m+1,$d);
                }
            }
        },
        {
            description=>'Номер отслеживания',
            name=>'tracking',
            type=>'text',
            make_change_in_search=>'1',
            filter_on=>'1',
        },
    ],
},