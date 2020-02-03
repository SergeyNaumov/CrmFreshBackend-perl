$form={
  title => 'Тарифы',
  work_table => 'tarif',
  work_table_id => 'id',
  make_delete => '1',
  default_find_filter => 'header',
  tree_use => '0',
  events=>{
    permissions=>sub{
      if($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{content}){
        if($form->{id}){
          my $sth=$form->{dbh}->prepare(q{
            SELECT
              wt.*, bd_b.attach blank_attach
            FROM
              tarif wt
              left join blank_document bd_b ON (wt.blank_bill_id = bd_b.id)
            WHERE wt.id=?
          });
          $sth->execute($form->{id});
          $form->{old_values}=$sth->fetchrow_hashref;
          #pre($form->{old_values});
        }
      }
      else{
        print_header();
        print "Доступ запрещён!" ; exit;
      }

      if($form->{manager}->{permissions}->{bill_notification}){
        push @{$form->{fields}},
        {
            description=>'Уведомление об окончании',
            name=>'notification_id',
            type=>'select_from_table',
            table=>'bill_notification',
            header_field=>'header',
            value_field=>'id',
            code=>sub{
              my $e=shift;
              $e->{field}.=qq{<a href="./admin_table.pl?config=bill_notification">управление уведомлениями</a>}
            }
        };
      }
    }
  },
  QUERY_SEARCH_TABLES=>
    [
      {table=>'tarif',alias=>'wt',},
      {table=>'blank_document',alias=>'bd_d',left_join=>1,link=>'wt.blank_dogovor_id = bd_d.id'},
      {table=>'blank_document',alias=>'bd_b',left_join=>1,link=>'wt.blank_bill_id = bd_b.id'},
      {table=>'blank_document',alias=>'bd_a',left_join=>1,link=>'wt.blank_act_id=bd_a.id'},
      {table=>'blank_document',alias=>'bd_f',left_join=>1,link=>'wt.blank_billfact_id=bd_a.id'},
      {table=>'bill_notification',alias=>'bn',left_join=>1,link=>'wt.notification_id=bn.id',for_fields=>['notification_id']}
    ],
	fields =>
	[
    {
      description=>'Вкл',
      type=>'checkbox',
      name=>'enabled',
      value=>1
    },
    {
      description=>'С НДС',
      type=>'checkbox',
      name=>'with_nds',
    },
    {
      description=>'Название тарифа',
      name=>'header',
      type=>'text',
      filter_code=>sub{
        my $s=$_[0]->{str};
        $s->{wt__header}=~s{([a-zA-Z]+)}{<span style="color: red;">$1</span>}g;
        return .$s->{wt__header}
      }

    },
    {
      description=>'Кол-во дней',
      name=>'count_days',
      type=>'text'
    },
    {
      description=>'Кол-во заявок',
      name=>'cnt_orders',
      type=>'text'
    },
    {
      description=>'Бланк для договора',
      table=>'blank_document',
      tablename=>'bd_d',
      type=>'select_from_table',
      header_field=>'header',
      value_field=>'id',
      name=>'blank_dogovor_id',
      regexp=>'^\d+$',
    },
    {
      description=>'Бланк для счёта',
      table=>'blank_document',
      tablename=>'bd_b',
      type=>'select_from_table',
      header_field=>'header',
      value_field=>'id',
      name=>'blank_bill_id',
      regexp=>'^\d+$',
      code=>sub{
        my $e=shift;
        if($form->{old_values}->{blank_attach}){
          $e->{field}.=qq{<br><a href="./files/blank_document/$form->{old_values}->{blank_attach}" target="_blank">скачать бланк</a>}
        }
        return $e->{field};
      }
    },

    {
      description=>'Бланк для акта',
      table=>'blank_document',
      tablename=>'bd_a',
      type=>'select_from_table',
      header_field=>'header',
      value_field=>'id',
      name=>'blank_act_id',
      regexp=>'^\d+$',
    },
    {
      description=>'Бланк для счёт-фактуры',
      table=>'blank_document',
      tablename=>'bd_f',
      type=>'select_from_table',
      header_field=>'header',
      value_field=>'id',
      before_code=>sub{
        my $e=shift;
        $e->{value}=99 if($form->{action} eq 'new');
      },
      name=>'blank_billfact_id',
      #regexp=>'^\d+$',
    },
    {
      description=>'Стоимость тарифа',
      name=>'summ',
      type=>'text',
    },
    {
      name=>'comment',
      description=>'Примечание к тарифу',
      type=>'textarea'
    },
    #{
    #  description=>'Уведомления об окончании тарифа',
    #  name=>'notification_end_paid',
    #  type=>'checkbox'
    #}
	]
};
