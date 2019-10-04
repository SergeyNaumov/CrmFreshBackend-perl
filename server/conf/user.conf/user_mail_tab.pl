{
    full_str=>1,
    description=>'Отправка писем',
    name=>'mail',
    type=>'1_to_m',
    link_add=>'./edit_form.pl?config=user_mail&action=new&user_id=<%form.id%>',
    link_edit=>'./edit_form.pl?config=user_mail&action=edit&id=<%id%>',
    table=>'user_mail',
    table_id=>'id',
    foreign_key=>'user_id',
    read_only=>1,
    tab=>'docpack',
    #where_string=>'DATEDIFF(current_timestamp, date_send)<60 or (datediff(current_timestamp, date_form)<60 and datediff(current_timestamp, date_form) is not null)',
    #view_type=>'list',
    make_delete => '0',
    make_create=>1,
    before_code=>sub{
        my $e=shift;
        #pre($e);
        if($form->{is_admin} || $form->{manager}->{permissions}->{manager_mail}){
            $e->{read_only} = 0;
        }
    },
    order=>'date_send desc',
    #perpage=>2,
    #limit=>2,
    # slide_code=>sub{
        # <table class="table table-striped slide_1_to_m" id="mail">
            # <tbody>
                # <tr>
                    # <td><b>Статус</b></td><td><b>Дата создания заявки</b></td><td><b>Дата отправки</b></td><td><b>Номер отслеживания</b></td><td>&nbsp;</td>
                # </tr>
                # <tr id="mail_1tom_tr_258">
                    # <td>Отправлен</td>
                    # <td>0000-00-00</td>
                    # <td>2019-01-28</td>
                    # <td>10946931036664</td> 
                    # <td><a href="./edit_form.pl?config=user_mail&amp;action=edit&amp;id=258" target="_blank"><img src="/icon/edit.png"></a></td>    
                # </tr>   
            # </tbody>
        # </table>
    # },
    fields=>[
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
        },
        {
            description=>'Дата создания заявки',
            name=>'date_form',
            type=>'date',
            before_code=>sub{
                my $e=shift;
                if($form->{action} eq 'add_form'){
                    my ($d,$m,$y)=(localtime(time))[3,4,5];
                    $e->{value}=sprintf("%04d-%02d-%02d",$y+1900,$m+1,$d);
                }
            },
            before_search=>sub{
                $form->{add_where}='DATEDIFF(current_timestamp, date_send)<60 or (datediff(current_timestamp, date_form)<60 and datediff(current_timestamp, date_form) is not null)';
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
        }
    ],
    code=>sub{
        my $e=shift;
        if($form->{action} eq 'new'){
            return '-'
        }
        return $e->{field}
    }
}
