
$form={
	title => 'Главный мастар',
	work_table => 'main_master',
	work_table_id => 'id',
	make_delete => '0',
  not_create=>1,
  read_only=>1,
	tree_use => '0',
  unique_keys=>[['login']],

	events=>{
		permissions=>[
      sub{
        if($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{operator}){
            $form->{make_delete}=1;
            $form->{read_only}=0;
            $form->{not_create}=0,
        }
      }
      
    ],
  },

  QUERY_SEARCH_TABLES=>
  [
    {table=>'main_master',alias=>'wt'},
    
  ],
  search_on_load=>1,
  fields =>
  [
    {
      name => 'header',
      description => 'ФИО',
      type => 'text',
      tab=>'main',
      regexp_rules=>[
        '/^.+$/','обязательно укажите ФИО'
      ],
      filter_on=>1
    },


	]
};



