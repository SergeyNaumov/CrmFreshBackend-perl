#use lib './extend/lib';
#use send_mes;
#use Data::Dumper;

$form={
    title => 'Выдача сертификатов',
    work_table => 'user_getting_cert',
    work_table_id => 'id',
    default_find_filter => 'priority status last_answer user_id',
    read_only => '1',
    make_delete=>'0',
    tree_use => '0',
    search_on_load=>'1',
    plugins => [
      'find::to_xls'
    ],
    QUERY_SEARCH_TABLES=>
    [
      {table=>'user_getting_cert',alias=>'wt',},
      {table=>'user',alias=>'u',link=>'wt.user_id = u.id',left_join=>1},
      {table=>'manager',alias=>'m',link=>'wt.manager_cert = m.id',left_join=>1},
      {table=>'user_cert',alias=>'uc',link=>'uc.user_id=wt.user_id',left_join=>1,for_fields=>['date_from']}
      #{table=>'user_getting_cert_doc',alias=>'docs',link=>'docs.user_getting_cert_id = wt.id',left_join=>1},
    ],
    events=>{
        permissions=>[
            # sub{
                # if($form->{action} eq 'new'){
                    # $form->{user_id}=param('user_id');
                    # pre($form->{user_id})
                # }
        
            # }
            # sub{
                # unless($form->{enabled}->{filter_on}){$form->{add_where}='wt.enabled=1'}
            # },
            sub{
                # #pre();
                if(($form->{manager}->{login} eq 'admin')){
                    $form->{is_admin}=1
                }
                # if($form->{id}){
                    # my $sth=$form->{dbh}->prepare(q{
                        # SELECT 
                        # uc.*,u.manager_id 
                        # from
                        # user_contact uc
                        # JOIN user u ON u.id=uc.user_id
                        # LEFT JOIN manager m ON m.id=u.manager_id
                        # where uc.id=?
                    # });
                    # $sth->execute($form->{id});
                    # if($form->{old_values}=$sth->fetchrow_hashref){
                        # $form->{is_owner_group}=($form->{old_values}->{group_id}~~$form->{manager}->{owner_groups});
                    # }
                # }
            },
            sub{
                if($form->{is_admin} || $form->{manager}->{permissions}->{make_delete}){
                    $form->{make_delete}=1
                }
                if($form->{is_admin} || $form->{manager}->{permissions}->{admin_cert}){
                    $form->{read_only} = 0;
                }
                if($form->{manager}->{permissions}->{manager_cert} && $form->{manager}->{id}==$form->{values}->{manager}){
                    $form->{read_only} =0
                }
        
                # if(
                # $form->{read_only} && 
                # (
                # ($form->{script} eq 'edit_form.pl' && $form->{action}=~m/^(insert|new)$/)
                # ||
                # (
                    # ($form->{old_values}->{manager_id} == $form->{manager}->{id})
                    # ||
                    # $form->{is_owner_group}
                    # ||
                    # ($form->{manager}->{permissions}->{edit_all_comp})
              
             
                # )
                # )
                # ){
                # # Если чел работает со своим клиентом -- разрешаем редактировать
                # $form->{read_only} = 0;
                # }
            },
        ],
        after_save=>sub{
            my @arr=('1','2','3','5','6','7','8','9','10','11','12','13');
            if($form->{new_values}->{inn}=~'^\d{10}$') {push @arr,'4','14','15','16'}
            #$form->{dbh}->do("UPDATE user_getting_cert_doc set comment='1' where id=1");
            foreach my $i (@arr)
            {
                my $sth=$form->{dbh}->prepare('SELECT count(*) from user_getting_cert_doc where user_getting_cert_id=? and type=?');
                    $sth->execute($form->{id},$i);
                    $sth=$sth->fetchrow();
                if(!$sth)
                {    
                    my $stb=$form->{dbh}->prepare("INSERT INTO user_getting_cert_doc(user_getting_cert_id, type) values(?,?)");
                    $stb->execute($form->{id},$i);
                }
                #$form->{dbh}->do("UPDATE user_getting_cert set priority=1 where id=$form->{id}")
            }
            my $sth=$form->{dbh}->do("UPDATE user_getting_cert set last_answer=CURRENT_TIMESTAMP() where id=$form->{id}");
        },
        before_search=>sub{
            if(param('order_date_from')){ # если включен фильтр "дата выдачи сертификата"
                $form->{select_fields}.=qq{, group_concat(uc.date_from SEPARATOR ' ; ') date_from_concat};
                $form->{GROUP_BY}='wt.id'
            }
            
        }
    },
    fields=>[
        {
            description=>'Дата выдачи сертификата',
            name=>'date_from',
            type=>'filter_extend_date',
            tablename=>'uc',
            filter_code=>sub{
                my $s=$_[0]->{str};
                return $s->{date_from_concat}
            }
        },
        {
            name=>'link',
            type=>'code',
            code=>sub{
                #my @links=(
                #{
                #    d=>qq{Карточка Компании},
                #    l=>qq{/edit_form.pl?config=user&action=edit&id=$form->{values}->{user_id}}
                #});
                #return join '<br>', map { return_link($_) } @links; 
                return qq{<a href="/edit_form.pl?config=user&action=edit&id=$form->{values}->{user_id}">Карточка Компании</a><br>}               
            }
        },
        {
            name=>'priority',
            type=>'select_values',
            read_only=>'1',
            description=>'Приоритет',
            values=>[
                {v=>1,d=>'1'},
                {v=>2,d=>'2'},
                {v=>3,d=>'3'},
            ],
            filter_on=>'1',
            filter_value=>'1',
            after_save=>sub{
                my $status=$form->{new_values}->{status};
                my $old_status=$form->{values}{status};
                if($status!=$old_status){
                    if ($status==3 || $status==5 || $status==6)
                    {
                        $form->{dbh}->do("UPDATE user_getting_cert set priority=1 where id=$form->{id}")
                    } 
                    elsif ($status==9 || $status==1)
                    {
                        $form->{dbh}->do("UPDATE user_getting_cert set priority=3 where id=$form->{id}")
                    }
                    else 
                    {
                        $form->{dbh}->do("UPDATE user_getting_cert set priority=2 where id=$form->{id}")
                    }
                    my $data = $form->{dbh}->selectrow_hashref("select u.firm,u.id, m.email from user_getting_cert ugc left join user u on ugc.user_id=u.id left join manager m on u.manager_id=m.id where ugc.id=$form->{id}");
                    my $message="<p>Статус изменён</p> 
                    <p>status$old_status -> status$status</p>
                    <a href=\"https://crm.strateg.ru/edit_form.pl?config=user&action=edit&id=$data->{id}\">Карточка компании $data->{firm}</a><br />
                    <a href=\"https://crm.strateg.ru/edit_form.pl?config=user_getting_cert_doc&action=edit&id=$form->{id}\">Карточка сертификации$data->{firm}</a>";
                    $message=~s/status1/Сертификация оплачена/gs;
                    $message=~s/status2/Ждём сканы/gs;
                    $message=~s/status3/Проверка сканов/gs;
                    $message=~s/status4/Ждём оригиналы/gs;
                    $message=~s/status5/Проверка оригиналов/gs;
                    $message=~s/status6/Составление отчёта/gs;
                    $message=~s/status7/Проверка завершена, подготовка к выпуску сертификата/gs;
                    $message=~s/status8/Сертификат выпущен/gs;
                    $message=~s/status9/Сертификат и договор отправлены/gs;
                    
                    $form->{self}->send_mes({
                        to=>$data->{email}.', krushin@digitalstrateg.ru',
                        subject=>qq{Изменён статус сертификации $data->{firm}},
                        message=>$message
                    });
                }
            },
        },
        {
            description=>'Менеджер сертификации',
            name=>'manager_cert',
            type=>'select_from_table',
            table=>'manager',
            header_field=>'name',
            value_field=>'id',
            read_only=>0,
            where=>'id in (select manager_id from manager_permissions where permissions_id=70)',
            before_code=>sub{
                my $e=shift;
                if($form->{manager}->{permissions}->{admin_cert} || $form->{manager}->{login} eq 'admin'){
                    $e->{read_only}=0
                }
            },
            tablename=>'m',
        },
        {
            description=>'Статус',
            name=>'status',
            type=>'select_values',
            regexp=>'^\d$',
            values=>[
                {v=>1,d=>'Сертификация оплачена'},
                {v=>2,d=>'Ждём сканы'},
                {v=>3,d=>'Проверка сканов'},
                {v=>4,d=>'Ждём оригиналы'},
                {v=>5,d=>'Проверка оригиналов'},
                {v=>6,d=>'Составление отчёта'},
                {v=>7,d=>'Проверка завершена, подготовка к выпуску сертификата'},
                {v=>8,d=>'Сертификат выпущен'},
                {v=>9,d=>'Сертификат и договор отправлены'},
            ],
            filter_on=>'1',
        },
        {
            description=>'Последнее изменение',
            name=>'last_answer',
            type=>'date',
            before_code=>sub{
                my $e=shift;
                if($form->{action} eq 'new'){
                    my ($d,$m,$y)=(localtime(time))[3,4,5];
                    $e->{value}=sprintf("%04d-%02d-%02d",$y+1900,$m+1,$d);
                }
            },
            filter_on=>'1',
            default_off=>'1'
        },
        {
            description=>'Сканы/оригиналы от клиента получены',
            name=>'docs_sent',
            type=>'date',
            before_code=>sub{
                my $e=shift;
                if($form->{action} eq 'new'){
                    my ($d,$m,$y)=(localtime(time))[3,4,5];
                    $e->{value}=sprintf("%04d-%02d-%02d",$y+1900,$m+1,$d);
                }
            },
            filter_on=>'1',
            default_off=>'1'
        },
        {
            description=>'Название компании',
            type=>'select_from_table',
            table=>'user',
            header_field=>'firm',
            value_field=>'id',
            name=>'user_id',
            autocomplete=>1,
            regexp=>'^\d+$',
            before_code=>sub{
                my $e=shift;
                if($form->{action} eq 'new'){
                    $e->{value}=param('user_id');
                }
                $e->{read_only}=1 if($form->{action}=~m{^(edit|update)$});
            },
            not_filter=>'1',
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
            description=>'ИНН',
            name=>'inn',
            type=>'text',
            regexp=>'^\d{10,12}$',
            before_code=>sub{
                my $e=shift;
                if($form->{action} eq 'new'){
                    my $sth=$form->{dbh}->prepare("SELECT inn FROM user where id=?");
                    $sth->execute(param('user_id'));
                    $sth=$sth->fetchrow();
                    $e->{value}=$sth;
                }
            }
        },
        {
            description=>'ОГРН',
            name=>'ogrn',
            type=>'text',
            before_code=>sub{
                my $e=shift;
                if($form->{action} eq 'new'){
                    my $sth=$form->{dbh}->prepare("SELECT ogrn FROM user where id=?");
                    $sth->execute(param('user_id'));
                    $sth=$sth->fetchrow();
                    $e->{value}=$sth;
                }
            }
        },
        {
            description=>'Комментарий',
            name=>'comment',
            type=>'textarea',
        },
        {
            description=>'Документы',
            name=>'docs',
            type=>'1_to_m',
            table=>'user_getting_cert_doc',
            table_id=>'id',
            foreign_key=>'user_getting_cert_id',
            order=>'type',
            fields=>[
                {
                    name=>'type',
                    description=>'Тип документа',
                    type=>'select_values',
                    regexp=>'\d*',
                    values=>[
                        {v=>1,d=>'Заявление'},
                        {v=>2,d=>'Анкета'},
                        {v=>3,d=>'Договор'},
                        {v=>4,d=>'Учредительные документы'},
                        {v=>5,d=>'Ген-директор, доверенность, паспорт(ИП)'},
                        {v=>6,d=>'ЕГРЮЛ/ЕГРИП'},
                        {v=>7,d=>'ОГРН Свидетельство о гос. регистрации ЮЛ/ ИП'},
                        {v=>8,d=>'ИНН Свидетельство о постановке на налоговый учет'},
                        {v=>9,d=>'Цепочка собственников'},
                        {v=>10,d=>'Лицензирование'},
                        {v=>11,d=>'Декларация соответствия требованиям'},
                        {v=>12,d=>'Опыт аналогичных договоров'},
                        {v=>13,d=>'Финансовая отчетность(налоговая для ИП)'},
                        {v=>14,d=>'Штатное расписание'},
                        {v=>15,d=>'Главный бухгалтер'},
                        {v=>16,d=>'Коллегиальный исполнительный орган'},
                        {v=>17,d=>'Недвижимость'},
                        {v=>18,d=>'Благодарственные письма'},
                        {v=>19,d=>'АО, выписка из реестра акционеров'},
                    ]
                },
                {
                    name=>'attach',
                    description=>'Документ',
                    filedir=>'./files/user_getting_cert',
                    type=>'file',
                    slide_code=>sub{
                        my $v=$_[0]->{value};
                        if ($v){
                            $v=~s{\s*<a .+?<\/a>\s*}{}gs;
                            $v=~s{(\s+|&nbsp;)$}{}gs;
                            return qq{<a target="_blank" href="./files/user_getting_cert/$v">открыть</a>};
                        } else {return qq{файл не загружен};}
                    }    
                },
                {
                    name=>'scan_ok',
                    description=>'Правильные сканы',
                    type=>'checkbox',
                    change_in_slide=>1,
                    before_code=>sub{
                        #my $e=shift; pre($e);
                    }
                },        
                {
                    description=>'Комментарий',
                    name=>'comment',
                    type=>'textarea',
                    change_in_slide=>1,
                },        
                {
                    name=>'orig_ok',
                    description=>'Правильные оригиналы',
                    type=>'checkbox',
                    change_in_slide=>1,
                },
            ],
        },
        {
            description=>'Вкл',
            type=>'checkbox',
            name=>'enabled',
            before_code=>sub{
                my $e=shift;
                $e->{value}=1 if($form->{action} eq 'new');
            }
        },
        {
            description=>'Сертификат',
            type=>'code',
            name=>'cert',
            code=>sub{
                return $form->{self}->template({
                    template=>'test_code.html',
                        vars=>{
                            a=>1,
                            b=>2
                        }
                    }
                );
                # my $sth=$form->{dbh}->prepare("SELECT id, number, date_from, date_to from user_cert where user_id=? order by date_from desc limit 1");
                #     $sth->execute($form->{values}{user_id});
                #     $sth=$sth->fetchrow_hashref();
                # if($sth){
                #     return ("<table border=\"1\"><tr><td>Номер сертификата:</td><td><a href=/tools/load_cert.pl?id=$sth->{id}>$sth->{number}</a></td></tr>
                #     <tr><td> от $sth->{date_from}</td><td>до $sth->{date_to}</td></tr></table>")
                # } else{
                #     return ("Сертификаты не найдёны")
                # }
                return '555';
            }
        }
    ],
},
