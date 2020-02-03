use lib './lib';

$form={
	title => 'История звонков',
	work_table => 'call_history',
	work_table_id => 'uid',
	make_delete => '1',
	default_find_filter => '',
	tree_use => '0',
  perpage=>20,
  make_delete=>0,
  read_only=>1,
  not_create=>1,
  not_edit=>1,
  javascript=>{
    #include=>['./conf/manager.conf/init.js?ns=1']
  },
  #explain=>1,
  plugins => [
     'find::to_xls'
  ],
	events=>{
		permissions=>[

    ]
	},
  QUERY_SEARCH_TABLES=>
    [
      {table=>'call_history',alias=>'wt',},
      {table=>'manager',alias=>'m',link=>'wt.manager_id = m.id',left_join=>1},
      {table=>'user',alias=>'u',link=>'wt.user_id = u.id', left_join=>1, for_fields=>['f_firm']},
    ],
	fields =>
	[
    {
      description=>'Идентификатор записи',
      name=>'uid',
      type=>'text',
      #filter_on=>1
    },
    {
      description=>'Организация',
      type=>'select_from_table',
      table=>'user',
      tablename=>'u',
      header_field=>'firm',
      value_field=>'id',
      autocomplete=>1,
      db_name=>'id',
      name=>'f_firm',
      filter_code=>sub{
        my $e=shift;
        return 'не известно: '.$e->{str}->{wt__client}.'' unless($e->{str}->{u__id});
        $e->{str}->{u__firm}='-' unless($e->{str}->{u__firm});
        return $s->{u__firm} if(param('plugin'));
        return qq{<a href="./edit_form.pl?config=user&action=edit&id=$e->{str}->{u__id}" target="_blank">$e->{str}->{u__firm}</a>}
      },
      filter_on=>1
    },
    {
      description=>'Тип звонка',
      name=>'type',
      type=>'select_values',
      values=>[
        {v=>1,d=>'входящий'},
        {v=>2,d=>'исходящий'},
        {v=>3,d=>'пропущенный'},
      ],
      filter_on=>1
    },

    {
      description=>'Сотрудник',
      type=>'select_from_table',
      table=>'manager',
      tablename=>'m',
      name=>'manager_id',
      header_field=>'name',
      value_field=>'id',
      filter_on=>1
    },
    {
      description=>'Время начала звонка',
      type=>'datetime',
      name=>'start',
      filter_on=>1
    },
    {
      description=>'Продолжительность звонка, сек',
      type=>'text',
      filter_type=>'range',
      name=>'duration',
      filter_on=>1
    },
    {
      description=>'Ссылка на запись',
      type=>'text',
      name=>'record',
      filter_on=>1,
      filter_code=>sub{
        my $str=$_[0]->{str}; 
        #print qq{<a href="$e->{str}->{wt__record}" target="_blank">слушать</a>};
        if($str->{wt__record}){
          return qq{<a href="$str->{wt__record}" target="_blank">слушать</a>}
        }
        #return '';
      }
    }
    
	]
};



