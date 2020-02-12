
$form={
	title => 'Реестр Си для поверителей',
	work_table => 'reestr_si',
	work_table_id => 'id',
	make_delete => '0',
  not_create=>1,
  read_only=>1,
	tree_use => '0',
  

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
    {table=>'reestr_si',alias=>'wt'},
    
  ],
  search_on_load=>1,
  fields =>
  [
    {name=>'id',read_only=>1,type=>'text',description=>'№',filter_on=>1},
    {
      name => 'header',
      description => 'Наименование в моей базе',
      type => 'text',
      regexp_rules=>[
        '/^.+$/','обязательно для заполнения'
      ],
      filter_on=>1
    },
    {
      name => 'header2',
      description => 'Наименование',
      type => 'text',
      regexp_rules=>[
        '/^.+$/','обязательно для заполнения'
      ],
      filter_on=>1
    },
    {
      name => 'type',
      description => 'Тип',
      type => 'textarea',
      regexp_rules=>[
        '/^.+$/','обязательно для заполнения'
      ],
      filter_on=>1
    },
    {
      name => 'num_gos',
      description => 'номер в госреестре',
      type => 'textarea',
      regexp_rules=>[
        '/^.+$/','обязательно для заполнения'
      ],
      filter_on=>1
    },
    {
      name => 'pov_h',
      description => 'межповерочный интервал х/в',
      type => 'text',
      regexp_rules=>[
        '/^\d+$/','укажите целое число'
      ],
      filter_on=>1
    },
    {
      name => 'pov_g',
      description => 'межповерочный интервал г/в',
      type => 'text',
      regexp_rules=>[
        '/^\d+$/','укажите целое число'
      ],
      filter_on=>1
    },
    {
      name => 'method',
      description => 'Методика поверки',
      type => 'textarea',
      regexp_rules=>[
        '/^.+$/','обязательно для заполнения'
      ],
      filter_on=>1
    },
	]
};



