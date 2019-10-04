$form={
title => 'Группы менеджеров',
work_table => 'manager_group',
work_table_id => 'id',
header_field=>'header',
default_find_filter=>'<%header%>',
tree_use => '1',
make_delete=>1,
#sort=>'1',
events=>{
	permissions=>sub{
		unless($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{manager_adm}){
      #print_header();
      #print "Доступ запрещён!";
      #exit;
      push @{$form->{errors}},'Доступ запрещён!'
    }
	}
},
cols=>[ # Модель формы: Колонки / блоки
  [ # Колонка1
    {description=>'Общая информация',name=>'main'},
  ],
  [
    {description=>'Права',name=>'permissions'},
  ]
],
fields =>
[

	{
		description=>'Наименование',
		name=>'header',
		type=>'text',
    tab=>'main'
  },
  {
    name=>'owner_id',
    description=>'Руководитель',
    type=>'select_from_table',
    table=>'manager',
    value_field=>'id',
    header_field=>'name',
    order=>'name',
    tab=>'main'
  },
  {
    before_code=>sub{
            my $e=shift;                    
    },
    description=>'Права группы',
    type=>'relation_tree',
    name=>'permissions',
    relation_table=>'permissions',
    relation_save_table=>'manager_group_permissions',
    relation_table_header=>'header',
    relation_save_table_header=>'header',
    relation_table_id=>'id',
    relation_save_table_id_worktable=>'group_id',
    relation_save_table_id_relation=>'permissions_id',
    before_code=>sub{
#        my $e=shift;
#        pre($e);
    },
    tab=>'permissions'
  },
]
};
