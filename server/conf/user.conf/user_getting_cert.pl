{
    full_str=>1,
    tab=>'cert',
    description=>'Выдача сертификатов',
    name=>'getting_certs',
    type=>'1_to_m',
    link_add=>'./edit_form.pl?config=user_getting_cert_doc&action=new&user_id=<%form.id%>',
    link_edit=>'./edit_form.pl?config=user_getting_cert_doc&action=edit&id=<%id%>',
    table=>'user_getting_cert',
    table_id=>'id',
    foreign_key=>'user_id',
    read_only=>0,
    tab=>'tab_cert',
    #view_type=>'list',
    make_delete => '0',
    make_create=>1,
    # before_code=>sub{
    #     my $e=shift;
    #     #pre($e);
    # },
    before_code=>sub{
        my $e=shift;
        if($form->{manager}->{login}=~m{^(skrash|admin|svcomplex)$}){
            
            $e->{make_delete}=1;
            #pre($e);
        }
    },
    fields=>[
        # {
            # description=>'Менеджер сертификации',
            # name=>'manager_cert',
            # type=>'select_from_table',
            # table=>'manager',
            # header_field=>'name',
            # value_field=>'id',
            # read_only=>0,
            # where=>'id in (select manager_id from manager_permissions where permissions_id=70)',
            # before_code=>sub{
                # my $e=shift;
                # if($form->{manager}->{permissions}->{change_manager_cert} || $form->{manager}->{login} eq 'admin'){
                    # $e->{read_only}=0
                # }
            # },
            # tablename=>'m',
        # },
        {
            description=>'Статус',
            name=>'status',
            type=>'select_values',
            regexp=>'^\d+$',
            values=>[
                {v=>1,d=>'Сертификация оплачена'},
                {v=>2,d=>'Ждём сканы'},
                {v=>3,d=>'Проверка сканов'},
                {v=>4,d=>'Ждём оригиналы'},
                {v=>5,d=>'Проверка оригиналов'},
                {v=>6,d=>'Составление отчёта'},
                {v=>7,d=>'Сертификат выпущен'},
                {v=>8,d=>'Сертификат и договор отправлены'},
            ],
            # slide_code=>sub{
            #     #pre(\@_);
            # }
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
                $e->{read_only}=1 if($form->{action}=~m{^(edit|update)$});
            }
        },
        {
            description=>'Последнее изменение',
            name=>'last_answer',
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
            description=>'Комментарий',
            name=>'comment',
            type=>'textarea',
        },
        {
            description=>'Вкл',
            type=>'checkbox',
            name=>'enabled'
        }
    ],
    code=>sub{
        my $e=shift;
        if($form->{action} eq 'new'){
            return '-'
        }
        return ''
    }
}
