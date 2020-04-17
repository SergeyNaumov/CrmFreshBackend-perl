
$form={
	title => 'Мастер',
	work_table => 'master',
	work_table_id => 'id',
	make_delete => '0',
  not_create=>1,
  read_only=>1,
  explain=>1,
	tree_use => '0',
	events=>{
		permissions=>[
      sub{
        #pre($form->{manager}->{login});
        if($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{operator}){
            $form->{make_delete}=1;
            $form->{read_only}=0;
            $form->{not_create}=0,
        }
        if($form->{action} eq 'new'){
          $form->{title}='Создание мастера'
        }
      }
    ],
  },
  AJAX=>{
    check_number=>sub{
        my $s=shift; my $values=shift;
        my $where='tnumber=?';
        if($form->{id}=~m/^\d+$/){
          $where.=' AND id<>'.$form->{id}
        }

        my $exists=$s->{db_r}->query(
          query=>'select count(*) from master where '.$where,
          values=>[$values->{tnumber}],
          onevalue=>1
        );
        return [
          tnumber=>{
            error=>$exists?'такой табельный номер уже существует':''
          }
        ]
    }
  },
  search_on_load=>1,
  QUERY_SEARCH_TABLES=>
  [
    {t=>'master',a=>'wt'},
    {t=>'main_master',a=>'mm',l=>'mm.id=wt.main_master_id',lj=>1},
  ],
  fields =>
  [
    {
      description=>'Табельный номер',
      type=>'text',
      name=>'tnumber',
      frontend=>{
          ajax=>{
            name=>'check_number'
          }
      },
      regexp_rules=>[
        '/^\d{3}$/','состоит из трёх цифр'
      ],
      filter_on=>1
    },
    {
      name => 'header',
      description => 'ФИО мастера',
      type => 'text',
      tab=>'main',
      regexp_rules=>[
        '/^.+$/','обязательно укажите ФИО мастера'
      ],
      filter_on=>1
    },
    {
      description=>'Главный мастер',
      name=>'main_master_id',
      type=>'select_from_table',
      table=>'main_master',
      tablename=>'mm',
      header_field=>'header',
      value_field=>'id',
      before_code=>sub{
        my $e=shift;
        #pre($e);
      },
      regexp_rules=>[
        '/^\d+$/','обязательно выберите главного мастера'
      ],
      filter_on=>1
    },
	]
};



